namespace Contoso.ProjectInspector;

/// <summary>
/// The review results with their full texts, for the Power Automate flows. Business event parameters are limited to
/// 250 characters by the platform (AL0762), so every event carries ReviewResultId and the flow reads the questions,
/// findings and answers not applied here: Get record (reviewResults, id = ReviewResultId).
/// </summary>
page 50110 "PI Review Results API"
{
    PageType = API;
    APIPublisher = 'contoso';
    APIGroup = 'projectInspector';
    APIVersion = 'v1.0';
    EntityName = 'reviewResult';
    EntitySetName = 'reviewResults';
    EntityCaption = 'Review Result';
    EntitySetCaption = 'Review Results';
    SourceTable = "PI Review Result";
    ODataKeyFields = SystemId;
    DataAccessIntent = ReadOnly;
    Editable = false;
    InsertAllowed = false;
    ModifyAllowed = false;
    DeleteAllowed = false;
    DelayedInsert = true;

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field(id; Rec.SystemId)
                {
                    Caption = 'Id';
                }
                field(entryNo; Rec."Entry No.")
                {
                    Caption = 'Entry No.';
                }
                field(projectNo; Rec."Project No.")
                {
                    Caption = 'Project No.';
                }
                field(decision; Rec.Decision)
                {
                    Caption = 'Decision';
                }
                field(status; StatusText)
                {
                    Caption = 'Status';
                }
                field(questions; QuestionsText)
                {
                    Caption = 'Questions';
                }
                field(findings; FindingsText)
                {
                    Caption = 'Findings';
                }
                field(notApplied; NotAppliedText)
                {
                    Caption = 'Not Applied';
                }
                field(report; Rec.Report)
                {
                    Caption = 'Report';
                }
                field(closed; Rec.Processed)
                {
                    Caption = 'Closed';
                }
                field(closedAt; Rec."Processed At")
                {
                    Caption = 'Closed At';
                }
            }
        }
    }

    trigger OnAfterGetRecord()
    begin
        StatusText := Rec.GetStatusText();
        QuestionsText := Rec.GetQuestionsText();
        FindingsText := Rec.GetFindingsText();
        NotAppliedText := Rec.GetNotAppliedText();
    end;

    var
        StatusText: Text;
        QuestionsText: Text;
        FindingsText: Text;
        NotAppliedText: Text;
}
