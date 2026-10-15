namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using System.Agents;

/// <summary>
/// For running the demo projects again after the instructions changed (an evaluation run), not for Scribe Agent:
/// GET  /api/contoso/projectInspector/v1.0/companies({id})/reviewReports returns the latest report of each project,
/// POST .../reviewReports({id})/Microsoft.NAV.restartReview stops the project's task and starts a new one.
/// </summary>
page 50106 "PI Review Reports API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'projectInspector';
    APIVersion = 'v1.0';
    EntityName = 'reviewReport';
    EntitySetName = 'reviewReports';
    EntityCaption = 'Review Report';
    EntitySetCaption = 'Review Reports';
    SourceTable = Job;
    ODataKeyFields = SystemId;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    Extensible = false;

    layout
    {
        area(Content)
        {
            repeater(Records)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                field(number; Rec."No.")
                {
                    Caption = 'No.';
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                }
                field(taskId; TaskId)
                {
                    Caption = 'Task Id';
                }
                field(taskStatus; TaskStatus)
                {
                    Caption = 'Task Status';
                }
                field(reportStatus; ReportStatus)
                {
                    Caption = 'Report Status';
                }
                field(reportCreatedAt; ReportCreatedAt)
                {
                    Caption = 'Report Created At';
                }
                field(report; ReportText)
                {
                    Caption = 'Report';
                }
            }
        }
    }

    var
        TaskId: BigInteger;
        TaskStatus: Text;
        ReportStatus: Text;
        ReportCreatedAt: DateTime;
        ReportText: Text;

    trigger OnAfterGetRecord()
    begin
        LoadLatestReport();
    end;

    /// <summary>
    /// Stops the review task of the project and starts a new one with the current instructions.
    /// </summary>
    [ServiceEnabled]
    procedure RestartReview(var ActionContext: WebServiceActionContext)
    var
        ReviewTrigger: Codeunit "PI Review Trigger";
    begin
        ReviewTrigger.RestartReview(Rec);

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"PI Review Reports API");
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    local procedure LoadLatestReport()
    var
        AgentTask: Record "Agent Task";
        AgentTaskMessage: Record "Agent Task Message";
        PIAgentSetup: Codeunit "PI Agent Setup";
        AgentMessage: Codeunit "Agent Message";
        AgentUserSecurityId: Guid;
    begin
        Clear(TaskId);
        Clear(TaskStatus);
        Clear(ReportStatus);
        Clear(ReportCreatedAt);
        Clear(ReportText);
        if not PIAgentSetup.TryGetActiveAgent(AgentUserSecurityId) then
            exit;

        AgentTask.SetRange("Agent User Security ID", AgentUserSecurityId);
        AgentTask.SetRange("External ID", Rec."No.");
        AgentTask.SetRange("Company Name", CompanyName());
        if not AgentTask.FindLast() then
            exit;
        TaskId := AgentTask.ID;
        TaskStatus := Format(AgentTask.Status);

        AgentTaskMessage.SetRange("Task ID", AgentTask.ID);
        AgentTaskMessage.SetRange(Type, AgentTaskMessage.Type::Output);
        if not AgentTaskMessage.FindSet() then
            exit;
        repeat
            if AgentTaskMessage.SystemCreatedAt > ReportCreatedAt then begin
                ReportCreatedAt := AgentTaskMessage.SystemCreatedAt;
                ReportStatus := Format(AgentTaskMessage.Status);
                ReportText := AgentMessage.GetText(AgentTaskMessage);
            end;
        until AgentTaskMessage.Next() = 0;
    end;
}
