@isTest
private class TaskTabsController_Test {

    @testSetup
    static void setupData() {
        // Use common labels directly
        String completedStatus = 'Completed';
        String nonCompletedStatus = 'Not Started';
        // If your org uses different labels for status, update above accordingly.

        List<Task> tasks = new List<Task>{
            new Task(Subject='Open High Task', Status = nonCompletedStatus, Priority='High', ActivityDate = Date.today().addDays(1)),
            new Task(Subject='Open Medium Task', Status = nonCompletedStatus, Priority='Medium', ActivityDate = Date.today().addDays(2)),
            new Task(Subject='Open Normal Task', Status = nonCompletedStatus, Priority='Normal', ActivityDate = Date.today().addDays(3)),
            new Task(Subject='Overdue Task', Status = nonCompletedStatus, Priority='Normal', ActivityDate = Date.today().addDays(-2)),
            new Task(Subject='Another Open Task', Status = nonCompletedStatus, Priority='Normal', ActivityDate = Date.today()),
            new Task(Subject='Completed Task', Status = completedStatus, Priority='Normal', ActivityDate = Date.today().addDays(-5))
        };
        insert tasks;
    }

    @isTest static void testDefaultOpenView_excludesCompleted() {
        List<Task> result = TaskTabsController.getTasks(null);
        for (Task t : result) {
            System.assertNotEquals('Completed', t.Status, 'Default OPEN view must exclude Completed tasks');
        }
    }

    @isTest static void testPriorityAndOverdueAndGetAll() {
        List<Task> high = TaskTabsController.getTasks('OPEN_HIGH');
        for (Task t : high) {
            System.assertEquals('High', t.Priority, 'OPEN_HIGH must return High priority tasks');
            System.assertNotEquals('Completed', t.Status);
        }

        List<Task> overdue = TaskTabsController.getTasks('OVERDUE');
        Boolean foundOverdue = false;
        for (Task t : overdue) {
            System.assert(t.ActivityDate != null && t.ActivityDate < Date.today(), 'OVERDUE must return tasks before today');
            if (t.Subject == 'Overdue Task') foundOverdue = true;
        }
        System.assert(foundOverdue, 'Inserted Overdue Task should be returned by OVERDUE view');

        List<Task> allT = TaskTabsController.getAllTasks();
        Boolean foundCompleted = false;
        for (Task t : allT) if (t.Subject == 'Completed Task' && t.Status == 'Completed') foundCompleted = true;
        System.assert(foundCompleted, 'getAllTasks should include Completed tasks');
    }
}