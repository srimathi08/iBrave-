public with sharing class OpportunityTaskController {

    /* ---------------- CLOSED WON ---------------- */
    @AuraEnabled
    public static Integer closeRelatedTasks(Id opportunityId) {

        List<Task> tasksToUpdate = new List<Task>();

        for (Task t : [
            SELECT Id, IsClosed
            FROM Task
            WHERE WhatId = :opportunityId
        ]) {
            if (!t.IsClosed) {
                t.Status = 'Completed';
                tasksToUpdate.add(t);
            }
        }

        if (!tasksToUpdate.isEmpty()) {
            update tasksToUpdate;
        }

        return tasksToUpdate.size();
    }

    /* ---------------- CLOSED LOST ---------------- */
   @AuraEnabled
public static Integer updateTasksOnClosedLost(
    Id opportunityId,
    String lossReason
) {
    List<Task> tasksToUpdate = new List<Task>();

    for (Task t : [
        SELECT Id, Status, IsClosed, Remarks__c
        FROM Task
        WHERE WhatId = :opportunityId
        AND IsClosed = false          // 🔥 ONLY pending tasks
    ]) {
        t.Status = 'In-Complete';     // or 'Not Started'
        t.Remarks__c = lossReason;   // copy exact loss reason
        tasksToUpdate.add(t);
    }

    if (!tasksToUpdate.isEmpty()) {
        update tasksToUpdate;
    }

    return tasksToUpdate.size();
}

}