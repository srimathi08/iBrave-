@IsTest
public class JobDescriptionCreationControllerTest {

    /* --------------------------------------------------
     * TEST SETUP
     * -------------------------------------------------- */
    @testSetup
    static void setupData() {

        Profile p = [
            SELECT Id
            FROM Profile
            WHERE Name = 'System Administrator'
            LIMIT 1
        ];

        User admin = new User(
            FirstName = 'Test',
            LastName  = 'Admin',
            Email     = 'admin@test.com',
            Username  = 'admin' + System.currentTimeMillis() + '@test.com',
            Alias     = 'tadm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey   = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert admin;

        Account baseAcc = new Account(Name = 'Sample Account');
        insert baseAcc;

        Opportunity baseOpp = new Opportunity(
            Name = 'Base Opp',
            AccountId = baseAcc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(15)
        );
        insert baseOpp;

        Service__c svc = new Service__c(
            Name = 'JD Source',
            EmailFrom__c = admin.Email,
            WhatsappFrom__c = '+919999999999',
            Email_Body__c =
                'Hiring Salesforce Dev for 2 months onsite @1500 OMR, Budget 3000 USD',
            OwnerId = admin.Id
        );
        insert svc;

        // Attach a file to Service__c
        ContentVersion cv = new ContentVersion(
            Title = 'JDFile',
            PathOnClient = 'JD.txt',
            VersionData = Blob.valueOf('file data')
        );
        insert cv;

        Id docId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        insert new ContentDocumentLink(
            LinkedEntityId = svc.Id,
            ContentDocumentId = docId,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
    }

    /* --------------------------------------------------
     * Utility JSON Builder
     * -------------------------------------------------- */
    private static String buildJson() {
        return '{ "jobs":[{' +
            '"jobDescription":{' +
                '"companyName":"TechCorp Pvt Ltd",' +
                '"opportunityName":"Salesforce Developer",' +
                '"title":"Salesforce Developer",' +
                '"experience":"3",' +
                '"responsibilities":"Develop Apex and LWC for 2 months onsite @1500 OMR or remote 3000 USD",' +
                '"preferredLocation":"Chennai",' +
                '"skillsRequired":"Apex, LWC, Integration",' +
                '"qualifications":"BE",' +
                '"jobType":"Onsite",' +
                '"opportunityStartDate":"' + Date.today().addDays(5) + '"' +
            '}' +
        '}]}';
    }

    /* --------------------------------------------------
     * 1. Happy Path
     * -------------------------------------------------- */
    @IsTest
    static void test_HappyPath() {

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        Test.startTest();
        List<String> res =
            JobDescriptionCreationController.createJobDescriptions(
                buildJson(),
                svc.Id
            );
        Test.stopTest();

        System.assertNotEquals(null, res);
        System.assert(res.size() > 0);

        Opportunity opp = [
            SELECT Amount, Budget_In_JD__c, Currency_Mentioned_In_JD__c
            FROM Opportunity
            WHERE Account.Name = 'TechCorp Pvt Ltd'
            LIMIT 1
        ];

        System.assert(opp.Amount > 0);
        System.assertNotEquals(null, opp.Currency_Mentioned_In_JD__c);
        System.assertNotEquals(null, opp.Budget_In_JD__c);
    }

    /* --------------------------------------------------
     * 2. Invalid JSON
     * -------------------------------------------------- */
    @IsTest
    static void test_InvalidJson() {
        List<String> res =
            JobDescriptionCreationController.createJobDescriptions(
                'invalid json',
                null
            );
        System.assertEquals(null, res);
    }

    /* --------------------------------------------------
     * 3. Missing jobs key
     * -------------------------------------------------- */
    @IsTest
    static void test_NoJobsKey() {
        String json = '{ "wrongKey":[] }';
        List<String> res =
            JobDescriptionCreationController.createJobDescriptions(
                json,
                null
            );
        System.assertEquals(null, res);
    }

    /* --------------------------------------------------
     * 4. Empty jobs list
     * -------------------------------------------------- */
    @IsTest
    static void test_EmptyJobs() {
        String json = '{ "jobs":[] }';
        List<String> res =
            JobDescriptionCreationController.createJobDescriptions(
                json,
                null
            );
        System.assert(res == null || res.isEmpty());
    }

    /* --------------------------------------------------
     * 5. Fallback Currency (no regex hit)
     * -------------------------------------------------- */
    @IsTest
    static void test_FallbackCurrency() {

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        String json =
            '{ "jobs":[{"jobDescription":{' +
                '"companyName":"NoCurrency Corp",' +
                '"experience":"2",' +
                '"responsibilities":"JD text",' +
                '"skillsRequired":"Apex",' +
                '"budgetMentioned":"1000",' +
                '"currencyMentioned":"EUR"' +
            '}}]}';

        JobDescriptionCreationController.createJobDescriptions(json, svc.Id);

        Opportunity opp = [
            SELECT Currency_Mentioned_In_JD__c, Amount
            FROM Opportunity
            WHERE Account.Name = 'NoCurrency Corp'
            LIMIT 1
        ];

        System.assertEquals('EUR', opp.Currency_Mentioned_In_JD__c);
        System.assert(opp.Amount > 0);
    }

    /* --------------------------------------------------
     * 6. JD + Role + Skills match
     * -------------------------------------------------- */
    @IsTest
    static void test_FullJDMatch_ReusesOpp() {

        Account acc = new Account(Name = 'Match Corp');
        insert acc;

        insert new Opportunity(
            Name = 'Existing',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Job_Description__c = 'Develop Apex classes',
            Role_Required__c = 'Salesforce Developer',
            Skills_Required__c = 'Apex, LWC'
        );

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        String json =
            '{ "jobs":[{"jobDescription":{' +
                '"companyName":"Match Corp",' +
                '"responsibilities":"Develop Apex classes",' +
                '"skillsRequired":"Apex, LWC",' +
                '"opportunityName":"Salesforce Developer"' +
            '}}]}';

        JobDescriptionCreationController.createJobDescriptions(json, svc.Id);

        Integer cnt =
            [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(1, cnt);
    }

    /* --------------------------------------------------
     * 7. JD-only match
     * -------------------------------------------------- */
    @IsTest
    static void test_JDOnlyMatch() {

        Account acc = new Account(Name = 'JD Only Corp');
        insert acc;

        insert new Opportunity(
            Name = 'Existing',
            AccountId = acc.Id,
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(10),
            Job_Description__c = 'Develop Apex classes'
        );

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        String json =
            '{ "jobs":[{"jobDescription":{' +
                '"companyName":"JD Only Corp",' +
                '"responsibilities":"Develop Apex classes"' +
            '}}]}';

        JobDescriptionCreationController.createJobDescriptions(json, svc.Id);

        Integer cnt =
            [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(1, cnt);
    }
}


/*@isTest
public class JobDescriptionCreationControllerTest {

    // -------------------------------
    // TEST SETUP — fixed root cause
    // -------------------------------
    @testSetup
    static void setupTestData() {

        // Get System Admin profile
        Profile p = [
            SELECT Id 
            FROM Profile 
            WHERE Name = 'System Administrator' 
            LIMIT 1
        ];

        // Create a real test System Admin user
        User sysAdmin = new User(
            FirstName = 'Test',
            LastName = 'Admin',
            Email = 'testadmin@example.com',
            Username = 'testadmin' + DateTime.now().getTime() + '@test.com',
            Alias = 'tadm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert sysAdmin;

        System.runAs(sysAdmin) {

            // Create Account + Opportunity baseline using simple logic
            Account a = new Account(Name = 'Sample Account');
            insert a;

            Opportunity opp = new Opportunity(
                Name = 'Sample Opp',
                AccountId = a.Id,
                StageName = 'Prospecting',
                CloseDate = Date.today().addDays(15)
            );
            insert opp;

            // Create a Service__c record
            Service__c serviceRec = new Service__c(
                Name = 'JD Service Record',
                EmailFrom__c = sysAdmin.Email,
                Email_Body__c = 'We are hiring a Salesforce Developer for 3 months onsite @1500 OMR. Budget approx 3000 USD.',
                WhatsappFrom__c = '+919000000000',
                OwnerId = sysAdmin.Id
            );
            insert serviceRec;

            // Create a JD sample
            Job_Description__c jdSample = new Job_Description__c(
                Name = 'Sample JD Record',
                Company_Name__c = 'Sample Co',
                Opportunity__c = opp.Id
            );
            insert jdSample;

            // Attach a file to Service__c (to cover file copy logic)
            ContentVersion cv = new ContentVersion(
                Title = 'SampleFile',
                PathOnClient = 'SampleFile.txt',
                VersionData = Blob.valueOf('test file')
            );
            insert cv;

            Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

            insert new ContentDocumentLink(
                LinkedEntityId = serviceRec.Id,
                ContentDocumentId = docId,
                ShareType = 'V'
            );
        }
    }

    // Utility: Build valid JSON input
    private static String buildValidJson() {
        return '{' +
            '"jobs": [' +
                '{' +
                    '"jobDescription": {' +
                        '"companyName": "TechCorp Pvt Ltd",' +
                        '"opportunityName": "TechCorp Opp",' +
                        '"opportunityCloseDate": "' + Date.today().addDays(15) + '",' +
                        '"opportunityStartDate": "' + Date.today().addDays(5) + '",' +
                        '"duration": "3 months",' +
                        '"title": "Salesforce Developer",' +
                        '"experience": "3",' +
                        '"responsibilities": "Develop Apex classes and LWC components for 2 months onsite @1500 OMR or remote 3000 USD.",' +
                        '"preferredLocation": "Chennai",' +
                        '"qualifications": "BE / B.Tech",' +
                        '"skillsRequired": "Apex, LWC, Integration",' +
                        '"budgetMentioned": "1500",' +
                        '"currencyMentioned": "USD",' +
                        '"jobType": "Onsite"' +
                    '}' +
                '}' +
            ']' +
        '}';
    }

    // -----------------------------
    // 1. Happy Path
    // -----------------------------
    @isTest
    static void testCreateJobDescriptions_HappyPath() {

        Service__c serviceRec = [SELECT Id FROM Service__c LIMIT 1];
        String jsonInput = buildValidJson();

        Test.startTest();
        List<String> result = JobDescriptionCreationController.createJobDescriptions(jsonInput, serviceRec.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.size() > 0);

        Account acc = [SELECT Id FROM Account WHERE Name = 'TechCorp Pvt Ltd' LIMIT 1];
        Opportunity opp = [
            SELECT Id, Skills_Required__c, Job_Description__c, Amount,
                   Budget_In_JD__c, Currency_Mentioned_In_JD__c,
                   Original_Budget_Amount__c, Original_Currency__c
            FROM Opportunity 
            WHERE AccountId = :acc.Id 
            LIMIT 1
        ];

        System.assert(opp.Amount > 0);
        System.assert(!String.isBlank(opp.Currency_Mentioned_In_JD__c));
        System.assert(!String.isBlank(opp.Budget_In_JD__c));
    }

    // -----------------------------
    // 2. Invalid JSON
    // -----------------------------
    @isTest
    static void testCreateJobDescriptions_InvalidJson() {
        String badJson = 'invalid json';
        List<String> res = JobDescriptionCreationController.createJobDescriptions(badJson, null);
        System.assertEquals(null, res);
    }

    // -----------------------------
    // 3. Missing jobs key
    // -----------------------------
    @isTest
    static void testCreateJobDescriptions_NoJobsKey() {
        String jsonInput = '{ "wrongKey": [] }';
        List<String> res = JobDescriptionCreationController.createJobDescriptions(jsonInput, null);
        System.assertEquals(null, res);
    }

    // -----------------------------
    // 4. Empty job list
    // -----------------------------
    @isTest
    static void testCreateJobDescriptions_EmptyJobList() {
        String jsonInput = '{ "jobs": [] }';
        List<String> res = JobDescriptionCreationController.createJobDescriptions(jsonInput, null);
        System.assert(res == null || res.isEmpty());
    }

    // -----------------------------
    // 5. Fallback Currency
    // -----------------------------
    @isTest
    static void testCreateJobDescriptions_FallbackCurrency() {
        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        String jsonInput = '{' +
            '"jobs":[{"jobDescription":{' +
                '"companyName":"NoCurrency Corp",' +
                '"opportunityName":"Opp",' +
                '"experience":"2",' +
                '"responsibilities":"No currency mentioned here",' +
                '"skillsRequired":"Apex",' +
                '"budgetMentioned":"1000",' +
                '"currencyMentioned":"EUR"' +
            '}}]}';

        List<String> res = JobDescriptionCreationController.createJobDescriptions(jsonInput, svc.Id);

        Account acc = [SELECT Id FROM Account WHERE Name = 'NoCurrency Corp' LIMIT 1];

        Opportunity opp = [
            SELECT Currency_Mentioned_In_JD__c, Budget_In_JD__c, Amount
            FROM Opportunity WHERE AccountId = :acc.Id LIMIT 1
        ];

        System.assertEquals('EUR', opp.Currency_Mentioned_In_JD__c);
        System.assert(opp.Amount > 0);
    }

    // -----------------------------
    // 6. JD + Role + Skills match
    // -----------------------------
    @isTest
    static void test_JDMatching_FullMatch() {

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        Account acc = new Account(Name = 'TechCorp Pvt Ltd');
        insert acc;

        Opportunity oldOpp = new Opportunity(
            Name = 'Existing',
            AccountId = acc.Id,
            CloseDate = Date.today().addDays(10),
            StageName = 'Prospecting',
            Job_Description__c = 'Develop Apex classes and LWC components',
            Role_Required__c = 'Salesforce Developer',
            Skills_Required__c = 'Apex, LWC, Integration'
        );
        insert oldOpp;

        String jsonInput =
            '{ "jobs":[{"jobDescription":{' +
                '"companyName":"TechCorp Pvt Ltd",' +
                '"opportunityName":"Match",' +
                '"responsibilities":"Develop Apex classes and LWC components",' +
                '"skillsRequired":"Apex, LWC, Integration",' +
                '"title":"Salesforce Developer"' +
            '}}]}';

        List<String> res = JobDescriptionCreationController.createJobDescriptions(jsonInput, svc.Id);

        Integer count = [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(1, count, 'Should reuse existing Opportunity');
    }

    // -----------------------------
    // 7. JD-only match
    // -----------------------------
    @isTest
    static void test_JDMatching_JDOnlyMatch() {

        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        Account acc = new Account(Name = 'TechCorp Pvt Ltd');
        insert acc;

        Opportunity oldOpp = new Opportunity(
            Name = 'Existing JD Only',
            AccountId = acc.Id,
            CloseDate = Date.today().addDays(10),
            StageName = 'Prospecting',
            Job_Description__c = 'Develop Apex classes and LWC components',
            Role_Required__c = 'Different Role',
            Skills_Required__c = 'Something else'
        );
        insert oldOpp;

        String jsonInput =
            '{ "jobs":[{"jobDescription":{' +
                '"companyName":"TechCorp Pvt Ltd",' +
                '"opportunityName":"Match",' +
                '"responsibilities":"Develop Apex classes and LWC components",' +
                '"skillsRequired":"Apex"' +
            '}}]}';

        List<String> res = JobDescriptionCreationController.createJobDescriptions(jsonInput, svc.Id);

        Integer count = [SELECT COUNT() FROM Opportunity WHERE AccountId = :acc.Id];
        System.assertEquals(1, count, 'Should reuse existing Opportunity');
    }
} */