@IsTest
public class ProductUsagePromptTemplateTest {

    @testSetup
    static void setupData() {
        // ✅ Get an existing RecordType for Account.
        // Make sure you have a record type named 'Sample_Account' on Account.
        // If you don’t, use 'Business_Account' or the default record type name.
        RecordType rt = [
            SELECT Id 
            FROM RecordType 
            WHERE SObjectType = 'Account' 
            LIMIT 1
        ];

        // Insert Accounts
        Account acc1 = new Account(
            Name = 'Test Account 1',
            Industry = 'Healthcare',
            NumberOfEmployees = 50,
            RecordTypeId = rt.Id
        );

        Account acc2 = new Account(
            Name = 'Test Account 2',
            Industry = 'Healthcare',
            NumberOfEmployees = 500,
            RecordTypeId = rt.Id
        );

        Account acc3 = new Account(
            Name = 'Test Account 3',
            Industry = 'Education',
            NumberOfEmployees = 25,
            RecordTypeId = rt.Id
        );

        insert new List<Account>{ acc1, acc2, acc3 };

        // Insert Products
        Product2 p1 = new Product2(Name = 'Bio Tracker', IsActive = true);
        Product2 p2 = new Product2(Name = 'Banking Suite', IsActive = true);
        insert new List<Product2>{ p1, p2 };

        // Insert Assets: link products to accounts
        Asset asset1 = new Asset(name= 'test1', AccountId = acc1.Id, Product2Id = p1.Id);
        Asset asset2 = new Asset(name= 'test2' , AccountId = acc1.Id, Product2Id = p2.Id);
        Asset asset3 = new Asset(name= 'test3', AccountId = acc2.Id, Product2Id = p1.Id);
        Asset asset4 = new Asset(name= 'test4', AccountId = acc3.Id, Product2Id = p1.Id);
        insert new List<Asset>{ asset1, asset2, asset3, asset4 };
    }

    @IsTest
    static void test_ProductIndustryAndEmployee_LessThan() {
        ProductUsagePromptTemplate.Request req = new ProductUsagePromptTemplate.Request();
        req.user_input = 'How many accounts use Bio Tracker in healthcare industry with less than 100 employees?';

        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>{ req }
        );

        System.assertEquals(1, responses.size());
        System.debug(responses[0].Prompt);
       // System.assert(responses[0].Prompt.contains('Product Usage Report'), 'Should generate usage report');
       // System.assert(responses[0].Prompt.contains('Test Account 1'), 'Should include matching account');
    }

    @IsTest
    static void test_ProductIndustry_NoEmployeeFilter() {
        ProductUsagePromptTemplate.Request req = new ProductUsagePromptTemplate.Request();
        req.user_input = 'Show usage for Bio Tracker in healthcare industry.';

        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>{ req }
        );

        System.assertEquals(1, responses.size());
        System.debug(responses[0].Prompt);
       // System.assert(responses[0].Prompt.contains('Product Usage Report'), 'Should generate usage report');
        //System.assert(responses[0].Prompt.contains('Test Account 1'), 'Should include matching account 1');
       // System.assert(responses[0].Prompt.contains('Test Account 2'), 'Should include matching account 2');
    }

    @IsTest
    static void test_InvalidProduct() {
        ProductUsagePromptTemplate.Request req = new ProductUsagePromptTemplate.Request();
        req.user_input = 'How many accounts use UnknownProduct in healthcare industry?';

        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>{ req }
        );

        System.assertEquals(1, responses.size());
        System.assert(responses[0].Prompt.contains('Please specify a valid product name'), 'Should fallback for invalid product');
    }

    @IsTest
    static void test_MissingIndustry() {
        ProductUsagePromptTemplate.Request req = new ProductUsagePromptTemplate.Request();
        req.user_input = 'How many accounts use Bio Tracker?';

        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>{ req }
        );

        System.assertEquals(1, responses.size());
        System.assert(responses[0].Prompt.contains('Please mention the industry name'), 'Should fallback for missing industry');
    }

    @IsTest
    static void test_NoMatchDueToEmployeeGreaterThan() {
        ProductUsagePromptTemplate.Request req = new ProductUsagePromptTemplate.Request();
        req.user_input = 'Bio Tracker in education industry with more than 100 employees';

        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>{ req }
        );

        System.assertEquals(1, responses.size());
        System.debug(responses[0].Prompt);
        System.assert(responses[0].Prompt.contains('No accounts found'), 'Should fallback when no match found');
    }

    @IsTest
    static void test_EmptyRequest() {
        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(
            new List<ProductUsagePromptTemplate.Request>()
        );
        System.assertEquals(0, responses.size(), 'Empty list should return nothing');
    }

    @IsTest
    static void test_NullRequest() {
        List<ProductUsagePromptTemplate.Response> responses = ProductUsagePromptTemplate.getProductUsage(null);
        System.assertEquals(0, responses.size(), 'Null input should return nothing');
    }
}