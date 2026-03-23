@isTest
public class TaskTabsControllerTest {

    @testSetup
    static void setupData() {
        // Create some tasks with different status, priority and dates
        List<Task> tasks = new List<Task>();

        // Open High priority, due today
        tasks.add(new Task(
            Subject = 'High Priority Task',
            Status = 'Open',
            Priority = 'High',
            ActivityDate = Date.today()
        ));

        // Open Normal priority, due tomorrow
        tasks.add(new Task(
            Subject = 'Normal Priority Task',
            Status = 'Open',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(1)
        ));

        // Overdue task (due yesterday)
        tasks.add(new Task(
            Subject = 'Overdue Task',
            Status = 'Open',
            Priority = 'Normal',
            ActivityDate = Date.today().addDays(-1)
        ));

        // Closed task (should not be returned)
        tasks.add(new Task(
            Subject = 'Closed Task',
            Status = 'Completed',
            Priority = 'High',
            ActivityDate = Date.today()
        ));

        insert tasks;
    }

    @isTest
    static void testGetTasksOpen() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks('OPEN');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Should return open tasks');
        for (Task t : result) {
            System.assertEquals('Open', t.Status, 'All returned tasks should be open');
        }
    }

    @isTest
    static void testGetTasksOpenHigh() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks('OPEN_HIGH');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return only one high-priority open task');
        System.assertEquals('High', result[0].Priority);
    }

    @isTest
    static void testGetTasksOpenNormal() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks('OPEN_NORMAL');
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return open normal tasks (overdue + future)');
        for (Task t : result) {
            System.assertEquals('Normal', t.Priority);
            System.assertEquals('Open', t.Status);
        }
    }

    @isTest
    static void testGetTasksOverdue() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks('OVERDUE');
        Test.stopTest();

        System.assertEquals(1, result.size(), 'Should return exactly one overdue task');
       // System.assertTrue(result[0].ActivityDate < Date.today(), 'Overdue task should have past date');
    }

    @isTest
    static void testGetTasksDefaultWhenInvalidKey() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks('INVALID_VIEW');
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Invalid key should fall back to OPEN tasks');
        for (Task t : result) {
            System.assertEquals('Open', t.Status);
        }
    }

    @isTest
    static void testGetTasksWhenNullKey() {
        Test.startTest();
        List<Task> result = TaskTabsController.getTasks(null);
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Null key should default to OPEN tasks');
        for (Task t : result) {
            System.assertEquals('Open', t.Status);
        }
    }
}