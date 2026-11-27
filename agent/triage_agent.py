#!/usr/bin/env python3
"""
WOWEngine Automated Error-Triage & Patching Agent (IllusoryBias).
Monitors incoming GitHub Issues containing player Lua logs, parses stack traces,
deduplicates open PRs, generates Blizzard-TOS-compliant fixes via the Gemini API,
validates every modified file with lua_validator.py, and outputs structured results
for GitHub Actions to open a Draft Pull Request.

Zero third-party pip dependencies (pure Python 3 standard library).
"""
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

from lua_validator import validate_lua_file

REPO_ROOT = Path(__file__).resolve().parent.parent
ALLOWED_ADDON_PREFIXES = ("WOWEngine/", "HordeEngine/", "AllianceEngine/")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

TRACE_REGEX = re.compile(
    r"(?:Interface[/\\]AddOns[/\\])?(?P<file>(?:WOWEngine|HordeEngine|AllianceEngine)[/\\][A-Za-z0-9_]+\.lua):(?P<line>\d+)",
    re.IGNORECASE,
)


def parse_issue_log(title: str, body: str) -> dict:
    """Extract Lua file/line stack traces, client build, and addon version from issue text."""
    combined = f"{title}\n{body}"
    matches = []
    seen = set()
    for m in TRACE_REGEX.finditer(combined):
        norm_file = m.group("file").replace("\\", "/")
        # Normalize canonical folder casing
        for prefix in ALLOWED_ADDON_PREFIXES:
            if norm_file.lower().startswith(prefix.lower()):
                norm_file = prefix + norm_file[len(prefix):]
                break
        line_no = int(m.group("line"))
        key = (norm_file, line_no)
        if key not in seen:
            seen.add(key)
            matches.append({"file": norm_file, "line": line_no})

    ver_match = re.search(r"Addon Version:\s*([0-9.]+)", combined, re.IGNORECASE)
    iface_match = re.search(r"Interface:\s*(\d+)", combined, re.IGNORECASE)
    client_match = re.search(r"Client Build:\s*([^\n]+)", combined, re.IGNORECASE)

    signature = (
        f"{matches[0]['file']}:{matches[0]['line']}"
        if matches
        else re.sub(r"\s+", " ", title.strip().lower())[:80]
    )

    return {
        "traces": matches,
        "addon_version": ver_match.group(1) if ver_match else "unknown",
        "interface": iface_match.group(1) if iface_match else "unknown",
        "client_build": client_match.group(1).strip() if client_match else "unknown",
        "signature": signature,
    }


def github_api(method: str, endpoint: str, token: str, payload: dict | None = None):
    url = f"https://api.github.com{endpoint}"
    data = json.dumps(payload).encode("utf-8") if payload is not None else None
    req = urllib.request.Request(
        url,
        data=data,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Accept": "application/vnd.github+json",
            "User-Agent": "WOWEngine-Triage-Agent",
            "Content-Type": "application/json",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        raw = resp.read().decode("utf-8")
        return json.loads(raw) if raw else {}


def find_duplicate_pr(repo: str, token: str, signature: str) -> dict | None:
    if not (repo and token and signature):
        return None
    try:
        prs = github_api("GET", f"/repos/{repo}/pulls?state=open&per_page=30", token)
        for pr in prs:
            body = pr.get("body") or ""
            if f"Signature: `{signature}`" in body:
                return {"number": pr["number"], "url": pr["html_url"]}
    except Exception:
        return None
    return None


def load_context_files(traces: list[dict]) -> dict[str, str]:
    """Load referenced Lua files, or default to core routing/UI files if no trace was provided."""
    files_to_read: list[str] = []
    for t in traces:
        if t["file"] not in files_to_read:
            files_to_read.append(t["file"])

    # Always include Compat.lua if a WOWEngine file is involved
    if any(f.startswith("WOWEngine/") for f in files_to_read) and "WOWEngine/Compat.lua" not in files_to_read:
        files_to_read.append("WOWEngine/Compat.lua")

    if not files_to_read:
        files_to_read = ["WOWEngine/MailRouter.lua", "WOWEngine/RosterScanner.lua", "WOWEngine/UI.lua"]

    loaded: dict[str, str] = {}
    for rel in files_to_read[:5]:  # cap context at 5 files
        p = REPO_ROOT / rel
        if p.exists() and p.is_file():
            loaded[rel] = p.read_text(encoding="utf-8")
    return loaded


def call_gemini_triage(api_key: str, title: str, body: str, parsed: dict, source_files: dict[str, str]) -> dict:
    system_instruction = (
        "You are the WOWEngine Automated Error-Triage Engineer for IllusoryBias. "
        "Analyze the user's WoW addon bug report and Lua source files, then return STRICT JSON ONLY.\n\n"
        "MANDATORY RULES:\n"
        "1. 100% Blizzard Terms of Service compliance: NEVER use /run, RunScript, CastSpellByName, "
        "TargetUnit, or bypass manual hardware-click mail sending.\n"
        "2. Preserve cross-client compatibility across WoW Forever 1.60.1 (Interface 16001), Retail Midnight (120100), "
        "Classic Era/SoD, TBC, and MoP using NS.Compat shims (C_Item.GetItemInfo, C_Container, issecretvalue).\n"
        "3. NEVER invent hardcoded character names; preserve strict self-mail blocking.\n"
        "4. Only propose code patches when there is a clear, reproducible code defect. "
        "If the issue is a user configuration question, missing info, or cannot be fixed safely, set should_patch=false.\n"
        "5. Every patch entry MUST provide an exact verbatim `search` block that appears once in `file` and its `replace` block.\n\n"
        "Return JSON with exact keys:\n"
        "{\n"
        '  "root_cause": "concise technical explanation",\n'
        '  "severity": "low|medium|high|critical",\n'
        '  "should_patch": true or false,\n'
        '  "pr_title": "short PR title",\n'
        '  "user_reply": "friendly, clear markdown reply to post on the GitHub issue",\n'
        '  "patches": [\n'
        '    {"file": "WOWEngine/Example.lua", "search": "exact existing lines", "replace": "fixed lines"}\n'
        "  ]\n"
        "}"
    )

    files_blob = []
    for rel, content in source_files.items():
        files_blob.append(f"=== FILE: {rel} ===\n{content}")

    user_prompt = (
        f"GitHub Issue Title: {title}\n"
        f"Parsed Metadata: {json.dumps(parsed)}\n\n"
        f"Issue Body:\n{body}\n\n"
        f"Relevant Source Files:\n" + "\n\n".join(files_blob)
    )

    url = (
        f"https://generativelanguage.googleapis.com/v1beta/models/"
        f"{GEMINI_MODEL}:generateContent?key={api_key}"
    )
    payload = {
        "system_instruction": {"parts": [{"text": system_instruction}]},
        "contents": [{"role": "user", "parts": [{"text": user_prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "responseMimeType": "application/json",
        },
    }

    req = urllib.request.Request(
        url,
        data=json.dumps(payload).encode("utf-8"),
        method="POST",
        headers={"Content-Type": "application/json"},
    )
    with urllib.request.urlopen(req, timeout=90) as resp:
        data = json.loads(resp.read().decode("utf-8"))

    raw_text = data["candidates"][0]["content"]["parts"][0]["text"]
    # Strip accidental markdown code fences if present
    raw_text = re.sub(r"^```(?:json)?\s*", "", raw_text.strip())
    raw_text = re.sub(r"\s*```$", "", raw_text)
    return json.loads(raw_text)


def apply_and_validate_patches(patches: list[dict]) -> tuple[bool, list[str], list[str]]:
    """Apply search/replace patches atomically; revert all if any check fails."""
    backups: dict[Path, str] = {}
    modified_files: list[str] = []
    errors: list[str] = []

    try:
        for idx, patch in enumerate(patches, 1):
            rel = str(patch.get("file", "")).replace("\\", "/")
            if not rel.startswith(ALLOWED_ADDON_PREFIXES) or not rel.endswith(".lua"):
                errors.append(f"Patch #{idx} rejected: file '{rel}' is outside allowed addon Lua paths.")
                break

            target = (REPO_ROOT / rel).resolve()
            if not target.exists():
                errors.append(f"Patch #{idx} rejected: file '{rel}' does not exist.")
                break

            original = target.read_text(encoding="utf-8")
            if target not in backups:
                backups[target] = original

            search = patch.get("search", "")
            replace = patch.get("replace", "")
            if not search or search not in original:
                errors.append(f"Patch #{idx} rejected: search snippet not found verbatim in '{rel}'.")
                break
            if original.count(search) > 1:
                errors.append(f"Patch #{idx} rejected: search snippet matched multiple places in '{rel}'.")
                break

            updated = original.replace(search, replace, 1)
            target.write_text(updated, encoding="utf-8", newline="\n")
            if rel not in modified_files:
                modified_files.append(rel)

        # Validate every modified file with strict syntax + TOS validator
        if not errors:
            for rel in modified_files:
                val_errors = validate_lua_file(REPO_ROOT / rel)
                if val_errors:
                    errors.extend(val_errors)

        if errors:
            for path, old_content in backups.items():
                path.write_text(old_content, encoding="utf-8", newline="\n")
            return False, [], errors

        return True, modified_files, []
    except Exception as exc:
        for path, old_content in backups.items():
            path.write_text(old_content, encoding="utf-8", newline="\n")
        return False, [], [f"Unexpected patch error: {exc}"]


def main() -> int:
    issue_num = os.environ.get("ISSUE_NUMBER", "0")
    issue_title = os.environ.get("ISSUE_TITLE", "")
    issue_body = os.environ.get("ISSUE_BODY", "")
    repo = os.environ.get("GITHUB_REPOSITORY", "")
    gh_token = os.environ.get("GITHUB_TOKEN", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")

    parsed = parse_issue_log(issue_title, issue_body)
    result = {
        "issue_number": issue_num,
        "signature": parsed["signature"],
        "patch_applied": False,
        "modified_files": [],
        "pr_title": f"fix: resolve issue #{issue_num}",
        "root_cause": "",
        "severity": "medium",
        "issue_comment": "",
    }

    # 1. Deduplication check against open PRs
    dup = find_duplicate_pr(repo, gh_token, parsed["signature"])
    if dup:
        result["issue_comment"] = (
            f"### WOWEngine Triage Agent\n\n"
            f"This error signature (`{parsed['signature']}`) already has an active fix in progress: "
            f"**PR #{dup['number']}** ({dup['url']}).\n\n"
            f"Once reviewed and merged, the updated build will be packaged for CurseForge."
        )
        Path("triage_result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        print("Duplicate PR detected; wrote triage_result.json.")
        return 0

    if not gemini_key:
        result["issue_comment"] = (
            "### WOWEngine Triage Agent\n\n"
            "Automated triage could not run because `GEMINI_API_KEY` is not configured in repository secrets."
        )
        Path("triage_result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        print("Missing GEMINI_API_KEY; wrote triage_result.json.")
        return 0

    # 2. Load referenced Lua files and query Gemini API
    source_files = load_context_files(parsed["traces"])
    try:
        ai_resp = call_gemini_triage(gemini_key, issue_title, issue_body, parsed, source_files)
    except Exception as exc:
        result["issue_comment"] = (
            f"### WOWEngine Triage Agent\n\n"
            f"Logged error signature `{parsed['signature']}` for manual review "
            f"(AI triage request encountered an error: `{exc}`)."
        )
        Path("triage_result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
        print("Gemini API call failed:", exc)
        return 0

    result["root_cause"] = ai_resp.get("root_cause", "No root cause provided.")
    result["severity"] = ai_resp.get("severity", "medium")
    result["pr_title"] = ai_resp.get("pr_title") or result["pr_title"]
    user_reply = ai_resp.get("user_reply", "Thank you for reporting this issue.")

    # 3. Apply & validate patches if proposed
    patches = ai_resp.get("patches") or []
    if ai_resp.get("should_patch") and patches:
        ok, mod_files, val_errors = apply_and_validate_patches(patches)
        if ok and mod_files:
            result["patch_applied"] = True
            result["modified_files"] = mod_files
            result["issue_comment"] = (
                f"### WOWEngine Triage Agent — Draft Fix Ready\n\n"
                f"**Severity:** `{result['severity']}` | **Signature:** `{parsed['signature']}`\n\n"
                f"**Root Cause:** {result['root_cause']}\n\n"
                f"{user_reply}\n\n"
                f"A validated, Blizzard-TOS-checked Draft Pull Request has been opened for IllusoryBias to test before CurseForge release."
            )
        else:
            err_bullets = "\n".join(f"- `{e}`" for e in val_errors)
            result["issue_comment"] = (
                f"### WOWEngine Triage Agent — Escalated for Manual Review\n\n"
                f"**Signature:** `{parsed['signature']}` | **Severity:** `{result['severity']}`\n\n"
                f"**Likely Root Cause:** {result['root_cause']}\n\n"
                f"{user_reply}\n\n"
                f"_Note: An automated patch was rejected by the syntax/TOS validator and reverted:_\n{err_bullets}"
            )
    else:
        result["issue_comment"] = (
            f"### WOWEngine Triage Agent\n\n"
            f"**Signature:** `{parsed['signature']}` | **Severity:** `{result['severity']}`\n\n"
            f"{user_reply}"
        )

    Path("triage_result.json").write_text(json.dumps(result, indent=2), encoding="utf-8")
    print("Triage completed cleanly:", json.dumps({k: v for k, v in result.items() if k != "issue_comment"}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
