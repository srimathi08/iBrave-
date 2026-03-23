@IsTest
public class TriggerExecutionGuardTest {

    @IsTest
    static void testCanExecute() {

        // First execution should be allowed
        Boolean firstRun = TriggerExecutionGuard.canExecute('TestKey');
        System.assertEquals(true, firstRun, 'First execution should be allowed');

        // Second execution with same key should be blocked
        Boolean secondRun = TriggerExecutionGuard.canExecute('TestKey');
        System.assertEquals(false, secondRun, 'Second execution should be blocked');

        // Different key should be allowed
        Boolean thirdRun = TriggerExecutionGuard.canExecute('AnotherKey');
        System.assertEquals(true, thirdRun, 'Different key should be allowed');
    }
}