/**
 * @description Test class for AutoCheckoutBatch
 * Coverage target: 95%+
 * FIXED: Uses existing org user instead of creating new User (avoids picklist errors)
 */
@isTest
private class AutoCheckoutBatchTest {

    // ── Use existing active user — no User insert needed ──────────
    private static User getTestUser() {
        return AutoCheckoutTestDataFactory.getExistingUser();
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 1: Happy path — single open record gets checked out
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testSingleOpenRecordGetsCheckedOut() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createOpenAttendance(u.Id);
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Check_Out_Time__c, Notes__c
            FROM   Employee_Attendance__c
            WHERE  Id = :att.Id
        ];

        System.assertNotEquals(null, updated.Check_Out_Time__c,
            'Check_Out_Time__c should be set by auto-checkout');
        DateTime expectedOut = DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 0, 0));
        System.assertEquals(expectedOut, updated.Check_Out_Time__c,
            'Checkout time should be 11:59 PM');
        System.assert(updated.Notes__c.contains('[AUTO CHECKOUT]'),
            'Notes should contain [AUTO CHECKOUT] tag');
        System.assert(updated.Notes__c.contains('11:59 PM'),
            'Notes should mention 11:59 PM');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 2: Record with null Notes__c — no throw, note appended
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testNullNotesHandledGracefully() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createOpenAttendanceNoNotes(u.Id);
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Notes__c, Check_Out_Time__c
            FROM   Employee_Attendance__c
            WHERE  Id = :att.Id
        ];
        System.assertNotEquals(null, updated.Check_Out_Time__c,
            'Checkout should be set even when original Notes was null');
        System.assert(updated.Notes__c.contains('[AUTO CHECKOUT]'),
            'Auto-checkout note should be present');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 3: Already checked-out record — must NOT be modified
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testAlreadyCheckedOutRecordNotModified() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createCheckedOutAttendance(u.Id);
        insert att;
        DateTime originalCheckout = att.Check_Out_Time__c;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c unchanged = [
            SELECT Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assertEquals(originalCheckout, unchanged.Check_Out_Time__c,
            'Already-checked-out record should NOT be modified');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 4: Past-date record — must NOT be modified
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testPastDateRecordNotModified() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createPastDateAttendance(u.Id);
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c unchanged = [
            SELECT Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assertEquals(null, unchanged.Check_Out_Time__c,
            'Past date records should not be touched');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 5: No open records — batch finishes gracefully
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testNoOpenRecordsToday() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createCheckedOutAttendance(u.Id);
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch should finish without errors when no open records');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 6: Bulk test — 50 open records processed correctly
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testBulkOpenRecords() {
        User u = getTestUser();

        Employee_Attendance__c[] bulkRecords = new Employee_Attendance__c[]{};
        for (Integer i = 0; i < 50; i++) {
            bulkRecords.add(new Employee_Attendance__c(
                Employee_Name__c  = u.Id,
                Date__c           = Date.today(),
                Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0)),
                Check_Out_Time__c = null,
                Work_Location__c  = 'Work from Office',
                Status__c         = 'Present',
                Notes__c          = 'Bulk record ' + i
            ));
        }
        insert bulkRecords;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c[] updated = [
            SELECT Id, Check_Out_Time__c
            FROM   Employee_Attendance__c
            WHERE  Employee_Name__c = :u.Id
            AND    Date__c          = :Date.today()
            AND    Check_Out_Time__c != null
        ];

        System.assertEquals(50, updated.size(), 'All 50 bulk records should be auto-checked out');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 7: Hours worked calculated and noted
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testHoursWorkedCalculation() {
        User u = getTestUser();

        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c  = u.Id,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Office',
            Status__c         = 'Present',
            Notes__c          = 'Hours test'
        );
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Notes__c, Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assert(updated.Notes__c.contains('Hours worked:'), 'Notes should contain hours worked value');
        System.assertNotEquals(null, updated.Check_Out_Time__c, 'Checkout time must be set');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 8: Mixed records — some open, some already checked out
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testMixedOpenAndClosedRecords() {
        User u = getTestUser();

        Employee_Attendance__c openRec   = AutoCheckoutTestDataFactory.createOpenAttendance(u.Id);
        Employee_Attendance__c closedRec = AutoCheckoutTestDataFactory.createCheckedOutAttendance(u.Id);
        Employee_Attendance__c[] toInsert = new Employee_Attendance__c[]{ openRec, closedRec };
        insert toInsert;

        DateTime originalClosedCheckout = closedRec.Check_Out_Time__c;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updatedOpen = [
            SELECT Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :openRec.Id
        ];
        Employee_Attendance__c updatedClosed = [
            SELECT Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :closedRec.Id
        ];
        System.assertNotEquals(null, updatedOpen.Check_Out_Time__c,
            'Open record should be auto-checked out');
        System.assertEquals(originalClosedCheckout, updatedClosed.Check_Out_Time__c,
            'Already-closed record should remain unchanged');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 9: WFH location record auto-checked out correctly
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testWFHLocationRecord() {
        User u = getTestUser();

        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c  = u.Id,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(10, 0, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Home',
            Status__c         = 'Present',
            Notes__c          = 'WFH today'
        );
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Check_Out_Time__c, Notes__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assertNotEquals(null, updated.Check_Out_Time__c, 'WFH record should also be auto-checked out');
        System.assert(updated.Notes__c.contains('[AUTO CHECKOUT]'), 'Auto-checkout note should be in WFH record');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 10: Verify auto checkout time is exactly 23:59:00
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testCheckoutTimeIsExactly2359() {
        User u = getTestUser();
        Employee_Attendance__c att = AutoCheckoutTestDataFactory.createOpenAttendance(u.Id);
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Check_Out_Time__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        DateTime expected = DateTime.newInstance(Date.today(), Time.newInstance(23, 59, 0, 0));
        System.assertEquals(expected, updated.Check_Out_Time__c, 'Checkout time must be exactly 11:59:00 PM');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 11: Existing notes preserved, auto-note appended
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testExistingNotesPreserved() {
        User u = getTestUser();

        String originalNote = 'Original check-in notes from employee';
        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c  = u.Id,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(9, 30, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Office',
            Status__c         = 'Present',
            Notes__c          = originalNote
        );
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Notes__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assert(updated.Notes__c.contains(originalNote), 'Original notes should be preserved');
        System.assert(updated.Notes__c.contains('[AUTO CHECKOUT]'), 'Auto-checkout note should be appended');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 12: Batch runs correctly with zero records
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testBatchWithZeroRecords() {
        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        System.assert(true, 'Batch with zero records should complete gracefully');
    }

    // ═══════════════════════════════════════════════════════════════
    // TEST 13: Late check-in record still gets auto-checked out
    // ═══════════════════════════════════════════════════════════════
    @isTest
    static void testLateCheckinRecordAutoCheckout() {
        User u = getTestUser();

        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c  = u.Id,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(11, 30, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Office',
            Status__c         = 'Late',
            Notes__c          = 'Late arrival - traffic'
        );
        insert att;

        Test.startTest();
        Database.executeBatch(new AutoCheckoutBatch(), 200);
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT Check_Out_Time__c, Notes__c FROM Employee_Attendance__c WHERE Id = :att.Id
        ];
        System.assertNotEquals(null, updated.Check_Out_Time__c,
            'Late check-in record must still be auto-checked out');
        System.assert(updated.Notes__c.contains('[AUTO CHECKOUT]'),
            'Late check-in record notes must contain auto-checkout marker');
    }
}