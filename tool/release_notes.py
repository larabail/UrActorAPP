#!/usr/bin/env python3
"""Generate Play release notes from conventional commit subjects.

Only user-facing types are included. A dependency bump or a refactor matters
to us and means nothing to someone reading a store listing, so `chore`, `ci`,
`refactor`, `test`, `docs`, `build` and `style` are dropped. Subjects that are
not conventional commits at all cannot be classified, so they are dropped too
rather than leaking raw developer shorthand into the store.

A commit subject is written for other developers, so it sometimes describes
internals that should not appear on a public listing. Any commit can override
its own note with a trailer:

    Release-Note: Fixed a problem that could sign you out unexpectedly.
    Release-Note: skip

`skip` excludes the commit even if its type would normally be included.

Play rejects notes longer than 500 characters per language, so the output is
trimmed to fit rather than being sent and refused.

Usage:
    python tool/release_notes.py --output release_notes.json
    python tool/release_notes.py --since build-46 --stdout
"""

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys

MAX_CHARS = 500

# Ordered by how much a user cares. When the notes have to be trimmed, the
# last section loses its entries first.
SECTIONS = [
    ("feat", "New"),
    ("fix", "Fixed"),
    ("perf", "Improved"),
    ("security", "Security"),
]
INCLUDED = {t for t, _ in SECTIONS}

SUBJECT = re.compile(
    r"^(?P<type>[a-z]+)(?:\((?P<scope>[^)]*)\))?(?P<breaking>!)?:\s*(?P<text>.+)$"
)
TRAILER = re.compile(r"^Release-Note:\s*(?P<text>.+)$", re.IGNORECASE | re.MULTILINE)
RECORD = "\x1e"  # commit separator; safe because it cannot appear in a message

FALLBACK = "Bug fixes and performance improvements."


def git(*args: str) -> str:
    result = subprocess.run(["git", *args], capture_output=True, text=True,
                            encoding="utf-8")
    if result.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def previous_tag() -> str | None:
    """The most recent build tag, which marks the last thing testers received."""
    tags = git("tag", "--list", "build-*", "--sort=-v:refname").splitlines()
    return tags[0].strip() if tags else None


def commits(since: str | None, until: str = "HEAD") -> list[str]:
    """Full messages in the range, one entry per commit."""
    rev = f"{since}..{until}" if since else until
    log = git("log", rev, "--no-merges", f"--format=%s%n%b{RECORD}")
    return [c.strip() for c in log.split(RECORD) if c.strip()]


def polish(text: str) -> str:
    """Turn a commit subject into a sentence a stranger can read."""
    text = text.strip().rstrip(".")
    # Commit subjects are imperative ("fix the crash"); a bullet reads better
    # as a statement, but rewriting tense reliably is not possible here, so
    # only the capitalisation is normalised.
    return text[:1].upper() + text[1:] if text else text


def collect(since: str | None, until: str = "HEAD") -> dict[str, list[str]]:
    grouped: dict[str, list[str]] = {t: [] for t in INCLUDED}
    for message in commits(since, until):
        subject = message.splitlines()[0]
        m = SUBJECT.match(subject)
        if not m:
            continue

        # An explicit trailer wins over the subject, because the subject is
        # written for developers and may describe internals that should not be
        # advertised on a public listing.
        override = TRAILER.search(message)
        if override:
            text = override.group("text").strip()
            if text.lower() in ("skip", "none", "no"):
                continue
            entry = text.rstrip(".")
        else:
            if m.group("type") not in INCLUDED:
                continue
            entry = polish(m.group("text"))

        kind = m.group("type") if m.group("type") in INCLUDED else "fix"
        if entry and entry not in grouped[kind]:
            grouped[kind].append(entry)
    return grouped


def render(grouped: dict[str, list[str]], limit: int = MAX_CHARS) -> str:
    """Build the note, dropping the least important entries until it fits."""
    entries: list[tuple[str, str]] = []
    for kind, _ in SECTIONS:
        for entry in grouped.get(kind, []):
            entries.append((kind, entry))

    if not entries:
        return FALLBACK

    def build(items: list[tuple[str, str]]) -> str:
        lines: list[str] = []
        for kind, heading in SECTIONS:
            section = [text for k, text in items if k == kind]
            if not section:
                continue
            if lines:
                lines.append("")
            lines.append(f"{heading}:")
            lines += [f"\u2022 {text}" for text in section]
        return "\n".join(lines)

    # Trim from the end, which is the least important section, until it fits.
    while entries:
        note = build(entries)
        if len(note) <= limit:
            return note
        entries.pop()

    return FALLBACK


def main() -> None:
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("--since", help="tag or ref to start from "
                                   "(default: latest build-* tag)")
    p.add_argument("--until", default="HEAD",
                   help="tag or ref to end at (default: HEAD)")
    p.add_argument("--output", help="write JSON of {language: text} here")
    p.add_argument("--language", default="en-US")
    p.add_argument("--stdout", action="store_true", help="print the note only")
    p.add_argument("--limit", type=int, default=MAX_CHARS)
    args = p.parse_args()

    since = args.since if args.since is not None else previous_tag()
    grouped = collect(since, args.until)
    note = render(grouped, args.limit)

    if args.stdout:
        print(note)
        return

    print(f"range: {since or 'full history'}..{args.until}", file=sys.stderr)
    print(f"length: {len(note)}/{args.limit}", file=sys.stderr)
    print(note, file=sys.stderr)

    if args.output:
        with open(args.output, "w", encoding="utf-8") as fh:
            json.dump({args.language: note}, fh, ensure_ascii=False, indent=2)
        print(f"wrote {args.output}", file=sys.stderr)


if __name__ == "__main__":
    main()
