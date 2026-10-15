# Handoff – Project Inspector (Directions EMEA 2026)

Working notes for building the demo: context, state, open goals and expected results. Read this first, then `README.md`.

## 1. Context

Session: **"One Voice Note, a Complete Project. AI Agents at Work in Business Central"**, Directions EMEA 2026, 29 Oct 2026, 13:45–14:30, Room 253. Recorded demos (no live demo).

| Part | Owner | Tool | Agent |
| --- | --- | --- | --- |
| Voice note / Teams transcript → project in BC | Nikola Pančić | Copilot Studio + BC MCP server | **Scribe Agent** |
| Review of the new project, questions to salesperson | Miljan Milosavljević | BC Agent SDK (this repo) | **Project Inspector** |

Flow: Salesperson voice note → Scribe Agent creates project (status Planning) through MCP → Scribe calls `submitForReview` → **Project Inspector** reviews against the Contoso project creation rules (PCR-01..PCR-31) → if there are questions, BC raises business event → Power Automate asks the salesperson in Teams → answer comes back through `clarificationAnswers` API → Project Inspector reviews again → project engineer sets status Quote.

All demo content is fictional (CRONUS US style). **Never add real customer, company or product names.**

## 2. Environment

| Item | Value |
| --- | --- |
| BC environment | Sandbox `bc29` (BC 29). Copy `.vscode/launch.example.json` to `.vscode/launch.json` in `App` and `Test` and fill in your tenant (`launch.json` is not in the repo). |
| Company | CRONUS USA (US localization, currency USD) |
| Repo | https://github.com/miljance/ProjectInspector |
| VS Code | Open `ProjectInspector.code-workspace` |
| Symbols | Not in the repo: run *Download symbols* in `App` (BC 29) and in `Test` (Library Assert + App). |
| Demo data | RapidStart packages `SCRIBE-DEMO`, `SCRIBE-PRJ-HEADERS`, `SCRIBE-PRJ-LINES` (apply in that order), kept with the session material, not in this repo |
| Rules | `Contoso Project Templates and Policies.md` (v1.2, PCR rule IDs), kept with the session material |
| Other APIs | OCPF APIs v3 (`ajansari/ocpfBCAPIsV3`) installed; Scribe uses pages 90842, 90846, 90854, 90910, 90912, 90913 |
| MCP configuration | `SCRIBE-AGENT` (MCP Server Configurations page) |

## 3. Current state

Created from the AL **Agent** project template, with the Agent Designer export applied (`App/.resources/Instructions/ProjectInspector-agent-export.xml`).

**Done (G1 and G2): compiles, published to `bc29`, all tests green:**

- App (50100..50149): agent registration (capability, metadata provider, factory, metadata, task execution, setup page/table, KPI, install/upgrade), instructions resource, review triggers, dispatcher interface + Agent Task Builder implementation, Open Points field, Project Card action, `projectReviews` API (+ `submitForReview`), `clarificationAnswers` API + log table/page, `ProjectClarificationRequested` external business event, permission set.
- Test (50150..50199): 26 tests in 4 codeunits, mock dispatcher, event spy, test library with real report samples. All pass in `bc29`; a mutation pass over the review triggers, answers, parser and clarification logic found no surviving mutant.
- Not covered by unit tests (needs an activated agent, part of G3): `PI Agent Task Dispatcher` and `PI Agent Task Execution`.

**Verified in the playground (Agent Designer), not in this app:** the instructions in `InstructionsV1.txt` produce the expected reports on all 6 demo projects (table in section 6). Step 8 (answers) was added afterwards and is untested.

## 4. Goals (in order)

### G1 – Compile the App – done
Findings from the BC 29 System Application source, now fixed in the code:
- `Agent Task`.`GetTaskByExternalId` uses `FindFirst()` and fails when there is no task; the dispatcher checks `TaskExists` first.
- `Agent Task Message Builder` has no `AddToTask`; a message is added with `.SetAgentTask(...).Create(true)`, which also sets the task to Ready when possible.
- Task messages default to `RequiresReview = true`; the dispatcher sets `false` for the first message too, otherwise the agent waits for an approval.
- `[ExternalBusinessEvent]` parameters are limited to 250 characters: `Questions` and `ProjectUrl` are `Text[250]` and cut off.

### G2 – Make the tests green (TDD) – done
- `Job.Validate(Status)` on an unsaved project fails in the base application (`Status - OnValidate` calls `Modify`), so the unsaved-project test calls `PI Review Trigger`.`OnAfterStatusValidated` directly.
- New test: a status change on a temporary project does not send a review.
- Fix code, not tests, unless a test is wrong about BC behaviour. New behaviour: write the failing test first.

### G3 – Agent works end to end in the sandbox
1. Enable capability *Project Inspector*, create the agent from the Role Center, add users (project managers, Copilot Studio connection user, Power Automate connection user), activate. Deactivate the Agent Designer version.
2. **Send to Project Inspector** on every demo project and compare with section 6.
3. Check that a second send of the same project adds a message to the same task (External ID = project No.).
4. Check that status Quote → Planning on an existing project creates a review.
- Done when: all 6 projects give the expected report from the coded agent.

### G4 – Clarification loop (Teams)
1. Verify the business event is raised from `AnalyzeAgentTaskMessage` (output message). Note: the output message is a Draft until reviewed; decide whether that is acceptable for the demo or move the event to a later point.
2. Power Automate flow: *When a business event occurs* (Project Inspector / ProjectClarificationRequested) → Teams *Post adaptive card and wait for a response* → BC *Create record* on `clarificationAnswers` (`projectNo`, `answer`, `answeredBy`).
3. Verify the answer reaches the same task, the task restarts and Project Inspector applies step 8 (does not ask again about answered points).
- Done when: FAB-01-IMP question "Please split the 38 days in task 003010 by phase (PCR-23)" goes to Teams, the answer comes back and the agent produces a new report.

### G5 – Scribe Agent integration (with Nikola)
- Add page 50102 `projectReviews` to MCP configuration `SCRIBE-AGENT` (Read + Modify, bound actions allowed). Check that `submitForReview` shows up as a tool in Copilot Studio.
- Scribe call order: customers → existing projects (PCR-03) → POST project → POST tasks → POST planning lines (no unitPrice) → PATCH `openPoints` → `submitForReview` once.
- Test one planning line POST through OCPF page 90913 by hand first (field validation order: `jobTaskNo` comes after `no`/`quantity` on that page).

### G6 – Nice to have
- Own agent profile with page customizations (show Totaling and Project Posting Group on the task list, Line Discount % on planning lines) so step 2 of the instructions can also check Totaling. Only if the instructions are re-tested afterwards.
- Edit-instructions page for the coded agent (Agent Designer actions are disabled on coded agents).
- KPI page: more useful numbers (open reviews, questions asked).

## 5. Design decisions (keep unless there is a reason)

- **Agent is read-only** (D365 READ). All writes (tasks, answers, events) happen in AL code, never by the agent.
- **No trigger on Job insert**: tasks and planning lines do not exist yet. Scribe calls `submitForReview` when done (PCR-27).
- **One task per project**, External ID = project No.; repeated triggers and answers add messages to that task.
- **Task message only names the project** (`Review <No.>`); the agent derives questions from the data (instructions step 6).
- **Business event is raised by code** (output message analysis), so the instructions stay unchanged.
- **Dispatcher interface + provider** exists only to make triggers testable without an activated agent.
- Answers come in through a **table + API page** (`clarificationAnswers`), not a bound action with parameters: easy for Power Automate and keeps a log.

## 6. Expected review results (demo data)

| Project | Status | Total | Days | Findings | Questions |
| --- | --- | --- | --- | --- | --- |
| FAB-01-IMP | OPEN POINTS | 75,250 | 44 | – | Please split the 38 days in task 003010 by phase (PCR-23) |
| TAI-01-IMP | ERRORS | 20,025 | 15 | Unit Price 1,100 instead of 1,250 (PCR-14); Discount of 375 (PCR-16) | Quote number for block 003000 (PCR-12) |
| PRO-01-WSH | ERRORS | 3,150 | 2 | Standard block 001000..001900 missing (PCR-10) | Workshop dates for task 001010 (PCR-22) |
| LIT-01-SUP | ERRORS | 8,400 | 0 | Customer Litware Inc. (C90040) is blocked (PCR-07) | Start/end date (PCR-20); 60 hours contingent (PCR-23) |
| WWI-01-IMP | ERRORS | 19,500 | 10 | Possible duplicate WWI-02-IMP (PCR-03) | 50 hours contingent (PCR-23) |
| WWI-02-IMP | ERRORS | 12,500 | 10 | Possible duplicate WWI-01-IMP (PCR-03) | Quote number for block 002000 (PCR-12); split 10 days in 002010 (PCR-23) |

Report format (step 7) is what `PI Report Parser` reads – if the format changes, change `Test/src/Library/PITestLibrary.Codeunit.al` samples and the parser together.

## 7. Conventions

- Object prefix `PI`, namespace `Contoso.ProjectInspector` (tests: `.Test`).
- App 50100..50149, Test 50150..50199.
- Tests: Given/When/Then comments, one behaviour per test, mock dispatcher via `PI Test Library`.UseMockDispatcher.
- Instructions change → edit `InstructionsV1.txt`, raise app version, publish (upgrade codeunit pushes them).
- English for code, captions and instructions (agents support English only).
