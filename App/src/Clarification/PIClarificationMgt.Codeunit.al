namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Decides whether a review report needs an answer from the salesperson and raises the business event.
/// </summary>
codeunit 50110 "PI Clarification Mgt."
{
    Access = Internal;

    var
        ReportParser: Codeunit "PI Report Parser";
        BusinessEvents: Codeunit "PI Business Events";

    /// <summary>
    /// Called for every message the agent writes. Returns true when the business event was raised.
    /// </summary>
    /// <param name="ExternalId">External ID of the agent task, which is the project No. Empty for tasks started by hand.</param>
    /// <param name="ReportText">The text of the agent message.</param>
    procedure HandleAgentReport(ExternalId: Text; ReportText: Text): Boolean
    var
        Job: Record Job;
        ProjectNo: Code[20];
    begin
        if not ReportParser.HasQuestions(ReportText) then
            exit(false);

        ProjectNo := CopyStr(ExternalId, 1, MaxStrLen(ProjectNo));
        if ProjectNo = '' then
            ProjectNo := ReportParser.GetProjectNo(ReportText);
        if ProjectNo = '' then
            exit(false);

        if not Job.Get(ProjectNo) then
            Job."No." := ProjectNo;

        BusinessEvents.RaiseClarificationRequested(Job, ReportParser.GetStatus(ReportText), ReportParser.GetQuestionsText(ReportText));
        exit(true);
    end;
}
