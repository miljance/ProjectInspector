namespace Contoso.ProjectInspector;

using System.Agents;

codeunit 50102 "PI Agent Metadata" implements IAgentMetadata
{
    Access = Internal;

    var
        PIAgentSetup: Codeunit "PI Agent Setup";

    procedure GetInitials(AgentUserId: Guid): Text[4]
    begin
        exit(PIAgentSetup.GetInitials());
    end;

    procedure GetSetupPageId(AgentUserId: Guid): Integer
    begin
        exit(PIAgentSetup.GetSetupPageId());
    end;

    procedure GetSummaryPageId(AgentUserId: Guid): Integer
    begin
        exit(PIAgentSetup.GetSummaryPageId());
    end;

    procedure GetAgentTaskMessagePageId(AgentUserId: Guid; MessageId: Guid): Integer
    begin
        exit(Page::"Agent Task Message Card");
    end;

    procedure GetAgentAnnotations(AgentUserId: Guid; var Annotations: Record "Agent Annotation")
    begin
        Clear(Annotations);
    end;
}
