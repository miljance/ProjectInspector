namespace Contoso.ProjectInspector;

/// <summary>
/// The review result that is being carried out, so PI Business Events can name it in every business event
/// (ReviewResultId). Business event parameters are limited to 250 characters by the platform (AL0762); the flows read
/// the full questions, findings and answers not applied through the reviewResults API with this ID.
/// </summary>
codeunit 50118 "PI Review Context"
{
    Access = Internal;
    SingleInstance = true;

    var
        ReviewResultId: Guid;

    procedure SetReviewResultId(NewReviewResultId: Guid)
    begin
        ReviewResultId := NewReviewResultId;
    end;

    procedure GetReviewResultId(): Guid
    begin
        exit(ReviewResultId);
    end;

    procedure ClearReviewResultId()
    begin
        Clear(ReviewResultId);
    end;
}
