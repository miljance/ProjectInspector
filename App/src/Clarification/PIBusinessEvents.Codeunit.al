namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using System.Integration;

/// <summary>
/// Business events of Project Inspector. Power Automate subscribes with
/// "When a business event occurs" (category Project Inspector).
/// </summary>
codeunit 50111 "PI Business Events"
{
    Access = Public;

    procedure RaiseClarificationRequested(var Job: Record Job; ReviewStatus: Text; Questions: Text)
    begin
        ProjectClarificationRequested(
            Job.SystemId, Job."No.", Job.Description, Job."Sell-to Customer Name",
            CopyStr(ReviewStatus, 1, 30), CopyStr(Questions, 1, 250), CopyStr(GetProjectUrl(Job), 1, 250));
        OnAfterClarificationRequested(Job."No.", Questions);
    end;

    /// <summary>
    /// Project Inspector reviewed a project and has questions for the salesperson.
    /// Questions holds one question per line, each ending with its rule ID.
    /// Business event parameters are limited to 250 characters, longer questions are cut off.
    /// </summary>
    [ExternalBusinessEvent('ProjectClarificationRequested', 'Project clarification requested', 'Project Inspector reviewed a project and has questions for the salesperson.', EventCategory::"Project Inspector")]
    local procedure ProjectClarificationRequested(ProjectId: Guid; ProjectNo: Code[20]; ProjectDescription: Text[100]; CustomerName: Text[100]; ReviewStatus: Text[30]; Questions: Text[250]; ProjectUrl: Text[250])
    begin
    end;

    /// <summary>
    /// Raised together with the business event, for AL subscribers (and the tests).
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterClarificationRequested(ProjectNo: Code[20]; Questions: Text)
    begin
    end;

    local procedure GetProjectUrl(var Job: Record Job): Text
    begin
        if IsNullGuid(Job.SystemId) then
            exit('');
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Job Card", Job, true));
    end;
}
