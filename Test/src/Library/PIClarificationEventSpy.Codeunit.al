namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;

/// <summary>
/// Listens to the clarification event while a test has it bound with BindSubscription.
/// </summary>
codeunit 50161 "PI Clarification Event Spy"
{
    EventSubscriberInstance = Manual;
    Access = Internal;

    var
        RaisedCount: Integer;
        LastProjectNo: Code[20];
        LastQuestions: Text;
        EventCounts: Dictionary of [Text, Integer];
        LastDetails: Dictionary of [Text, Text];
        LastReviewResultId: Guid;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PI Business Events", 'OnAfterClarificationRequested', '', false, false)]
    local procedure OnAfterClarificationRequested(ProjectNo: Code[20]; Questions: Text)
    begin
        RaisedCount += 1;
        LastProjectNo := ProjectNo;
        LastQuestions := Questions;
    end;

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PI Business Events", 'OnAfterReviewEventRaised', '', false, false)]
    local procedure OnAfterReviewEventRaised(EventName: Text; ProjectNo: Code[20]; Details: Text)
    var
        ReviewContext: Codeunit "PI Review Context";
    begin
        if EventCounts.ContainsKey(EventName) then
            EventCounts.Set(EventName, EventCounts.Get(EventName) + 1)
        else
            EventCounts.Add(EventName, 1);
        LastDetails.Set(EventName, Details);
        LastReviewResultId := ReviewContext.GetReviewResultId();
    end;

    /// <summary>
    /// The review result the last business event belongs to (the ReviewResultId parameter the flows read with).
    /// </summary>
    procedure GetLastReviewResultId(): Guid
    begin
        exit(LastReviewResultId);
    end;

    /// <summary>
    /// How often the business event with this name was raised, for example 'ProjectRejected'.
    /// </summary>
    procedure GetEventCount(EventName: Text): Integer
    begin
        if EventCounts.ContainsKey(EventName) then
            exit(EventCounts.Get(EventName));
    end;

    procedure GetLastDetails(EventName: Text): Text
    begin
        if LastDetails.ContainsKey(EventName) then
            exit(LastDetails.Get(EventName));
    end;

    procedure GetTotalEventCount() Total: Integer
    var
        EventCount: Integer;
    begin
        foreach EventCount in EventCounts.Values() do
            Total += EventCount;
    end;

    procedure GetRaisedCount(): Integer
    begin
        exit(RaisedCount);
    end;

    procedure GetLastProjectNo(): Code[20]
    begin
        exit(LastProjectNo);
    end;

    procedure GetLastQuestions(): Text
    begin
        exit(LastQuestions);
    end;
}
