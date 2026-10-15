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
    /// The reviewer's choices when the agent asks for the decision (step 9 of the instructions): approve, reject or
    /// send the questions. They are always offered; the platform shows them as named options in the task pane.
    /// </summary>
    procedure GetAgentTaskUserInterventionSuggestions(AgentTaskUserInterventionRequestDetails: Record "Agent User Int Request Details"; var Suggestions: Record "Agent Task User Int Suggestion")
    var
        CheckProjectSummaryLbl: Label 'Check the project number';
        CheckProjectDescriptionLbl: Label 'The project named in the task does not exist or is not in status Planning.', Locked = true;
        CheckProjectInstructionsLbl: Label 'Reply with the correct project number, or stop the task if the project is no longer in status Planning.', Locked = true;
        ApproveSummaryLbl: Label 'Approve project (status Quote)';
        ApproveDescriptionLbl: Label 'The reviewer approves the project after the review, also when points are open.', Locked = true;
        ApproveInstructionsLbl: Label 'The reviewer approves the project. On the Project Card of the project invoke the action "Approve Project". Then finish the task without another reply.', Locked = true;
        RejectSummaryLbl: Label 'Reject project and notify';
        RejectDescriptionLbl: Label 'The reviewer rejects the project; the team is notified with the findings.', Locked = true;
        RejectInstructionsLbl: Label 'The reviewer rejects the project. On the Project Card of the project invoke the action "Reject Project". Then finish the task without another reply.', Locked = true;
        QuestionsSummaryLbl: Label 'Send questions to the salesperson';
        QuestionsDescriptionLbl: Label 'The reviewer sends the questions of the report to the salesperson in Teams.', Locked = true;
        QuestionsInstructionsLbl: Label 'The reviewer sends the questions to the salesperson. On the Project Card of the project invoke the action "Send Questions to Salesperson". Then finish the task without another reply.', Locked = true;
    begin
        if AgentTaskUserInterventionRequestDetails.Type <> AgentTaskUserInterventionRequestDetails.Type::Assistance then
            exit;

        AddSuggestion(Suggestions, 'PI-APPROVE', ApproveSummaryLbl, ApproveDescriptionLbl, ApproveInstructionsLbl, true);
        AddSuggestion(Suggestions, 'PI-REJECT', RejectSummaryLbl, RejectDescriptionLbl, RejectInstructionsLbl, true);
        AddSuggestion(Suggestions, 'PI-QUESTIONS', QuestionsSummaryLbl, QuestionsDescriptionLbl, QuestionsInstructionsLbl, true);
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
