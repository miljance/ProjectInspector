namespace Contoso.ProjectInspector;

page 50104 "PI Clarification Answers"
{
    PageType = List;
    ApplicationArea = Jobs;
    UsageCategory = History;
    Caption = 'Project Inspector Answers';
    SourceTable = "PI Clarification Answer";
    Editable = false;
    SourceTableView = sorting("Entry No.") order(descending);

    layout
    {
        area(Content)
        {
            repeater(Answers)
            {
                field("Entry No."; Rec."Entry No.") { }
                field("Project No."; Rec."Project No.") { }
                field(Answer; Rec.Answer) { }
                field("Answered By"; Rec."Answered By") { }
                field("Received At"; Rec."Received At") { }
            }
        }
    }
}
