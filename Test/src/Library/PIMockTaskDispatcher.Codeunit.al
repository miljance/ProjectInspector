namespace Contoso.ProjectInspector.Test;

using Contoso.ProjectInspector;

/// <summary>
/// Test double for the agent task dispatcher. Records every call instead of creating agent tasks,
/// so the tests do not need an activated Project Inspector agent.
/// SingleInstance keeps the recorded calls readable after the code under test used the interface.
/// </summary>
codeunit 50160 "PI Mock Task Dispatcher" implements "PI ITask Dispatcher"
{
    SingleInstance = true;
    Access = Internal;

    var
        Available: Boolean;
        SendCount: Integer;
        AnswerCount: Integer;
        StopCount: Integer;
        LastStoppedProjectNo: Code[20];
        SendCountAtStop: Integer;
        LastProjectNo: Code[20];
        LastTitle: Text[150];
        LastMessage: Text;
        LastAnswerProjectNo: Code[20];
        LastAnswer: Text;

    procedure Reset()
    begin
        Available := true;
        SendCount := 0;
        AnswerCount := 0;
        StopCount := 0;
        Clear(LastStoppedProjectNo);
        SendCountAtStop := 0;
        Clear(LastProjectNo);
        Clear(LastTitle);
        Clear(LastMessage);
        Clear(LastAnswerProjectNo);
        Clear(LastAnswer);
    end;

    procedure SetAvailable(NewAvailable: Boolean)
    begin
        Available := NewAvailable;
    end;

    procedure IsAvailable(): Boolean
    begin
        exit(Available);
    end;

    procedure SendReview(ProjectNo: Code[20]; TaskTitle: Text[150]; MessageText: Text)
    begin
        SendCount += 1;
        LastProjectNo := ProjectNo;
        LastTitle := TaskTitle;
        LastMessage := MessageText;
    end;

    procedure AddAnswer(ProjectNo: Code[20]; MessageText: Text)
    begin
        AnswerCount += 1;
        LastAnswerProjectNo := ProjectNo;
        LastAnswer := MessageText;
    end;

    procedure StopReview(ProjectNo: Code[20])
    begin
        StopCount += 1;
        LastStoppedProjectNo := ProjectNo;
        SendCountAtStop := SendCount;
    end;

    procedure GetStopCount(): Integer
    begin
        exit(StopCount);
    end;

    procedure GetLastStoppedProjectNo(): Code[20]
    begin
        exit(LastStoppedProjectNo);
    end;

    /// <summary>
    /// How many reviews had been sent when StopReview was called last, to check the order of the calls.
    /// </summary>
    procedure GetSendCountAtStop(): Integer
    begin
        exit(SendCountAtStop);
    end;

    procedure GetSendCount(): Integer
    begin
        exit(SendCount);
    end;

    procedure GetAnswerCount(): Integer
    begin
        exit(AnswerCount);
    end;

    procedure GetLastProjectNo(): Code[20]
    begin
        exit(LastProjectNo);
    end;

    procedure GetLastTitle(): Text[150]
    begin
        exit(LastTitle);
    end;

    procedure GetLastMessage(): Text
    begin
        exit(LastMessage);
    end;

    procedure GetLastAnswerProjectNo(): Code[20]
    begin
        exit(LastAnswerProjectNo);
    end;

    procedure GetLastAnswer(): Text
    begin
        exit(LastAnswer);
    end;
}
