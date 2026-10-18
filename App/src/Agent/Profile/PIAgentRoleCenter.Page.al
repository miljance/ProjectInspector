namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;
using Microsoft.Sales.Customer;

/// <summary>
/// Home page of the Project Inspector agent (profile "Project Inspector Agent"), like the Sales Order Agent's own role
/// center. An agent can only open the pages its home page and the opened pages offer: it cannot search. So the menu
/// lists every page the instructions start from:
/// - Projects: the project, its tasks and planning lines (steps 1 to 3, 8) and the duplicate check (step 5).
/// - Customers: the Blocked check (step 4). The agent cannot reach the customer from the project card, so it comes here.
/// - Project Inspector Review Results: the report and the reviewer's decision (step 8).
/// </summary>
page 50109 "PI Agent Role Center"
{
    PageType = RoleCenter;
    Caption = 'Project Inspector';
    ApplicationArea = All;

    layout
    {
        area(RoleCenter)
        {
        }
    }

    actions
    {
        area(Embedding)
        {
            ToolTip = 'Review new projects against the project creation rules and record the review result.';

            action(Projects)
            {
                ApplicationArea = Jobs;
                Caption = 'Projects';
                Image = Job;
                RunObject = Page "Job List";
                ToolTip = 'Open the projects to review their tasks, planning lines and dates, and to look for duplicates.';
            }
            action(Customers)
            {
                ApplicationArea = Jobs;
                Caption = 'Customers';
                Image = Customer;
                RunObject = Page "Customer List";
                ToolTip = 'Open the customers to check whether the customer of the project is blocked.';
            }
            action(ReviewResults)
            {
                ApplicationArea = Jobs;
                Caption = 'Project Inspector Review Results';
                Image = TaskList;
                RunObject = Page "PI Review Results";
                ToolTip = 'Record the review report of a project and get the reviewer''s decision.';
            }
        }
    }
}
