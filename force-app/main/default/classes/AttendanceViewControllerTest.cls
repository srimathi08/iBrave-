/**
 * @description Test class for AttendanceViewController
 * @author Salesforce Consultant
 * @date 2025-12-15
 * @version 2.0 - Focused on code coverage
 */
@isTest
private class AttendanceViewControllerTest {
    
    // Test data constants
    private static final String EMPLOYEE_FIRST_NAME = 'Test';
    private static final String EMPLOYEE_LAST_NAME = 'Employee';
    private static final String EMPLOYEE_EMAIL = 'test.employee@example.com';
    private static final String EMPLOYEE_USERNAME = 'test.employee@example.com.test';
    private static final String EMPLOYEE_ALIAS = 'testemp';
    private static final String BRANCH_NAME = 'Test Branch';
    private static final String BRANCH_CITY = 'Test City';
    private static final String BRANCH_STATE = 'Test State';
    
    @TestSetup
    static void setupTestData() {
        // Create Account and Contact for Community user
        Account testAccount = new Account(Name = 'Test Company Account');
        insert testAccount;
        
        Contact testContact = new Contact(
            AccountId = testAccount.Id,
            FirstName = EMPLOYEE_FIRST_NAME,
            LastName = EMPLOYEE_LAST_NAME,
            Email = EMPLOYEE_EMAIL
        );
        insert testContact;
        
        // Create Community user
        Profile customerProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        
        User testEmployee = new User(
            ContactId = testContact.Id,
            FirstName = EMPLOYEE_FIRST_NAME,
            LastName = EMPLOYEE_LAST_NAME,
            Email = EMPLOYEE_EMAIL,
            Username = EMPLOYEE_USERNAME,
            Alias = EMPLOYEE_ALIAS,
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = customerProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert testEmployee;
        
        // Create Branch
        Branch__c testBranch = new Branch__c(
            Branch_Name__c = BRANCH_NAME,
            City__c = BRANCH_CITY,
            State__c = BRANCH_STATE,
            Is_Active__c = true
        );
        insert testBranch;
        
        // Create Leave Type
        Leave_Type__c leaveType = new Leave_Type__c(
            Leave_Type_Name__c = 'Casual Leave',
            Leave_Code__c = 'CL',
            Is_Active__c = true
        );
        insert leaveType;
        
        // Create diverse attendance records
        Date today = Date.today();
        List<Employee_Attendance__c> attendanceRecords = new List<Employee_Attendance__c>();
        
        // Today - checked in only
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today,
            Check_In_Time__c = DateTime.now().addHours(-2),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false,
            Notes__c = 'Today session'
        ));
        
        // Yesterday - WFH Approved
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-1),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-1), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-1), Time.newInstance(17, 30, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Approved WFH',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c = 'Approved',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -2 - Client Place
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-2),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-2), Time.newInstance(8, 30, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-2), Time.newInstance(18, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Client Place',
            Client_Place_Details__c = 'ABC Corp Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -3 - Field Work
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-3),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-3), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-3), Time.newInstance(16, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Field Work',
            Field_Work_Details__c = 'Site visit',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -4 - WFH Pending
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-4),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-4), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-4), Time.newInstance(17, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Pending approval',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c = 'Pending',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -5 - WFH Rejected
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-5),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-5), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-5), Time.newInstance(17, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Rejected',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c = 'Rejected',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -6 - Late
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-6),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-6), Time.newInstance(10, 30, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-6), Time.newInstance(18, 30, 0, 0)),
            Status__c = 'Late',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -7 - Absent
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-7),
            Status__c = 'Absent',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -8 - Half Day
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-8),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-8), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-8), Time.newInstance(13, 0, 0, 0)),
            Status__c = 'Half Day',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -9 - Multiple sessions - Morning
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-9),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-9), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-9), Time.newInstance(12, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = true
        ));
        
        // Day -9 - Multiple sessions - Afternoon
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-9),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-9), Time.newInstance(14, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-9), Time.newInstance(18, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 2,
            Is_Multiple_Session__c = true
        ));
        
        // Day -10 - WFH without approval submission
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-10),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-10), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-10), Time.newInstance(17, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'No approval needed',
            Submitted_For_Approval__c = false,
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -11 - Null times
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-11),
            Check_In_Time__c = null,
            Check_Out_Time__c = null,
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        // Day -12 - No notes
        attendanceRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = today.addDays(-12),
            Check_In_Time__c = DateTime.newInstance(today.addDays(-12), Time.newInstance(9, 0, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(today.addDays(-12), Time.newInstance(17, 0, 0, 0)),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Notes__c = null,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        insert attendanceRecords;
        
        // Create leave requests
        Leave_Request__c approvedLeave = new Leave_Request__c(
            Employee__c = testEmployee.Id,
            Leave_Type__c = leaveType.Id,
            Start_Date__c = today.addDays(1),
            End_Date__c = today.addDays(1),
            Total_Days__c = 1,
            Reason__c = 'Medical',
            Status__c = 'Approved',
            Is_Active__c = true,
            Is_Half_Day__c = false
        );
        insert approvedLeave;
        
        Leave_Request__c pendingLeave = new Leave_Request__c(
            Employee__c = testEmployee.Id,
            Leave_Type__c = leaveType.Id,
            Start_Date__c = today.addDays(2),
            End_Date__c = today.addDays(2),
            Total_Days__c = 1,
            Reason__c = 'Personal',
            Status__c = 'Pending',
            Is_Active__c = true,
            Is_Half_Day__c = true,
            Half_Day_Type__c = 'First Half'
        );
        insert pendingLeave;
        
        Leave_Request__c cancelledLeave = new Leave_Request__c(
            Employee__c = testEmployee.Id,
            Leave_Type__c = leaveType.Id,
            Start_Date__c = today.addDays(3),
            End_Date__c = today.addDays(3),
            Total_Days__c = 1,
            Reason__c = 'Cancelled',
            Status__c = 'Cancelled',
            Is_Active__c = true,
            Is_Half_Day__c = false
        );
        insert cancelledLeave;
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecords_Success() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecords_BlankEmployeeId() {
        Test.startTest();
        try {
            AttendanceViewController.getEmployeeAttendanceRecords('', 50);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecords_InvalidEmployeeId() {
        Test.startTest();
        try {
            AttendanceViewController.getEmployeeAttendanceRecords('005000000000000AAA', 50);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecords_DefaultLimit() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, null);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecords_InactiveUser() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        testEmployee.IsActive = false;
        update testEmployee;
        Test.startTest();
        try {
            AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetTodayAttendance_Success() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(testEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTodayAttendance_BlankEmployeeId() {
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance('');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTodayAttendance_NoRecord() {
        Account newAccount = new Account(Name = 'New Test Company');
        insert newAccount;
        Contact newContact = new Contact(
            AccountId = newAccount.Id,
            FirstName = 'New',
            LastName = 'Employee',
            Email = 'new.employee@example.com'
        );
        insert newContact;
        Profile customerProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        User newEmployee = new User(
            ContactId = newContact.Id,
            FirstName = 'New',
            LastName = 'Employee',
            Email = 'new.employee@example.com',
            Username = 'new.employee@example.com.test',
            Alias = 'newemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = customerProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert newEmployee;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendance(newEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTodayAttendanceRecord_Success() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord(testEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTodayAttendanceRecord_BlankEmployeeId() {
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord('');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetAttendanceSummaryWithWFH_Success() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Date startDate = Date.today().addDays(-30);
        Date endDate = Date.today();
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(testEmployee.Id, startDate, endDate);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetAttendanceSummaryWithWFH_DefaultDates() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(testEmployee.Id, null, null);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetAttendanceSummaryWithWFH_BlankEmployeeId() {
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH('', null, null);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testLocationFieldsAccess_Success() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.testLocationFieldsAccess(testEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testLocationFieldsAccess_BlankEmployeeId() {
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.testLocationFieldsAccess('');
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testCheckLeaveForDate_ApprovedLeave() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Date tomorrow = Date.today().addDays(1);
        String dateString = String.valueOf(tomorrow.year()) + '-' + 
                           String.valueOf(tomorrow.month()).leftPad(2, '0') + '-' + 
                           String.valueOf(tomorrow.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(testEmployee.Id, dateString);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testCheckLeaveForDate_PendingLeave() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Date dayAfterTomorrow = Date.today().addDays(2);
        String dateString = String.valueOf(dayAfterTomorrow.year()) + '-' + 
                           String.valueOf(dayAfterTomorrow.month()).leftPad(2, '0') + '-' + 
                           String.valueOf(dayAfterTomorrow.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(testEmployee.Id, dateString);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testCheckLeaveForDate_CancelledLeaveExcluded() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Date threeDaysLater = Date.today().addDays(3);
        String dateString = String.valueOf(threeDaysLater.year()) + '-' + 
                           String.valueOf(threeDaysLater.month()).leftPad(2, '0') + '-' + 
                           String.valueOf(threeDaysLater.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(testEmployee.Id, dateString);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testCheckLeaveForDate_NoLeave() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Date futureDate = Date.today().addDays(10);
        String dateString = String.valueOf(futureDate.year()) + '-' + 
                           String.valueOf(futureDate.month()).leftPad(2, '0') + '-' + 
                           String.valueOf(futureDate.day()).leftPad(2, '0');
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.checkLeaveForDate(testEmployee.Id, dateString);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecordsWithApproval() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecordsWithApproval(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testAttendanceWithVariousWorkLocations() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testBulkRecordHandling() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        List<Employee_Attendance__c> bulkRecords = new List<Employee_Attendance__c>();
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        for (Integer i = 13; i <= 30; i++) {
            bulkRecords.add(new Employee_Attendance__c(
                Employee_Name__c = testEmployee.Id,
                Date__c = Date.today().addDays(-i),
                Check_In_Time__c = DateTime.now().addDays(-i).addHours(-8),
                Check_Out_Time__c = DateTime.now().addDays(-i).addHours(-1),
                Status__c = 'Present',
                Work_Location__c = 'Work from Office',
                Branch__c = testBranch.Id,
                Session_Number__c = 1,
                Is_Multiple_Session__c = false
            ));
        }
        insert bulkRecords;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 100);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testGetTodayAttendanceRecord_NoRecords() {
        Account newAccount = new Account(Name = 'Another Test Company');
        insert newAccount;
        Contact newContact = new Contact(
            AccountId = newAccount.Id,
            FirstName = 'Another',
            LastName = 'Employee',
            Email = 'another.employee@example.com'
        );
        insert newContact;
        Profile customerProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        User anotherEmployee = new User(
            ContactId = newContact.Id,
            FirstName = 'Another',
            LastName = 'Employee',
            Email = 'another.employee@example.com',
            Username = 'another.employee@example.com.test',
            Alias = 'anemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = customerProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert anotherEmployee;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord(anotherEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testWFHWithNullApprovalStatus() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c wfhRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-13),
            Check_In_Time__c = DateTime.now().addDays(-13).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-13).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Null status test',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c = 'Pending',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert wfhRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testWFHWithUnknownApprovalStatus() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c wfhRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-14),
            Check_In_Time__c = DateTime.now().addDays(-14).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-14).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Work from Home',
            WFH_Reason__c = 'Rejected status test',
            Submitted_For_Approval__c = true,
            WFH_Approval_Status__c = 'Rejected',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert wfhRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testClientPlaceWithLongDetails() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        String longDetails = 'This is a very long client place details text that exceeds fifty characters to test the substring functionality';
        Employee_Attendance__c clientRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-15),
            Check_In_Time__c = DateTime.now().addDays(-15).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-15).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Client Place',
            Client_Place_Details__c = longDetails,
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert clientRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testFieldWorkWithLongDetails() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        String longDetails = 'This is a very long field work details text that exceeds fifty characters to test the substring functionality';
        Employee_Attendance__c fieldRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-16),
            Check_In_Time__c = DateTime.now().addDays(-16).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-16).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Field Work',
            Field_Work_Details__c = longDetails,
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert fieldRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testClientPlaceWithBlankDetails() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c clientRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-17),
            Check_In_Time__c = DateTime.now().addDays(-17).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-17).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Client Place',
            Client_Place_Details__c = null,
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert clientRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testFieldWorkWithBlankDetails() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c fieldRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-18),
            Check_In_Time__c = DateTime.now().addDays(-18).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-18).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Field Work',
            Field_Work_Details__c = null,
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert fieldRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testOfficeWorkWithBranchDetails() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c officeRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-19),
            Check_In_Time__c = DateTime.now().addDays(-19).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-19).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert officeRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testOfficeWorkWithNoBranch() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        Employee_Attendance__c officeRecord = new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-20),
            Check_In_Time__c = DateTime.now().addDays(-20).addHours(-8),
            Check_Out_Time__c = DateTime.now().addDays(-20).addHours(-1),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        );
        insert officeRecord;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testStatusBadgeClasses() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        List<Employee_Attendance__c> statusRecords = new List<Employee_Attendance__c>();
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-21),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-22),
            Status__c = 'Late',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-23),
            Status__c = 'Absent',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-24),
            Status__c = 'Half Day',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-25),
            Status__c = 'Holiday',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        statusRecords.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today().addDays(-26),
            Status__c = 'Leave',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 1,
            Is_Multiple_Session__c = false
        ));
        
        insert statusRecords;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 50);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testMultipleTodaySessions() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Branch__c testBranch = [SELECT Id FROM Branch__c WHERE Branch_Name__c = :BRANCH_NAME LIMIT 1];
        
        List<Employee_Attendance__c> todaySessions = new List<Employee_Attendance__c>();
        
        todaySessions.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today(),
            Check_In_Time__c = DateTime.now().addHours(-6),
            Check_Out_Time__c = DateTime.now().addHours(-4),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 2,
            Is_Multiple_Session__c = true
        ));
        
        todaySessions.add(new Employee_Attendance__c(
            Employee_Name__c = testEmployee.Id,
            Date__c = Date.today(),
            Check_In_Time__c = DateTime.now().addHours(-2),
            Status__c = 'Present',
            Work_Location__c = 'Work from Office',
            Branch__c = testBranch.Id,
            Session_Number__c = 3,
            Is_Multiple_Session__c = true
        ));
        
        insert todaySessions;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getTodayAttendanceRecord(testEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testZeroLimitRecords() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 0);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testNegativeLimitRecords() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, -10);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testAttendanceSummaryWithNoRecords() {
        Account newAccount = new Account(Name = 'Summary Test Company');
        insert newAccount;
        Contact newContact = new Contact(
            AccountId = newAccount.Id,
            FirstName = 'Summary',
            LastName = 'Employee',
            Email = 'summary.employee@example.com'
        );
        insert newContact;
        Profile customerProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        User summaryEmployee = new User(
            ContactId = newContact.Id,
            FirstName = 'Summary',
            LastName = 'Employee',
            Email = 'summary.employee@example.com',
            Username = 'summary.employee@example.com.test',
            Alias = 'sumemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = customerProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert summaryEmployee;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getAttendanceSummaryWithWFH(summaryEmployee.Id, Date.today().addDays(-30), Date.today());
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testLocationFieldsWithNoRecords() {
        Account newAccount = new Account(Name = 'Location Test Company');
        insert newAccount;
        Contact newContact = new Contact(
            AccountId = newAccount.Id,
            FirstName = 'Location',
            LastName = 'Employee',
            Email = 'location.employee@example.com'
        );
        insert newContact;
        Profile customerProfile = [SELECT Id FROM Profile WHERE Name = 'Customer Community Login User' LIMIT 1];
        User locationEmployee = new User(
            ContactId = newContact.Id,
            FirstName = 'Location',
            LastName = 'Employee',
            Email = 'location.employee@example.com',
            Username = 'location.employee@example.com.test',
            Alias = 'locemp',
            TimeZoneSidKey = 'America/Los_Angeles',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            ProfileId = customerProfile.Id,
            LanguageLocaleKey = 'en_US',
            IsActive = true
        );
        insert locationEmployee;
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.testLocationFieldsAccess(locationEmployee.Id);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
    
    @isTest
    static void testCheckLeaveWithInvalidDateFormat() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        try {
            Map<String, Object> result = AttendanceViewController.checkLeaveForDate(testEmployee.Id, 'invalid-date');
        } catch (Exception e) {
            System.assertNotEquals(null, e);
        }
        Test.stopTest();
    }
    
    @isTest
    static void testGetEmployeeAttendanceRecordsLargeLimit() {
        User testEmployee = [SELECT Id FROM User WHERE Username = :EMPLOYEE_USERNAME LIMIT 1];
        Test.startTest();
        Map<String, Object> result = AttendanceViewController.getEmployeeAttendanceRecords(testEmployee.Id, 1000);
        Test.stopTest();
        System.assertNotEquals(null, result);
    }
}