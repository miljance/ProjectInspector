# Project Inspector

A Business Central agent, built with the AL Agent SDK, that reviews every new customer project in status **Planning** against the Contoso project creation rules (PCR) and reports findings and questions for the salesperson. When there are questions, they go to the salesperson in Teams and the answer comes back to the agent.

Built for the Directions EMEA 2026 session **"One Voice Note, a Complete Project. AI Agents at Work in Business Central"** (29 Oct 2026). The agent was designed and tested in Agent Designer, exported (`App/.resources/Instructions/ProjectInspector-agent-export.xml`) and moved into this app with the AL **Agent** project template.

**Status:** the app compiles against BC 29 and all 26 tests pass in a BC 29 sandbox. The agent itself still has to be run end to end, see [Next steps](#next-steps).

All demo content is fictional (CRONUS US style). **Never add real customer, company or product names.**

## The demo

| Part | Presenter | Tool | Agent |
| --- | --- | --- | --- |
| Voice note / Teams transcript → project in BC | Nikola Pančić | Copilot Studio + BC MCP server | **Scribe Agent** |
| Review of the new project, questions to the salesperson | Miljan Milosavljević | BC Agent SDK (this repo) | **Project Inspector** |

1. The salesperson records a voice note about a customer call.
2. Scribe Agent creates the project in status Planning through the BC MCP server and calls `submitForReview`.
3. **Project Inspector** reviews the project against the rules PCR-01..PCR-31.
4. If it has questions, BC raises a business event and Power Automate asks the salesperson in Teams.
5. The answer comes back through the `clarificationAnswers` API and Project Inspector reviews again.
6. The project engineer sets status Quote.

The demos are recorded, not live. Environment: BC 29 sandbox (US localization, currency USD); the demo data sits in its own company. Scribe Agent uses the OCPF APIs v3 and the MCP configuration `SCRIBE-AGENT`. The demo data and the rules document `Contoso Project Templates and Policies.md` are kept with the session material, not in this repo.

## How it works

### Review triggers

| Trigger | Where | Code |
| --- | --- | --- |
| Submit for Review | Scribe Agent calls the bound action `submitForReview` on `projectReviews` through the MCP server | `PI Review Trigger`.SubmitForReview |
| Send to Project Inspector | Action on the Project Card | `PI Review Trigger`.SubmitForReview |
| Status changes back to Planning | `OnAfterValidate` of Status in table extension `PI Job` (existing projects only, never blocks the change) | `PI Review Trigger`.OnAfterStatusValidated |

All three create one agent task per project: title and message `Review <No.>`, External ID = project No. A second trigger for the same project adds a message to the existing task.

### Questions to the salesperson

When Project Inspector writes a report with **Questions for the salesperson**, `PI Agent Task Execution` (AnalyzeAgentTaskMessage on output messages) raises the external business event **ProjectClarificationRequested** (category *Project Inspector*) with ProjectId, ProjectNo, ProjectDescription, CustomerName, ReviewStatus, Questions (one per line) and ProjectUrl.

The Power Automate flow:

1. Business Central: **When a business event occurs**, category *Project Inspector*, event *ProjectClarificationRequested*.
2. Teams: **Post adaptive card and wait for a response** to the salesperson, with the questions and a text field for the answer.
3. Business Central: **Create record** on `clarificationAnswers` with `projectNo`, `answer` and `answeredBy`.

The answer is added to the review task, the task is set to Ready and Project Inspector repeats the review (step 8 of the instructions).

### APIs

Base URL: `/api/contoso/projectInspector/v1.0/companies({companyId})/`

| Entity set | Page | Used by |
| --- | --- | --- |
| `projectReviews` (GET, PATCH `openPoints`, action `submitForReview`) | 50102 | Scribe Agent through the MCP server (configuration `SCRIBE-AGENT`, Read + Modify) |
| `clarificationAnswers` (POST) | 50103 | Power Automate |

## Set up

1. In `App` and `Test`, copy `.vscode/launch.example.json` to `.vscode/launch.json` and set your tenant and sandbox. `launch.json` is not in the repo.
2. Run *Download symbols* in both folders, then publish **App** (F5 in the App folder).
3. **Copilot & agent capabilities**: enable *Project Inspector*.
4. Role Center: choose the Project Inspector avatar with **+**, set it up, add the users who may send it tasks (project managers, the Copilot Studio and Power Automate connection users) and activate it.
5. If the environment also has a Project Inspector built in Agent Designer, deactivate it, so there is only one.
6. Assign the permission set **PI Project Inspector** to the users and connections from step 4.
7. Open a project in Planning and choose **Send to Project Inspector**.

To load the demo data, apply the RapidStart packages `SCRIBE-DEMO`, `SCRIBE-PRJ-HEADERS` and `SCRIBE-PRJ-LINES` in that order.

## Tests

The tests do not need an activated agent: `PI Test Library`.UseMockDispatcher replaces the agent task dispatcher with `PI Mock Task Dispatcher` through `PI Dispatcher Provider`, and `PI Clarification Event Spy` listens to `OnAfterClarificationRequested`.

1. Make sure the sandbox has **Library Assert** and **Test Runner** installed.
2. Publish **App**, then **Test**.
3. Run 50150..50153 with the AL Test Runner extension or the **AL Test Tool** page (130451): *Get Test Codeunits* → *Run*.

| Codeunit | Covers |
| --- | --- |
| 50150 PI Review Trigger Tests | Submit for Review, status change to Planning, no active agent, unsaved and temporary project |
| 50151 PI Report Parser Tests | questions, status and project No. from the report, CR LF |
| 50152 PI Clarification Answer Tests | answer goes to the task of the project, empty answer, unknown project |
| 50153 PI Clarification Event Tests | business event raised only when there are questions, project No. fallback |

Not covered by unit tests, because they need a real agent: `PI Agent Task Dispatcher` (Tasks AL API) and `PI Agent Task Execution` (runs in the agent session). Check those by hand in the sandbox.

Write tests first, with Given/When/Then comments and one behaviour per test. Change a test only when it is wrong about BC behaviour. Example: `Job.Validate(Status)` on an unsaved project always fails in the base application (`Status - OnValidate` calls `Modify`), so that case calls `PI Review Trigger`.OnAfterStatusValidated directly.

## Agent instructions

The instructions are in `App/.resources/Instructions/InstructionsV1.txt`. To change them, edit the file, raise the version in `App/app.json` and publish: `PI Agent Upgrade` sets the new instructions on every Project Inspector agent.

They were tuned on the six demo projects below, so after a change run all six again. `PI Report Parser` reads the report format of step 7: if the format changes, change the parser and the samples in `Test/src/Library/PITestLibrary.Codeunit.al` together.

### Expected review results

| Project | Status | Total | Days | Findings | Questions |
| --- | --- | --- | --- | --- | --- |
| FAB-01-IMP | OPEN POINTS | 75,250 | 44 | – | Please split the 38 days in task 003010 by phase (PCR-23); App users, Travel and Go-live from the Open Points field (PCR-24) |
| TAI-01-IMP | ERRORS | 20,025 | 15 | Unit Price 1,100 instead of 1,250 (PCR-14); Discount of 375 (PCR-16) | Quote number for block 003000 (PCR-12) |
| PRO-01-WSH | ERRORS | 3,150 | 2 | Standard block 001000..001900 missing (PCR-10) | Workshop dates for task 001010 (PCR-22) |
| LIT-01-SUP | ERRORS | 8,400 | 0 | Customer Litware Inc. (C90040) is blocked (PCR-07) | Start/end date (PCR-20); 60 hours contingent (PCR-23) |
| WWI-01-IMP | ERRORS | 19,500 | 10 | Possible duplicate WWI-02-IMP (PCR-03) | 50 hours contingent (PCR-23) |
| WWI-02-IMP | ERRORS | 12,500 | 10 | Possible duplicate WWI-01-IMP (PCR-03) | Quote number for block 002000 (PCR-12); split 10 days in 002010 (PCR-23) |

FAB-01-IMP carries the four open points Scribe Agent writes for it (users, travel, go-live, split of days) in the Open Points field; the RapidStart package `SCRIBE-PRJ-HEADERS` fills it, so install the app before importing the demo data. The split of days is asked once, by step 6c.

The other five results come from the Agent Designer version of the agent. The first run of the coded agent on FAB-01-IMP also asked for workshop dates on the travel task; step 6e now only looks at SERVICES lines. Step 6f (Open Points field) and step 8 (answers) are new, so run all six projects again before recording.

## Design decisions

- **The agent is read-only** (D365 READ). All writes (tasks, answers, events) happen in AL code, never by the agent.
- **No trigger on project insert**: tasks and planning lines do not exist yet. Scribe Agent calls `submitForReview` when it is done (PCR-27).
- **One task per project**, External ID = project No. Repeated triggers and answers add messages to that task. A task keeps the instructions it was created with, and a stopped or archived task never runs again, so the dispatcher only reuses a task that is not stopped or archived. To test new instructions, stop the old task and send the project again: it gets a new task.
- **The task message only names the project** (`Review <No.>`); the agent finds the open points in the data (step 6 of the instructions).
- **The business event is raised by code** (analysis of the output message), so the instructions stay unchanged.
- **Dispatcher interface + provider** exist only to make the triggers testable without an activated agent.
- **Answers come in through a table + API page** (`clarificationAnswers`), not a bound action with parameters: simple for Power Automate, and it keeps a log.
- **Questions go to the salesperson whenever the report has some**, also when it has findings (status ERRORS): only the salesperson can answer them, and the findings stay in the report for the project engineer.
- **The answer is passed on as text.** Project Inspector is read-only and does not change planning lines; whoever applies the answer (the engineer, or Scribe Agent) changes the project, and the next review sees the change.

### BC 29 agent API notes

Checked against the System Application source:

- `Agent Task`.GetTaskByExternalId fails when there is no task, so the dispatcher calls `TaskExists` first.
- A message is added to an existing task with `Agent Task Message Builder`.SetAgentTask(...).Create(true), which also sets the task to Ready when possible.
- Task messages default to *requires review*; the dispatcher turns that off, otherwise the agent waits for an approval.
- Business event parameters are limited to 250 characters, so `Questions` and `ProjectUrl` are cut off at 250.

## Next steps

1. **Agent end to end in the sandbox.** Set the agent up (see [Set up](#set-up)), run **Send to Project Inspector** on all six demo projects and compare with [Expected review results](#expected-review-results). Check that a second send adds a message to the same task, and that a change from Quote back to Planning starts a review.
2. **Clarification loop in Teams.** The agent's report is an outgoing message in status Draft until a user chooses **Continue** in the task pane. Check whether the business event is raised when the draft is written or only after **Continue**, and decide which one the demo needs. With four FAB questions the `Questions` parameter is about 220 of its 250 characters. Build the Power Automate flow and check that the answer reaches the same task and the agent does not ask again about answered points. Done when the FAB-01-IMP question goes to Teams and the answer produces a new report.
3. **Scribe Agent integration.** Add page 50102 `projectReviews` to the MCP configuration `SCRIBE-AGENT` (Read + Modify, bound actions allowed) and check that `submitForReview` shows up as a tool in Copilot Studio.
   - Scribe call order: customers → existing projects (PCR-03) → POST project → POST tasks → POST planning lines (no unit price) → PATCH `openPoints` → `submitForReview` once.
   - Scribe uses OCPF API pages 90842, 90846, 90854, 90910, 90912 and 90913. Test one planning line POST through page 90913 by hand first: on that page `jobTaskNo` is validated after `no` and `quantity`.
4. **Nice to have.** An own agent profile with page customizations (Totaling and Project Posting Group on the task list, Line Discount % on planning lines), an edit-instructions page for the coded agent, and more useful KPI numbers (open reviews, questions asked).

## Repository layout

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

Conventions: object prefix `PI`, namespace `Contoso.ProjectInspector` (tests: `Contoso.ProjectInspector.Test`). English for code, captions and instructions (agents support English only).

## License

[MIT](LICENSE)
