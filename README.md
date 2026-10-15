# Project Inspector

Business Central agent that reviews every new customer project in status **Planning** against the Contoso project creation rules (PCR) and reports findings and questions for the salesperson. Demo for Directions EMEA 2026, session "One Voice Note, a Complete Project".

The agent was designed and tested in Agent Designer, exported (`App/.resources/Instructions/ProjectInspector-agent-export.xml`) and moved into this app with the AL **Agent** project template.

## The demo

Session **"One Voice Note, a Complete Project. AI Agents at Work in Business Central"**, Directions EMEA 2026, 29 Oct 2026. Recorded demos, no live demo.

| Part | Presenter | Tool | Agent |
| --- | --- | --- | --- |
| Voice note / Teams transcript → project in BC | Nikola Pančić | Copilot Studio + BC MCP server | **Scribe Agent** |
| Review of the new project, questions to the salesperson | Miljan Milosavljević | BC Agent SDK (this repo) | **Project Inspector** |

Flow: salesperson voice note → Scribe Agent creates the project (status Planning) through MCP → Scribe calls `submitForReview` → **Project Inspector** reviews it against the Contoso project creation rules (PCR-01..PCR-31) → if there are questions, BC raises a business event → Power Automate asks the salesperson in Teams → the answer comes back through the `clarificationAnswers` API → Project Inspector reviews again → the project engineer sets status Quote.

Environment: BC 29 sandbox, company CRONUS USA (currency USD). The Scribe Agent uses the OCPF APIs v3 and the MCP configuration `SCRIBE-AGENT`. The demo data (RapidStart packages `SCRIBE-DEMO`, `SCRIBE-PRJ-HEADERS`, `SCRIBE-PRJ-LINES`, applied in that order) and the rules document `Contoso Project Templates and Policies.md` are kept with the session material, not in this repo.

All demo content is fictional (CRONUS US style). **Never add real customer, company or product names.**

## Structure

```
ProjectInspector/
├── ProjectInspector.code-workspace   open this in VS Code
├── App/                              the agent app (50100..50149)
│   ├── .resources/Instructions/
│   │   ├── InstructionsV1.txt        agent instructions (export + step 8 for answers)
│   │   └── ProjectInspector-agent-export.xml
│   └── src/
│       ├── Agent/                    agent registration, setup, KPI, install/upgrade, task execution
│       ├── Review/                   review triggers, dispatcher, Open Points field, Project Card action
│       ├── Clarification/            report parser, business event, answers table and page
│       ├── Api/                      projectReviews and clarificationAnswers API pages
│       └── Permissions/
└── Test/                             test app (50150..50199)
    └── src/
        ├── Tests/                    test codeunits (Given/When/Then)
        └── Library/                  mock dispatcher, event spy, test data
```

## How it works

| Trigger | Where | Code |
| --- | --- | --- |
| Submit for Review | Scribe Agent calls bound action `submitForReview` on `projectReviews` through the MCP server | `PI Review Trigger`.SubmitForReview |
| Status changes back to Planning | `OnAfterValidateEvent` of Job.Status (existing projects only, never blocks the change) | `PI Review Trigger`.OnAfterStatusValidated |
| Send to Project Inspector | Action on the Project Card | `PI Review Trigger`.SubmitForReview |

All three create one agent task per project: title and message `Review <No.>`, External ID = project No. A second trigger for the same project adds a message to the existing task.

When Project Inspector writes a report with **Questions for the salesperson**, `PI Agent Task Execution` (AnalyzeAgentTaskMessage on output messages) raises the external business event **ProjectClarificationRequested** (category Project Inspector) with: ProjectId, ProjectNo, ProjectDescription, CustomerName, ReviewStatus, Questions (one per line), ProjectUrl.

Power Automate:

1. Business Central: **When a business event occurs**, category *Project Inspector*, event *ProjectClarificationRequested*.
2. Teams: **Post adaptive card and wait for a response** to the salesperson, with the questions and a text field for the answer.
3. Business Central: **Create record** on `clarificationAnswers` (API publisher `contoso`, group `projectInspector`, version `v1.0`) with `projectNo`, `answer`, `answeredBy`.

The answer is added to the review task, the task is set to Ready and Project Inspector repeats the review (step 8 of the instructions).

## APIs

| Entity set | Page | Used by |
| --- | --- | --- |
| `projectReviews` (GET, PATCH `openPoints`, action `submitForReview`) | 50102 | Scribe Agent through the MCP server (add to configuration SCRIBE-AGENT, Read + Modify) |
| `clarificationAnswers` (POST) | 50103 | Power Automate |

Base URL: `/api/contoso/projectInspector/v1.0/companies({companyId})/`

## Set up in the sandbox

1. In `App` and `Test`, copy `.vscode/launch.example.json` to `.vscode/launch.json` and set your tenant and sandbox, then *Download symbols*. Publish **App** (F5 in the App folder).
2. **Copilot & agent capabilities**: enable *Project Inspector*.
3. Role Center: choose the Project Inspector avatar with **+**, set it up, add the users who may send it tasks (project managers, the Copilot Studio and Power Automate connection users), activate.
4. Deactivate the Project Inspector created in Agent Designer, so there is only one.
5. Assign permission set **PI Project Inspector** to the users and connections in step 3.
6. Open a project in Planning, choose **Send to Project Inspector**.

## Tests (TDD)

The tests do not need an activated agent: `PI Test Library`.UseMockDispatcher replaces the agent task dispatcher with `PI Mock Task Dispatcher` through `PI Dispatcher Provider`, and `PI Clarification Event Spy` listens to `OnAfterClarificationRequested`.

1. Make sure the sandbox has the test framework: **Library Assert** and **Test Runner** (Extension Management, or publish them from an artifact if they are missing).
2. Publish **App**, then **Test** (Download symbols in the Test folder first).
3. Run the tests with the AL Test Runner extension or the **AL Test Tool** page (130451): *Get Test Codeunits* → 50150..50153 → *Run*.

| Codeunit | Covers |
| --- | --- |
| 50150 PI Review Trigger Tests | Submit for Review, status change to Planning, no active agent, unsaved and temporary project |
| 50151 PI Report Parser Tests | questions, status and project No. from the report, CR LF |
| 50152 PI Clarification Answer Tests | answer goes to the task of the project, empty answer, unknown project |
| 50153 PI Clarification Event Tests | business event raised only when there are questions, project No. fallback |

Not covered by unit tests (needs a real agent, check by hand): `PI Agent Task Dispatcher` (Tasks AL API) and `PI Agent Task Execution` (runs in the agent session).

Write tests first, with Given/When/Then comments and one behaviour per test. Change a test only when it is wrong about BC behaviour: for example, `Job.Validate(Status)` on an unsaved project always fails in the base application (`Status - OnValidate` calls `Modify`), so that case calls `PI Review Trigger`.OnAfterStatusValidated directly.

## Change the instructions

Edit `App/.resources/Instructions/InstructionsV1.txt`, raise the version in `App/app.json` and publish. `PI Agent Upgrade` sets the new instructions on every Project Inspector agent. The instructions were tuned on the six demo projects below: after a change, run all six again.

## Expected review results (demo data)

| Project | Status | Total | Days | Findings | Questions |
| --- | --- | --- | --- | --- | --- |
| FAB-01-IMP | OPEN POINTS | 75,250 | 44 | – | Please split the 38 days in task 003010 by phase (PCR-23) |
| TAI-01-IMP | ERRORS | 20,025 | 15 | Unit Price 1,100 instead of 1,250 (PCR-14); Discount of 375 (PCR-16) | Quote number for block 003000 (PCR-12) |
| PRO-01-WSH | ERRORS | 3,150 | 2 | Standard block 001000..001900 missing (PCR-10) | Workshop dates for task 001010 (PCR-22) |
| LIT-01-SUP | ERRORS | 8,400 | 0 | Customer Litware Inc. (C90040) is blocked (PCR-07) | Start/end date (PCR-20); 60 hours contingent (PCR-23) |
| WWI-01-IMP | ERRORS | 19,500 | 10 | Possible duplicate WWI-02-IMP (PCR-03) | 50 hours contingent (PCR-23) |
| WWI-02-IMP | ERRORS | 12,500 | 10 | Possible duplicate WWI-01-IMP (PCR-03) | Quote number for block 002000 (PCR-12); split 10 days in 002010 (PCR-23) |

These were verified with the Agent Designer version of the agent. Step 8 of the instructions (answers) was added afterwards and is not verified yet. `PI Report Parser` reads the report format of step 7: if the format changes, change the parser and the samples in `Test/src/Library/PITestLibrary.Codeunit.al` together.

## Design decisions

- **The agent is read-only** (D365 READ). All writes (tasks, answers, events) happen in AL code, never by the agent.
- **No trigger on project insert**: tasks and planning lines do not exist yet. Scribe Agent calls `submitForReview` when it is done (PCR-27).
- **One task per project**, External ID = project No. Repeated triggers and answers add messages to that task.
- **The task message only names the project** (`Review <No.>`); the agent finds the open points in the data (step 6 of the instructions).
- **The business event is raised by code** (analysis of the output message), so the instructions stay unchanged.
- **Dispatcher interface + provider** exist only to make the triggers testable without an activated agent.
- **Answers come in through a table + API page** (`clarificationAnswers`), not a bound action with parameters: simple for Power Automate, and it keeps a log.

Notes on the BC 29 agent APIs, checked against the System Application source:

- `Agent Task`.GetTaskByExternalId fails when there is no task, so the dispatcher calls `TaskExists` first.
- A message is added to an existing task with `Agent Task Message Builder`.SetAgentTask(...).Create(true), which also sets the task to Ready when possible.
- Task messages default to *requires review*; the dispatcher turns that off, otherwise the agent waits for an approval.
- Business event parameters are limited to 250 characters, so `Questions` and `ProjectUrl` are cut off at 250.

## Status and next steps

Done: the app compiles against BC 29 and all 26 tests pass in a BC 29 sandbox.

1. **Agent end to end in the sandbox.** Enable the capability, create and activate the agent (see *Set up in the sandbox*), run **Send to Project Inspector** on all six demo projects and compare with the table above. Check that a second send adds a message to the same task, and that a change from Quote back to Planning starts a review.
2. **Clarification loop in Teams.** Check that the business event is raised from the output message (it is a draft until reviewed: decide whether that is fine for the demo or raise the event later), build the Power Automate flow, and check that the answer reaches the same task and the agent does not ask again about answered points. Done when the FAB-01-IMP question goes to Teams and the answer produces a new report.
3. **Scribe Agent integration.** Add page 50102 `projectReviews` to the MCP configuration `SCRIBE-AGENT` (Read + Modify, bound actions allowed) and check that `submitForReview` shows up as a tool in Copilot Studio. Scribe call order: customers → existing projects (PCR-03) → POST project → POST tasks → POST planning lines (no unit price) → PATCH `openPoints` → `submitForReview` once. Scribe uses OCPF API pages 90842, 90846, 90854, 90910, 90912 and 90913; test one planning line POST through page 90913 by hand first (on that page `jobTaskNo` is validated after `no` and `quantity`).
4. **Nice to have.** Own agent profile with page customizations (Totaling and Project Posting Group on the task list, Line Discount % on planning lines), an edit-instructions page for the coded agent, and more useful KPI numbers (open reviews, questions asked).

## Conventions

- Object prefix `PI`, namespace `Contoso.ProjectInspector` (tests: `Contoso.ProjectInspector.Test`).
- App 50100..50149, Test 50150..50199.
- English for code, captions and instructions (agents support English only).
