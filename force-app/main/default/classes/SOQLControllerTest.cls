@isTest
private class SOQLControllerTest {
    
    @TestSetup
    static void setupTestData() {
        // Safe profile lookup
        List<Profile> profiles = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        if (profiles.isEmpty()) {
            return;
        }
        
        Profile p = profiles[0];
        String uniqueUsername = 'testuser' + System.currentTimeMillis() + '@test.com';
        
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = uniqueUsername
        );
        insert testUser;
        
        // Create branch safely
        try {
            insert new Branch__c(
                Branch_Name__c = 'Test Branch', 
                City__c = 'Mumbai', 
                State__c = 'MH'
            );
        } catch (Exception e) {
            // Branch might exist or have validation rules
        }
        
        // Create attendance records with safe values
        Id empId = testUser.Id;
        List<Branch__c> branches = [SELECT Id FROM Branch__c WHERE Branch_Name__c = 'Test Branch' LIMIT 1];
        Id branchId = branches.isEmpty() ? null : branches[0].Id;
        
        try {
            insert new Employee_Attendance__c(
                Employee_Name__c = empId,
                Date__c = Date.today(),
                Status__c = 'Present',
                Work_Location__c = 'Work from Office',
                Branch__c = branchId
            );
        } catch (Exception e) {
            // Ignore data creation errors
        }
    }

    // Note: Schema.fields.getMap().keyset() returns LOWERCASE field names
    // So all field names passed to queryRecords must be lowercase

    @isTest 
    static void testValidFieldsNoWhere() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id,name',
            null
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testValidFieldsWithWhere() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id,status__c',
            'status__c != null'
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testTrimmedFields() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            ' id , name ',
            ''
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testEmptyWhereClause() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id',
            ''
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testBlankWhereClause() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id',
            '   '
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testSingleField() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id',
            null
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testMultipleValidFields() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id,date__c,status__c',
            null
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    @isTest 
    static void testCacheablePath() {
        Test.startTest();
        SOQLController.queryRecords('Employee_Attendance__c', 'id', null);
        SOQLController.queryRecords('Employee_Attendance__c', 'id', null);
        Test.stopTest();
    }

    // Test the EXCEPTION path for invalid field - covers throw statement
    @isTest 
    static void testInvalidFieldThrowsException() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SOQLController.queryRecords(
                'Employee_Attendance__c',
                'id,invalidfield__xyz',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid field');
    }

    // Invalid field at the beginning of the list
    @isTest 
    static void testInvalidFieldFirst() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SOQLController.queryRecords(
                'Employee_Attendance__c',
                'fakefield__c,id,name',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid field');
    }

    // Invalid field with spaces (to test trimming logic in validation)
    @isTest 
    static void testInvalidFieldWithSpaces() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            SOQLController.queryRecords(
                'Employee_Attendance__c',
                'id, notafield__c ',
                null
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        
        System.assertEquals(true, exceptionThrown, 'Exception should be thrown for invalid field');
    }

    // Test with actual WHERE clause that returns records
    @isTest 
    static void testValidWhereClauseReturnsRecords() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Employee_Attendance__c',
            'id,name,status__c',
            'id != null'
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }

    // Test using Account (standard object)
    @isTest 
    static void testWithStandardObject() {
        Test.startTest();
        List<SObject> results = SOQLController.queryRecords(
            'Account',
            'id,name',
            null
        );
        Test.stopTest();
        System.assertNotEquals(null, results);
    }
}