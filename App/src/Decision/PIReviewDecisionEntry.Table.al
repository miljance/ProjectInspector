namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

/// <summary>
/// The reviewer's decisions after Project Inspector reports. The Project Card actions write them (also when the agent
/// clicks them on the reviewer's choice); PI Report Monitor processes each one once: status change and business event.
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
            ToolTip = 'Specifies the user who chose the action; the agent when it acted on the reviewer''s choice.';
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
        key(Pending; Processed, "Entry No.")
        {
        }
    }
}
