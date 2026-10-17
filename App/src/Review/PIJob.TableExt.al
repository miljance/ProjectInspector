namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Projects.Project.Planning;

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
        // The review report states these days; the agent added them up itself and got it wrong. Support is planned
        // in hours (R-SUPPORT, HOUR) and is not counted.
        field(50101; "PI Planned Days"; Decimal)
        {
            Caption = 'Planned Days';
            ToolTip = 'Specifies the sum of the quantities of all resource planning lines planned in days (unit of measure DAY): the consultant, developer and trainer days of the project.';
            FieldClass = FlowField;
            CalcFormula = sum("Job Planning Line".Quantity where("Job No." = field("No."),
                                                                  Type = const(Resource),
                                                                  "Unit of Measure Code" = const('DAY')));
            DecimalPlaces = 0 : 2;
            Editable = false;
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
