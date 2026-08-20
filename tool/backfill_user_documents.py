#!/usr/bin/env python3
"""Backfill the per-user documents this app assumes already exist.

Every user owns a top-level Firestore collection named after their uid, holding
a fixed set of documents. Nothing creates those documents up front -- they come
into being the first time something is written to them -- but the app writes
with `update()`, which fails with `not-found` on a missing document instead of
creating it. `signup.dart` only ever created the original eleven, so every
account made before Seen, SeenWith, Friends, Notifications, Recommendations,
RewatchedTV and FavWriters were added is missing them, and every write to one
throws.

This script creates the missing documents empty, and repairs friendships that
were left one-sided by the same bug: accepting a request updates BOTH users'
Friends documents, and when the sender had no Friends document that second
write threw inside an unawaited handler, so the friendship was only half
recorded. That in turn makes the security rules deny access, because they read
friendship from the target's list.

Every write here is additive. Nothing is deleted, no existing field is altered,
and no friendship is invented -- a pair is only made symmetric when one side
already claims it. Documents are created with the shapes `objects/user.dart`
expects, so an older client that still calls `update()` simply stops throwing.

Runs read-only by default and prints what it would do. Pass --apply to write.

    python tool/backfill_user_documents.py --key path\\to\\service-account.json
    python tool/backfill_user_documents.py --key ... --apply

The service account key is a credential: keep it out of the repository.
"""

import argparse
import json
import sys

import requests
import google.auth.transport.requests
from google.oauth2 import service_account

PROJECT = "actordb-cf981"

# The shape each document must have when created. `Friends` is the only one
# that needs a field: user.dart does `friends = f["friends"]` and then calls
# `.add()` on the result, so an empty map would leave it null and crash. The
# rest are read by iterating their keys, which an empty document satisfies.
STANDARD_DOCS = {
    "Country": {},
    "Calendar": {},
    "FavActors": {},
    "FavDirectors": {},
    "FavWriters": {},
    "Favorites": {},
    "Movies": {},
    "TVShows": {},
    "Watchlist": {},
    "Seen": {},
    "SeenWith": {},
    "Reviews": {},
    "Rewatched": {},
    "RewatchedTV": {},
    "Friends": {"friends": []},
    "Notifications": {},
    "Recommendations": {},
}

# Settings is deliberately absent: it is the public profile, it always exists
# already, and fabricating an empty one would create a profile with no username.

# Top-level collections that are not user collections. The first three are
# shared app data; the rest are dead legacy collections with no reference
# anywhere in lib/, left over from earlier versions.
NOT_USER_COLLECTIONS = {
    "Watchlists", "Oscars", "usernames",
    "Actors", "Admin", "AllMovies", "AllMoviesIds", "ExploreMovies",
    "Reviews", "lb_backup3",
}


def to_firestore_value(value):
    if isinstance(value, list):
        return {"arrayValue": {"values": [to_firestore_value(v) for v in value]}}
    if isinstance(value, str):
        return {"stringValue": value}
    if isinstance(value, bool):
        return {"booleanValue": value}
    if isinstance(value, int):
        return {"integerValue": str(value)}
    if isinstance(value, dict):
        return {"mapValue": {"fields": {k: to_firestore_value(v)
                                        for k, v in value.items()}}}
    raise TypeError(f"unsupported value: {value!r}")


class Firestore:
    def __init__(self, key_path):
        creds = service_account.Credentials.from_service_account_file(
            key_path, scopes=["https://www.googleapis.com/auth/datastore"])
        creds.refresh(google.auth.transport.requests.Request())
        self.headers = {"Authorization": f"Bearer {creds.token}"}
        self.name_prefix = (f"projects/{PROJECT}/databases/(default)/documents")
        self.base = f"https://firestore.googleapis.com/v1/{self.name_prefix}"

    def collection_ids(self):
        ids, token = [], None
        while True:
            body = {"pageSize": 300}
            if token:
                body["pageToken"] = token
            r = requests.post(f"{self.base}:listCollectionIds",
                              headers=self.headers, json=body)
            r.raise_for_status()
            payload = r.json()
            ids += payload.get("collectionIds", [])
            token = payload.get("nextPageToken")
            if not token:
                return ids

    def document_ids(self, collection):
        names, token = [], None
        while True:
            params = {"pageSize": 100}
            if token:
                params["pageToken"] = token
            r = requests.get(f"{self.base}/{collection}",
                             headers=self.headers, params=params)
            if not r.ok:
                return names
            payload = r.json()
            names += [d["name"].rsplit("/", 1)[1]
                      for d in payload.get("documents", [])]
            token = payload.get("nextPageToken")
            if not token:
                return names

    def get(self, path):
        r = requests.get(f"{self.base}/{path}", headers=self.headers)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.json().get("fields", {})

    def create(self, path, data):
        """Create a document, refusing to overwrite one that already exists."""
        collection, doc_id = path.rsplit("/", 1)
        r = requests.post(
            f"{self.base}/{collection}",
            headers=self.headers,
            params={"documentId": doc_id},
            json={"fields": {k: to_firestore_value(v) for k, v in data.items()}},
        )
        r.raise_for_status()

    def append_to_friends(self, uid, friend_uid):
        """Add one uid to a friends array, leaving every other field alone.

        `appendMissingElements` is the server-side equivalent of the client's
        `FieldValue.arrayUnion`, so running this twice adds nothing the second
        time and no other field of the document is read or rewritten.
        """
        r = requests.post(
            f"{self.base}:commit",
            headers=self.headers,
            json={"writes": [{
                "transform": {
                    "document": f"{self.name_prefix}/{uid}/Friends",
                    "fieldTransforms": [{
                        "fieldPath": "friends",
                        "appendMissingElements": {
                            "values": [{"stringValue": friend_uid}]
                        },
                    }],
                },
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
    verb = "creating" if args.apply else "would create"

    collections = [c for c in db.collection_ids()
                   if c not in NOT_USER_COLLECTIONS]

    # A collection without a Settings document is an abandoned sign-up rather
    # than an account, and giving it documents would not make it a real user.
    users, skipped = [], []
    existing = {}
    for uid in collections:
        docs = db.document_ids(uid)
        existing[uid] = set(docs)
        (users if "Settings" in existing[uid] else skipped).append(uid)

    print(f"{len(collections)} candidate collections, {len(users)} real "
          f"accounts, {len(skipped)} skipped as abandoned sign-ups\n")

    created = 0
    touched_users = 0
    for uid in users:
        missing = [d for d in STANDARD_DOCS if d not in existing[uid]]
        if not missing:
            continue
        touched_users += 1
        print(f"{uid}: {verb} {', '.join(missing)}")
        for doc_id in missing:
            if args.apply:
                db.create(f"{uid}/{doc_id}", STANDARD_DOCS[doc_id])
            created += 1
            existing[uid].add(doc_id)

    print(f"\n{created} documents across {touched_users} accounts\n")

    # Reload friends lists now that every account has a Friends document, then
    # make every claimed friendship mutual. Only pairs where one side already
    # lists the other are repaired; no relationship is invented.
    friends = {}
    for uid in users:
        fields = db.get(f"{uid}/Friends") or {}
        values = fields.get("friends", {}).get("arrayValue", {}).get("values", [])
        friends[uid] = [v.get("stringValue") for v in values]

    repairs = []
    for uid, listed in friends.items():
        for other in listed:
            if other in friends and uid not in friends[other]:
                repairs.append((other, uid))

    verb = "adding" if args.apply else "would add"
    for target, missing_friend in repairs:
        print(f"{target}: {verb} {missing_friend} back to their friends list")
        if args.apply:
            db.append_to_friends(target, missing_friend)
            friends[target].append(missing_friend)

    print(f"\n{len(repairs)} one-sided friendships repaired")

    unknown = sorted({o for lst in friends.values() for o in lst
                      if o not in friends})
    if unknown:
        print("\nfriend uids with no account in this project, left alone:")
        for uid in unknown:
            print(f"    {uid}")

    if not args.apply:
        print("\nNothing was written. Re-run with --apply to perform these "
              "changes.")


if __name__ == "__main__":
    sys.exit(main())
