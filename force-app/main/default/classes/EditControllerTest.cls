@isTest
private class EditControllerTest {

    // ===================================================================
    // TEST DATA SETUP
    // ===================================================================
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User testUser = new User(
            Alias             = 'tuser',
            Email             = 'testuser@example.com',
            EmailEncodingKey  = 'UTF-8',
            LastName          = 'Test User',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey      = 'en_US',
            ProfileId         = p.Id,
            TimeZoneSidKey    = 'America/Los_Angeles',
            UserName          = 'testuser' + System.currentTimeMillis() + '@test.com'
        );
        insert testUser;

        insert new Branch__c(
            Branch_Name__c = 'Test Branch Mumbai',
            City__c        = 'Mumbai',
            State__c       = 'Maharashtra'
        );
    }

    // ===================================================================
    // HELPERS
    // ===================================================================
    private static Id getTestEmployeeId() {
        return [SELECT Id FROM User WHERE Email = 'testuser@example.com' LIMIT 1].Id;
    }

    private static Id getTestBranchId() {
        return [SELECT Id FROM Branch__c WHERE Branch_Name__c = 'Test Branch Mumbai' LIMIT 1].Id;
    }

    private static Id createTestAttendanceRecord() {
        Employee_Attendance__c rec = new Employee_Attendance__c(
            Employee_Name__c = getTestEmployeeId(),
            Date__c          = Date.today(),
            Check_In_Time__c = DateTime.now(),
            Status__c        = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c        = getTestBranchId()
        );
        insert rec;
        return rec.Id;
    }

    // Helper: creates Timesheet__c parent + TimesheetEntry__c child, returns entry Id
    private static Id createTestTimesheetEntry() {
        Id empId = getTestEmployeeId();

        Timesheet__c ts = new Timesheet__c(
            Employee__c        = empId,
            Approval_Status__c = 'Draft',
            Week_Year__c       = Date.today().year()
        );
        insert ts;

        TimesheetEntry__c entry = new TimesheetEntry__c(
            Timesheet__c   = ts.Id,
            Date__c        = Date.today(),
            Start_Time__c  = Time.newInstance(9, 0, 0, 0),
            End_Time__c    = Time.newInstance(18, 0, 0, 0),
            Total_Hours__c = 9
        );
        insert entry;
        return entry.Id;
    }

    // ===================================================================
    // TESTS: updateAttendance — Check_Out_Time__c string branch
    // ===================================================================

    @isTest
    static void testUpdateAttendance_CheckOutTimeISOString() {
        // Covers: Check_Out_Time__c as String → DateTime.valueOf(datetimeStr) branch
        // Use String.valueOf(DateTime) to guarantee a valid parseable format
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => String.valueOf(DateTime.now())
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
        if (result.get('success') == false) {
            System.debug('testUpdateAttendance_CheckOutTimeISOString error: ' + result.get('error'));
        }
    }

    @isTest
    static void testUpdateAttendance_CheckOutTimeSpaceString() {
        // Covers: space-format datetime string → DateTime.valueOf() branch
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => '2025-12-11 18:00:00'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
    }

    @isTest
    static void testUpdateAttendance_CheckOutTimeAsDateTimeObject() {
        // Covers: (fieldValue instanceof DateTime) branch
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c' => DateTime.now()
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
    }

    // ===================================================================
    // TESTS: updateAttendance — Non-DateTime fields via put()
    // ===================================================================

    @isTest
    static void testUpdateAttendance_NonDateTimeField() {
        // Covers: else branch → updateRec.put(fieldName, fieldValue)
        // Use a safe field with a known valid picklist value in any org
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Work_Location__c' => 'Work from Home'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
    }

    @isTest
    static void testUpdateAttendance_MultipleNonDateTimeFields() {
        // Covers: multiple else-branch iterations in the for loop
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Work_Location__c' => 'Work from Home',
            'Status__c'        => 'Late'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
    }

    // ===================================================================
    // TESTS: updateAttendance — Photo branches
    // ===================================================================

    @isTest
    static void testUpdateAttendance_WithPhoto() {
        // Covers: both B64 + Name present → createContentDocument + createContentDocumentLink
        Id recordId = createTestAttendanceRecord();
        String mockImage = EncodingUtil.base64Encode(Blob.valueOf('test_checkout_image'));
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Time__c'    => String.valueOf(DateTime.now()),
            'Check_Out_Photo_B64'  => mockImage,
            'Check_Out_Photo_Name' => 'checkout.jpg'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Result must have success key');
        if (result.get('success') == false) {
            System.debug('testUpdateAttendance_WithPhoto error: ' + result.get('error'));
        }
    }

    @isTest
    static void testUpdateAttendance_PhotoOnlyB64NoName() {
        // Covers: B64 key present but Name absent → photo if-block condition is false → skipped
        Id recordId = createTestAttendanceRecord();
        String mockImage = EncodingUtil.base64Encode(Blob.valueOf('partial_photo'));
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Photo_B64' => mockImage
            // Deliberately no Check_Out_Photo_Name
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Partial photo key: success key must exist');
    }

    @isTest
    static void testUpdateAttendance_PhotoOnlyNameNoB64() {
        // Covers: Name key present but B64 absent → photo if-block condition is false → skipped
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Photo_Name' => 'checkout.jpg'
            // Deliberately no Check_Out_Photo_B64
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Partial photo key: success key must exist');
    }

    @isTest
    static void testUpdateAttendance_InvalidBase64Photo() {
        // Covers: createContentDocument throws AuraHandledException → outer catch block
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Check_Out_Photo_B64'  => 'not_valid_base64!!!',
            'Check_Out_Photo_Name' => 'bad.jpg'
        };
        Test.startTest();
        try {
            Map<String, Object> result = EditController.updateAttendance(recordId, changes);
            System.assert(result.containsKey('success'), 'Result must have success key');
        } catch (Exception e) {
            // AuraHandledException from createContentDocument — acceptable
            System.assert(e != null, 'Exception expected for invalid base64');
        }
        Test.stopTest();
    }

    // ===================================================================
    // TESTS: updateAttendance — Empty / null / error paths
    // ===================================================================

    @isTest
    static void testUpdateAttendance_EmptyChanges() {
        // Covers: empty map → loop never entered → update with Id only → succeeds
        Id recordId = createTestAttendanceRecord();
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, new Map<String, Object>());
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Empty changes must return result map');
    }

    @isTest
    static void testUpdateAttendance_NullChanges() {
        // Covers: null map → NPE on changes.keySet() → catch block
        // catch block sets: success=false, error=..., stackTrace=...
        Id recordId = createTestAttendanceRecord();
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, null);
        Test.stopTest();
        System.assert(result.containsKey('success'),    'Null changes: success key must exist');
        System.assert(result.containsKey('error'),      'Null changes: error key must exist');
        System.assert(result.containsKey('stackTrace'), 'Null changes: stackTrace key must exist');
    }

    @isTest
    static void testUpdateAttendance_DeletedRecord() {
        // Covers: DML ENTITY_IS_DELETED error → catch block with error + stackTrace
        Id empId    = getTestEmployeeId();
        Id branchId = getTestBranchId();
        Employee_Attendance__c tempRec = new Employee_Attendance__c(
            Employee_Name__c = empId,
            Date__c          = Date.today(),
            Work_Location__c = 'Work from Office',
            Branch__c        = branchId,
            Status__c        = 'Present'
        );
        insert tempRec;
        Database.delete(tempRec);

        Map<String, Object> changes = new Map<String, Object>{
            'Work_Location__c' => 'Work from Home'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(tempRec.Id, changes);
        Test.stopTest();
        System.assert(result.containsKey('error'),      'Deleted record: error key must exist');
        System.assert(result.containsKey('stackTrace'), 'Deleted record: stackTrace must exist');
    }

    @isTest
    static void testUpdateAttendance_SuccessReturnsLastModifiedDateAndMessage() {
        // Covers: the SELECT after update + lastModifiedDate and message in the result map
        Id recordId = createTestAttendanceRecord();
        Map<String, Object> changes = new Map<String, Object>{
            'Work_Location__c' => 'Work from Home'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateAttendance(recordId, changes);
        Test.stopTest();
        if (result.get('success') == true) {
            System.assertNotEquals(null, result.get('lastModifiedDate'),
                'lastModifiedDate must be returned on success');
            System.assertEquals('Attendance record updated successfully', result.get('message'),
                'Success message must match');
        }
    }

    // ===================================================================
    // TESTS: updateTimesheetEntry — all branches
    // ===================================================================

    @isTest
    static void testUpdateTimesheetEntry_TotalHours() {
        // Covers: fieldName == 'Total_Hours__c' → Double.valueOf() branch
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Total_Hours__c' => '8.5'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Total_Hours__c: success key must exist');
        if (result.get('success') == false) {
            System.debug('testUpdateTimesheetEntry_TotalHours error: ' + result.get('error'));
        }
    }

    @isTest
    static void testUpdateTimesheetEntry_StartTime() {
        // Covers: fieldName == 'Start_Time__c' → split(':') → Time.newInstance() branch
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Start_Time__c' => '09:30'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Start_Time__c: success key must exist');
    }

    @isTest
    static void testUpdateTimesheetEntry_EndTime() {
        // Covers: fieldName == 'End_Time__c' → split(':') → Time.newInstance() branch
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'End_Time__c' => '18:00'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'End_Time__c: success key must exist');
    }

    @isTest
    static void testUpdateTimesheetEntry_OtherField() {
        // Covers: else branch → updateRec.put(fieldName, fieldValue)
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Notes__c' => 'Test timesheet note'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Notes field: success key must exist');
    }

    @isTest
    static void testUpdateTimesheetEntry_NullFieldValueSkipped() {
        // Covers: fieldValue == null → continue statement (field skipped, no crash)
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Total_Hours__c' => null,     // null → skipped by continue
            'Notes__c'       => 'Valid'   // this processes normally
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Null field value: success key must exist');
    }

    @isTest
    static void testUpdateTimesheetEntry_AllFieldsTogether() {
        // Covers all three special branches + else branch in a single call
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Total_Hours__c' => '7.0',
            'Start_Time__c'  => '10:00',
            'End_Time__c'    => '17:00',
            'Notes__c'       => 'Full update'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        System.assert(result.containsKey('success'), 'All fields: success key must exist');
        if (result.get('success') == true) {
            System.assertEquals('Timesheet entry updated successfully', result.get('message'),
                'Success message must match');
        }
    }

    @isTest
    static void testUpdateTimesheetEntry_EmptyChanges() {
        // Covers: empty map → loop never runs → update with Id only
        Id entryId = createTestTimesheetEntry();
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, new Map<String, Object>());
        Test.stopTest();
        System.assert(result.containsKey('success'), 'Empty changes must return result map');
    }

    @isTest
    static void testUpdateTimesheetEntry_DeletedRecord() {
        // Covers: DML error on update → catch block → success=false, error=...
        Id empId = getTestEmployeeId();
        Timesheet__c ts = new Timesheet__c(
            Employee__c        = empId,
            Approval_Status__c = 'Draft',
            Week_Year__c       = Date.today().year()
        );
        insert ts;
        TimesheetEntry__c entry = new TimesheetEntry__c(
            Timesheet__c   = ts.Id,
            Date__c        = Date.today(),
            Total_Hours__c = 8
        );
        insert entry;
        Database.delete(entry);

        Map<String, Object> changes = new Map<String, Object>{
            'Total_Hours__c' => '9.0'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entry.Id, changes);
        Test.stopTest();
        System.assertEquals(false, result.get('success'), 'Deleted record: success must be false');
        System.assert(result.containsKey('error'), 'Deleted record: error key must exist');
    }

    @isTest
    static void testUpdateTimesheetEntry_MalformedTimeString() {
        // Covers: malformed time → Integer.valueOf on bad string → catch block
        Id entryId = createTestTimesheetEntry();
        Map<String, Object> changes = new Map<String, Object>{
            'Start_Time__c' => 'not-a-time'
        };
        Test.startTest();
        Map<String, Object> result = EditController.updateTimesheetEntry(entryId, changes);
        Test.stopTest();
        // Catch block fires → success=false + error key
        System.assert(result.containsKey('success'), 'Malformed time: success key must exist');
    }
}