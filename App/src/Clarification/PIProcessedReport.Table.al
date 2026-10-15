namespace Contoso.ProjectInspector;

/// <summary>
/// The agent replies that PI Report Monitor has already read, so each reply raises the clarification event at most once.
/// </summary>
table 50103 "PI Processed Report"
{
    Access = Internal;
    Caption = 'Project Inspector Processed Report';
    DataClassification = SystemMetadata;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;

    fields
    {
        field(1; "Message ID"; Guid)
        {
            Caption = 'Message ID';
            ToolTip = 'Specifies the agent task message that holds the review report.';
        }
        field(2; "Task ID"; BigInteger)
        {
            Caption = 'Task ID';
            ToolTip = 'Specifies the agent task the report belongs to.';
        }
        field(3; "Project No."; Code[20])
        {
            Caption = 'Project No.';
            ToolTip = 'Specifies the project that was reviewed.';
            DataClassification = CustomerContent;
        }
        field(4; "Event Raised"; Boolean)
        {
            Caption = 'Event Raised';
            ToolTip = 'Specifies whether the report had questions and the ProjectClarificationRequested business event was raised.';
        }
        field(5; "Processed At"; DateTime)
        {
            Caption = 'Processed At';
            ToolTip = 'Specifies when the report monitor read the report.';
        }
    }

    keys
    {
        key(PK; "Message ID")
        {
            Clustered = true;
        }
    }
}
