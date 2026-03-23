@IsTest
public class AccountRenewalPromptTemplateTest {

    @IsTest
    static void testGetRenewalInfo_WithMonthYearAndRegion() {
        // Create test user
        User testUser = [SELECT Id FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];

        // Create test account that matches filters
        Account acc = new Account(
            Name = 'Test Account 1',
            Renewal_Date__c = Date.today().addMonths(1),
            MRR__c = 5000,
            OwnerId = testUser.Id,
            Region__c = 'Asia'
        );
        insert acc;

        // Prepare request: user input with month, year, and region
        AccountRenewalPromptTemplate.Request req = new AccountRenewalPromptTemplate.Request();
        req.user_input = 'May 2025 Asia';

        List<AccountRenewalPromptTemplate.Request> requests = new List<AccountRenewalPromptTemplate.Request>{ req };

        // Call method
        Test.startTest();
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(requests);
        Test.stopTest();

        System.assertEquals(1, responses.size(), 'There should be one response.');
        System.debug('Prompt: ' + responses[0].Prompt);
        System.assert(responses[0].Prompt.contains('Renewals Scheduled'), 'Prompt should contain expected text.');
    }

    @IsTest
    static void testGetRenewalInfo_ThisMonth() {
        // Create account renewing this month
        Account acc = new Account(
            Name = 'Test Account 2',
            Renewal_Date__c = Date.today().addDays(5),
            MRR__c = 2500,
            OwnerId = UserInfo.getUserId()
        );
        insert acc;

        AccountRenewalPromptTemplate.Request req = new AccountRenewalPromptTemplate.Request();
        req.user_input = 'this month';

        Test.startTest();
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(new List<AccountRenewalPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].Prompt.contains('Renewals Scheduled'), 'Prompt should contain expected text.');
    }

    @IsTest
    static void testGetRenewalInfo_YearOnly() {
        Integer nextYear = Date.today().year() + 1;

        // Create an account for next year
        Account acc = new Account(
            Name = 'Test Account 3',
            Renewal_Date__c = Date.newInstance(nextYear, 6, 15),
            MRR__c = 3000,
            OwnerId = UserInfo.getUserId()
        );
        insert acc;

        AccountRenewalPromptTemplate.Request req = new AccountRenewalPromptTemplate.Request();
        req.user_input = String.valueOf(nextYear);

        Test.startTest();
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(new List<AccountRenewalPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].Prompt.contains('Renewals Scheduled'), 'Prompt should contain expected text.');
    }

    @IsTest
    static void testGetRenewalInfo_UnrecognizedDate() {
        AccountRenewalPromptTemplate.Request req = new AccountRenewalPromptTemplate.Request();
        req.user_input = 'someday soonish';

        Test.startTest();
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(new List<AccountRenewalPromptTemplate.Request>{ req });
        Test.stopTest();

        System.assertEquals(1, responses.size());
        System.assert(responses[0].Prompt.contains('Could not recognize'), 'Prompt should contain fallback message.');
    }

    @IsTest
    static void testGetRenewalInfo_EmptyRequest() {
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(new List<AccountRenewalPromptTemplate.Request>());
        System.assertEquals(0, responses.size(), 'Empty input should return empty response.');
    }

    @IsTest
    static void testGetRenewalInfo_NullRequest() {
        List<AccountRenewalPromptTemplate.Response> responses = AccountRenewalPromptTemplate.getRenewalInfo(null);
        System.assertEquals(0, responses.size(), 'Null input should return empty response.');
    }
}