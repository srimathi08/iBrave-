@isTest
public class AccountFlexSummary_Test {
    
    @isTest
    static void test_getInterviewSummary() {
        // 🧩 Step 1: Create full test data hierarchy
        Map<String, SObject> dataMap = TestDataFactory.createAccountHierarchy(true);
        
        // Extract required records
        Account testAccount = (Account) dataMap.get('Account');
        Interview__c testInterview = (Interview__c) dataMap.get('Interview');
        
        Test.startTest();
            // 🧠 Step 2: Call the method under test
            AccountFlexSummary.SummaryWrapper result = AccountFlexSummary.getInterviewSummary(testAccount.Id);
        Test.stopTest();

        // ✅ Step 3: Assert results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(testAccount.Name, result.accountName, 'Account Name should match');
        System.assertEquals(1, result.interviewCount, 'Interview count should be 1');
    }

    @isTest
    static void test_getInterviewSummary_NoInterviews() {
        // 🧩 Step 1: Create an account without interviews
        Account acc = TestDataFactory.createAccount(true);

        Test.startTest();
            // 🧠 Step 2: Call the method under test for account with no interviews
            AccountFlexSummary.SummaryWrapper result = AccountFlexSummary.getInterviewSummary(acc.Id);
        Test.stopTest();

        // ✅ Step 3: Assert results
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals(acc.Name, result.accountName, 'Account Name should match');
        System.assertEquals(0, result.interviewCount, 'Interview count should be 0 for no interviews');
    }
}