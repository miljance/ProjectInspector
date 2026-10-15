# Project Inspector – notes for Claude Code

- Start with `HANDOFF.md` (goals G1..G6, current state, expected results), then `README.md`.
- Two AL projects: `App/` (50100..50149) and `Test/` (50150..50199). Open `ProjectInspector.code-workspace`.
- Work test-first: add or change a test in `Test/`, see it fail, then change `App/`.
- Never put real customer, company or product names in code, data or instructions. Demo data is fictional (CRONUS US).
- The agent must stay read-only (D365 READ). Writes happen in AL code only.
- Agent instructions live in `App/.resources/Instructions/InstructionsV1.txt`. They were tuned on 6 demo projects; change them only with a reason and re-test all 6 (HANDOFF.md section 6).
