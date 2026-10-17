# Project Inspector – notes for Claude Code

- Start with `README.md`: the demo, how the app works, design decisions, expected review results, status and next steps.
- Two AL projects: `App/` (50100..50149) and `Test/` (50150..50199). Open `ProjectInspector.code-workspace`.
- Work test-first: add or change a test in `Test/`, see it fail, then change `App/`.
- Never put real customer, company or product names in code, data or instructions. Demo data is fictional (CRONUS US).
- The agent reads with D365 READ and writes only through PI Agent Edit: applying the salesperson's answers and recording its review result. Status changes, decisions and business events happen in AL code (PI Report Monitor), never by the agent.
- One approval per review round, on the Review Result card; nothing is carried out before the reviewer chooses Continue. README, *Design decisions*, lists the alternatives that were tried and dropped.
- Agent instructions live in `App/.resources/Instructions/InstructionsV1.txt`. They were tuned on 6 demo projects; change them only with a reason and re-test all 6 (README, *Expected review results*). Every evaluation run is a real agent task and uses Copilot credits: say how many runs, and ask first.
