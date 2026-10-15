namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// Runs in the agent session: user intervention suggestions for Project Inspector tasks.
/// </summary>
codeunit 50104 "PI Agent Task Execution" implements IAgentTaskExecution
{
    Access = Internal;

    procedure AnalyzeAgentTaskMessage(AgentTaskMessage: Record "Agent Task Message"; var Annotations: Record "Agent Annotation")
    begin
        // Business Central calls this only for the input messages of a task (checked on BC 29), never for the agent's
        // replies, so the clarification event is raised by the PI Report Monitor job instead.
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
}
