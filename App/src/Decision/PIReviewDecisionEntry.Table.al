namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// Log of the reviewer's decisions on Project Inspector reports. The reviewer chooses in the task pane, the agent writes
/// the decision into its report, and PI Report Monitor carries it out once: status change and business event.
/// </summary>
table 50104 "PI Review Decision Entry"
{
    Access = Internal;
    Caption = 'Project Inspector Review Decision';
    DataClassification = CustomerContent;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;

    fields
    {
        field(1; "Entry No."; Integer)
        {
            Caption = 'Entry No.';
            ToolTip = 'Specifies the number of the decision.';
            AutoIncrement = true;
        }
        field(2; "Project No."; Code[20])
        {
            Caption = 'Project No.';
            ToolTip = 'Specifies the project the decision is about.';
            TableRelation = Job;
        }
        field(3; Decision; Enum "PI Review Decision")
        {
            Caption = 'Decision';
            ToolTip = 'Specifies what the reviewer decided: approve the project (status Quote), reject it, or send the questions to the salesperson.';
        }
        field(4; "Decided At"; DateTime)
        {
            Caption = 'Decided At';
            ToolTip = 'Specifies when the decision was made.';
        }
        field(5; "Decided By"; Code[50])
        {
            Caption = 'Decided By';
            ToolTip = 'Specifies the user whose session carried out the decision (the report monitor job).';
            DataClassification = EndUserIdentifiableInformation;
        }
        field(6; Processed; Boolean)
        {
            Caption = 'Processed';
            ToolTip = 'Specifies whether the report monitor carried out the decision.';
        }
        field(7; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            ToolTip = 'Specifies when the report monitor carried out the decision.';
        }
        field(8; Result; Text[250])
        {
            Caption = 'Result';
            ToolTip = 'Specifies what the report monitor did, or why it could not carry out the decision.';
        }
    }

    keys
    {
        key(PK; "Entry No.")
        {
            Clustered = true;
        }
    }
}
