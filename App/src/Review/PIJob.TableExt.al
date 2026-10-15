namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

tableextension 50100 "PI Job" extends Job
{
    fields
    {
        field(50100; "PI Open Points"; Text[2048])
        {
            Caption = 'Open Points';
            ToolTip = 'Specifies the open points Scribe Agent found in the conversation, one per line as <topic>: <question> (PCR-24).';
            DataClassification = CustomerContent;
        }
        modify(Status)
        {
            trigger OnAfterValidate()
            var
                ReviewTrigger: Codeunit "PI Review Trigger";
            begin
                ReviewTrigger.OnAfterStatusValidated(Rec, xRec);
            end;
        }
    }
}
