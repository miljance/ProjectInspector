# Project Inspector

A Business Central agent, built with the AL Agent SDK, that reviews every new customer project in status **Planning** against the Contoso project creation rules (PCR). It writes one review report per round, the project engineer decides once (approve, reject, or send the questions to the salesperson), and Business Central carries the decision out and tells the team in Teams. When the salesperson answers, Project Inspector applies the answers to the project and reviews it again.

Built for the Directions EMEA 2026 session **"One Voice Note, a Complete Project. AI Agents at Work in Business Central"** (29 Oct 2026). The agent was designed and tested in Agent Designer, exported (`App/.resources/Instructions/ProjectInspector-agent-export.xml`) and moved into this app with the AL **Agent** project template.

**Status:** version 2.21 compiles against BC 29 and all 97 tests pass in a BC 29 sandbox. The one-approval review flow (Review Result page, decision after Continue) is being tested end to end in the sandbox, see [Next steps](#next-steps).

All demo content is fictional (CRONUS US style). **Never add real customer, company or product names.**

## The demo

| Part | Presenter | Tool | Agent |
| --- | --- | --- | --- |
| Voice note / Teams transcript → project in BC | Nikola Pančić | Copilot Studio + BC MCP server | **Scribe Agent** |
| Review of the new project, decision, answers from the salesperson | Miljan Milosavljević | BC Agent SDK (this repo) | **Project Inspector** |

1. The salesperson records a voice note about a customer call.
2. Scribe Agent creates the project in status Planning through the BC MCP server (project, then `buildProjectStructure` for all tasks and planning lines) and calls `submitForReview`.
3. **Project Inspector** reviews the project against the rules PCR-01..PCR-31 and records its report on the **Project Inspector Review Result** page.
4. The project engineer reads the report there (and may edit it), chooses **Approve**, **Reject** or **Send Questions** in the **Decision** field on that page and then **Continue** in the task pane.
5. Business Central carries out the decision: status Quote, or a business event that Power Automate posts to Teams.
6. The salesperson's answer comes back through the `clarificationAnswers` API; Project Inspector applies it to the project and the next round starts at step 3.

The demos are recorded, not live. Environment: BC 29 sandbox (US localization, currency USD); the demo data sits in its own company. Scribe Agent uses the OCPF APIs v3 and the MCP configuration `SCRIBE-AGENT`. The demo data and the rules document `Contoso Project Templates and Policies.md` are kept with the session material, not in this repo.

## How it works

### Review triggers

| Trigger | Where | Code |
| --- | --- | --- |
| Submit for Review | Scribe Agent calls the bound action `submitForReview` on `projectReviews` through the MCP server | `PI Review Trigger`.SubmitForReview |
| Send to Project Inspector | Action on the Project Card | `PI Review Trigger`.SubmitForReview |
| Status changes back to Planning | `OnAfterValidate` of Status in table extension `PI Job` (existing projects with tasks only, never blocks the change: Scribe Agent creates a project as Open and sets Planning before it builds the structure) | `PI Review Trigger`.OnAfterStatusValidated |
| Restart review | Bound action `restartReview` on `reviewReports` (evaluation runs) | `PI Review Trigger`.RestartReview |

All triggers send `Review <No.>` to the project's task, External ID = project No. `PI Agent Task Dispatcher` reuses the newest task of the project that is not stopped or archived (also a completed one) and creates a new task otherwise. A task keeps the instructions it was created with, so after new instructions stop the old task (or use `restartReview`) to get a new one.

### The agent's home page

Project Inspector runs with its own profile **Project Inspector Agent** and home page `PI Agent Role Center` (50109): Projects, Customers and Project Inspector Review Results. An agent cannot search for pages, it only reaches what its home page and the opened pages offer. On the Project Manager home page it could not reach the Review Results page. The upgrade sets the profile on existing agents (`PI Agent Setup`.UpdateProfile, per company).

Permissions: **D365 READ** to review, plus **PI Agent Edit** to apply the salesperson's answers (Job, Job Task, Job Task Dimension, Job Planning Line) and to record the review result.

### One review round, one approval

1. The agent checks the project (steps 1 to 6 of the instructions). A project without tasks is a finding, not a reason to stop.
2. Business Central has already created the result of the round (table `PI Review Result` 50105) together with the task or message: `PI Review Trigger` calls `StartRound` for every review and every answer, ties the result to the agent task and closes an older open result of the project. The agent opens Project Inspector Review Results from its home page, opens its project's result (never New) and writes the report into the card (50108).
3. It asks for assistance **on the card**. The review opens the card: the report in a full-width editable field and the **Decision** field (Approve, Reject, Send Questions).
4. The engineer may edit the report (findings and questions are sent as they are on the card), **chooses the decision in the Decision field** and chooses **Continue**. Only a person can set the Decision: the table refuses it in the agent's session and records who decided (`Decided By`, `Decided At`), and the monitor carries out only a decision a person set. Business Central cannot tell which option a reviewer gave the agent (the agent log is OnPrem only), so this keeps a confused or prompt-injected agent from approving a project on its own. The agent only checks that the field is filled and ends the task; it never replies.
5. **Nothing happens before Continue.** The job queue job `PI Report Monitor` (every minute, created in the company on the first review) carries out a result only when its agent task is completed, each result in its own transaction (`PI Review Result Processor`): a result that fails keeps its error in Status and is tried again, the others still go out. The Status says what really happened, also when an Approve could not set Quote. "Decide later" or "Stop task" leaves it untouched. The card shows the step in **Status**: waiting for your decision, decision waiting for Continue, or what was done.

A result is **Closed** when it was carried out, replaced by a newer round, or its task was stopped ("Review stopped before a decision.", nothing is carried out); the Status says which. A closed result is read-only, and in the agent's session the Review Results list shows only open results, so a new round never overwrites an old one. The agent writes into a plain Report field that only its session shows; people see the report in a full-width editor in its own FastTab, and the Project Card shows Open Points the same way.

### Decisions and business events

All events are external business events in category *Project Inspector*; parameters are limited to 250 characters each.

| Event | Raised when | Main parameters |
| --- | --- | --- |
| **ProjectClarificationRequested** | Decision Send Questions | ReviewStatus, Questions (one per line) |
| **ProjectReviewApproved** | Decision Approve; the project is set to status Quote first | NewStatus |
| **ProjectRejected** | Decision Reject | Findings (one per line) |
| **ProjectChangesNotApplied** | The report lists answers the agent could not apply ("Not applied") | NotApplied |
| **ProjectCancelled** | The salesperson cancelled the project (CANCELLED report, no decision needed) | Reason |

Every event also has ProjectId, **ReviewResultId**, ProjectNo, ProjectDescription, CustomerName and ProjectUrl. Each decision is logged once in `PI Review Decision Entry`.

The platform limits every text parameter of an external business event to 250 characters (compiler error AL0762), so Questions, Findings, NotApplied and Reason are only a preview: FAB-01-IMP's eight questions are 460 characters. The flows read the full texts with **Get record** on `reviewResults` using ReviewResultId.

### Answers from the salesperson

Power Automate posts the answer to `clarificationAnswers`; `PI Review Trigger`.RegisterAnswer adds it to the project's task. Project Inspector applies the answers (instructions, *When answers arrive*): dates, quantities, new planning lines, split of days, quote numbers for `Q-NEW-<n>`, Open Points. It never changes Unit Price or Line Discount %: a price or discount from an answer goes to **Not applied** with the reason (PCR-14, PCR-16) and on to Teams. Then it reviews the changed project and records the next report.

### Power Automate flows

All flows post to the same Teams channel.

1. **Questions:** When a business event occurs (*ProjectClarificationRequested*) → **Get record** on `reviewResults` with id = ReviewResultId → Teams adaptive card to the salesperson with `questions` from that record and an answer field → Create record on `clarificationAnswers` with `projectNo`, `answer`, `answeredBy`.
2. **Approved, rejected, changes not applied, cancelled:** one flow per event, each When a business event occurs → Get record on `reviewResults` (for rejected and not applied: `findings`, `notApplied`) → Post message in a chat or channel. Multi-line texts: `replace(body('Get_record')?['findings'], decodeUriComponent('%0A'), '<br>')`.

### APIs

Base URL: `/api/contoso/projectInspector/v1.0/companies({companyId})/`

| Entity set | Page | Used by |
| --- | --- | --- |
| `projectReviews` (GET, PATCH `openPoints`, actions `submitForReview`, `buildProjectStructure`) | 50102 | Scribe Agent through the MCP server (configuration `SCRIBE-AGENT`, Read + Modify, bound actions allowed) |
| `clarificationAnswers` (POST) | 50103 | Power Automate |
| `agentStatuses` (GET) | 50105 | Checking a deployment: instructions version and counters of each agent |
| `reviewReports` (GET, action `restartReview`) | 50106 | Evaluation runs: latest report of each project (reply or recorded result), start a new review task |
| `reviewResults` (GET) | 50110 | Power Automate: full questions, findings and answers not applied of the review result named in a business event (ReviewResultId), plus decision and status |

`buildProjectStructure(tasksJson, linesJson)` creates all tasks and planning lines of a project without tasks in one call, because the BC MCP server leaves out `Job No.` (Job Task) and `Line No.` (Job Planning Line) on create. Both parameters are JSON arrays sent as text:

- tasksJson: `[{"jobTaskNo", "description", "jobTaskType"}]` (Posting, Heading, Total, Begin-Total, End-Total), in the order of the task list. The tasks are indented and End-Totals get their Totaling.
- linesJson: `[{"jobTaskNo", "type", "no", "description", "quantity", "unitOfMeasureCode", "lineType", "planningDate"}]`; `quantity` is required, `planningDate` is YYYY-MM-DD. Line numbers are 10000, 20000 … per task; the line takes the project's currency, and the price always comes from the card (PCR-14), a price in the JSON is ignored.
- Only a project in status Planning without tasks is built; a `totaling` in tasksJson is used for Total tasks.

## Set up

1. In `App` and `Test`, copy `.vscode/launch.example.json` to `.vscode/launch.json` and set your tenant and sandbox. `launch.json` is not in the repo.
2. Run *Download symbols* in both folders, then publish **App** (F5 in the App folder).
3. **Copilot & agent capabilities**: enable *Project Inspector*.
4. Role Center: choose the Project Inspector avatar with **+**, set it up, add the users who may send it tasks (project managers, the Copilot Studio and Power Automate connection users) and activate it. The agent gets its profile and permissions from the app.
5. If the environment also has a Project Inspector built in Agent Designer, deactivate it, so there is only one.
6. Assign the permission set **PI Project Inspector** to the users and connections from step 4.
7. Open a project in Planning and choose **Send to Project Inspector**. Check **Job Queue Entries**: *Project Inspector: send review decisions and notifications* must be Ready.

To load the demo data, apply the RapidStart packages `SCRIBE-DEMO`, `SCRIBE-PRJ-HEADERS` and `SCRIBE-PRJ-LINES` in that order.

## Tests

The tests do not need an activated agent: `PI Test Library`.UseMockDispatcher replaces the agent task dispatcher with `PI Mock Task Dispatcher` through `PI Dispatcher Provider` (it also answers whether a task is finished), and `PI Clarification Event Spy` records every business event.

1. Make sure the sandbox has **Library Assert** and **Test Runner** installed.
2. Publish **App**, then **Test**. When the `PI ITask Dispatcher` interface gets a new method, publish a Test app with the new mock method first, then App, then the full Test app.
3. Run the codeunits with the AL Test Runner extension or the **AL Test Tool** page (130451): *Get Test Codeunits* → *Run*.

| Codeunit | Covers |
| --- | --- |
| 50150 PI Review Trigger Tests | Submit for Review, restart, status change to Planning (only with tasks), no active agent, unsaved and temporary project |
| 50151 PI Report Parser Tests | questions, findings, not applied, status and project No. from the report, CR LF and HTML line breaks |
| 50152 PI Clarification Answer Tests | answer goes to the task of the project, empty answer, unknown project |
| 50153 PI Clarification Event Tests | questions event, project No. fallback |
| 50154 PI Agent KPI Tests | the summary page shows which instructions version the agent has |
| 50155 PI Report Monitor Tests | each sent reply is read once and logged |
| 50156 PI Report Event Tests | approve, reject, questions, not applied and cancelled from a report with a Decision line |
| 50157 PI Review Decision Tests | each decision is logged and carried out once |
| 50158 PI Project Structure Tests | `buildProjectStructure`: indentation, totaling (also Total tasks), line numbers, card prices, unit of measure, project currency, required quantity, date format, status Planning, refused input |
| 50159 PI Suggestion Tests | no decision buttons on the result card (the reviewer uses the Decision field), project check elsewhere, the agent's own profile |
| 50163 PI Review Result Tests | one result per round created by code, older open result replaced, stopped task closes its result, only a decision a person chose is carried out, events name their result and the full questions are readable, decision waits for Continue, each result carried out once, edited report, status text, task link |
| 50164 PI Planned Days Tests | Planned Days on the Project Card sum only the resource lines planned in days |
| 50165 PI Planning Lines Page Tests | Project Planning Lines show Line Discount Amount |

Not covered by unit tests, because they need an agent session or a real agent: `PI Agent Task Dispatcher` (Tasks AL API, task status), the agent-session parts of the result pages (only open results, Decision editable only for the agent), and the agent's behaviour itself. Check those in the sandbox.

Write tests first, with Given/When/Then comments and one behaviour per test. Change a test only when it is wrong about BC behaviour. Example: `Job.Validate(Status)` on an unsaved project always fails in the base application (`Status - OnValidate` calls `Modify`), so that case calls `PI Review Trigger`.OnAfterStatusValidated directly.

## Agent instructions

The instructions are in `App/.resources/Instructions/InstructionsV1.txt`. To change them, edit the file, raise the version in `App/app.json` and publish: `PI Agent Upgrade` sets the new instructions, permissions and profile on every Project Inspector agent. After publishing, check **Instructions version** in the agent setup dialog or with GET `agentStatuses`: Business Central cannot show the instructions themselves.

They were tuned on the six demo projects below, so after a change run all six again with `tools/Run-ReviewEval.ps1` (it restarts the reviews through the `reviewReports` API, waits for the reports and checks status, totals and every finding and question by rule ID). **Each run is a real agent task and uses Copilot credits.** `PI Report Parser` reads the report format of step 7: if the format changes, change the parser and the samples in `Test/src/Library/PITestLibrary.Codeunit.al` together.

### Expected review results

| Project | Status | Total | Days | Findings | Questions |
| --- | --- | --- | --- | --- | --- |
| FAB-01-IMP | OPEN POINTS | 75,250 | 44 | – | Quote numbers for blocks 002000, 003000, 004000 and 005000 (PCR-12); App users, Travel, Go-live and Discount from the Open Points field (PCR-24) |
| TAI-01-IMP | ERRORS | 20,025 | 15 | Unit Price 1,100 instead of 1,250 (PCR-14); Discount of 375 (PCR-16) | Quote number for block 003000 (PCR-12) |
| PRO-01-WSH | ERRORS | 3,150 | 2 | Standard block 001000..001900 missing (PCR-10) | Workshop dates for task 001010 (PCR-22) |
| LIT-01-SUP | ERRORS | 8,400 | 0 | Customer Litware Inc. (C90040) is blocked (PCR-07) | Start/end date (PCR-20); 60 hours contingent (PCR-23) |
| WWI-01-IMP | ERRORS | 19,500 | 10 | Possible duplicate WWI-02-IMP (PCR-03) | 50 hours contingent (PCR-23) |
| WWI-02-IMP | ERRORS | 12,500 | 10 | Possible duplicate WWI-01-IMP (PCR-03) | Quote number for block 002000 (PCR-12); split 10 days in 002010 (PCR-23) |

FAB-01-IMP is the version Scribe Agent builds from the Teams meeting transcript: Sara splits the 38 days by phase (four lines in 003010), the call gives no quote numbers (blocks `Q-NEW-1` … `Q-NEW-4`), and the Open Points field holds the quote-number line plus users, travel, go-live and the 10 % discount Laura asked for. The RapidStart package `SCRIBE-PRJ-HEADERS` fills the field, so install the app before importing the demo data. The quote-number line is asked by step 2g, block by block. The implementation block has no TRAVEL task until the trips are agreed; when the salesperson answers, the agent adds the task (*When answers arrive*).

Version 2.21 (instructions rewritten so that every rule appears once) matches all six (18 Oct 2026, one evaluation run). Versions 2.13 to 2.20 got 3 to 5 of 6 per run, each missing a different check. The evaluation also checks that every line of the Open Points field is a question in the first report. Tests change the demo data (answers are applied to the projects), so run `tools/Reset-DemoData.ps1 -Tenant <tenant id> -PackageFolder <folder with the .rapidstart files>` before an evaluation or a recording: it deletes the six projects and imports the packages again. RapidStart writes Unit Price and Line Discount % before Business Central takes the price from the resource card, so after applying `SCRIBE-PRJ-LINES` the script sets both again on the planning lines (TAI-01-IMP: 12 × 1,100 and 10 % on 3 × 1,250), otherwise TAI shows 22,200 and no discount.

## Design decisions

- **The agent changes data only for the salesperson's answers** (PI Agent Edit) and to record its review result. Status changes, decisions and business events happen in AL code (`PI Report Monitor`), never by the agent.
- **One approval per round.** The engineer decides once, on the Review Result card, with the options in the task pane. Tried and dropped: decision actions on the Project Card (decisions belong to the agent's options, like the Payables Agent's), a help request followed by a review of the reply (two steps), options on the review of an outgoing message (Business Central shows none there), and editing a Decision line in the reply (Sales Order Agent style).
- **Only a person decides.** The reviewer chooses the decision in a field on the card; a decision the agent user set is never carried out.
- **The agent never replies.** Like the Payables Agent, it limits its interactions to asking for assistance; the report lives on our page, where we control the fields.
- **Nothing happens before Continue.** A decision counts only after the agent task that recorded it has completed.
- **No trigger on project insert**: tasks and planning lines do not exist yet. Scribe Agent calls `submitForReview` when it is done (PCR-27).
- **One task per project**, External ID = project No. Repeated triggers and answers add messages to that task until it is stopped or archived.
- **The task message only names the project** (`Review <No.>`); the agent finds the open points in the data (steps 1 to 6 of the instructions).
- **Dispatcher interface + provider** exist only to make the triggers and the Continue check testable without an activated agent.
- **Answers come in through a table + API page** (`clarificationAnswers`), not a bound action with parameters: simple for Power Automate, and it keeps a log.
- **Business Central does the arithmetic.** The report's total is the Billable (Total Price) of task 999999 and its days are **Planned Days** on the Project Card (resource lines with unit of measure DAY). Its discount check reads Line Discount Amount, which Project Inspector shows on Project Planning Lines. Adding up the lines itself, the agent was off by 100 USD or 2 days in some runs.
- **Instructions state every rule once.** Each check names its rule ID and the exact finding or question text; the review keeps two lists (findings, questions) from the first step to the report, and checks every planning line in one pass while the page is open. Versions 2.13 to 2.20 added a sentence per failed run and ended with checks that were skipped at random; 2.21 rewrote the text from scratch (190 to 147 lines).
- **Prices always come from the cards** (PCR-14), also in `buildProjectStructure`; a price discussed with the customer becomes an open point (PCR-15, PCR-16) for a person to decide.

### BC 29 agent API notes

Checked against the System Application source and in the sandbox:

- A message is added to an existing task with `Agent Task Message Builder`.SetAgentTask(...).Create(true), which also sets the task to Ready when possible. Task messages default to *requires review*; the dispatcher turns that off.
- A task keeps the instructions it was created with; a stopped task never runs again.
- `AnalyzeAgentTaskMessage` is called only for a task's input messages, not for the agent's replies.
- Suggestions (`GetAgentTaskUserInterventionSuggestions`) are shown for assistance requests; the review of an outgoing message shows only Continue and Decide later. The request details carry the page the agent is on (`Page ID`).
- The outgoing message page (4308 `Agent Task Message Card`) is `Extensible = false`: no action or field can be added there.
- The review opens the page the agent is on, with the record the assistance request names ("Entry No.: 2"). With an AutoIncrement key the request did not know its record and the review opened another result, so `PI Review Result` assigns its number in `OnInsert`. The card also sorts newest first as a fallback.
- `Agent Task Log Entry` is OnPrem only: cloud code cannot read which option the reviewer chose. `Agent Session`.GetCurrentSessionAgentTaskId tells a record which task wrote it.
- An agent cannot search for pages; give it its own profile with every page it needs. `Agent`.SetProfile needs a company, so call it in `OnUpgradePerCompany`.
- Business event parameters are limited to 250 characters.
- Publishing an App that drops a table the installed Test app uses fails and leaves both apps uninstalled; publish them again in the right order.

## Next steps

1. **One-approval flow end to end.** Stop old tasks, send FAB-01-IMP, check that a new result is created, that the card opens on it, that the decision waits for Continue and that the Status shows the outcome.
2. **Power Automate.** Build the four notification flows (approved, rejected, changes not applied, cancelled) and check the questions loop: card in Teams, answer on the same task, answers applied, next report.
3. **Evaluation.** Re-import the demo data and run the six projects with `tools/Run-ReviewEval.ps1` (uses Copilot credits).
4. **Before the session.** The app is published from VS Code (Dev); upload it as a per-tenant extension so a sandbox update does not remove it.

## Repository layout

```
ProjectInspector/
├── ProjectInspector.code-workspace   open this in VS Code
├── App/                              the agent app (50100..50149)
│   ├── .resources/Instructions/
│   │   ├── InstructionsV1.txt        agent instructions
│   │   └── ProjectInspector-agent-export.xml
│   └── src/
│       ├── Agent/                    agent registration, setup, profile + home page, KPI, install/upgrade, task execution
│       ├── Review/                   review triggers, dispatcher, Open Points field, Project Card action
│       ├── Clarification/            report parser, business events, report monitor, answers table and page
│       ├── Decision/                 Review Result table and pages, decision log
│       ├── Api/                      projectReviews (buildProjectStructure), clarificationAnswers, agentStatuses, reviewReports
│       └── Permissions/
├── Test/                             test app (50150..50199)
│   └── src/
│       ├── Tests/                    test codeunits (Given/When/Then)
│       └── Library/                  mock dispatcher, event spy, test data
└── tools/
    ├── Run-ReviewEval.ps1            evaluation runner
    └── Reset-DemoData.ps1            demo projects back to the RapidStart packages
```

Conventions: object prefix `PI`, namespace `Contoso.ProjectInspector` (tests: `Contoso.ProjectInspector.Test`). English for code, captions and instructions (agents support English only).

## License

[MIT](LICENSE)
