@isTest
public class InterviewQuestionRelatedOppTest {

    private static Opportunity makeOpportunity() {
        Account acc = new Account(
            Name = 'Candidate Tester',
            Type = 'Candidate'
        );
        insert acc;

        Opportunity opp = new Opportunity(
            Name = 'Interview Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            AccountId = acc.Id
        );
        insert opp;

        return opp;
    }

    @isTest
    static void testGetQuestionsWithRecords() {
        Opportunity opp = makeOpportunity();

        // Insert interview questions linked to opportunity
        List<Interview_Question__c> questions = new List<Interview_Question__c>{
            new Interview_Question__c(
                Candidate_Name__c = opp.AccountId,
                Opportunity_Name__c = opp.Id,
                Question__c = 'Tell me about yourself?'
            ),
            new Interview_Question__c(
                Candidate_Name__c = opp.AccountId,
                Opportunity_Name__c = opp.Id,
                Question__c = 'What are your strengths?'
            )
        };
        insert questions;

        Test.startTest();
        List<String> result = InterviewQuestionRelatedOpp.getInterviewQuestions(opp.Id);
        Test.stopTest();

        System.assertEquals(2, result.size(), 'Should return 2 questions');
        System.assert(result.contains('Tell me about yourself?'));
        System.assert(result.contains('What are your strengths?'));
    }

    @isTest
    static void testGetQuestionsNoRecords() {
        Opportunity opp = makeOpportunity();

        Test.startTest();
        List<String> result = InterviewQuestionRelatedOpp.getInterviewQuestions(opp.Id);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty list when no questions exist');
    }

    @isTest
    static void testGetQuestionsWithNullId() {
        Test.startTest();
        List<String> result = InterviewQuestionRelatedOpp.getInterviewQuestions(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return empty list when opportunityId is null');
    }
}