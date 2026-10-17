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
    // No InherentPermissions on the table: who may read, record and change results comes from the permission sets
    // (PI Project Inspector, PI Agent Edit); the code that creates and carries out results grants itself what it needs.
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
            ToolTip = 'Specifies the reviewer''s decision: Approve sets the project to Quote, Reject notifies the salesperson with the findings, Send Questions sends the questions of the report to the salesperson. Choose it here and then Continue in the task pane; only the reviewer chooses it, never the agent. Nothing is carried out before the task is finished.';

            trigger OnValidate()
            var
                AgentSession: Codeunit "Agent Session";
                AgentMetadataProvider: Enum "Agent Metadata Provider";
            begin
                if AgentSession.IsAgentSession(AgentMetadataProvider) then
                    Error(OnlyReviewerDecidesErr);
                if Processed then
                    Error(AlreadyProcessedErr, "Project No.");
                if Decision = Decision::" " then begin
                    Clear("Decided By");
                    Clear("Decided At");
                end else begin
                    "Decided By" := UserSecurityId();
                    "Decided At" := CurrentDateTime();
                end;
            end;
        }
        field(11; "Decided By"; Guid)
        {
            Caption = 'Decided By';
            ToolTip = 'Specifies the user who chose the decision. Only a decision chosen by a person, not by the agent, is carried out.';
            DataClassification = EndUserPseudonymousIdentifiers;
            Editable = false;
        }
        field(12; "Decided At"; DateTime)
        {
            Caption = 'Decided At';
            ToolTip = 'Specifies when the reviewer chose the decision.';
            Editable = false;
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
        if "Entry No." = 0 then begin
            // Two rounds can start at the same time (an API submit and a status change).
            LastReviewResult.LockTable();
            if LastReviewResult.FindLast() then
                "Entry No." := LastReviewResult."Entry No." + 1
            else
                "Entry No." := 1;
        end;
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
        OnlyReviewerDecidesErr: Label 'Only the reviewer chooses the decision. Ask for assistance on this page and wait for the reviewer.';

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
    [InherentPermissions(PermissionObjectType::TableData, Database::"PI Review Result", 'RIM')]
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
        WaitingForDecisionTxt: Label 'Waiting for your decision: choose it in the Decision field and then Continue in the task pane.';
        NotByReviewerTxt: Label 'Decision %1 was not chosen by a reviewer and is not carried out. Choose the decision in the Decision field.', Comment = '%1 = decision';
        WaitingForContinueTxt: Label 'Decision: %1. Carried out after the task is finished.', Comment = '%1 = decision';
    begin
        if Processed then
            exit(Result);
        if Report = '' then
            exit(ReviewingTxt);
        if Decision = Decision::" " then
            exit(WaitingForDecisionTxt);
        if not IsDecidedByReviewer() then
            exit(StrSubstNo(NotByReviewerTxt, Decision));
        exit(StrSubstNo(WaitingForContinueTxt, Decision));
    end;

    /// <summary>
    /// True when a person chose the decision on the card: Business Central cannot tell which option the reviewer gave
    /// the agent, so only a decision a person set here is carried out, never one the agent user set.
    /// </summary>
    procedure IsDecidedByReviewer(): Boolean
    var
        PIAgentSetup: Record "PI Agent Setup";
    begin
        if IsNullGuid("Decided By") then
            exit(false);
        exit(not PIAgentSetup.Get("Decided By"));
    end;

    /// <summary>
    /// The full questions of the report, one per line, for the reviewResults API (business event parameters are cut at 250).
    /// </summary>
    procedure GetQuestionsText(): Text
    var
        ReportParser: Codeunit "PI Report Parser";
    begin
        exit(ReportParser.GetQuestionsText(Report));
    end;

    procedure GetFindingsText(): Text
    var
        ReportParser: Codeunit "PI Report Parser";
    begin
        exit(ReportParser.GetFindingsText(Report));
    end;

    procedure GetNotAppliedText(): Text
    var
        ReportParser: Codeunit "PI Report Parser";
    begin
        exit(ReportParser.GetNotAppliedText(Report));
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
