namespace Contoso.ProjectInspector;

using Microsoft.Projects.Project.Job;

codeunit 50112 "PI Job Subscribers"
{
    Access = Internal;

    [EventSubscriber(ObjectType::Table, Database::Job, 'OnAfterValidateEvent', 'Status', false, false)]
    local procedure OnAfterValidateJobStatus(var Rec: Record Job; var xRec: Record Job; CurrFieldNo: Integer)
    var
        ReviewTrigger: Codeunit "PI Review Trigger";
    begin
        ReviewTrigger.OnAfterStatusValidated(Rec, xRec);
    end;
}
