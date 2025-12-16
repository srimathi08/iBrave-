@isTest
private class DMLManagerTest {

    /* =====================================================
       TEST SETUP
    ====================================================== */
    @testSetup
    static void setupData() {
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 10; i++) {
            accounts.add(new Account(
                Name = 'Test Account ' + i,
                Industry = 'Technology'
            ));
        }
        insert accounts;
    }

    /* =====================================================
       INSERT RECORDS
    ====================================================== */
    @isTest
    static void testInsertRecords_Success() {
        List<Account> accs = new List<Account>{
            new Account(Name = 'Insert One'),
            new Account(Name = 'Insert Two')
        };

        Test.startTest();
        List<Id> ids = DMLManager.insertRecords(accs);
        Test.stopTest();

        System.assertEquals(2, ids.size());
    }

    @isTest
    static void testInsertRecords_Exception() {
        try {
            Test.startTest();
            DMLManager.insertRecords(
                new List<Account>{ new Account() } // Name missing
            );
            Test.stopTest();
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    /* =====================================================
       UPDATE RECORDS
    ====================================================== */
    @isTest
    static void testUpdateRecords_Success() {
        List<Account> accs = [SELECT Id, Name FROM Account LIMIT 2];
        for (Account a : accs) {
            a.Name += ' Updated';
        }

        Test.startTest();
        Boolean result = DMLManager.updateRecords(accs);
        Test.stopTest();

        System.assertEquals(true, result);
    }

    @isTest
    static void testUpdateRecords_Exception() {
        Account acc = [SELECT Id, Name FROM Account LIMIT 1];
        acc.Name = null; // Required field violation

        try {
            Test.startTest();
            DMLManager.updateRecords(new List<Account>{ acc });
            Test.stopTest();
            System.assert(false, 'Exception expected');
        } catch (AuraHandledException e) {
            System.assertNotEquals(null, e.getMessage());
        }
    }

    /* =====================================================
       UPSERT RECORDS
    ====================================================== */
    @isTest
    static void testUpsertRecords_Success() {
        List<Account> accs = [SELECT Id, Name FROM Account LIMIT 1];
        accs.add(new Account(Name = 'Upsert New'));

        Test.startTest();
        List<Id> ids = DMLManager.upsertRecords(accs);
        Test.stopTest();

        System.assertEquals(2, ids.size());
    }

    /* =====================================================
       DELETE RECORDS
    ====================================================== */
    @isTest
    static void testDeleteRecords_Success() {
        List<Account> accs = [SELECT Id FROM Account LIMIT 2];

        Test.startTest();
        Boolean result = DMLManager.deleteRecords(accs);
        Test.stopTest();

        System.assertEquals(true, result);
    }

    /* =====================================================
       SAFE DELETE
    ====================================================== */
    @isTest
    static void testSafeDelete_Failure() {
        Account fake = new Account(
            Id = Account.SObjectType.getDescribe().getKeyPrefix() + '000000000000'
        );

        Test.startTest();
        Boolean result = DMLManager.safeDelete(new List<Account>{ fake });
        Test.stopTest();

        System.assertEquals(false, result);
    }

    /* =====================================================
       INSERT WITH RESULTS (PARTIAL SUCCESS)
    ====================================================== */
    @isTest
    static void testInsertWithResults_PartialSuccess() {
        List<Account> accs = new List<Account>{
            new Account(Name = 'Valid'),
            new Account(), // Invalid
            new Account(Name = 'Valid 2')
        };

        Test.startTest();
        Database.SaveResult[] results =
            DMLManager.insertRecordsWithResults(accs, false);
        Test.stopTest();

        System.assertEquals(3, results.size());

        Integer failCount = 0;
        for (Database.SaveResult sr : results) {
            if (!sr.isSuccess()) {
                failCount++;
                System.assert(sr.getErrors().size() > 0);
            }
        }

        System.assertEquals(1, failCount);
    }

    /* =====================================================
       UPDATE WITH RESULTS (NO DUPLICATE IDS – FIXED)
    ====================================================== */
    @isTest
    static void testUpdateWithResults_PartialSuccess() {

        // Get TWO DIFFERENT real records
        List<Account> accs = [
            SELECT Id, Name
            FROM Account
            LIMIT 2
        ];

        // First record – valid update
        accs[0].Name = accs[0].Name + ' Updated';

        // Second record – invalid update (same record, required field missing)
        accs[1].Name = null;

        Test.startTest();
        Database.SaveResult[] results =
            DMLManager.updateRecordsWithResults(accs, false);
        Test.stopTest();

        System.assertEquals(2, results.size());

        Integer successCount = 0;
        Integer failureCount = 0;

        for (Database.SaveResult sr : results) {
            if (sr.isSuccess()) {
                successCount++;
            } else {
                failureCount++;
                System.assert(sr.getErrors().size() > 0);
            }
        }

        System.assertEquals(1, successCount);
        System.assertEquals(1, failureCount);
    }

    /* =====================================================
       NULL INPUT SAFETY
    ====================================================== */
    @isTest
    static void testNullInputs() {
        System.assertEquals(0, DMLManager.insertRecords(null).size());
        System.assertEquals(false, DMLManager.updateRecords(null));
        System.assertEquals(0, DMLManager.upsertRecords(null).size());
        System.assertEquals(false, DMLManager.deleteRecords(null));
        System.assertEquals(false, DMLManager.safeDelete(null));
        System.assertEquals(0,
            DMLManager.insertRecordsWithResults(null, false).size());
        System.assertEquals(0,
            DMLManager.updateRecordsWithResults(null, false).size());
    }
}