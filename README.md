# WOWEngine Suite (IllusoryBias) + Automated Error-Triage Agent

Multi-version World of Warcraft addon suite (`WOWEngine`, `HordeEngine`, `AllianceEngine` — **v1.3.10**) supporting **WoW Forever (1.60.1 / Interface 16001)**, **Retail**, **Classic Era / SoD**, **TBC**, and **Mists of Pandaria**, with an automated GitHub Actions Error-Triage Agent.

## Repository Contents
- `WOWEngine/`, `HordeEngine/`, `AllianceEngine/` — Addon suite (`v1.3.10`) including `/he bugreport` in-game error log exporter.
- `.github/ISSUE_TEMPLATE/bug_report.yml` — Structured bug report form for CurseForge/GitHub users.
- `.github/workflows/wowengine-error-triage.yml` — Automated agent triggered on every new bug report; parses Lua traces, calls Gemini API, validates patches for syntax + Blizzard TOS compliance, and opens a Draft PR.
- `.github/workflows/lua-ci.yml` — Automated syntax (`luac5.1 -p`) & Blizzard TOS validator on every push and PR.
- `agent/triage_agent.py` & `agent/lua_validator.py` — Pure Python 3 standard-library agent & validator (zero pip installs required).

## Quick GitHub Setup (3 Minutes)
1. Upload all folders from this package (`WOWEngine`, `HordeEngine`, `AllianceEngine`, `agent`, `.github`, and `README.md`) to the root of your `WOWEngine` GitHub repository.
2. Go to **Settings -> Secrets and variables -> Actions -> New repository secret**, add **`GEMINI_API_KEY`** with your key from Google AI Studio.
3. Go to **Settings -> Actions -> General -> Workflow permissions**, enable **Read and write permissions** and check **Allow GitHub Actions to create and approve pull requests**, then click **Save**.
4. On CurseForge, set your project's **Issues URL** to `https://github.com/<YourUsername>/WOWEngine/issues`.
5. Test it: run `/he bugreport` in-game, copy the output, and open a test Issue on GitHub—the agent will respond automatically within ~30 seconds.
