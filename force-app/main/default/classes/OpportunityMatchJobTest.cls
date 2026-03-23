@isTest
public class OpportunityMatchJobTest {

    // Mock class for callouts so the batch can run
    private class TestHttpMock implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"success": true}');
            return res;
        }
    }

    @isTest
    static void testOpportunityMatchJobExecution() {

        // -----------------------------
        // 1. Test Data Setup
        // -----------------------------
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        // -----------------------------
        // 2. Enable callout mock
        // -----------------------------
        Test.setMock(HttpCalloutMock.class, new TestHttpMock());

        // -----------------------------
        // 3. Start Test Context
        // -----------------------------
        Test.startTest();

        // Queueable → Should launch batch inside
        System.enqueueJob(new OpportunityMatchJob(opp.Id));

        Test.stopTest(); // executes queueable + batch

        // -----------------------------
        // 4. Assertions
        // -----------------------------

        // Validate batch job was created
        List<AsyncApexJob> jobs = [
            SELECT Id, JobType, Status 
            FROM AsyncApexJob
            WHERE JobType = 'BatchApex'
        ];

        System.assert(!jobs.isEmpty(), 'Batch job should have been launched.');
    }
}





/*@isTest
public class OpportunityMatchJob_Test {

    @testSetup
    static void setupData() {
        // Try to get RecordTypes (they already exist in most orgs)
        Map<String, Id> recordTypeMap = new Map<String, Id>();
        for (RecordType rt : [
            SELECT Id, DeveloperName 
            FROM RecordType 
            WHERE SObjectType = 'Account' 
            AND DeveloperName IN ('Employee','Candidates','Contractor')
        ]) {
            recordTypeMap.put(rt.DeveloperName, rt.Id);
        }

        // If RecordTypes don’t exist (in sandbox/test), still create accounts without RT filter
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 3; i++) {
            Account acc = TestDataFactory.createAccount(false);
            acc.Name = 'TestCandidate_' + i;
            if (recordTypeMap.containsKey('Employee') && i == 0) {
                acc.RecordTypeId = recordTypeMap.get('Employee');
            } else if (recordTypeMap.containsKey('Candidates') && i == 1) {
                acc.RecordTypeId = recordTypeMap.get('Candidates');
            } else if (recordTypeMap.containsKey('Contractor') && i == 2) {
                acc.RecordTypeId = recordTypeMap.get('Contractor');
            }
            accounts.add(acc);
        }
        insert accounts;

        // Create an Opportunity using TestDataFactory
        Opportunity opp = TestDataFactory.createOpportunity(true, accounts[0].Id, null);
    }

    @isTest
    static void test_Queueable_Execute() {
        Opportunity opp = [SELECT Id FROM Opportunity LIMIT 1];

        Test.startTest();
            System.enqueueJob(new OpportunityMatchJob(opp.Id));
        Test.stopTest();

        // ✅ Verify that the job executed without throwing exceptions
        System.assert(true, 'Queueable executed successfully with candidate accounts.');
    }

    @isTest
    static void test_Queueable_WithNoAccounts() {
        // Delete all Accounts to simulate no candidate accounts
        delete [SELECT Id FROM Account];

        Opportunity opp = TestDataFactory.createOpportunity(true, null, null);

        Test.startTest();
            System.enqueueJob(new OpportunityMatchJob(opp.Id));
        Test.stopTest();

        // ✅ Should still complete gracefully
        System.assert(true, 'Queueable executed successfully with no accounts available.');
    }
} */