namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using System.Agents;

/// <summary>
/// The review report of one round (step 9 of the instructions). The agent records it on the Review Result card and asks
/// for assistance there, so the review opens this card: the reviewer reads the report and sets the Decision, and the
/// agent ends the task without a reply. The outgoing message page of Business Central cannot be extended
/// (Extensible = false), so a decision field or action is only possible here.
/// PI Report Monitor carries out each decided result once, and a CANCELLED report without a decision.
/// </summary>
table 50105 "PI Review Result"
{
    Access = Internal;
    Caption = 'Project Inspector Review Result';
    DataClassification = CustomerContent;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;
    LookupPageId = "PI Review Results";
    DrillDownPageId = "PI Review Results";

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the number of the review result.';
        }
        field(2; "Project No."; Code[20])
        {
            Caption = 'Project No.';
            ToolTip = 'Specifies the project that was reviewed.';
            TableRelation = Job;
        }
        field(3; Report; Text[2048])
        {
            Caption = 'Report';
            ToolTip = 'Specifies the review report of Project Inspector. The findings and questions are sent as they are here.';
        }
        field(4; "Recorded At"; DateTime)
        {
            Caption = 'Recorded At';
            ToolTip = 'Specifies when the agent recorded the result.';
            Editable = false;
        }
        field(5; "Recorded By"; Code[50])
        {
            Caption = 'Recorded By';
            ToolTip = 'Specifies the user who recorded the result, normally the Project Inspector agent.';
            DataClassification = EndUserIdentifiableInformation;
            Editable = false;
        }
        field(6; Processed; Boolean)
        {
            Caption = 'Closed';
            ToolTip = 'Specifies whether the result is closed: carried out, replaced by a newer review round, or stopped. The Status says which. A closed result cannot change.';
            Editable = false;
        }
        field(7; "Processed At"; DateTime)
        {
            Caption = 'Closed At';
            ToolTip = 'Specifies when the result was closed.';
            Editable = false;
        }
        field(8; Result; Text[250])
        {
            Caption = 'Result';
            ToolTip = 'Specifies what the report monitor did with the result.';
            Editable = false;
        }
        field(9; Decision; Enum "PI Review Result Decision")
        {
            Caption = 'Decision';
            ToolTip = 'Specifies the reviewer''s decision: Approve sets the project to Quote, Reject notifies the salesperson with the findings, Send Questions sends the questions of the report to the salesperson. Blank until the reviewer decided; nothing is carried out before.';
        }
        field(10; "Agent Task ID"; BigInteger)
        {
            Caption = 'Agent Task ID';
            ToolTip = 'Specifies the Project Inspector task that recorded the result. Its decision is carried out only after that task has finished, that is after the reviewer chose Continue.';
            Editable = false;
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
        // Processed is a Boolean, but the monitor filters on the rare side: almost every result is processed.
        key(Pending; Processed, "Entry No.")
        {
        }
    }

    /// <summary>
    /// The number is assigned here, not with AutoIncrement: an AutoIncrement number reaches the page only after the
    /// record is read again, so the agent's assistance request did not know its record and the review opened another
    /// result. With the number set before the insert, every task's review opens its own result.
    /// </summary>
    trigger OnInsert()
    var
        LastReviewResult: Record "PI Review Result";
        AgentSession: Codeunit "Agent Session";
    begin
        if "Entry No." = 0 then
            if LastReviewResult.FindLast() then
                "Entry No." := LastReviewResult."Entry No." + 1
            else
                "Entry No." := 1;
        "Recorded At" := CurrentDateTime();
        "Recorded By" := CopyStr(UserId(), 1, MaxStrLen("Recorded By"));
        LinkToAgentTask(AgentSession.GetCurrentSessionAgentTaskId());
    end;

    trigger OnModify()
    var
        AgentSession: Codeunit "Agent Session";
    begin
        LinkToAgentTask(AgentSession.GetCurrentSessionAgentTaskId());
    end;

    /// <summary>
    /// An open result belongs to the task that works on it: when the agent continues an unprocessed result of an
    /// older (for example stopped) task, its decision must wait for the current task, not for one that never finishes.
    /// AgentTaskId is -1 outside an agent session; a carried-out result keeps its task.
    /// </summary>
    procedure LinkToAgentTask(AgentTaskId: BigInteger)
    begin
        if Processed or (AgentTaskId <= 0) then
            exit;
        "Agent Task ID" := AgentTaskId;
    end;

    var
        AlreadyProcessedErr: Label 'The review result for project %1 was already carried out. Create a new result.', Comment = '%1 = project No.';

    /// <summary>
    /// The report for the full-width view on the card (RichContent, like the outgoing message page): one line per
    /// report line, characters with a meaning in HTML shown as written.
    /// </summary>
    procedure GetReportAsHtml(): Text
    var
        ReportParser: Codeunit "PI Report Parser";
    begin
        exit(ReportParser.ToHtml(Report));
    end;

    /// <summary>
    /// Opens the result of a new review round, before the agent starts: the agent never creates a result, it fills in
    /// the one Business Central created for its task (like the Payables Agent fills in a draft created by code).
    /// An older open result of the project is closed, so the agent always finds exactly one open result.
    /// </summary>
    procedure StartRound(ProjectNo: Code[20]; AgentTaskId: BigInteger)
    var
        OpenReviewResult: Record "PI Review Result";
        ReplacedTxt: Label 'Replaced by a newer review round.';
    begin
        OpenReviewResult.SetRange("Project No.", ProjectNo);
        OpenReviewResult.SetRange(Processed, false);
        OpenReviewResult.ModifyAll(Result, ReplacedTxt);
        OpenReviewResult.ModifyAll("Processed At", CurrentDateTime());
        OpenReviewResult.ModifyAll(Processed, true);

        Init();
        "Entry No." := 0;
        "Project No." := ProjectNo;
        "Agent Task ID" := AgentTaskId;
        Insert(true);
    end;

    /// <summary>
    /// The step the result is in, for the card: the agent is reviewing, waiting for the decision, waiting for Continue,
    /// or what was done.
    /// </summary>
    procedure GetStatusText(): Text
    var
        ReviewingTxt: Label 'Project Inspector is reviewing the project.';
        WaitingForDecisionTxt: Label 'Waiting for your decision in the task pane.';
        WaitingForContinueTxt: Label 'Decision: %1. Carried out after the task is finished.', Comment = '%1 = decision';
    begin
        if Processed then
            exit(Result);
        if Report = '' then
            exit(ReviewingTxt);
        if Decision = Decision::" " then
            exit(WaitingForDecisionTxt);
        exit(StrSubstNo(WaitingForContinueTxt, Decision));
    end;

    /// <summary>
    /// Stores the report as the reviewer edited it in the full-width view (HTML), one line per report line.
    /// </summary>
    procedure SetReportFromHtml(Html: Text)
    var
        ReportParser: Codeunit "PI Report Parser";
    begin
        if Processed then
            Error(AlreadyProcessedErr, "Project No.");
        Report := CopyStr(ReportParser.ToReportText(Html), 1, MaxStrLen(Report));
    end;
}
