namespace Contoso.ProjectInspector;

/// <summary>
/// Read-only status of the Project Inspector agents, for checking a deployment:
/// GET /api/contoso/projectInspector/v1.0/companies({id})/agentStatuses
/// Business Central cannot read the instructions back from an agent, so the version shows which ones it has.
/// </summary>
page 50105 "PI Agent Status API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'projectInspector';
    APIVersion = 'v1.0';
    EntityName = 'agentStatus';
    EntitySetName = 'agentStatuses';
    EntityCaption = 'Agent Status';
    EntitySetCaption = 'Agent Statuses';
    SourceTable = "PI Agent KPI";
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
                field(agentUserSecurityId; Rec."User Security ID")
                {
                    Caption = 'Agent User Security ID';
                }
                field(instructionsVersion; Rec."Instructions Version")
                {
                    Caption = 'Instructions Version';
                }
                field(instructionsUpdatedAt; Rec."Instructions Updated At")
                {
                    Caption = 'Instructions Updated At';
                }
                field(reviewsRequested; Rec."Reviews Requested")
                {
                    Caption = 'Reviews Requested';
                }
                field(answersReceived; Rec."Answers Received")
                {
                    Caption = 'Answers Received';
                }
            }
        }
    }
}
