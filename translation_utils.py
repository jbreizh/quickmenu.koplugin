#!/usr/bin/env python3
"""
Extract translatable strings from all Lua source files and compare against .po files.

Usage:
    python3 translation_utils.py [--update-po] [--locale LOCALE]

Flags:
    --update-po     Write missing msgids into all (or specified) locale .po files
    --remove-dead   Remove msgids from .po files not found in any Lua source
    --alphabetize   Sort all entries in .po files alphabetically by msgid
    --list-missing      Print msgids absent from .po files entirely and exit
    --list-untranslated Print msgids present in .po but with empty msgstr and exit
    --locale LOCALE Only process one locale (e.g. zh_CN)
    --show-dead     Show msgids in .po files not found in any Lua source
"""

import argparse
import os
import re
import sys

# Directories relative to this script
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
LOCALES_DIR = os.path.join(SCRIPT_DIR, "locale")

# Lua directories to scan (skip test/build artefacts)
LUA_DIRS = [
    SCRIPT_DIR,
]
LUA_EXCLUDE_DIRS = {"node_modules", ".git", "dist"}
LUA_EXCLUDE_FILES = {"translation_utils.py"}

# ---------------------------------------------------------------------------
# Patterns for extractable string calls
# ---------------------------------------------------------------------------
# _("...") and _('...')
_RE_GETTEXT_DQ = re.compile(r'_\(\s*"((?:[^"\\]|\\.)*)"\s*\)', re.DOTALL)
_RE_GETTEXT_SQ = re.compile(r"_\(\s*'((?:[^'\\]|\\.)*)'\s*\)", re.DOTALL)

# C_("context", "string") — context-aware gettext; we extract the string part
_RE_CGETTEXT_DQ = re.compile(r'C_\(\s*"[^"]*"\s*,\s*"((?:[^"\\]|\\.)*)"\s*\)', re.DOTALL)
_RE_CGETTEXT_SQ = re.compile(r"C_\(\s*'[^']*'\s*,\s*'((?:[^'\\]|\\.)*)'\s*\)", re.DOTALL)

# Multiline Lua long strings inside _([[...]]) — uncommon but possible
_RE_GETTEXT_LS = re.compile(r'_\(\s*\[\[(.*?)\]\]\s*\)', re.DOTALL)

ALL_PATTERNS = [
    _RE_GETTEXT_DQ,
    _RE_GETTEXT_SQ,
    _RE_CGETTEXT_DQ,
    _RE_CGETTEXT_SQ,
    _RE_GETTEXT_LS,
]


def unescape_lua(s: str) -> str:
    """Convert Lua escape sequences to the canonical form used in .po files."""
    # Only handle common escapes; Lua and Python share most of them
    return (
        s.replace("\\n", "\n")
         .replace("\\t", "\t")
         .replace('\\"', '"')
         .replace("\\'", "'")
         .replace("\\\\", "\\")
    )


def extract_from_file(path: str) -> list[str]:
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            src = f.read()
    except OSError:
        return []

    found = []
    for pat in ALL_PATTERNS:
        for m in pat.finditer(src):
            raw = m.group(1)
            found.append(unescape_lua(raw))
    return found


def collect_lua_strings() -> dict[str, list[str]]:
    """Return {msgid: [file, ...]} for every translatable string in all Lua files."""
    result: dict[str, list[str]] = {}

    for root, dirs, files in os.walk(SCRIPT_DIR):
        # Prune excluded directories in-place
        dirs[:] = [d for d in dirs if d not in LUA_EXCLUDE_DIRS]
        for fname in files:
            if not fname.endswith(".lua"):
                continue
            fpath = os.path.join(root, fname)
            rel = os.path.relpath(fpath, SCRIPT_DIR)
            for s in extract_from_file(fpath):
                result.setdefault(s, []).append(rel)

    return result


# ---------------------------------------------------------------------------
# .po file helpers
# ---------------------------------------------------------------------------

def po_header(po_path: str) -> str:
    """Return the raw header block (everything before the first non-empty msgid)."""
    with open(po_path, encoding="utf-8") as f:
        content = f.read()
    # Header ends just before the first msgid that isn't the empty-string header
    # i.e. before the first `\nmsgid "` that is NOT `msgid ""`
    m = re.search(r'\nmsgid "(?!"\n)', content)
    return content[: m.start() + 1] if m else content


def parse_po(po_path: str) -> dict[str, str]:
    """Return {msgid: msgstr} for all entries in a .po file."""
    entries: dict[str, str] = {}
    try:
        with open(po_path, encoding="utf-8") as f:
            content = f.read()
    except OSError:
        return entries

    # Split on blank lines to get blocks
    blocks = re.split(r"\n\n+", content.strip())
    for block in blocks:
        mid_m = re.search(r'^msgid "((?:[^"\\]|\\.)*)"', block, re.MULTILINE)
        mstr_m = re.search(r'^msgstr "((?:[^"\\]|\\.)*)"', block, re.MULTILINE)
        if mid_m and mstr_m:
            msgid = mid_m.group(1).replace("\\n", "\n")
            msgstr = mstr_m.group(1).replace("\\n", "\n")
            if msgid:  # skip the header entry
                entries[msgid] = msgstr
    return entries


def msgid_to_po_line(s: str) -> str:
    """Encode a string as a .po-compatible quoted value."""
    escaped = s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
    return escaped


def format_entry(msgid: str, msgstr: str = "") -> str:
    return f'msgid "{msgid_to_po_line(msgid)}"\nmsgstr "{msgid_to_po_line(msgstr)}"\n'


def rewrite_po(po_path: str, existing: dict[str, str], lua_strings: set, to_add: list[str], remove_dead: bool, alphabetize: bool = False) -> tuple[int, int]:
    """Rewrite a .po file, removing dead entries and/or appending new ones. Returns (removed, added)."""
    header = po_header(po_path)
    parts = [header.rstrip("\n")]
    removed = 0

    kept = {}
    for msgid, msgstr in existing.items():
        if remove_dead and msgid not in lua_strings:
            removed += 1
            continue
        kept[msgid] = msgstr

    for msgid in sorted(to_add):
        kept[msgid] = ""

    entry_iter = sorted(kept.items(), key=lambda kv: kv[0].lower()) if alphabetize else list(kept.items())
    for msgid, msgstr in entry_iter:
        parts.append(format_entry(msgid, msgstr).rstrip("\n"))

    added = len(to_add)

    with open(po_path, "w", encoding="utf-8") as f:
        f.write("\n\n".join(parts) + "\n")

    return removed, added


def write_updated_po(po_path: str, existing: dict[str, str], to_add: list[str]) -> None:
    """Append missing msgids (with empty msgstr) to a .po file."""
    with open(po_path, encoding="utf-8", errors="replace") as f:
        content = f.read()

    if not content.endswith("\n\n"):
        content = content.rstrip("\n") + "\n\n"

    additions = []
    for msgid in sorted(to_add):
        additions.append(format_entry(msgid))

    with open(po_path, "w", encoding="utf-8") as f:
        f.write(content + "\n".join(additions))

    print(f"  -> wrote {len(additions)} new entries to {os.path.relpath(po_path, SCRIPT_DIR)}")


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def get_missing_per_locale(locale: str | None = None) -> dict[str, list[str]]:
    """Return {locale: [msgid, ...]} for msgids present in Lua but absent from the .po file entirely."""
    lua_strings = collect_lua_strings()
    po_files = sorted(f for f in os.listdir(LOCALES_DIR) if f.endswith(".po"))
    if locale:
        po_files = [f for f in po_files if f == f"{locale}.po"]

    result: dict[str, list[str]] = {}
    for po_file in po_files:
        loc = po_file[:-3]
        existing = parse_po(os.path.join(LOCALES_DIR, po_file))
        result[loc] = sorted(s for s in lua_strings if s not in existing)
    return result


def get_untranslated_per_locale(locale: str | None = None) -> dict[str, list[str]]:
    """Return {locale: [msgid, ...]} for entries present in .po but with an empty msgstr."""
    po_files = sorted(f for f in os.listdir(LOCALES_DIR) if f.endswith(".po"))
    if locale:
        po_files = [f for f in po_files if f == f"{locale}.po"]

    result: dict[str, list[str]] = {}
    for po_file in po_files:
        loc = po_file[:-3]
        existing = parse_po(os.path.join(LOCALES_DIR, po_file))
        result[loc] = sorted(msgid for msgid, msgstr in existing.items() if not msgstr)
    return result


def apply_translations(locale: str, translations: dict[str, str]) -> int:
    """Write a {msgid: msgstr} dict into the given locale's .po file. Returns number of entries updated."""
    po_path = os.path.join(LOCALES_DIR, f"{locale}.po")
    existing = parse_po(po_path)
    existing.update({k: v for k, v in translations.items() if v})
    lua_strings = collect_lua_strings()
    rewrite_po(po_path, existing, set(lua_strings.keys()), [], remove_dead=False, alphabetize=True)
    return sum(1 for v in translations.values() if v)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--update-po", action="store_true", help="Append missing msgids to .po files")
    parser.add_argument("--remove-dead", action="store_true", help="Remove msgids from .po files that no longer exist in Lua source")
    parser.add_argument("--alphabetize", action="store_true", help="Sort all entries in .po files alphabetically by msgid")
    parser.add_argument("--list-missing", action="store_true", help="Print msgids absent from .po files entirely and exit")
    parser.add_argument("--list-untranslated", action="store_true", help="Print msgids present in .po but with empty msgstr and exit")
    parser.add_argument("--locale", metavar="LOCALE", help="Only process this locale (e.g. zh_CN)")
    parser.add_argument("--show-dead", action="store_true", help="Show msgids in .po but not in Lua source")
    args = parser.parse_args()

    if args.list_missing:
        for loc, msgids in get_missing_per_locale(args.locale).items():
            print(f"[{loc}]  {len(msgids)} missing")
            for s in msgids:
                print(f"  {repr(s)}")
        return

    if args.list_untranslated:
        for loc, msgids in get_untranslated_per_locale(args.locale).items():
            print(f"[{loc}]  {len(msgids)} untranslated")
            for s in msgids:
                print(f"  {repr(s)}")
        return

    print("Scanning Lua source files...")
    lua_strings = collect_lua_strings()
    print(f"  Found {len(lua_strings)} unique translatable strings\n")

    # Determine which .po files to process
    po_files = sorted(f for f in os.listdir(LOCALES_DIR) if f.endswith(".po"))
    if args.locale:
        target = f"{args.locale}.po"
        if target not in po_files:
            print(f"Error: {target} not found in {LOCALES_DIR}", file=sys.stderr)
            sys.exit(1)
        po_files = [target]

    for po_file in po_files:
        locale = po_file[:-3]
        po_path = os.path.join(LOCALES_DIR, po_file)
        existing = parse_po(po_path)

        missing = sorted(s for s in lua_strings if s not in existing)
        show_dead = args.show_dead or args.remove_dead
        dead = sorted(s for s in existing if s not in lua_strings) if show_dead else []

        print(f"[{locale}]  missing={len(missing)}  dead={len(dead) if show_dead else '?'}")

        if missing:
            print("  MISSING (in Lua, not in .po):")
            for s in missing:
                preview = repr(s)
                files = lua_strings[s]
                print(f"    {preview}  <- {', '.join(files[:2])}{'...' if len(files) > 2 else ''}")

        if dead:
            print("  DEAD (in .po, not in Lua):")
            for s in dead:
                print(f"    {repr(s)}")

        need_write = (args.update_po and missing) or args.remove_dead or args.alphabetize
        if need_write:
            removed, added = rewrite_po(
                po_path, existing, set(lua_strings.keys()),
                missing if args.update_po else [],
                args.remove_dead,
                args.alphabetize,
            )
            if args.remove_dead and removed:
                print(f"  -> removed {removed} dead entries")
            if args.update_po and added:
                print(f"  -> added {added} new entries")
            if args.alphabetize:
                print(f"  -> alphabetized entries")

        print()


if __name__ == "__main__":
    main()
