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

    /// <summary>
    /// The reviewer's choices when the agent asks for assistance on the Review Result card (step 8 of the instructions):
    /// approve, reject or send the questions, as buttons in the task pane next to the Decision field and actions on the
    /// card. On any other page the agent is stuck, and decisions without the report would mislead, so only the project
    /// check is offered there. The outgoing message page cannot be extended and shows no suggestions (checked on BC 29),
    /// so Project Inspector does not reply; it ends the task once the decision is set.
    /// </summary>
    procedure GetAgentTaskUserInterventionSuggestions(AgentTaskUserInterventionRequestDetails: Record "Agent User Int Request Details"; var Suggestions: Record "Agent Task User Int Suggestion")
    var
        CheckProjectSummaryLbl: Label 'Check the project number';
        CheckProjectDescriptionLbl: Label 'The project named in the task does not exist or is not in status Planning.', Locked = true;
        CheckProjectInstructionsLbl: Label 'Reply with the correct project number, or stop the task if the project is no longer in status Planning.', Locked = true;
    begin
        if AgentTaskUserInterventionRequestDetails.Type <> AgentTaskUserInterventionRequestDetails.Type::Assistance then
            exit;

        // On the Review Result card the reviewer chooses the decision in the Decision field, not through the agent.
        if AgentTaskUserInterventionRequestDetails."Page ID" = Page::"PI Review Result Card" then
            exit;
        AddSuggestion(Suggestions, 'PI-CHECK-PROJECT', CheckProjectSummaryLbl, CheckProjectDescriptionLbl, CheckProjectInstructionsLbl, false);
    end;

    local procedure AddSuggestion(var Suggestions: Record "Agent Task User Int Suggestion"; SuggestionCode: Code[20]; Summary: Text[100]; Description: Text[1024]; Instructions: Text[1024]; AlwaysIncluded: Boolean)
    begin
        Suggestions.Init();
        Suggestions.Code := SuggestionCode;
        Suggestions.Summary := Summary;
        Suggestions.Description := Description;
        Suggestions.Instructions := Instructions;
        Suggestions."Always Included" := AlwaysIncluded;
        Suggestions.Insert();
    end;

    procedure GetAgentTaskPageContext(AgentTaskPageContextRequest: Record "Agent Task Page Context Req."; var AgentTaskPageContext: Record "Agent Task Page Context")
    begin
    end;
}
