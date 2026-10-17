namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Used by Scribe Agent through the Business Central MCP server (configuration SCRIBE-AGENT):
/// PATCH openPoints, then call the bound action submitForReview once (PCR-24, PCR-27).
/// /api/contoso/projectInspector/v1.0/companies({id})/projectReviews({id})/Microsoft.NAV.submitForReview
/// </summary>
page 50102 "PI Project Reviews API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'projectInspector';
    APIVersion = 'v1.0';
    EntityName = 'projectReview';
    EntitySetName = 'projectReviews';
    EntityCaption = 'Project Review';
    EntitySetCaption = 'Project Reviews';
    SourceTable = Job;
    ODataKeyFields = SystemId;
    DelayedInsert = true;
    InsertAllowed = false;
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
                    Editable = false;
                }
                field(number; Rec."No.")
                {
                    Caption = 'No.';
                    Editable = false;
                }
                field(description; Rec.Description)
                {
                    Caption = 'Description';
                    Editable = false;
                }
                field(status; Rec.Status)
                {
                    Caption = 'Status';
                    Editable = false;
                }
                field(openPoints; Rec."PI Open Points")
                {
                    Caption = 'Open Points';
                }
            }
        }
    }

    /// <summary>
    /// Sends the project to Project Inspector. Call it once, after all tasks and planning lines exist.
    /// </summary>
    [ServiceEnabled]
    procedure SubmitForReview(var ActionContext: WebServiceActionContext)
    var
        ReviewTrigger: Codeunit "PI Review Trigger";
    begin
        ReviewTrigger.SubmitForReview(Rec);

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"PI Project Reviews API");
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;

    /// <summary>
    /// Creates all tasks and planning lines of a new project in one call; either everything is created or nothing.
    /// tasksJson: [{"jobTaskNo":"002010","description":"SERVICES","jobTaskType":"Posting"}, ...] in the order of the
    /// task list; Begin-Total and End-Total tasks are indented and totaled automatically.
    /// linesJson: [{"jobTaskNo":"002010","type":"Resource","no":"R-CONSULT","description":"Setup","quantity":18}, ...];
    /// line numbers and prices are filled by Business Central. Call it before Submit for Review.
    /// </summary>
    [ServiceEnabled]
    procedure BuildProjectStructure(var ActionContext: WebServiceActionContext; tasksJson: Text; linesJson: Text)
    var
        ProjectStructure: Codeunit "PI Project Structure";
    begin
        ProjectStructure.Build(Rec, tasksJson, linesJson);

        ActionContext.SetObjectType(ObjectType::Page);
        ActionContext.SetObjectId(Page::"PI Project Reviews API");
        ActionContext.AddEntityKey(Rec.FieldNo(SystemId), Rec.SystemId);
        ActionContext.SetResultCode(WebServiceActionResultCode::Updated);
    end;
}
