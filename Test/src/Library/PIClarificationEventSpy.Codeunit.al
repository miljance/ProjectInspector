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

    [EventSubscriber(ObjectType::Codeunit, Codeunit::"PI Business Events", 'OnAfterClarificationRequested', '', false, false)]
    local procedure OnAfterClarificationRequested(ProjectNo: Code[20]; Questions: Text)
    begin
        RaisedCount += 1;
        LastProjectNo := ProjectNo;
        LastQuestions := Questions;
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
