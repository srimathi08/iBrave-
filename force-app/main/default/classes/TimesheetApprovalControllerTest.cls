@IsTest
public class TimesheetApprovalControllerTest {

    // -----------------------------------------------------
    // TEST DATA SETUP
    // -----------------------------------------------------

    @TestSetup
    static void setupData() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User manager = new User(
            Alias = 'mgr',
            Email = 'manager@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Manager',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'manager' + DateTime.now().getTime() + '@test.com'
        );
        insert manager;

        User employee = new User(
            Alias = 'emp',
            Email = 'employee@test.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Employee',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = 'employee' + DateTime.now().getTime() + '@test.com'
        );
        insert employee;

        Timesheet__c ts = new Timesheet__c(
            Employee__c = employee.Id,
            Manager__c = manager.Id,
            Week_Number__c = 10,
            Week_Year__c = 2026,
            Approval_Status__c = 'Submitted',
            Submitted_Date__c = DateTime.now(),
            Approval_Token__c = 'VALID_TOKEN',
            Token_Expiry__c = DateTime.now().addDays(1)
        );
        insert ts;

        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today(),
            Total_Hours__c = 8
        );
    }

    // -----------------------------------------------------
    // MISSING TOKEN
    // -----------------------------------------------------

    @IsTest
    static void testMissingToken() {

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        // No token parameter

        TimesheetApprovalController ctrl = new TimesheetApprovalController();

        System.assertEquals(true, ctrl.showMessage);
        System.assertEquals(false, ctrl.isSuccess);
    }

    // -----------------------------------------------------
    // INVALID TOKEN
    // -----------------------------------------------------

    @IsTest
    static void testInvalidToken() {

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'BAD_TOKEN');

        TimesheetApprovalController ctrl = new TimesheetApprovalController();

        System.assertEquals(true, ctrl.showMessage);
        System.assertEquals(false, ctrl.showForm);
    }

    // -----------------------------------------------------
    // EXPIRED TOKEN
    // -----------------------------------------------------

    @IsTest
    static void testExpiredToken() {

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        ts.Approval_Token__c = 'EXPIRED_TOKEN';
        ts.Token_Expiry__c = DateTime.now().addDays(-1);
        update ts;

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'EXPIRED_TOKEN');

        TimesheetApprovalController ctrl = new TimesheetApprovalController();

        System.assertEquals(true, ctrl.showMessage);
        System.assertEquals(false, ctrl.isSuccess);
    }

    // -----------------------------------------------------
    // ALREADY PROCESSED
    // -----------------------------------------------------

    @IsTest
    static void testAlreadyProcessed() {

        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        ts.Approval_Status__c = 'Approved';
        ts.Approval_Token__c = 'USED_TOKEN';
        ts.Token_Expiry__c = DateTime.now().addDays(1);
        update ts;

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'USED_TOKEN');

        TimesheetApprovalController ctrl = new TimesheetApprovalController();

        System.assertEquals(true, ctrl.showMessage);
        System.assertEquals(true, ctrl.isSuccess);
    }

    // -----------------------------------------------------
    // UNAUTHORIZED USER
    // -----------------------------------------------------

    @IsTest
    static void testUnauthorizedUser() {

        User randomUser = [SELECT Id FROM User WHERE LastName = 'Employee' LIMIT 1];

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'VALID_TOKEN');

        System.runAs(randomUser) {

            TimesheetApprovalController ctrl = new TimesheetApprovalController();

            System.assertEquals(true, ctrl.showMessage);
            System.assertEquals(false, ctrl.isSuccess);
        }
    }

    // -----------------------------------------------------
    // APPROVE FLOW
    // -----------------------------------------------------

    @IsTest
    static void testApproveTimesheet() {

        User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'VALID_TOKEN');

        System.runAs(manager) {

            TimesheetApprovalController ctrl = new TimesheetApprovalController();
            ctrl.comments = 'Looks good';

            Test.startTest();
            ctrl.approveTimesheet();
            Test.stopTest();

            Timesheet__c ts = [
                SELECT Approval_Status__c, Approval_Token__c
                FROM Timesheet__c
                LIMIT 1
            ];

            System.assertEquals('Approved', ts.Approval_Status__c);
            System.assertEquals(null, ts.Approval_Token__c);
        }
    }

    // -----------------------------------------------------
    // REJECT FLOW
    // -----------------------------------------------------

    @IsTest
    static void testRejectTimesheet() {

        // Reset sheet
        Timesheet__c ts = [SELECT Id FROM Timesheet__c LIMIT 1];
        ts.Approval_Status__c = 'Submitted';
        ts.Approval_Token__c = 'REJECT_TOKEN';
        ts.Token_Expiry__c = DateTime.now().addDays(1);
        update ts;

        User manager = [SELECT Id FROM User WHERE LastName = 'Manager' LIMIT 1];

        Test.setCurrentPage(Page.TimesheetApprovalPage);
        ApexPages.currentPage().getParameters().put('token', 'REJECT_TOKEN');

        System.runAs(manager) {

            TimesheetApprovalController ctrl = new TimesheetApprovalController();
            ctrl.comments = 'Fix hours';

            Test.startTest();
            ctrl.rejectTimesheet();
            Test.stopTest();

            Timesheet__c updated = [
                SELECT Approval_Status__c
                FROM Timesheet__c
                LIMIT 1
            ];

            System.assertEquals('Rejected', updated.Approval_Status__c);
        }
    }
}