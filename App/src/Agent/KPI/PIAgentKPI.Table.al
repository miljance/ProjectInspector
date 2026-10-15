namespace Contoso.ProjectInspector;

table 50101 "PI Agent KPI"
{
    Access = Internal;
    Caption = 'Project Inspector KPI';
    DataClassification = CustomerContent;
    InherentEntitlements = RIMDX;
    InherentPermissions = RIMDX;
    ReplicateData = false;
    DataPerCompany = false;

    fields
    {
        field(1; "User Security ID"; Guid)
        {
            Caption = 'User Security ID';
            ToolTip = 'Specifies the unique identifier of the agent user.';
            DataClassification = EndUserPseudonymousIdentifiers;
            Editable = false;
        }
        field(10; "Reviews Requested"; Integer)
        {
            Caption = 'Reviews requested';
            ToolTip = 'Specifies how many project reviews were sent to Project Inspector.';
        }
        field(11; "Answers Received"; Integer)
        {
            Caption = 'Answers received';
            ToolTip = 'Specifies how many answers from salespeople were passed to Project Inspector.';
        }
        field(20; "Instructions Version"; Text[30])
        {
            Caption = 'Instructions version';
            ToolTip = 'Specifies the app version whose instructions were last set on the agent. New tasks use these instructions; a task keeps the instructions it was created with.';
            Editable = false;
        }
        field(21; "Instructions Updated At"; DateTime)
        {
            Caption = 'Instructions updated at';
            ToolTip = 'Specifies when the instructions were last set on the agent.';
            Editable = false;
        }
    }

    keys
    {
        key(Key1; "User Security ID")
        {
            Clustered = true;
        }
    }

    procedure AddReviewRequested(AgentUserSecurityId: Guid)
    begin
        GetOrCreate(AgentUserSecurityId);
        Rec."Reviews Requested" += 1;
        Rec.Modify();
    end;

    procedure AddAnswerReceived(AgentUserSecurityId: Guid)
    begin
        GetOrCreate(AgentUserSecurityId);
        Rec."Answers Received" += 1;
        Rec.Modify();
    end;

    procedure SetInstructionsVersion(AgentUserSecurityId: Guid; InstructionsVersion: Text[30])
    begin
        GetOrCreate(AgentUserSecurityId);
        Rec."Instructions Version" := InstructionsVersion;
        Rec."Instructions Updated At" := CurrentDateTime();
        Rec.Modify();
    end;

    local procedure GetOrCreate(AgentUserSecurityId: Guid)
    begin
        if Rec.Get(AgentUserSecurityId) then
            exit;
        Rec.Init();
        Rec."User Security ID" := AgentUserSecurityId;
        Rec.Insert();
    end;
}
