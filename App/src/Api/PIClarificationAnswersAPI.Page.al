namespace Contoso.ProjectInspector;

/// <summary>
/// Used by Power Automate after the salesperson answered the adaptive card in Teams:
/// POST /api/contoso/projectInspector/v1.0/companies({id})/clarificationAnswers
/// { "projectNo": "FAB-01-IMP", "answer": "...", "answeredBy": "daniel@contoso.com" }
/// The answer is added to the review task of the project and Project Inspector reviews the project again.
/// </summary>
page 50103 "PI Clarification Answers API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'projectInspector';
    APIVersion = 'v1.0';
    EntityName = 'clarificationAnswer';
    EntitySetName = 'clarificationAnswers';
    EntityCaption = 'Clarification Answer';
    EntitySetCaption = 'Clarification Answers';
    SourceTable = "PI Clarification Answer";
    ODataKeyFields = SystemId;
    DelayedInsert = true;
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
                    Editable = false;
                }
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'Entry No.';
                    Editable = false;
                }
                field(projectNo; Rec."Project No.")
                {
                    Caption = 'Project No.';
                }
                field(answer; Rec.Answer)
                {
                    Caption = 'Answer';
                }
                field(answeredBy; Rec."Answered By")
                {
                    Caption = 'Answered By';
                }
                field(receivedAt; Rec."Received At")
                {
                    Caption = 'Received At';
                    Editable = false;
                }
            }
        }
    }

    trigger OnInsertRecord(BelowxRec: Boolean): Boolean
    var
        ReviewTrigger: Codeunit "PI Review Trigger";
    begin
        ReviewTrigger.RegisterAnswer(Rec);
        exit(true);
    end;
}
