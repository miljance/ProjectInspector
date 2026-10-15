namespace Contoso.ProjectInspector;

using System.Agents;
using System.AI;

page 50100 "PI Agent Setup"
{
    PageType = ConfigurationDialog;
    Extensible = false;
    ApplicationArea = All;
    IsPreview = true;
    Caption = 'Set up Project Inspector';
    InstructionalText = 'Project Inspector reviews every new project in status Planning against the project creation rules and asks the salesperson about open points. It only reads data.';
    AdditionalSearchTerms = 'Project Inspector, Agent';
    SourceTable = "PI Agent Setup";
    SourceTableTemporary = true;
    InherentEntitlements = X;
    InherentPermissions = X;

    layout
    {
        area(Content)
        {
            part(AgentSetupPart; "Agent Setup Part")
            {
                ApplicationArea = All;
                UpdatePropagation = Both;
            }
        }
    }

    actions
    {
        area(SystemActions)
        {
            systemaction(OK)
            {
                Caption = 'Update';
                Enabled = IsUpdated;
                ToolTip = 'Apply the changes to the agent setup.';
            }

            systemaction(Cancel)
            {
                Caption = 'Cancel';
                ToolTip = 'Discards the changes and closes the setup page.';
            }
        }
    }

    var
        TempAgentSetupBuffer: Record "Agent Setup Buffer";
        AzureOpenAI: Codeunit "Azure OpenAI";
        IsUpdated: Boolean;
        CapabilityNotEnabledErr: Label 'The Project Inspector capability is not enabled in Copilot & agent capabilities.\\Enable the capability before you set up the agent.';

    trigger OnOpenPage()
    var
        PIAgentSetup: Codeunit "PI Agent Setup";
        UserSecurityIDFilter: Text;
        UserSecurityID: Guid;
    begin
        if not AzureOpenAI.IsEnabled(Enum::"Copilot Capability"::"Project Inspector") then
            Error(CapabilityNotEnabledErr);

        UserSecurityIDFilter := Rec.GetFilter("User Security ID");
        if not Evaluate(UserSecurityID, UserSecurityIDFilter) then
            Clear(UserSecurityID);

        Rec."User Security ID" := UserSecurityID;

        CurrPage.AgentSetupPart.Page.Initialize(
            UserSecurityID,
            PIAgentSetup.GetAgentMetadataProvider(),
            PIAgentSetup.GetAgentUserName(),
            PIAgentSetup.GetDefaultDisplayName(),
            PIAgentSetup.GetAgentSummary());

        InitializePage();
    end;

    trigger OnAfterGetRecord()
    begin
        InitializePage();
    end;

    trigger OnAfterGetCurrRecord()
    begin
        IsUpdated := IsUpdated or CurrPage.AgentSetupPart.Page.GetChangesMade();
    end;

    trigger OnModifyRecord(): Boolean
    begin
        IsUpdated := true;
    end;

    trigger OnQueryClosePage(CloseAction: Action): Boolean
    var
        PIAgentSetup: Codeunit "PI Agent Setup";
    begin
        if CloseAction = CloseAction::Cancel then
            exit(true);

        CurrPage.AgentSetupPart.Page.GetAgentSetupBuffer(TempAgentSetupBuffer);
        PIAgentSetup.SaveSetupRecord(Rec, TempAgentSetupBuffer);
        exit(true);
    end;

    local procedure InitializePage()
    var
        PIAgentSetup: Codeunit "PI Agent Setup";
    begin
        CurrPage.AgentSetupPart.Page.GetAgentSetupBuffer(TempAgentSetupBuffer);
        PIAgentSetup.InitializeSetupRecord(Rec);
        IsUpdated := IsUpdated or CurrPage.AgentSetupPart.Page.GetChangesMade();
    end;
}
