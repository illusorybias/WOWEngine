#!/usr/bin/env python3
"""
WOWEngine Lua Syntax, Escape, Block-Balance & Blizzard TOS Validator.
Runs in GitHub Actions CI and inside the automated Error-Triage Agent before any PR is opened.
"""
import re
import shutil
import subprocess
import sys
from pathlib import Path

ADDON_DIRS = ["WOWEngine", "HordeEngine", "AllianceEngine"]

# Strictly forbidden patterns under Blizzard Terms of Service & IllusoryBias rules
FORBIDDEN_TOS_PATTERNS = [
    (r"\bRunScript\s*\(", "Protected RunScript() call violates Blizzard TOS"),
    (r"\bCastSpellByName\s*\(", "Protected CastSpellByName() call violates Blizzard TOS"),
    (r"\bCastSpellByID\s*\(", "Protected CastSpellByID() call violates Blizzard TOS"),
    (r"\bUseAction\s*\(", "Protected UseAction() call violates Blizzard TOS"),
    (r"\bTargetUnit\s*\(", "Protected TargetUnit() call violates Blizzard TOS"),
    (r"\bMoveForwardStart\s*\(", "Automated movement violates Blizzard TOS"),
    (r'"/run\b', "Slash /run command violates IllusoryBias TOS guardrail"),
    (r"'/run\b", "Slash /run command violates IllusoryBias TOS guardrail"),
]


def strip_comments_and_strings(txt: str, keep_strings: bool = False) -> str:
    """Single-pass Lua scanner that accurately distinguishes -- comments from -- inside strings."""
    out: list[str] = []
    i = 0
    n = len(txt)
    while i < n:
        ch = txt[i]
        if ch == "-" and i + 1 < n and txt[i + 1] == "-":
            # Skip to end of line
            while i < n and txt[i] != "\n":
                i += 1
            continue
        elif ch in ('"', "'"):
            quote = ch
            start = i
            i += 1
            while i < n and txt[i] != "\n":
                if txt[i] == "\\":
                    i += 2
                    continue
                if txt[i] == quote:
                    i += 1
                    break
                i += 1
            if keep_strings:
                out.append(txt[start:i])
            else:
                out.append('""')
            continue
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def validate_lua_file(path: Path) -> list[str]:
    errors: list[str] = []
    try:
        txt = path.read_text(encoding="utf-8")
    except Exception as exc:
        return [f"{path}: failed to read UTF-8 text ({exc})"]

    lines = txt.splitlines()

    # 1. Character-by-character string & escape sequence check
    for idx, line in enumerate(lines, 1):
        i = 0
        n = len(line)
        in_str = None
        while i < n:
            ch = line[i]
            if in_str is None:
                if ch == "-" and i + 1 < n and line[i + 1] == "-":
                    break
                elif ch in ('"', "'"):
                    in_str = ch
            else:
                if ch == "\\":
                    if i + 1 >= n:
                        errors.append(f"{path}:{idx}: trailing backslash in string")
                        break
                    nxt = line[i + 1]
                    if nxt not in ("n", "t", "r", "\\", '"', "'", "a", "b", "f", "v", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"):
                        errors.append(f"{path}:{idx}: invalid Lua escape \\{nxt}")
                    i += 1
                elif ch == in_str:
                    in_str = None
            i += 1
        if in_str is not None:
            errors.append(f"{path}:{idx}: unclosed string literal")

    # 2. Structural block & delimiter balance check (single-pass stripped)
    cleaned = strip_comments_and_strings(txt, keep_strings=False)
    opens = len(re.findall(r"\b(function|if|for|while)\b", cleaned))
    ends = len(re.findall(r"\bend\b", cleaned))
    if opens != ends:
        errors.append(f"{path}: Lua block mismatch (opens={opens}, ends={ends})")
    if cleaned.count("(") != cleaned.count(")"):
        errors.append(f"{path}: unmatched parentheses")
    if cleaned.count("{") != cleaned.count("}"):
        errors.append(f"{path}: unmatched curly braces")

    # 3. Blizzard TOS compliance check (comments stripped, strings preserved)
    no_comments = strip_comments_and_strings(txt, keep_strings=True)
    for pattern, reason in FORBIDDEN_TOS_PATTERNS:
        if re.search(pattern, no_comments):
            errors.append(f"{path}: TOS GUARDRAIL FAILED — {reason}")

    # 4. Real Lua bytecode parse check via luac -p if available
    luac_bin = shutil.which("luac") or shutil.which("luac5.1") or shutil.which("luac5.4")
    if luac_bin:
        proc = subprocess.run([luac_bin, "-p", str(path)], capture_output=True, text=True)
        if proc.returncode != 0:
            errors.append(f"{path}: luac syntax error: {proc.stderr.strip()}")

    return errors


def validate_repo(root: Path) -> list[str]:
    all_errors: list[str] = []
    for folder in ADDON_DIRS:
        target = root / folder
        if not target.exists():
            continue
        for lua_file in sorted(target.rglob("*.lua")):
            all_errors.extend(validate_lua_file(lua_file))
    return all_errors


def main() -> int:
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(".")
    errs = validate_repo(root)
    if errs:
        print("VALIDATION FAILED:")
        for e in errs:
            print("  -", e)
        return 1
    print("OK: All WOWEngine Lua files passed syntax, escape, balance, and Blizzard TOS checks.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
