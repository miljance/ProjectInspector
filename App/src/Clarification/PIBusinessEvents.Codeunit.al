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
        OnAfterReviewEventRaised('ProjectClarificationRequested', Job."No.", Questions);
    end;

    procedure RaiseReviewApproved(var Job: Record Job)
    begin
        ProjectReviewApproved(
            Job.SystemId, Job."No.", Job.Description, Job."Sell-to Customer Name",
            CopyStr(Format(Job.Status), 1, 30), CopyStr(GetProjectUrl(Job), 1, 250));
        OnAfterReviewEventRaised('ProjectReviewApproved', Job."No.", Format(Job.Status));
    end;

    procedure RaiseRejected(var Job: Record Job; Findings: Text)
    begin
        ProjectRejected(
            Job.SystemId, Job."No.", Job.Description, Job."Sell-to Customer Name",
            CopyStr(Findings, 1, 250), CopyStr(GetProjectUrl(Job), 1, 250));
        OnAfterReviewEventRaised('ProjectRejected', Job."No.", Findings);
    end;

    procedure RaiseChangesNotApplied(var Job: Record Job; NotApplied: Text)
    begin
        ProjectChangesNotApplied(
            Job.SystemId, Job."No.", Job.Description, Job."Sell-to Customer Name",
            CopyStr(NotApplied, 1, 250), CopyStr(GetProjectUrl(Job), 1, 250));
        OnAfterReviewEventRaised('ProjectChangesNotApplied', Job."No.", NotApplied);
    end;

    procedure RaiseCancelled(var Job: Record Job; Reason: Text)
    begin
        ProjectCancelled(
            Job.SystemId, Job."No.", Job.Description, Job."Sell-to Customer Name",
            CopyStr(Reason, 1, 250), CopyStr(GetProjectUrl(Job), 1, 250));
        OnAfterReviewEventRaised('ProjectCancelled', Job."No.", Reason);
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
    /// The reviewer approved the project; it is now in status Quote.
    /// </summary>
    [ExternalBusinessEvent('ProjectReviewApproved', 'Project review approved', 'The reviewer approved the project after the Project Inspector review; it is now in status Quote.', EventCategory::"Project Inspector")]
    local procedure ProjectReviewApproved(ProjectId: Guid; ProjectNo: Code[20]; ProjectDescription: Text[100]; CustomerName: Text[100]; NewStatus: Text[30]; ProjectUrl: Text[250])
    begin
    end;

    /// <summary>
    /// The reviewer rejected the project. Findings holds one finding per line (at most 250 characters).
    /// </summary>
    [ExternalBusinessEvent('ProjectRejected', 'Project rejected', 'The reviewer rejected the project after the Project Inspector review.', EventCategory::"Project Inspector")]
    local procedure ProjectRejected(ProjectId: Guid; ProjectNo: Code[20]; ProjectDescription: Text[100]; CustomerName: Text[100]; Findings: Text[250]; ProjectUrl: Text[250])
    begin
    end;

    /// <summary>
    /// Project Inspector could not apply some of the salesperson's answers. NotApplied holds one point per line with the reason.
    /// </summary>
    [ExternalBusinessEvent('ProjectChangesNotApplied', 'Project changes not applied', 'Project Inspector could not apply some answers of the salesperson; the salesperson has to change them.', EventCategory::"Project Inspector")]
    local procedure ProjectChangesNotApplied(ProjectId: Guid; ProjectNo: Code[20]; ProjectDescription: Text[100]; CustomerName: Text[100]; NotApplied: Text[250]; ProjectUrl: Text[250])
    begin
    end;

    /// <summary>
    /// The salesperson cancelled the project in an answer; Project Inspector stopped.
    /// </summary>
    [ExternalBusinessEvent('ProjectCancelled', 'Project cancelled', 'The salesperson cancelled the project; Project Inspector stopped the review.', EventCategory::"Project Inspector")]
    local procedure ProjectCancelled(ProjectId: Guid; ProjectNo: Code[20]; ProjectDescription: Text[100]; CustomerName: Text[100]; Reason: Text[250]; ProjectUrl: Text[250])
    begin
    end;

    /// <summary>
    /// Raised together with the business event, for AL subscribers (and the tests).
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterClarificationRequested(ProjectNo: Code[20]; Questions: Text)
    begin
    end;

    /// <summary>
    /// Raised together with every business event of Project Inspector, for AL subscribers (and the tests).
    /// </summary>
    [IntegrationEvent(false, false)]
    local procedure OnAfterReviewEventRaised(EventName: Text; ProjectNo: Code[20]; Details: Text)
    begin
    end;

    local procedure GetProjectUrl(var Job: Record Job): Text
    begin
        if IsNullGuid(Job.SystemId) then
            exit('');
        exit(GetUrl(ClientType::Web, CompanyName(), ObjectType::Page, Page::"Job Card", Job, true));
    end;
}
