#!/usr/bin/env python3
"""Backfill `memberUids` on every playlist.

A playlist records who can see it in `Users`, a list of single-key maps
mapping a uid to a role: [{uidA: "Owner"}, {uidB: "Approved"}]. Firestore
cannot query that for membership -- `arrayContains` matches a whole element,
and the role is part of the element, so you cannot ask "is this uid in here"
without already knowing their role. That is the only reason the app downloaded
the entire Watchlists collection and filtered it on the device: to find the
handful of lists one user belongs to, it read everybody's.

`memberUids` is the flat, queryable projection of `Users`. The
`syncPlaylistMembers` Cloud Function keeps it current from here on, but a
trigger only fires when a document is written, so playlists that nobody
touches would never gain the field. This script fills it in once for the
documents that already exist.

Every write is additive and touches one field. The update mask names only
`memberUids`, so nothing else in the document is read back, rewritten, or at
risk. Running it twice changes nothing the second time, and a playlist whose
field is already correct is skipped without a write.

Deploy the function BEFORE running this. In the other order, any playlist
written between the backfill and the deploy would be missed.

Runs read-only by default and prints what it would do. Pass --apply to write.

    python tool/backfill_playlist_members.py --key path\\to\\service-account.json
    python tool/backfill_playlist_members.py --key ... --apply

The service account key is a credential: keep it out of the repository.
"""

import argparse
import sys

import requests
import google.auth.transport.requests
from google.oauth2 import service_account

PROJECT = "actordb-cf981"


def member_uids_from(users_field):
    """The uids in a raw Firestore `Users` array value.

    Mirrors memberUidsFrom() in functions/playlist_members.js and
    PlaylistService.memberUidsFrom in the client. Sorted, so the comparison
    below is positional and the three implementations agree on the result.

    Anything that is not a map of uid to role is skipped rather than raising:
    these documents were written by several years of client versions and are
    not guaranteed to be well formed.
    """
    if not users_field:
        return []

    uids = []
    for element in users_field.get("arrayValue", {}).get("values", []):
        fields = element.get("mapValue", {}).get("fields")
        if not isinstance(fields, dict):
            continue
        for uid in fields:
            if uid and uid not in uids:
                uids.append(uid)
    return sorted(uids)


def existing_member_uids(field):
    """The stored `memberUids`, or None if the field is absent.

    Absent and empty are different: an empty list is a playlist with no
    members, which is already correct and needs no write.
    """
    if field is None:
        return None
    values = field.get("arrayValue", {}).get("values", [])
    return [v.get("stringValue") for v in values]


class Firestore:
    def __init__(self, key_path):
        creds = service_account.Credentials.from_service_account_file(
            key_path, scopes=["https://www.googleapis.com/auth/datastore"])
        creds.refresh(google.auth.transport.requests.Request())
        self.headers = {"Authorization": f"Bearer {creds.token}"}
        self.name_prefix = f"projects/{PROJECT}/databases/(default)/documents"
        self.base = f"https://firestore.googleapis.com/v1/{self.name_prefix}"

    def playlists(self):
        """Every document in Watchlists, as (id, fields) pairs."""
        token = None
        while True:
            params = {"pageSize": 100}
            if token:
                params["pageToken"] = token
            r = requests.get(f"{self.base}/Watchlists",
                             headers=self.headers, params=params)
            r.raise_for_status()
            payload = r.json()
            for doc in payload.get("documents", []):
                yield doc["name"].rsplit("/", 1)[1], doc.get("fields", {})
            token = payload.get("nextPageToken")
            if not token:
                return

    def set_member_uids(self, doc_id, uids):
        """Write memberUids and nothing else.

        The update mask limits the write to one field, so a playlist being
        edited on someone's phone at this moment cannot lose that edit. The
        currentDocument precondition means a list deleted mid-run is not
        resurrected by this script.
        """
        r = requests.post(
            f"{self.base}:commit",
            headers=self.headers,
            json={"writes": [{
                "update": {
                    "name": f"{self.name_prefix}/Watchlists/{doc_id}",
                    "fields": {
                        "memberUids": {
                            "arrayValue": {
                                "values": [{"stringValue": u} for u in uids]
                            }
                        }
                    },
                },
                "updateMask": {"fieldPaths": ["memberUids"]},
                "currentDocument": {"exists": True},
            }]},
        )
        r.raise_for_status()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--key", required=True,
                        help="path to a service account JSON key")
    parser.add_argument("--apply", action="store_true",
                        help="perform the writes; omit to preview them")
    args = parser.parse_args()

    db = Firestore(args.key)

    total = 0
    needed = 0
    written = 0
    empty = 0

    for doc_id, fields in db.playlists():
        total += 1
        expected = member_uids_from(fields.get("Users"))
        current = existing_member_uids(fields.get("memberUids"))

        if not expected:
            # A playlist with no readable members. Left alone and reported:
            # it is either corrupt or orphaned, and inventing members for it
            # is not this script's job.
            empty += 1
            print(f"  {doc_id}: no members found in Users -- skipped")
            continue

        if current == expected:
            continue

        needed += 1
        name = fields.get("Name", {}).get("stringValue", "?")
        print(f"  {doc_id} ({name}): {current!r} -> {expected!r}")

        if args.apply:
            db.set_member_uids(doc_id, expected)
            written += 1

    print()
    print(f"playlists scanned:        {total}")
    print(f"needing memberUids:       {needed}")
    print(f"with no usable Users:     {empty}")
    if args.apply:
        print(f"updated:                  {written}")
    else:
        print("\nDry run. Nothing was written. Pass --apply to perform it.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
