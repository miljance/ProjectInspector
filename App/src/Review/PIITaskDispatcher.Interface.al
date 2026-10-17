namespace Contoso.ProjectInspector;

/// <summary>
/// Sends work to the Project Inspector agent. The default implementation creates agent tasks;
/// the tests replace it with a mock so they run without an activated agent.
/// </summary>
interface "PI ITask Dispatcher"
{
    /// <summary>
    /// Returns true when an active Project Inspector agent can take the task.
    /// </summary>
    procedure IsAvailable(): Boolean;

    /// <summary>
    /// Starts a review of the project. If a review task for the project exists, the message is added to it.
    /// </summary>
    procedure SendReview(ProjectNo: Code[20]; TaskTitle: Text[150]; MessageText: Text);

    /// <summary>
    /// Adds the answer of the salesperson to the review task of the project.
    /// </summary>
    procedure AddAnswer(ProjectNo: Code[20]; MessageText: Text);

    /// <summary>
    /// Stops the review tasks of the project that can still run, so the next review starts a new task
    /// with the current instructions.
    /// </summary>
    procedure StopReview(ProjectNo: Code[20]);

    /// <summary>
    /// Returns true when the agent task has finished, that is after the reviewer chose Continue and the agent
    /// ended the task. A task that waits for the reviewer, or was stopped, is not finished.
    /// </summary>
    procedure IsReviewTaskFinished(AgentTaskId: BigInteger): Boolean;

    /// <summary>
    /// Returns the ID of the project's review task that can still run (the one SendReview and AddAnswer use), or 0.
    /// </summary>
    procedure GetReviewTaskId(ProjectNo: Code[20]): BigInteger;

    /// <summary>
    /// Returns true when the agent task was stopped (by a user or by the system) or no longer exists: it never runs
    /// again, so its open review result is closed without carrying anything out.
    /// </summary>
    procedure IsReviewTaskStopped(AgentTaskId: BigInteger): Boolean;
}
