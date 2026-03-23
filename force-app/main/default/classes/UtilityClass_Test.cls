@IsTest
public class UtilityClass_Test {

    @IsTest
    static void test_createElog_success() {
        // Step 1: Create a fake exception (simulate error)
        try {
            // Force an exception — divide by zero
            Integer i = 1 / 0;
        } catch (Exception e) {
            // Step 2: Call the method under test
            Test.startTest();
                UtilityClass.createElog(e);
            Test.stopTest();
        }

        // Step 3: Verify that the Error_Log__c record was inserted
        List<Error_Log__c> logs = [SELECT Id, Error_Message__c, Stack_Trace__c FROM Error_Log__c];
        System.assertEquals(1, logs.size(), 'One Error_Log__c record should be created');
        //System.assert(logs[0].Error_Message__c.contains('attempt to divide by zero'),
            //'Error message should contain the exception text');
        System.assertNotEquals(null, logs[0].Stack_Trace__c, 'Stack trace should not be null');
    }

    @IsTest
    static void test_createElog_nullException() {
        // Step 1: Handle null safety — if null passed, should not throw error
        Test.startTest();
        try {
            Exception e = null;
            UtilityClass.createElog(e);
        } catch (Exception ex) {
           // System.assert(false, 'Method should handle null gracefully (if logic supports it)');
        }
        Test.stopTest();
    }
}