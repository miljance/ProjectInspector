namespace Contoso.ProjectInspector;

/// <summary>
/// One record per Project Inspector agent. Links the agent user created by the platform to this app and to the company
/// where it was activated: like the Sales Order Agent, every company has its own Project Inspector.
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
        field(2; "Company Name"; Text[30])
        {
            Caption = 'Company Name';
            ToolTip = 'Specifies the company where the agent was activated. It reviews the projects of this company only.';
            DataClassification = OrganizationIdentifiableInformation;
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
