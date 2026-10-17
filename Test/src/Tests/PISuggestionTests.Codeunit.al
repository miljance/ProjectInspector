namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;
using System.Agents;
using System.Reflection;
using System.TestLibraries.Utilities;

/// <summary>
/// The agent asks for the decision on the Review Result card, which it opens from its own home page; the task pane then
/// offers the three decisions as buttons. On any other assistance request (the agent is stuck somewhere else) the
/// decisions would be misleading, so only the project check is offered there. Business Central shows no suggestions on
/// the review of an outgoing message (checked on BC 29), and the agent does not reply anyway.
/// </summary>
codeunit 50159 "PI Suggestion Tests"
{
    Subtype = Test;
    TestPermissions = Disabled;

    var
        Assert: Codeunit "Library Assert";
        TaskExecution: Codeunit "PI Agent Task Execution";

    [Test]
    procedure AssistanceOnTheResultCardOffersTheDecisions()
    var
        TempRequestDetails: Record "Agent User Int Request Details" temporary;
        TempSuggestion: Record "Agent Task User Int Suggestion" temporary;
    begin
        // [GIVEN] The agent asks for the decision on the Review Result card
        TempRequestDetails.Type := TempRequestDetails.Type::Assistance;
        TempRequestDetails."Page ID" := Page::"PI Review Result Card";

        // [WHEN] Business Central asks for the suggestions
        TaskExecution.GetAgentTaskUserInterventionSuggestions(TempRequestDetails, TempSuggestion);

        // [THEN] Approve, reject and send questions are offered, each setting the Decision field
        AssertDecision(TempSuggestion, 'PI-APPROVE', 'Decision field to Approve');
        AssertDecision(TempSuggestion, 'PI-REJECT', 'Decision field to Reject');
        AssertDecision(TempSuggestion, 'PI-QUESTIONS', 'Decision field to Send Questions');
        Assert.AreEqual(3, TempSuggestion.Count(), 'Only the three decisions belong to the result card.');
    end;

    [Test]
    procedure AssistanceElsewhereOffersOnlyTheProjectCheck()
    var
        TempRequestDetails: Record "Agent User Int Request Details" temporary;
        TempSuggestion: Record "Agent Task User Int Suggestion" temporary;
    begin
        // [GIVEN] The agent asks for assistance on another page, for example because the project is not in Planning
        TempRequestDetails.Type := TempRequestDetails.Type::Assistance;
        TempRequestDetails."Page ID" := Page::"PI Review Results";

        // [WHEN] Business Central asks for the suggestions
        TaskExecution.GetAgentTaskUserInterventionSuggestions(TempRequestDetails, TempSuggestion);

        // [THEN] Only the project check is offered, no decision without the report
        Assert.AreEqual(1, TempSuggestion.Count(), 'Only the project check is expected.');
        TempSuggestion.FindFirst();
        Assert.AreEqual('PI-CHECK-PROJECT', TempSuggestion.Code, 'Wrong suggestion.');
    end;

    [Test]
    procedure ReviewOfAMessageOffersNothing()
    var
        TempRequestDetails: Record "Agent User Int Request Details" temporary;
        TempSuggestion: Record "Agent Task User Int Suggestion" temporary;
    begin
        // [GIVEN] An outgoing message waits for review; Business Central does not show suggestions there
        TempRequestDetails.Type := TempRequestDetails.Type::ReviewMessage;

        // [WHEN] Business Central asks for the suggestions
        TaskExecution.GetAgentTaskUserInterventionSuggestions(TempRequestDetails, TempSuggestion);

        // [THEN] None are offered
        Assert.RecordIsEmpty(TempSuggestion);
    end;

    [Test]
    procedure AgentStartsOnItsOwnHomePage()
    var
        TempAllProfile: Record "All Profile" temporary;
        PIAgentSetup: Codeunit "PI Agent Setup";
        CurrentModuleInfo: ModuleInfo;
    begin
        // [GIVEN] The Project Inspector app
        NavApp.GetModuleInfo('92c92ce8-1ee4-4cb0-a0ae-9969f4fb64a0', CurrentModuleInfo);

        // [WHEN] The agent's default profile is read
        PIAgentSetup.GetDefaultProfile(TempAllProfile);

        // [THEN] It is the Project Inspector profile of this app, whose home page lists the pages the agent needs
        Assert.AreEqual('PROJECT INSPECTOR AGENT', TempAllProfile."Profile ID", 'Wrong profile.');
        Assert.AreEqual(CurrentModuleInfo.Id(), TempAllProfile."App ID", 'The profile must come from Project Inspector.');
    end;

    local procedure AssertDecision(var TempSuggestion: Record "Agent Task User Int Suggestion" temporary; SuggestionCode: Code[20]; DecisionLine: Text)
    var
        MissingErr: Label 'Suggestion %1 is missing.', Comment = '%1 = suggestion code', Locked = true;
        NotAlwaysErr: Label 'Suggestion %1 must always be shown.', Comment = '%1 = suggestion code', Locked = true;
        NoDecisionErr: Label 'Suggestion %1 must set the "%2".', Comment = '%1 = suggestion code, %2 = decision', Locked = true;
        ReplyErr: Label 'Suggestion %1 must end the task without a reply.', Comment = '%1 = suggestion code', Locked = true;
    begin
        TempSuggestion.SetRange(Code, SuggestionCode);
        Assert.IsTrue(TempSuggestion.FindFirst(), StrSubstNo(MissingErr, SuggestionCode));
        Assert.IsTrue(TempSuggestion."Always Included", StrSubstNo(NotAlwaysErr, SuggestionCode));
        Assert.IsTrue(TempSuggestion.Instructions.Contains(DecisionLine), StrSubstNo(NoDecisionErr, SuggestionCode, DecisionLine));
        Assert.IsTrue(TempSuggestion.Instructions.Contains('without a reply'), StrSubstNo(ReplyErr, SuggestionCode));
        TempSuggestion.SetRange(Code);
    end;
}
