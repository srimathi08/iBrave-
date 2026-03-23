@isTest
private class OpportunityMatchBatchTest {

    // --------------------------
    // MOCK CLASS
    // --------------------------
    private class EinsteinMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody('{"score": 8, "explanation": "Good match"}');
            return res;
        }
    }

    // --------------------------
    // MAIN TEST
    // --------------------------
    @isTest
    static void testOpportunityMatchBatch() {

        // Register callout mock
        Test.setMock(HttpCalloutMock.class, new EinsteinMock());

        // Create Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today(),
            Job_Description__c = 'Sample JD',
            Skills_Required__c = 'Apex, LWC',
            Experience_Required__c = '3'
        );
        insert opp;

        // Record Type
        Id rtId = Schema.SObjectType.Account.getRecordTypeInfosByDeveloperName()
                   .get('Employee').getRecordTypeId();

        // VALID candidate – should be processed
        Account a1 = new Account(
            Name = 'Valid Candidate',
            RecordTypeId = rtId,
            Status__c = 'Active',
            Description = 'Valid description',
            Years_of_Experience__c = '5'
        );

        // BLACKLIST – should be skipped
        Account a2 = new Account(
            Name = 'Blacklisted Person',
            RecordTypeId = rtId,
            Status__c = 'Active',
            Description = 'Some text'
        );

        // EMPTY DESCRIPTION – should be skipped
        Account a3 = new Account(
            Name = 'No Description Person',
            RecordTypeId = rtId,
            Status__c = 'Active',
            Description = ''
        );

        insert new List<Account>{ a1, a2, a3 };

        Test.startTest();
        Database.executeBatch(new OpportunityMatchBatch(opp.Id), 100);
        Test.stopTest();

        // Validate Job Match
        List<Job_Match__c> matches = [
            SELECT Id, Candidate_Name__c, Match_Score__c, Explanation__c
            FROM Job_Match__c
        ];

    }
}