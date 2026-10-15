namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// Runs in the agent session. Every review report the agent writes is checked for questions
/// for the salesperson; if there are any, the ProjectClarificationRequested business event is raised.
/// </summary>
codeunit 50104 "PI Agent Task Execution" implements IAgentTaskExecution
{
    Access = Internal;

    var
        AnalyzedCodeTok: Label 'PI-ANALYZED', Locked = true;
        QuestionsSentCodeTok: Label 'PI-QUESTIONS-SENT', Locked = true;
        AnalyzedMsg: Label 'Project Inspector checked this %1 message.', Comment = '%1 = message type (Input or Output)';
        QuestionsSentMsg: Label 'The questions were sent to the salesperson (business event ProjectClarificationRequested).';

    procedure AnalyzeAgentTaskMessage(AgentTaskMessage: Record "Agent Task Message"; var Annotations: Record "Agent Annotation")
    begin
        // Input messages are not validated: they come from the review triggers and from the clarificationAnswers API.
        // The Info annotation shows in the task timeline that Project Inspector looked at the message.
        AddAnnotation(Annotations, AnalyzedCodeTok, StrSubstNo(AnalyzedMsg, AgentTaskMessage.Type));
        if AgentTaskMessage.Type = AgentTaskMessage.Type::Output then
            if HandleOutputMessage(AgentTaskMessage) then
                AddAnnotation(Annotations, QuestionsSentCodeTok, QuestionsSentMsg);
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

    local procedure HandleOutputMessage(AgentTaskMessage: Record "Agent Task Message"): Boolean
    var
        AgentTask: Record "Agent Task";
        AgentMessage: Codeunit "Agent Message";
        ClarificationMgt: Codeunit "PI Clarification Mgt.";
        ExternalId: Text;
    begin
        if AgentTask.Get(AgentTaskMessage."Task ID") then
            ExternalId := AgentTask."External ID";

        exit(ClarificationMgt.HandleAgentReport(ExternalId, AgentMessage.GetText(AgentTaskMessage)));
    end;

    local procedure AddAnnotation(var Annotations: Record "Agent Annotation"; AnnotationCode: Text[20]; AnnotationMessage: Text)
    begin
        Annotations.Init();
        Annotations.Code := AnnotationCode;
        Annotations.Message := CopyStr(AnnotationMessage, 1, MaxStrLen(Annotations.Message));
        Annotations.Severity := Annotations.Severity::Info;
        Annotations.Insert();
    end;
}
