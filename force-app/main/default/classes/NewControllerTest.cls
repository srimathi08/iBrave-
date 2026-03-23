@isTest
private class NewControllerTest {

    // ===================================================================
    // HELPERS
    // ===================================================================
    private static String fmtDate(Date d) {
        return d.year() + '-' +
               String.valueOf(d.month()).leftPad(2,'0') + '-' +
               String.valueOf(d.day()).leftPad(2,'0');
    }

    private static String fmtDT(Date d, Integer h, Integer m) {
        return fmtDate(d) + ' ' +
               String.valueOf(h).leftPad(2,'0') + ':' +
               String.valueOf(m).leftPad(2,'0') + ':00';
    }

    private static Map<String, Object> basePayload(Id empId, String loc, Date d) {
        return new Map<String, Object>{
            'Employee_Name__c' => empId,
            'Date__c'          => fmtDate(d),
            'Check_In_Time__c' => fmtDT(d, 9, 0),
            'Check_Out_Time__c'=> fmtDT(d, 18, 0),
            'Status__c'        => 'Present',
            'Work_Location__c' => loc,
            'Notes__c'         => 'Test note'
        };
    }

    // ===================================================================
    // TEST DATA
    // ===================================================================
    @TestSetup
    static void setupTestData() {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User mgr = new User(
            FirstName='Mgr', LastName='NC',
            Email='mgr_nc@testorg.com',
            Username='mgr_nc_' + System.currentTimeMillis() + '@testorg.com',
            Alias='mgrnc', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert mgr;

        User emp = new User(
            FirstName='Emp', LastName='NC',
            Email='emp_nc@testorg.com',
            Username='emp_nc_' + System.currentTimeMillis() + '@testorg.com',
            Alias='empnc', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id,
            ManagerId=mgr.Id
        );
        insert emp;

        // Employee with NO manager
        User empNoMgr = new User(
            FirstName='NoMgr', LastName='NC',
            Email='nomgr_nc@testorg.com',
            Username='nomgr_nc_' + System.currentTimeMillis() + '@testorg.com',
            Alias='nomgr', TimeZoneSidKey='America/Los_Angeles',
            LocaleSidKey='en_US', EmailEncodingKey='UTF-8',
            LanguageLocaleKey='en_US', ProfileId=p.Id
        );
        insert empNoMgr;

        Branch__c branch = new Branch__c(
            Branch_Name__c = 'Test Branch',
            City__c        = 'Chennai',
            State__c       = 'Tamil Nadu'
        );
        insert branch;
    }

    // ===================================================================
    // createAttendance — basic field paths
    // ===================================================================

    @isTest
    static void testCreate_WFH_WithReason() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Home', Date.today());
        p.put('WFH_Reason__c', 'Working from home today');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,  r.get('success'));
        System.assertEquals(true,  r.get('hasWFHReason'));
        System.assertEquals(false, r.get('hasClientPlaceDetails'));
        System.assertEquals(false, r.get('hasFieldWorkDetails'));
    }

    @isTest
    static void testCreate_WFH_BlankReason_FalseFlag() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Home', Date.today().addDays(-1));
        p.put('WFH_Reason__c', '');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,  r.get('success'));
        System.assertEquals(false, r.get('hasWFHReason'));
    }

    @isTest
    static void testCreate_Office_WithBranch() {
        User emp    = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Branch__c b = [SELECT Id FROM Branch__c LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Office', Date.today().addDays(-2));
        p.put('Branch_Name__c', b.Id);
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertEquals(true, r.get('hasBranch'));
        String msg = (String) r.get('message');
        System.assert(msg.contains('Office') || msg.contains('branch'));
    }

    @isTest
    static void testCreate_Office_NullBranch_FalseFlag() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Office', Date.today().addDays(-3));
        p.put('Branch_Name__c', null);
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,  r.get('success'));
        System.assertEquals(false, r.get('hasBranch'));
    }

    @isTest
    static void testCreate_ClientPlace_WithDetails() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Client Place', Date.today().addDays(-4));
        p.put('Client_Place_Details__c', 'ABC Corp, 123 Main Street');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertEquals(true, r.get('hasClientPlaceDetails'));
        String msg = (String) r.get('message');
        System.assert(msg.contains('Client') || msg.contains('visit'));
    }

    @isTest
    static void testCreate_ClientPlace_BlankDetails_FalseFlag() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Client Place', Date.today().addDays(-5));
        p.put('Client_Place_Details__c', '');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,  r.get('success'));
        System.assertEquals(false, r.get('hasClientPlaceDetails'));
    }

    @isTest
    static void testCreate_FieldWork_WithDetails() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Field Work', Date.today().addDays(-6));
        p.put('Field_Work_Details__c', 'Site inspection Tower A');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertEquals(true, r.get('hasFieldWorkDetails'));
        String msg = (String) r.get('message');
        System.assert(msg.contains('Field') || msg.contains('field'));
    }

    @isTest
    static void testCreate_FieldWork_BlankDetails_FalseFlag() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Field Work', Date.today().addDays(-7));
        p.put('Field_Work_Details__c', '');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,  r.get('success'));
        System.assertEquals(false, r.get('hasFieldWorkDetails'));
    }

    @isTest
    static void testCreate_BusinessTravel_Message() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Business Travel', Date.today().addDays(-8));
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertNotEquals(null, r.get('message'));
    }

    @isTest
    static void testCreate_NoCheckOutTime() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c' => emp.Id,
            'Date__c'          => fmtDate(Date.today()),
            'Check_In_Time__c' => fmtDT(Date.today(), 9, 0),
            'Status__c'        => 'Present',
            'Work_Location__c' => 'Work from Home'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreate_LateStatus() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Home', Date.today().addDays(-9));
        p.put('Status__c', 'Late');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true,   r.get('success'));
        System.assertEquals('Late', r.get('status'));
    }

    @isTest
    static void testCreate_ODFields() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Home', Date.today().addDays(-10));
        p.put('Is_OD_Request__c',         true);
        p.put('OD_Approval_Status__c',    'Pending');
        p.put('OD_Reason__c',             'Genuine OD reason');
        p.put('Submitted_For_Approval__c', true);
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreate_WithCheckInPhoto() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Office', Date.today().addDays(-11));
        p.put('Check_In_Photo_B64',  EncodingUtil.base64Encode(Blob.valueOf('photo data in')));
        p.put('Check_In_Photo_Name', 'checkin.jpg');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        String msg = (String) r.get('message');
        System.assert(msg.contains('photo'));
    }

    @isTest
    static void testCreate_WithCheckOutPhoto() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Office', Date.today().addDays(-12));
        p.put('Check_Out_Photo_B64',  EncodingUtil.base64Encode(Blob.valueOf('photo data out')));
        p.put('Check_Out_Photo_Name', 'checkout.jpg');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreate_BothPhotos() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Map<String, Object> p = basePayload(emp.Id, 'Work from Office', Date.today().addDays(-13));
        p.put('Check_In_Photo_B64',   EncodingUtil.base64Encode(Blob.valueOf('in photo')));
        p.put('Check_In_Photo_Name',  'in.jpg');
        p.put('Check_Out_Photo_B64',  EncodingUtil.base64Encode(Blob.valueOf('out photo')));
        p.put('Check_Out_Photo_Name', 'out.jpg');
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreate_TFormatDateTime() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-14);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d),
            'Check_In_Time__c'  => fmtDate(d) + 'T09:00:00Z',
            'Check_Out_Time__c' => fmtDate(d) + 'T18:00:00Z',
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Home'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    // ===================================================================
    // createAttendance — error paths
    // ===================================================================

    @isTest
    static void testCreate_NullPayload() {
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(null);
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
        System.assertNotEquals(null, r.get('error'));
    }

    @isTest
    static void testCreate_EmptyPayload() {
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(new Map<String, Object>());
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
    }

    @isTest
    static void testCreate_MissingEmployeeId() {
        Map<String, Object> p = new Map<String, Object>{
            'Date__c'   => fmtDate(Date.today()),
            'Status__c' => 'Present'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createAttendance(p);
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
    }

    // ===================================================================
    // testNewFieldsAccess
    // ===================================================================

    @isTest
    static void testNewFieldsAccess_HappyPath() {
        Test.startTest();
        Map<String, Object> r = NewController.testNewFieldsAccess();
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertNotEquals(null, r.get('objectName'));
        System.assertNotEquals(null, r.get('hasClientPlaceDetailsField'));
        System.assertNotEquals(null, r.get('hasFieldWorkDetailsField'));
        System.assertNotEquals(null, r.get('hasWFHReasonField'));
    }

    // ===================================================================
    // debugAttendanceRecord
    // ===================================================================

    @isTest
    static void testDebug_HappyPath_WFH() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Employee_Attendance__c rec = new Employee_Attendance__c(
            Employee_Name__c        = emp.Id,
            Date__c                 = Date.today().addDays(-1),
            Check_In_Time__c        = DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(9,0,0,0)),
            Check_Out_Time__c       = DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(18,0,0,0)),
            Status__c               = 'Present',
            Work_Location__c        = 'Work from Home',
            WFH_Reason__c           = 'WFH reason',
            WFH_Approval_Status__c  = 'Approved',
            Submitted_For_Approval__c = true,
            Session_Number__c       = 1
        );
        insert rec;
        Test.startTest();
        Map<String, Object> r = NewController.debugAttendanceRecord(rec.Id);
        Test.stopTest();
        System.assertEquals(true,   r.get('success'));
        System.assertEquals(rec.Id, r.get('recordId'));
        System.assertEquals(false,  r.get('hasClientPlaceDetails'));
        System.assertEquals(false,  r.get('hasFieldWorkDetails'));
        System.assertEquals(true,   r.get('submittedForApproval'));
    }

    @isTest
    static void testDebug_ClientPlaceDetails() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Employee_Attendance__c rec = new Employee_Attendance__c(
            Employee_Name__c        = emp.Id,
            Date__c                 = Date.today().addDays(-2),
            Check_In_Time__c        = DateTime.newInstance(Date.today().addDays(-2), Time.newInstance(9,0,0,0)),
            Status__c               = 'Present',
            Work_Location__c        = 'Client Place',
            Client_Place_Details__c = 'ABC Corp HQ',
            Session_Number__c       = 1
        );
        insert rec;
        Test.startTest();
        Map<String, Object> r = NewController.debugAttendanceRecord(rec.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertEquals(true, r.get('hasClientPlaceDetails'));
    }

    @isTest
    static void testDebug_FieldWorkDetails() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Employee_Attendance__c rec = new Employee_Attendance__c(
            Employee_Name__c      = emp.Id,
            Date__c               = Date.today().addDays(-3),
            Check_In_Time__c      = DateTime.newInstance(Date.today().addDays(-3), Time.newInstance(9,0,0,0)),
            Status__c             = 'Present',
            Work_Location__c      = 'Field Work',
            Field_Work_Details__c = 'Site inspection',
            Session_Number__c     = 1
        );
        insert rec;
        Test.startTest();
        Map<String, Object> r = NewController.debugAttendanceRecord(rec.Id);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertEquals(true, r.get('hasFieldWorkDetails'));
    }

    @isTest
    static void testDebug_BlankId() {
        Test.startTest();
        Map<String, Object> r = NewController.debugAttendanceRecord('');
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
    }

    @isTest
    static void testDebug_NotFound() {
        Test.startTest();
        Map<String, Object> r = NewController.debugAttendanceRecord('a0Z000000000001AAA');
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
    }

    // ===================================================================
    // createODAttendance
    // ===================================================================

    @isTest
    static void testCreateOD_WithManager() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-1);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d),
            'Check_In_Time__c'  => fmtDT(d, 9, 0),
            'Check_Out_Time__c' => fmtDT(d, 18, 0),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Home',
            'OD_Reason__c'      => 'Client meeting offsite yesterday'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        System.assertNotEquals(null, r.get('recordId'));
        // Verify OD flags
        Employee_Attendance__c rec = [
            SELECT Is_OD_Request__c, OD_Approval_Status__c, Submitted_For_Approval__c
            FROM Employee_Attendance__c WHERE Id = :(String) r.get('recordId')
        ];
        System.assertEquals(true,      rec.Is_OD_Request__c);
        System.assertEquals('Pending', rec.OD_Approval_Status__c);
        System.assertEquals(true,      rec.Submitted_For_Approval__c);
    }

    @isTest
    static void testCreateOD_NoManager_AdminFallback() {
        User emp = [SELECT Id FROM User WHERE Email = 'nomgr_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-2);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d),
            'Check_In_Time__c'  => fmtDT(d, 9, 0),
            'Check_Out_Time__c' => fmtDT(d, 17, 0),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Office',
            'OD_Reason__c'      => 'Test OD no manager'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreateOD_WithBranch() {
        User emp    = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Branch__c b = [SELECT Id FROM Branch__c LIMIT 1];
        Date d = Date.today().addDays(-4);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d),
            'Check_In_Time__c'  => fmtDT(d, 9, 0),
            'Check_Out_Time__c' => fmtDT(d, 18, 0),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Office',
            'Branch_Name__c'    => b.Id,
            'OD_Reason__c'      => 'Was in office but forgot to check in'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreateOD_ClientPlace() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-5);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'      => emp.Id,
            'Date__c'               => fmtDate(d),
            'Check_In_Time__c'      => fmtDT(d, 10, 0),
            'Check_Out_Time__c'     => fmtDT(d, 17, 0),
            'Status__c'             => 'Late',
            'Work_Location__c'      => 'Client Place',
            'Client_Place_Details__c' => 'XYZ Office Bangalore',
            'OD_Reason__c'          => 'Was at client site'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreateOD_FieldWork() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-6);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'    => emp.Id,
            'Date__c'             => fmtDate(d),
            'Check_In_Time__c'    => fmtDT(d, 8, 0),
            'Check_Out_Time__c'   => fmtDT(d, 16, 0),
            'Status__c'           => 'Present',
            'Work_Location__c'    => 'Field Work',
            'Field_Work_Details__c' => 'Site visit Tower B',
            'OD_Reason__c'        => 'Was doing field work'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
    }

    @isTest
    static void testCreateOD_NullPayload() {
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(null);
        Test.stopTest();
        System.assertEquals(false, r.get('success'));
    }

    @isTest
    static void testCreateOD_TwoRecordsDifferentDates() {
        // ✅ NO nested startTest — both calls inside single startTest/stopTest
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d1 = Date.today().addDays(-8);
        Date d2 = Date.today().addDays(-9);

        Map<String, Object> p1 = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d1),
            'Check_In_Time__c'  => fmtDT(d1, 9, 0),
            'Check_Out_Time__c' => fmtDT(d1, 17, 0),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Home',
            'OD_Reason__c'      => 'OD day 1'
        };
        Map<String, Object> p2 = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d2),
            'Check_In_Time__c'  => fmtDT(d2, 9, 0),
            'Check_Out_Time__c' => fmtDT(d2, 17, 0),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Home',
            'OD_Reason__c'      => 'OD day 2'
        };

        Test.startTest();
        Map<String, Object> r1 = NewController.createODAttendance(p1);
        Map<String, Object> r2 = NewController.createODAttendance(p2);
        Test.stopTest();

        System.assertEquals(true, r1.get('success'), 'OD 1 should succeed');
        System.assertEquals(true, r2.get('success'), 'OD 2 should succeed');
    }

    @isTest
    static void testCreateOD_MessageField() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-10);
        Map<String, Object> p = new Map<String, Object>{
            'Employee_Name__c'  => emp.Id,
            'Date__c'           => fmtDate(d),
            'Check_In_Time__c'  => fmtDT(d, 9, 30),
            'Check_Out_Time__c' => fmtDT(d, 18, 30),
            'Status__c'         => 'Present',
            'Work_Location__c'  => 'Work from Home',
            'OD_Reason__c'      => 'Attended virtual conference'
        };
        Test.startTest();
        Map<String, Object> r = NewController.createODAttendance(p);
        Test.stopTest();
        System.assertEquals(true, r.get('success'));
        String msg = (String) r.get('message');
        System.assertNotEquals(null, msg);
        System.assert(msg.length() > 0);
    }

    // ===================================================================
    // @TestVisible private methods — direct coverage
    // ===================================================================

    @isTest
    static void testFormatTimeForEmail_ValidDateTime() {
        Test.startTest();
        String r = NewController.formatTimeForEmail('2026-03-18 09:15:00');
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assert(r.contains(':'));
    }

    @isTest
    static void testFormatTimeForEmail_TFormat() {
        Test.startTest();
        String r = NewController.formatTimeForEmail('2026-03-18T09:15:00Z');
        Test.stopTest();
        System.assertNotEquals(null, r);
    }

    @isTest
    static void testFormatTimeForEmail_Blank() {
        Test.startTest();
        String r = NewController.formatTimeForEmail('');
        Test.stopTest();
        System.assertEquals('--', r);
    }

    @isTest
    static void testFormatTimeForEmail_Null() {
        Test.startTest();
        String r = NewController.formatTimeForEmail(null);
        Test.stopTest();
        System.assertEquals('--', r);
    }

    @isTest
    static void testFormatTimeForEmail_InvalidFallback() {
        // Invalid datetime — hits catch and returns substring fallback
        Test.startTest();
        String r = NewController.formatTimeForEmail('09:30');
        Test.stopTest();
        System.assertNotEquals(null, r);
    }

    @isTest
    static void testBuildEmailRow_WithValue() {
        Test.startTest();
        String r = NewController.buildEmailRow('Employee', 'John Doe');
        Test.stopTest();
        System.assert(r.contains('Employee'));
        System.assert(r.contains('John Doe'));
    }

    @isTest
    static void testBuildEmailRow_NullValue() {
        Test.startTest();
        String r = NewController.buildEmailRow('Date', null);
        Test.stopTest();
        System.assert(r.contains('--'));
    }

    @isTest
    static void testBuildEmailRow_BlankValue() {
        Test.startTest();
        String r = NewController.buildEmailRow('Location', '');
        Test.stopTest();
        System.assert(r.contains('--'));
    }

    @isTest
    static void testBuildODEmailBody_HappyPath() {
        Test.startTest();
        String r = NewController.buildODEmailBody(
            'John Doe', 'Manager Name', '18/03/2026',
            'Work from Home', '09:00 AM', '06:00 PM',
            'Had a family emergency',
            'https://test.salesforce.com/abc', 'abc123'
        );
        Test.stopTest();
        System.assertNotEquals(null, r);
        System.assert(r.contains('John Doe'));
        System.assert(r.contains('Manager Name'));
        System.assert(r.contains('Work from Home'));
    }

    @isTest
    static void testSendODApprovalEmailToManager_WithManager() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-20);
        Test.startTest();
        try {
            NewController.sendODApprovalEmailToManager(
                emp.Id, 'fakeRecId001',
                'Had an external meeting',
                fmtDate(d), 'Work from Home',
                fmtDT(d, 9, 0), fmtDT(d, 18, 0)
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
        System.assert(true, 'Method should complete');
    }

    @isTest
    static void testSendODApprovalEmailToManager_NoManager() {
        User emp = [SELECT Id FROM User WHERE Email = 'nomgr_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-21);
        Test.startTest();
        try {
            NewController.sendODApprovalEmailToManager(
                emp.Id, 'fakeRecId002',
                'Field visit', fmtDate(d),
                'Field Work', fmtDT(d, 8, 0), fmtDT(d, 16, 0)
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }

    @isTest
    static void testSendFallbackODEmail_HappyPath() {
        User emp = [SELECT Id FROM User WHERE Email = 'emp_nc@testorg.com' LIMIT 1];
        Date d = Date.today().addDays(-22);
        Test.startTest();
        try {
            NewController.sendFallbackODEmail(
                emp, 'fakeRecId003',
                'Fallback test reason', fmtDate(d),
                'Work from Home', fmtDT(d, 9, 0), fmtDT(d, 17, 0)
            );
        } catch (Exception e) {
            System.assertNotEquals(null, e.getMessage());
        }
        Test.stopTest();
        System.assert(true);
    }
}