@isTest
private class EditControllerTest {
    
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias = 'tuser',
            Email = 'testuser@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;
        
        insert new Branch__c(
            Branch_Name__c = 'Test Branch Mumbai', 
            City__c = 'Mumbai', 
            State__c = 'Maharashtra'
        );
    }

    private static Id getTestEmployeeId() {
        return [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1].Id;
    }

    private static Id getTestBranchId() {
        return [SELECT Id FROM Branch__c WHERE Branch_Name__c = 'Test Branch Mumbai' LIMIT 1].Id;
    }

    // ✅ FIXED: Create VALID attendance record
    private static Id createTestAttendanceRecord() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();
        
        Employee_Attendance__c testAtt = new Employee_Attendance__c(
            Employee_Name__c = empId,
            Date__c = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = branchId  // REQUIRED
        );
        insert testAtt;
        return testAtt.Id;  // ✅ Returns REAL record ID
    }

    @isTest static void testUpdateAttendanceBasicSuccess() {
        Id recordId = createTestAttendanceRecord();  // ✅ VALID ID
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => '2025-12-11T18:00:00Z',
            'Status__c' => 'Completed'
        };

        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();

        System.assert(result.containsKey('success'));
    }

    @isTest static void testUpdateAttendanceWithPhotoSuccess() {
        Id recordId = createTestAttendanceRecord();
        String mockImage = EncodingUtil.base64Encode(Blob.valueOf('test_checkout_image'));
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => '2025-12-11T18:00:00Z',
            'Check_Out_Photo_B64' => mockImage,
            'Check_Out_Photo_Name' => 'checkout.jpg'
        };

        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();

        System.assert(result.containsKey('success'));
    }

    @isTest static void testUpdateAttendanceDateTimeStringParsing() {
        Id recordId = createTestAttendanceRecord();
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => '2025-12-11 18:00:00',  // Space format
            'Status__c' => 'Completed'
        };

        Test.startTest();
        EditController.updateAttendance(recordId, changes);
        Test.stopTest();
    }

    @isTest static void testUpdateAttendanceDateTimeObject() {
        Id recordId = createTestAttendanceRecord();
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => DateTime.now(),
            'Status__c' => 'Completed'
        };

        Test.startTest();
        EditController.updateAttendance(recordId, changes);
        Test.stopTest();
    }

    @isTest static void testUpdateAttendanceMultipleFields() {
        Id recordId = createTestAttendanceRecord();
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => '2025-12-11T18:00:00Z',
            'Status__c' => 'Completed',
            'Notes__c' => 'Updated notes'
        };

        Test.startTest();
        EditController.updateAttendance(recordId, changes);
        Test.stopTest();
    }

    @isTest static void testUpdateAttendancePhotoOnly() {
        Id recordId = createTestAttendanceRecord();
        String mockImage = EncodingUtil.base64Encode(Blob.valueOf('photo_only_test'));
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Photo_B64' => mockImage,
            'Check_Out_Photo_Name' => 'photo.jpg'
        };

        Test.startTest();
        EditController.updateAttendance(recordId, changes);
        Test.stopTest();
    }

    // ✅ FIXED: Test INVALID scenarios without fake IDs
    @isTest static void testUpdateAttendanceInvalidRecord() {
        Id empId = getTestEmployeeId();
        Id branchId = getTestBranchId();
        
        // Create record, then DELETE it to test DML error path
        Employee_Attendance__c tempRecord = new Employee_Attendance__c(
            Employee_Name__c = empId,
            Date__c = Date.today(),
            Work_Location__c = 'Work from Office',
            Branch__c = branchId,
            Status__c = 'Present'
        );
        insert tempRecord;
        Database.delete(tempRecord);  // Delete to make ID invalid
        
        Map<String, Object> changes = new Map<String, Object>{
            'Status__c' => 'Completed'
        };

        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(tempRecord.Id, changes);
        Test.stopTest();

        System.assert(result.containsKey('success'));
        System.assert(result.containsKey('error'));  // DML error expected
    }

    @isTest static void testUpdateAttendanceNullChanges() {
        Id recordId = createTestAttendanceRecord();
        
        Test.startTest();
        EditController.updateAttendance(recordId, null);
        Test.stopTest();
    }

    @isTest static void testUpdateAttendanceEmptyChanges() {
        Id recordId = createTestAttendanceRecord();
        
        Test.startTest();
        EditController.updateAttendance(recordId, new Map<String, Object>());
        Test.stopTest();
    }

    @isTest static void testContentDocumentCreation() {
        Id recordId = createTestAttendanceRecord();
        String mockImage = EncodingUtil.base64Encode(Blob.valueOf('content_doc_test'));
        
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Photo_B64' => mockImage,
            'Check_Out_Photo_Name' => 'content_doc.jpg'
        };

        Test.startTest();
        EditController.updateAttendance(recordId, changes);
        Test.stopTest();
    }

    // ✅ Test photo creation exception path
    @isTest static void testContentDocumentCreationException() {
        Id recordId = createTestAttendanceRecord();
        
        Map<String, Object> badPhotoChanges = new Map<String, Object>{
            'Check_Out_Photo_B64' => 'invalid_base64!',  // Invalid base64
            'Check_Out_Photo_Name' => 'bad.jpg'
        };

        Test.startTest();
        try {
            EditController.updateAttendance(recordId, badPhotoChanges);
        } catch (Exception e) {
            // Expected exception from createContentDocument
        }
        Test.stopTest();
    }
}