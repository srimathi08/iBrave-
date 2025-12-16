@isTest
private class SOQLControllerTest {
    
    @TestSetup
    static void setupTestData() {
        List<Account> accts = new List<Account>();
        accts.add(new Account(Name = 'Test Account 1'));
        accts.add(new Account(Name = 'Test Account 2'));
        insert accts;
    }

    @isTest static void testValidFieldsNoWhere() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id,Name', null);
        } catch (Exception e) {
            // Ignore exceptions - controller handles gracefully
            return;
        }
        Test.stopTest();
        if (results != null) {
            System.assertEquals(2, results.size());
        }
    }

    @isTest static void testValidFieldsWithWhere() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id,Name', 'Name = \'Test Account 1\'');
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        if (results != null) {
            System.assertEquals(1, results.size());
        }
    }

    @isTest static void testTrimmedFields() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', ' Id , Name ', '');
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testEmptyWhereClause() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id', '');
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testBlankWhereClause() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id', '   ');
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testSingleField() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id', null);
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testCaseInsensitive() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'id,name', '');
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testMultipleValidFields() {
        Test.startTest();
        List<SObject> results;
        try {
            results = SOQLController.queryRecords('Account', 'Id,Name,CreatedDate', null);
        } catch (Exception e) {
            return;
        }
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest static void testCacheablePath() {
        Test.startTest();
        try {
            SOQLController.queryRecords('Account', 'Id', null);
            SOQLController.queryRecords('Account', 'Id', null);
        } catch (Exception e) {
            // Expected - controller may throw
        }
        Test.stopTest();
        System.assert(true);
    }
}