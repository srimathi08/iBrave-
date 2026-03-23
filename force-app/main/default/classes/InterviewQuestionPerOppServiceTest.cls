@isTest
public class InterviewQuestionPerOppServiceTest {

    private static Account makeAccount() {
         Account acc = new Account(
            Name = 'Candidate Tester',
            Type = 'Candidate' 
        );
        insert acc;
        return acc;
    }

    private static Opportunity makeOpportunity(Account acc) {
        Opportunity opp = new Opportunity(
            Name = 'Test Opp',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;
        return opp;
    }

    @isTest
    static void testAwardPointsOnFirstQuestion() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc);

        // Insert first Interview Question → should trigger Points Ledger creation
        Interview_Question__c q = new Interview_Question__c(
            Candidate_Name__c = acc.Id,
            Opportunity_Name__c = opp.Id,
            Question__c = 'Tell me about yourself?'
        );

        Test.startTest();
        insert q; // trigger fires InterviewQuestionPerOppService.syncForDml
        Test.stopTest();

        // Assert one Points Ledger created
        List<Points_Ledger__c> ledgers = [
            SELECT Account__c, Opportunity__c, Action__c, Points__c, Key__c
            FROM Points_Ledger__c
            WHERE Account__c = :acc.Id AND Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, ledgers.size(), 'One Points Ledger should be inserted');
        System.assertEquals(5, ledgers[0].Points__c, 'Should grant 5 points');
        System.assertEquals('QuestionOnOpportunity', ledgers[0].Action__c);
    }

    @isTest
    static void testNoDuplicatePoints() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc);

        // Insert first Interview Question
        Interview_Question__c q1 = new Interview_Question__c(
            Candidate_Name__c = acc.Id,
            Opportunity_Name__c = opp.Id,
            Question__c = 'First question'
        );
        insert q1;

        // Insert second Interview Question for same pair → no new Points Ledger should be created
        Interview_Question__c q2 = new Interview_Question__c(
            Candidate_Name__c = acc.Id,
            Opportunity_Name__c = opp.Id,
            Question__c = 'Second question'
        );
        insert q2;

        List<Points_Ledger__c> ledgers = [
            SELECT Id FROM Points_Ledger__c
            WHERE Account__c = :acc.Id AND Opportunity__c = :opp.Id
        ];

        System.assertEquals(1, ledgers.size(), 'Only one award per (Account, Opportunity) should exist');
    }

    @isTest
    static void testNoAwardIfNoQuestionText() {
        Account acc = makeAccount();
        Opportunity opp = makeOpportunity(acc);

        // Insert Interview Question with null candidate/opportunity → should be ignored
        Interview_Question__c q = new Interview_Question__c(
            Question__c = 'This should not count'
        );
        insert q;

        System.assertEquals(
            0,
            [SELECT COUNT() FROM Points_Ledger__c WHERE Action__c = 'QuestionOnOpportunity'],
            'No ledger entry should be created when missing Account/Opportunity'
        );
    }
}