namespace Contoso.ProjectInspector;

/// <summary>
/// Hands out the dispatcher the review triggers use. Tests call SetDispatcher with a mock.
/// </summary>
codeunit 50108 "PI Dispatcher Provider"
{
    SingleInstance = true;
    Access = Internal;

    var
        OverrideDispatcher: Interface "PI ITask Dispatcher";
        HasOverride: Boolean;

    procedure GetDispatcher(): Interface "PI ITask Dispatcher"
    var
        AgentTaskDispatcher: Codeunit "PI Agent Task Dispatcher";
        Dispatcher: Interface "PI ITask Dispatcher";
    begin
        if HasOverride then
            exit(OverrideDispatcher);

        Dispatcher := AgentTaskDispatcher;
        exit(Dispatcher);
    end;

    procedure SetDispatcher(NewDispatcher: Interface "PI ITask Dispatcher")
    begin
        OverrideDispatcher := NewDispatcher;
        HasOverride := true;
    end;

    procedure ResetDispatcher()
    begin
        HasOverride := false;
    end;
}
