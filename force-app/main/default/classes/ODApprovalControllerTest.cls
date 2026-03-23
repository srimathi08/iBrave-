@isTest
private class ODApprovalControllerTest {

    private static User createTestUser() {

        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            FirstName = 'Akshaya',
            LastName = 'Pandian',
            Email = 'testuser@test.com',
            Username = 'testuser' + System.currentTimeMillis() + '@test.com',
            Alias = 'test',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id
        );
        insert u;

        return u;
    }

    private static Employee_Attendance__c createAttendanceRecord() {

        User emp = createTestUser();

        Employee_Attendance__c att = new Employee_Attendance__c(
            Employee_Name__c = emp.Id,
            Date__c = Date.today(),
            Work_Location__c = 'Work from Home',
            Check_In_Time__c = DateTime.now(),
            Check_Out_Time__c = DateTime.now().addHours(9),
            OD_Reason__c = 'Testing OD',
            OD_Approval_Status__c = 'Pending'
        );

        insert att;
        return att;
    }

    @isTest
    static void testConstructor_Success() {

        Employee_Attendance__c att = createAttendanceRecord();

        Test.setCurrentPage(Page.ODvfpage);
        ApexPages.currentPage().getParameters().put('id', att.Id);

        Test.startTest();
        ODApprovalController ctrl = new ODApprovalController();
        Test.stopTest();

        System.assertEquals(false, ctrl.recordNotFound);
        System.assertNotEquals(att.Name, ctrl.recordName);
        System.assertEquals('Work from Home', ctrl.workLocation);
        System.assertEquals('Pending', ctrl.odStatus);

        System.assertNotEquals(null, ctrl.odDate);
        System.assertNotEquals(null, ctrl.checkInTime);
        System.assertNotEquals(null, ctrl.checkOutTime);
    }

    @isTest
    static void testConstructor_NoId() {

        Test.setCurrentPage(Page.ODvfpage);

        ODApprovalController ctrl = new ODApprovalController();

        System.assertEquals(true, ctrl.recordNotFound);
    }

    @isTest
    static void testConstructor_InvalidId() {

        Test.setCurrentPage(Page.ODvfpage);
        ApexPages.currentPage().getParameters().put('id', 'a00000000000000AAA');

        ODApprovalController ctrl = new ODApprovalController();

        System.assertEquals(true, ctrl.recordNotFound);
    }

    @isTest
    static void testApproveOD() {

        Employee_Attendance__c att = createAttendanceRecord();

        Test.setCurrentPage(Page.ODvfpage);
        ApexPages.currentPage().getParameters().put('id', att.Id);

        ODApprovalController ctrl = new ODApprovalController();
        ctrl.managerComments = 'Approved by manager';

        Test.startTest();
        ctrl.approveOD();
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT OD_Approval_Status__c, Approval_Comments__c
            FROM Employee_Attendance__c
            WHERE Id = :att.Id
        ];

        System.assertEquals('Approved', updated.OD_Approval_Status__c);
        System.assertEquals('Approved by manager', updated.Approval_Comments__c);
        System.assertEquals('Approved', ctrl.odStatus);
    }

    @isTest
    static void testRejectOD_WithComments() {

        Employee_Attendance__c att = createAttendanceRecord();

        Test.setCurrentPage(Page.ODvfpage);
        ApexPages.currentPage().getParameters().put('id', att.Id);

        ODApprovalController ctrl = new ODApprovalController();
        ctrl.managerComments = 'Rejected reason';

        Test.startTest();
        ctrl.rejectOD();
        Test.stopTest();

        Employee_Attendance__c updated = [
            SELECT OD_Approval_Status__c, Approval_Comments__c
            FROM Employee_Attendance__c
            WHERE Id = :att.Id
        ];

        System.assertEquals('Rejected', updated.OD_Approval_Status__c);
        System.assertEquals('Rejected reason', updated.Approval_Comments__c);
        System.assertEquals('Rejected', ctrl.odStatus);
    }

    @isTest
    static void testRejectOD_WithoutComments() {

        Employee_Attendance__c att = createAttendanceRecord();

        Test.setCurrentPage(Page.ODvfpage);
        ApexPages.currentPage().getParameters().put('id', att.Id);

        ODApprovalController ctrl = new ODApprovalController();
        ctrl.managerComments = '';

        ctrl.rejectOD();

        System.assertEquals('Comments are required for rejection.', ctrl.errorMessage);
    }
}