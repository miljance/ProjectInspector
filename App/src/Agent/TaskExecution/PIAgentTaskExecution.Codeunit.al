namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// Runs in the agent session. Every review report the agent writes is checked for questions
/// for the salesperson; if there are any, the ProjectClarificationRequested business event is raised.
/// </summary>
codeunit 50104 "PI Agent Task Execution" implements IAgentTaskExecution
{
    Access = Internal;

    procedure AnalyzeAgentTaskMessage(AgentTaskMessage: Record "Agent Task Message"; var Annotations: Record "Agent Annotation")
    begin
        if AgentTaskMessage.Type = AgentTaskMessage.Type::Output then
            HandleOutputMessage(AgentTaskMessage);
        // Input messages are not validated: they come from the review triggers and from the clarificationAnswers API.
    end;

    procedure GetAgentTaskUserInterventionSuggestions(AgentTaskUserInterventionRequestDetails: Record "Agent User Int Request Details"; var Suggestions: Record "Agent Task User Int Suggestion")
    var
        SummaryLbl: Label 'Check the project number';
        DescriptionLbl: Label 'The project named in the task does not exist or is not in status Planning.', Locked = true;
        InstructionsLbl: Label 'Reply with the correct project number, or stop the task if the project is no longer in status Planning.', Locked = true;
    begin
        if AgentTaskUserInterventionRequestDetails.Type <> AgentTaskUserInterventionRequestDetails.Type::Assistance then
            exit;

        Suggestions.Summary := SummaryLbl;
        Suggestions.Description := DescriptionLbl;
        Suggestions.Instructions := InstructionsLbl;
        Suggestions.Insert();
    end;

    procedure GetAgentTaskPageContext(AgentTaskPageContextRequest: Record "Agent Task Page Context Req."; var AgentTaskPageContext: Record "Agent Task Page Context")
    begin
    end;

    local procedure HandleOutputMessage(AgentTaskMessage: Record "Agent Task Message")
    var
        AgentTask: Record "Agent Task";
        AgentMessage: Codeunit "Agent Message";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
        ExternalId: Text;
    begin
        if AgentTask.Get(AgentTaskMessage."Task ID") then
            ExternalId := AgentTask."External ID";

        ClarificationMgt.HandleAgentReport(ExternalId, AgentMessage.GetText(AgentTaskMessage));
    end;
}
