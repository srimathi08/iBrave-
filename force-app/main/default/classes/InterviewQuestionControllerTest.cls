@isTest
public class InterviewQuestionControllerTest {

    // Helper to create a Candidate Account and related Opportunity
    private static Opportunity makeOpportunity() {
        // Create an Account that satisfies the lookup filter on Candidate_Name__c
        Account acc = new Account(
            Name = 'Candidate Tester',
            Type = 'Candidate' // ✅ ensures it passes lookup filter
        );
        insert acc;

        // Create an Opportunity linked to that Account
        Opportunity opp = new Opportunity(
            Name = 'Interview Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(7),
            AccountId = acc.Id
        );
        insert opp;

        return opp;
    }

    @isTest
    static void testSaveInterviewQuestionsInsertsRecords() {
        Opportunity opp = makeOpportunity();
        Id candidateId = opp.AccountId;

        List<String> sampleQuestions = new List<String>{
            'Tell me about yourself?',
            'What are your strengths?'
        };

        Date interviewDate = Date.today().addDays(2);

        Test.startTest();
        InterviewQuestionController.saveInterviewQuestions(candidateId, opp.Id, interviewDate, sampleQuestions);
        Test.stopTest();

        // Verify records inserted
        List<Interview_Question__c> inserted = [
            SELECT Candidate_Name__c, Opportunity_Name__c, Interview_Date__c, Question__c
            FROM Interview_Question__c
            WHERE Opportunity_Name__c = :opp.Id
        ];

        System.assertEquals(2, inserted.size(), 'Two interview questions should be inserted');
        Set<String> qTexts = new Set<String>();
        for (Interview_Question__c iq : inserted) {
            System.assertEquals(candidateId, iq.Candidate_Name__c);
            System.assertEquals(opp.Id, iq.Opportunity_Name__c);
            System.assertEquals(interviewDate, iq.Interview_Date__c);
            qTexts.add(iq.Question__c);
        }

        System.assert(qTexts.contains('Tell me about yourself?'));
        System.assert(qTexts.contains('What are your strengths?'));
    }

    @isTest
    static void testSaveInterviewQuestionsWithEmptyList() {
        Opportunity opp = makeOpportunity();
        Id candidateId = opp.AccountId;

        // Empty list → should not insert anything
        Test.startTest();
        InterviewQuestionController.saveInterviewQuestions(candidateId, opp.Id, Date.today(), new List<String>());
        Test.stopTest();

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Interview_Question__c WHERE Opportunity_Name__c = :opp.Id],
            'No records should be inserted for empty list'
        );
    }
}