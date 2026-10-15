namespace Contoso.ProjectInspector;

/// <summary>
/// One record per Project Inspector agent. Links the agent user created by the platform to this app.
/// </summary>
table 50100 "PI Agent Setup"
{
    Access = Internal;
    Caption = 'Project Inspector Setup';
    DataClassification = CustomerContent;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;
    DataPerCompany = false;

    fields
    {
        field(1; "User Security ID"; Guid)
        {
            Caption = 'User Security ID';
            ToolTip = 'Specifies the unique identifier of the agent user.';
            DataClassification = SystemMetadata;
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "User Security ID")
        {
            Clustered = true;
        }
    }
}
