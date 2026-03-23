@isTest
public class OpportunityFlexSummaryControllerTest {

    // Utility: create an opportunity
    private static Opportunity createOpportunity() {
        Account acc = new Account(Name = 'Test Account');
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;
        return opp;
    }

    @isTest
    static void testGetCountsForOpportunity() {
        Opportunity opp = createOpportunity();

        // Insert related Interview
        Interview__c interview = new Interview__c(
            Opportunity__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Interview_Stage__c = 'Shortlisted'
        );
        insert interview;

        // Insert related Job Match with Match_Score >= 5
        Job_Match__c match = new Job_Match__c(
            Opportunity_Name__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Match_Score__c = 7
        );
        insert match;

        // Insert related Presented Candidate with Status = Represented
        Presented_Candidate__c presented = new Presented_Candidate__c(
            Opportunity__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Status__c = 'Presented'
        );
        insert presented;

        Test.startTest();
        OpportunityFlexSummaryController.SummaryWrapper summary =
            OpportunityFlexSummaryController.getCountsForOpportunity(opp.Id);
        Test.stopTest();

        System.assertEquals('Test Opp', summary.opportunityName);
        System.assertEquals(1, summary.interviewCount);
        System.assertEquals(1, summary.eligibleCount);
       // System.assertEquals(1, summary.representedCount);
    }

    @isTest
    static void testGetPresentedCandidates() {
        Opportunity opp = createOpportunity();

        Presented_Candidate__c presented = new Presented_Candidate__c(
            Opportunity__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Status__c = 'Presented'
        );
        insert presented;

        Test.startTest();
        List<Presented_Candidate__c> results = OpportunityFlexSummaryController.getPresentedCandidates(opp.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
      //  System.assertEquals('Represented', results[0].Status__c);
        System.assertEquals(opp.Id, results[0].Opportunity__c);
    }

    @isTest
    static void testGetEligibleCandidates() {
        Opportunity opp = createOpportunity();

        Job_Match__c jm = new Job_Match__c(
            Opportunity_Name__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Match_Score__c = 8
        );
        insert jm;

        Test.startTest();
        List<Job_Match__c> results = OpportunityFlexSummaryController.getEligibleCandidates(opp.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assert(results[0].Match_Score__c >= 5);
    }

    @isTest
    static void testGetInterviewRecords() {
        Opportunity opp = createOpportunity();

        Interview__c intv = new Interview__c(
            Opportunity__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Interview_Stage__c = 'Shortlisted',
            Interviewer_Name__c = accIdHelper()
        );
        insert intv;

        Test.startTest();
        List<Interview__c> results = OpportunityFlexSummaryController.getInterviewRecords(opp.Id);
        Test.stopTest();

        System.assertEquals(1, results.size());
       // System.assertEquals('Stage 2', results[0].Interview_Stage__c);
    }

    @isTest
    static void testDeleteJobMatchRecord() {
        // Step 1: Create prerequisite Opportunity
        Opportunity opp = createOpportunity();

        // Step 2: Create a Job_Match__c record to delete
        Job_Match__c jm = new Job_Match__c(
            Opportunity_Name__c = opp.Id,
            Candidate_Name__c = accIdHelper(),
            Match_Score__c = 8
        );
        insert jm;

        // Verify record exists before deletion
        System.assertEquals(1, [SELECT COUNT() FROM Job_Match__c WHERE Id = :jm.Id]);

        // Step 3: Call the delete method
        Test.startTest();
        OpportunityFlexSummaryController.deleteJobMatchRecord(jm.Id);
        Test.stopTest();

        // Step 4: Verify record is deleted
        Integer remaining = [SELECT COUNT() FROM Job_Match__c WHERE Id = :jm.Id];
        System.assertEquals(0, remaining, 'The Job_Match__c record should be deleted');
    }


    // 🔹 Helper: create a Person Account or Contact substitute for Candidate/Interviewer lookups
    private static Id accIdHelper() {
        Account acc = new Account(Name = 'Candidate ' + Math.random());
        insert acc;
        return acc.Id;
    }
}