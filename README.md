# Project Inspector

Business Central agent that reviews every new customer project in status **Planning** against the Contoso project creation rules (PCR) and reports findings and questions for the salesperson. Demo for Directions EMEA 2026, session "One Voice Note, a Complete Project".

The agent was designed and tested in Agent Designer, exported (`App/.resources/Instructions/ProjectInspector-agent-export.xml`) and moved into this app with the AL **Agent** project template.

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
| 50150 PI Review Trigger Tests | Submit for Review, status change to Planning, no active agent, unsaved project |
| 50151 PI Report Parser Tests | questions, status and project No. from the report, CR LF |
| 50152 PI Clarification Answer Tests | answer goes to the task of the project, empty answer, unknown project |
| 50153 PI Clarification Event Tests | business event raised only when there are questions, project No. fallback |

Not covered by unit tests (needs a real agent, check by hand): `PI Agent Task Dispatcher` (Tasks AL API) and `PI Agent Task Execution` (runs in the agent session).

## Change the instructions

Edit `App/.resources/Instructions/InstructionsV1.txt`, raise the version in `App/app.json` and publish. `PI Agent Upgrade` sets the new instructions on every Project Inspector agent.
