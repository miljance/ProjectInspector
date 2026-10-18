namespace Contoso.ProjectInspector;

using System.Agents;

/// <summary>
/// Where Project Inspector records the review report of each round (step 8 of its instructions).
/// The agent opens it from its home page and adds a new result on the card. In the agent's session the list shows
/// only results that were not carried out yet, so the agent never reopens a finished result of an earlier round.
/// </summary>
page 50107 "PI Review Results"
{
    PageType = List;
    ApplicationArea = Jobs;
    UsageCategory = Lists;
    Caption = 'Project Inspector Review Results';
    SourceTable = "PI Review Result";
    SourceTableView = sorting("Entry No.") order(descending);
    CardPageId = "PI Review Result Card";
    Editable = false;

    layout
    {
        area(Content)
        {
            repeater(Results)
            {
                field("Entry No."; Rec."Entry No.") { }
                field("Project No."; Rec."Project No.") { }
                field(Decision; Rec.Decision) { }
                field("Recorded At"; Rec."Recorded At") { }
                field(Processed; Rec.Processed) { }
                field(Result; Rec.Result) { }
                field("Recorded By"; Rec."Recorded By") { }
            }
        }
    }

    trigger OnOpenPage()
    var
        AgentSession: Codeunit "Agent Session";
        AgentMetadataProvider: Enum "Agent Metadata Provider";
    begin
        if AgentSession.IsAgentSession(AgentMetadataProvider) then
            Rec.SetRange(Processed, false);
    end;
}
