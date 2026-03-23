@IsTest
public class AccountMRRPromptTemplateTest {

    @IsTest
    static void testMRR_WithRegion() {
        // Setup test user (current user)
        Id ownerId = UserInfo.getUserId();

        // Insert accounts in different regions
        Account asiaAcc = new Account(
            Name = 'AsiaCorp',
            MRR__c = 1200,
            Region__c = 'Asia',
            OwnerId = ownerId
        );
        Account europeAcc = new Account(
            Name = 'EuroTech',
            MRR__c = 800,
            Region__c = 'Europe',
            OwnerId = ownerId
        );
        insert new List<Account>{ asiaAcc, europeAcc };

        // Prepare request to filter by 'Asia'
        AccountMRRPromptTemplate.Request req = new AccountMRRPromptTemplate.Request();
        req.user_input = 'What is the MRR for Asia?';

        Test.startTest();
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(new List<AccountMRRPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.debug('Prompt: ' + responses[0].Prompt);
        System.assert(responses[0].Prompt.contains('Asia'), 'Output should mention Asia region');
        System.assert(responses[0].Prompt.contains('AsiaCorp'), 'Output should list AsiaCorp');
        System.assert(!responses[0].Prompt.contains('EuroTech'), 'Output should not list EuroTech');
    }

    @IsTest
    static void testMRR_WithSpecificAccountName() {
        Id ownerId = UserInfo.getUserId();

        Account acc1 = new Account(
            Name = 'BioNova Solutions',
            MRR__c = 5000,
            Region__c = 'North America',
            OwnerId = ownerId
        );
        Account acc2 = new Account(
            Name = 'MegaCorp',
            MRR__c = 2000,
            Region__c = 'North America',
            OwnerId = ownerId
        );
        insert new List<Account>{ acc1, acc2 };

        // User specifically mentions 'BioNova Solutions'
        AccountMRRPromptTemplate.Request req = new AccountMRRPromptTemplate.Request();
        req.user_input = 'Show me MRR for BioNova Solutions';

        Test.startTest();
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(new List<AccountMRRPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.debug('Prompt: ' + responses[0].Prompt);
        System.assert(responses[0].Prompt.contains('BioNova Solutions'), 'Output should list BioNova Solutions only');
        System.assert(!responses[0].Prompt.contains('MegaCorp'), 'Output should NOT list MegaCorp');
    }

    @IsTest
    static void testMRR_NoMatch() {
        Id ownerId = UserInfo.getUserId();

        Account acc = new Account(
            Name = 'AlphaTest',
            MRR__c = 3000,
            Region__c = 'Europe',
            OwnerId = ownerId
        );
        insert acc;

        // Input that does not match any region or account name
        AccountMRRPromptTemplate.Request req = new AccountMRRPromptTemplate.Request();
        req.user_input = 'Show MRR for Mars Base';

        Test.startTest();
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(new List<AccountMRRPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.debug('Prompt: ' + responses[0].Prompt);
      //  System.assert(responses[0].Prompt.contains('No matching accounts found'), 'Should return fallback no match message');
    }

    @IsTest
    static void testMRR_AllAccounts_NoFilter() {
        Id ownerId = UserInfo.getUserId();

        Account acc1 = new Account(
            Name = 'OpenSky',
            MRR__c = 7000,
            OwnerId = ownerId
        );
        Account acc2 = new Account(
            Name = 'DeepTech',
            MRR__c = 3000,
            OwnerId = ownerId
        );
        insert new List<Account>{ acc1, acc2 };

        AccountMRRPromptTemplate.Request req = new AccountMRRPromptTemplate.Request();
        req.user_input = 'Show total MRR';

        Test.startTest();
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(new List<AccountMRRPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.debug('Prompt: ' + responses[0].Prompt);
        System.assert(responses[0].Prompt.contains('OpenSky'), 'Output should include OpenSky');
        System.assert(responses[0].Prompt.contains('DeepTech'), 'Output should include DeepTech');
        System.assert(responses[0].Prompt.contains('10000.00'), 'Total MRR should be 10000.00');
    }

    @IsTest
    static void testMRR_EmptyRequest() {
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(new List<AccountMRRPromptTemplate.Request>());
        System.assertEquals(0, responses.size(), 'Should return no output for empty request');
    }

    @IsTest
    static void testMRR_NullRequest() {
        List<AccountMRRPromptTemplate.Response> responses = AccountMRRPromptTemplate.getMRRInfo(null);
        System.assertEquals(0, responses.size(), 'Should return no output for null request');
    }

}