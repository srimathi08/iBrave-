@isTest
private class AttendanceControllerTest {

    // ─────────────────────────────────────────────
    // Test Data Factory
    // ─────────────────────────────────────────────

    private static Attendance_Record__c createAttendanceRecord(
        String userId,
        Boolean isActive,
        String status,
        DateTime checkInTime,
        DateTime checkOutTime
    ) {
        Attendance_Record__c record = new Attendance_Record__c();
        record.User__c            = userId;
        record.Date__c            = Date.today();
        record.Is_Active__c       = isActive;
        record.Status__c          = status;
        record.Check_In_Time__c   = checkInTime;
        record.Check_Out_Time__c  = checkOutTime;
        // Short addresses to avoid STRING_TOO_LONG errors
        record.Check_In_Address__c  = 'HQ';
        record.Check_Out_Address__c = checkOutTime != null ? 'HQ' : null;

        if (checkOutTime != null && checkInTime != null) {
            Long diffMs = checkOutTime.getTime() - checkInTime.getTime();
            record.Total_Hours__c = (Decimal.valueOf(diffMs) / (1000 * 60 * 60)).setScale(2);
        }

        insert record;
        return record;
    }

    // ─────────────────────────────────────────────
    // getCurrentAttendanceStatus — no active session
    // ─────────────────────────────────────────────

    @isTest
    static void testGetCurrentAttendanceStatus_NoActiveSession() {
        Test.startTest();
        Map<String, Object> result = AttendanceController.getCurrentAttendanceStatus();
        Test.stopTest();

        System.assertEquals(false, result.get('hasActiveSession'), 'hasActiveSession should be false');
        System.assertEquals(false, result.get('isCheckedIn'),      'isCheckedIn should be false');
    }

    // ─────────────────────────────────────────────
    // getCurrentAttendanceStatus — active "Checked In"
    // ─────────────────────────────────────────────

    @isTest
    static void testGetCurrentAttendanceStatus_ActiveCheckedIn() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, true, 'Checked In', System.now().addHours(-2), null);

        Test.startTest();
        Map<String, Object> result = AttendanceController.getCurrentAttendanceStatus();
        Test.stopTest();

        System.assertEquals(true, result.get('hasActiveSession'), 'Should have active session');
        System.assertEquals(true, result.get('isCheckedIn'),      'Should be checked in');
        System.assertNotEquals(null, result.get('elapsedSeconds'), 'elapsedSeconds should be populated');
        Long elapsed = (Long) result.get('elapsedSeconds');
        System.assert(elapsed > 0, 'Elapsed seconds should be positive');
    }

    // ─────────────────────────────────────────────
    // getCurrentAttendanceStatus — active "Checked Out"
    // ─────────────────────────────────────────────

    @isTest
    static void testGetCurrentAttendanceStatus_ActiveCheckedOut() {
        String userId = UserInfo.getUserId();
        Attendance_Record__c activeOut = new Attendance_Record__c(
            User__c          = userId,
            Date__c          = Date.today(),
            Is_Active__c     = true,
            Status__c        = 'Checked Out',
            Check_In_Time__c = System.now().addHours(-4)
        );
        insert activeOut;

        Test.startTest();
        Map<String, Object> result = AttendanceController.getCurrentAttendanceStatus();
        Test.stopTest();

        System.assertEquals(true,  result.get('hasActiveSession'), 'Should have active session');
        System.assertEquals(false, result.get('isCheckedIn'),      'Should NOT be checked in');
        System.assertEquals(null,  result.get('elapsedSeconds'),   'elapsedSeconds should be null');
    }

    // ─────────────────────────────────────────────
    // checkIn — success
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckIn_Success() {
        Test.startTest();
        Map<String, Object> result = AttendanceController.checkIn(37.7749, -122.4194, 'HQ', null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'checkIn should succeed');
        System.assertEquals('Successfully checked in', result.get('message'));
        System.assertNotEquals(null, result.get('attendanceRecord'), 'attendanceRecord should be returned');
    }

    // ─────────────────────────────────────────────
    // checkIn — without location
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckIn_NoLocation() {
        Test.startTest();
        Map<String, Object> result = AttendanceController.checkIn(null, null, null, null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'checkIn without location should succeed');
    }

    // ─────────────────────────────────────────────
    // checkIn — with image
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckIn_WithImage() {
        ContentVersion cv = new ContentVersion(
            Title          = 'CheckInImg',
            PathOnClient   = 'CheckInImg.png',
            VersionData    = Blob.valueOf('img'),
            IsMajorVersion = true
        );
        insert cv;
        String imageId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        Test.startTest();
        Map<String, Object> result = AttendanceController.checkIn(37.7749, -122.4194, 'HQ', imageId);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'checkIn with image should succeed');
    }

    // ─────────────────────────────────────────────
    // checkIn — duplicate active session (exception)
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckIn_AlreadyCheckedIn() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, true, 'Checked In', System.now().addHours(-1), null);

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AttendanceController.checkIn(37.7749, -122.4194, 'HQ', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown for duplicate check-in');
    }

    // ─────────────────────────────────────────────
    // checkOut — success
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckOut_Success() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, true, 'Checked In', System.now().addHours(-3), null);

        Test.startTest();
        Map<String, Object> result = AttendanceController.checkOut(37.7749, -122.4194, 'HQ', null);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'checkOut should succeed');
        System.assertEquals('Successfully checked out', result.get('message'));
        System.assertNotEquals(null, result.get('attendanceRecord'), 'attendanceRecord should be returned');
    }

    // ─────────────────────────────────────────────
    // checkOut — with image, no location
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckOut_WithImageNoLocation() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, true, 'Checked In', System.now().addHours(-2), null);

        ContentVersion cv = new ContentVersion(
            Title          = 'CheckOutImg',
            PathOnClient   = 'CheckOutImg.png',
            VersionData    = Blob.valueOf('img'),
            IsMajorVersion = true
        );
        insert cv;
        String imageId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1].ContentDocumentId;

        Test.startTest();
        Map<String, Object> result = AttendanceController.checkOut(null, null, 'Remote', imageId);
        Test.stopTest();

        System.assertEquals(true, result.get('success'), 'checkOut with image should succeed');
    }

    // ─────────────────────────────────────────────
    // checkOut — no active session (exception)
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckOut_NoActiveSession() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            AttendanceController.checkOut(37.7749, -122.4194, 'HQ', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown when no active session exists');
    }

    // ─────────────────────────────────────────────
    // checkOut — total hours calculation
    // ─────────────────────────────────────────────

    @isTest
    static void testCheckOut_TotalHoursCalculation() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, true, 'Checked In', System.now().addHours(-8), null);

        Test.startTest();
        Map<String, Object> result = AttendanceController.checkOut(37.7749, -122.4194, 'HQ', null);
        Test.stopTest();

        Attendance_Record__c updated = (Attendance_Record__c) result.get('attendanceRecord');
        System.assertNotEquals(null, updated.Total_Hours__c, 'Total_Hours__c should be set');
        System.assert(updated.Total_Hours__c > 0, 'Total hours should be positive');
    }

    // ─────────────────────────────────────────────
    // getAttendanceHistory — with records
    // ─────────────────────────────────────────────

    @isTest
    static void testGetAttendanceHistory_WithRecords() {
        String userId = UserInfo.getUserId();
        createAttendanceRecord(userId, false, 'Checked Out', System.now().addHours(-5), System.now().addHours(-1));
        createAttendanceRecord(userId, true,  'Checked In',  System.now().addHours(-1), null);

        Test.startTest();
        List<Map<String, Object>> history = AttendanceController.getAttendanceHistory(10);
        Test.stopTest();

        System.assert(history.size() >= 2, 'Should return at least 2 records');
        Map<String, Object> first = history[0];
        System.assertNotEquals(null, first.get('Id'),          'Id should be present');
        System.assertNotEquals(null, first.get('Date'),        'Date should be present');
        System.assertNotEquals(null, first.get('CheckInTime'), 'CheckInTime should be present');
        System.assertNotEquals(null, first.get('Status'),      'Status should be present');
    }

    // ─────────────────────────────────────────────
    // getAttendanceHistory — empty
    // ─────────────────────────────────────────────

    @isTest
    static void testGetAttendanceHistory_Empty() {
        Test.startTest();
        List<Map<String, Object>> history = AttendanceController.getAttendanceHistory(5);
        Test.stopTest();

        System.assertNotEquals(null, history, 'Result should not be null');
        System.assertEquals(0, history.size(), 'Should be empty when no records exist');
    }

    // ─────────────────────────────────────────────
    // getAttendanceHistory — limit respected
    // ─────────────────────────────────────────────

    @isTest
    static void testGetAttendanceHistory_LimitRespected() {
        String userId = UserInfo.getUserId();
        for (Integer i = 0; i < 5; i++) {
            Attendance_Record__c r = new Attendance_Record__c(
                User__c           = userId,
                Date__c           = Date.today().addDays(-i),
                Is_Active__c      = false,
                Status__c         = 'Checked Out',
                Check_In_Time__c  = System.now().addHours(-(i + 5)),
                Check_Out_Time__c = System.now().addHours(-(i + 1))
            );
            insert r;
        }

        Test.startTest();
        List<Map<String, Object>> history = AttendanceController.getAttendanceHistory(3);
        Test.stopTest();

        System.assert(history.size() <= 3, 'Result count should respect the limit of 3');
    }

    // ─────────────────────────────────────────────
    // getUserDetails
    // ─────────────────────────────────────────────

    @isTest
    static void testGetUserDetails() {
        Test.startTest();
        User u = AttendanceController.getUserDetails();
        Test.stopTest();

        System.assertNotEquals(null, u,       'User should not be null');
        System.assertNotEquals(null, u.Name,  'Name should be populated');
        System.assertNotEquals(null, u.Email, 'Email should be populated');
    }

    // ─────────────────────────────────────────────
    // Full flow: checkIn → status → checkOut → history
    // ─────────────────────────────────────────────

    @isTest
    static void testFullAttendanceFlow() {
        Test.startTest();

        // 1. Check in
        Map<String, Object> checkInResult = AttendanceController.checkIn(37.7749, -122.4194, 'HQ', null);
        System.assertEquals(true, checkInResult.get('success'), 'Check-in should succeed');

        // 2. Status
        Map<String, Object> status = AttendanceController.getCurrentAttendanceStatus();
        System.assertEquals(true, status.get('hasActiveSession'), 'Active session should exist');
        System.assertEquals(true, status.get('isCheckedIn'),      'Should be checked in');

        // 3. Check out
        Map<String, Object> checkOutResult = AttendanceController.checkOut(37.7750, -122.4195, 'Lobby', null);
        System.assertEquals(true, checkOutResult.get('success'), 'Check-out should succeed');

        // 4. History
        List<Map<String, Object>> history = AttendanceController.getAttendanceHistory(5);
        System.assert(history.size() >= 1, 'History should have at least one record');

        Test.stopTest();
    }
}