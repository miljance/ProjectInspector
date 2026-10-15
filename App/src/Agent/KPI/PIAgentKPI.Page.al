namespace Contoso.ProjectInspector;

page 50101 "PI Agent KPI"
{
    PageType = CardPart;
    ApplicationArea = All;
    Caption = 'Project Inspector Summary';
    SourceTable = "PI Agent KPI";
    Editable = false;
    Extensible = false;

    layout
    {
        area(Content)
        {
            cuegroup(KeyMetrics)
            {
                Caption = 'Key Performance Indicators';

                field(ReviewsRequested; Rec."Reviews Requested")
                {
                }
                field(AnswersReceived; Rec."Answers Received")
                {
                }
            }
        }
    }

    var
        AgentDoesNotExistErr: Label 'The agent does not exist. Please check the configuration.';

    trigger OnOpenPage()
    var
        UserSecurityIDFilter: Text;
    begin
        if IsNullGuid(Rec."User Security ID") then begin
            UserSecurityIDFilter := Rec.GetFilter("User Security ID");
            if not Evaluate(Rec."User Security ID", UserSecurityIDFilter) then
                Error(AgentDoesNotExistErr);
        end;

        if not Rec.Get(Rec."User Security ID") then
            Rec.Insert();
    end;
}
