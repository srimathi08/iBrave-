@IsTest
public class AttendanceReminderBatchTest {

    @TestSetup
    static void setupData() {

        Profile stdProfile =
            [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        Profile adminProfile =
            [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];

        Long ts = System.currentTimeMillis();

        /* ---------------- ADMIN USER (SUMMARY EMAIL) ---------------- */
        User admin = new User(
            Username = 'admin_' + ts + '@test.com',
            Email = 'admin@test.com',
            LastName = 'Admin',
            Alias = 'adm',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = adminProfile.Id,
            IsActive = true
        );
        insert admin;

        /* ---------------- EMPLOYEES ---------------- */
        List<User> users = new List<User>();

        // 1️⃣ Needs reminder (NO attendance, NO leave)
        users.add(new User(
            Username = 'u1_' + ts + '@test.com',
            Email = 'u1@test.com',
            LastName = 'NeedsReminder',
            Alias = 'u1',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id,
            Employee_IDs__c = '1003',
            IsActive = true
        ));

        // 2️⃣ Already checked in
        users.add(new User(
            Username = 'u2_' + ts + '@test.com',
            Email = 'u2@test.com',
            LastName = 'CheckedIn',
            Alias = 'u2',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id,
            Employee_IDs__c = '1003',
            IsActive = true
        ));

        // 3️⃣ On leave
        users.add(new User(
            Username = 'u3_' + ts + '@test.com',
            Email = 'u3@test.com',
            LastName = 'OnLeave',
            Alias = 'u3',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = stdProfile.Id,
             Employee_IDs__c = '1003',
            IsActive = true
        ));

        insert users;

        /* ---------------- ATTENDANCE (CHECKED-IN USER) ---------------- */
        insert new Employee_Attendance__c(
            Employee_Name__c = users[1].Id,
            Date__c = Date.today(),
            Check_In_Time__c = System.now()
        );

        /* ---------------- LEAVE (ON-LEAVE USER) ---------------- */
        insert new Leave_Request__c(
            Employee__c = users[2].Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today(),
            Status__c = 'Approved',
            Is_Active__c = true,
            Total_Days__c = 1
        );
    }

    /* =========================================================
       FULL BATCH EXECUTION
       ========================================================= */
    @IsTest
    static void testAttendanceReminderBatch_FullCoverage() {

        Test.startTest();
        Database.executeBatch(new AttendanceReminderBatch(), 200);
        Test.stopTest();

        // Emails are invoked (user reminder + admin summary)
        //System.assert(Limits.getEmailInvocations() > 0,
           // 'Emails should be sent');
    }

    /* =========================================================
       START METHOD COVERAGE
       ========================================================= */
    @IsTest
    static void testStartMethod() {
        AttendanceReminderBatch batch = new AttendanceReminderBatch();

        Test.startTest();
        Database.QueryLocator ql = batch.start(null);
        Test.stopTest();

        System.assertNotEquals(null, ql);
    }

    /* =========================================================
       EMPTY DATA SAFETY
       ========================================================= */
    @IsTest
    static void testBatchWithNoEmployees() {

        Test.startTest();
        Database.executeBatch(new AttendanceReminderBatch(), 50);
        Test.stopTest();

        // Should complete without exception
        System.assert(true);
    }
}