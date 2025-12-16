@isTest
public class LeaveRequestControllerTest {

    private static User createEmployee(String lastName, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName = 'Test',
            LastName = lastName,
            Email = lastName.toLowerCase() + '@test.com',
            Username = lastName.toLowerCase() + System.currentTimeMillis() + '@test.com',
            Alias = lastName.length() > 4 ? lastName.substring(0,4).toUpperCase() : lastName.toUpperCase(),
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ManagerId = managerId
        );
        insert u;
        return u;
    }

    private static Leave_Type__c createLeaveType(String name, String code, Decimal maxOccurrences) {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c = name,
            Leave_Code__c = code,
            Is_Active__c = true,
            Is_Fallback_Leave__c = false,
            Max_Lifetime_Occurrences__c = maxOccurrences
        );
        insert lt;
        return lt;
    }

    private static Employee_Leave_Balance__c createLeaveBalance(Id empId, Id ltId, String year, Boolean isEligible, Decimal totalAllocated) {
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = empId,
            Leave_Type__c = ltId,
            Year__c = year,
            Is_Eligible__c = isEligible,
            Total_Allocated__c = totalAllocated,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 0,
            Lifetime_Usage_Count__c = 0,
            Is_Active__c = true
        );
        insert lb;
        return lb;
    }

    // ==================== getManagerInfo TESTS ====================
    @isTest static void testGetManagerInfo_HasManager() {
        User mgr = createEmployee('Manager', null);
        User emp = createEmployee('Employee', mgr.Id);

        Test.startTest();
        Map<String,String> result = LeaveRequestController.getManagerInfo(emp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals('', result.get('managerId'));
    }

    @isTest static void testGetManagerInfo_NoManager() {
        User emp = createEmployee('NoManager', null);

        Test.startTest();
        Map<String,String> result = LeaveRequestController.getManagerInfo(emp.Id);
        Test.stopTest();

        System.assertEquals('', result.get('managerId'));
    }

    @isTest static void testGetManagerInfo_InvalidEmployee() {
        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LeaveRequestController.getManagerInfo('001000000000000');
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown);
    }

    // ==================== validateLeaveEligibility TESTS ====================
    @isTest static void testValidateLeaveEligibility_Eligible() {
        User mgr = createEmployee('MgrValid', null);
        User emp = createEmployee('EmpValid', mgr.Id);
        Leave_Type__c lt = createLeaveType('Annual', 'AL', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 10);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 5);
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('isEligible'));
    }

    @isTest static void testValidateLeaveEligibility_NoBalance() {
        User emp = createEmployee('EmpNoBal', null);
        Leave_Type__c lt = createLeaveType('Sick', 'SL', null);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
    }

    @isTest static void testValidateLeaveEligibility_NotEligible() {
        User emp = createEmployee('EmpIneligible', null);
        Leave_Type__c lt = createLeaveType('Sick', 'SL', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), false, 10);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
    }

    @isTest static void testValidateLeaveEligibility_InsufficientBalance() {
        User emp = createEmployee('EmpLowBal', null);
        Leave_Type__c lt = createLeaveType('Annual', 'AL', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 2);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 5);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
    }

    // ==================== submitLeaveRequest TESTS ====================
    @isTest static void testSubmitLeaveRequest_Success() {
        User mgr = createEmployee('MgrSubmit', null);
        User emp = createEmployee('EmpSubmit', mgr.Id);
        Leave_Type__c lt = createLeaveType('TestLeave', 'TL', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 10);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Reason__c = 'Test reason'
        );

        Test.startTest();
        String lrId = LeaveRequestController.submitLeaveRequest(lr);
        Test.stopTest();

        System.assertNotEquals(null, lrId);
    }

    @isTest static void testSubmitLeaveRequest_NoEmployee() {
        Leave_Request__c lr = new Leave_Request__c(
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LeaveRequestController.submitLeaveRequest(lr);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown);
    }

    @isTest static void testSubmitLeaveRequest_NoManager() {
        User emp = createEmployee('EmpNoMgr', null);
        Leave_Type__c lt = createLeaveType('Test', 'T1', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 10);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            LeaveRequestController.submitLeaveRequest(lr);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();
        System.assert(exceptionThrown);
    }

    // ==================== cancelLeaveRequest TESTS ====================
    @isTest static void testCancelLeaveRequest_Success_Pending() {
        User mgr = createEmployee('MgrCancel', null);
        User emp = createEmployee('EmpCancel', mgr.Id);
        Leave_Type__c lt = createLeaveType('CancelLeave', 'CL', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 10);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Pending',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Test cancel');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest static void testCancelLeaveRequest_Success_Approved() {
        User mgr = createEmployee('MgrCancelApp', null);
        User emp = createEmployee('EmpCancelApp', mgr.Id);
        Leave_Type__c lt = createLeaveType('ApprovedCancel', 'AC', null);
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()), true, 10);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Approved',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Admin cancel');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest static void testCancelLeaveRequest_AlreadyCancelled() {
        User mgr = createEmployee('MgrAlreadyCancel', null);
        User emp = createEmployee('EmpAlreadyCancel', mgr.Id);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Cancelled',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Test');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    @isTest static void testCancelLeaveRequest_Completed() {
        User mgr = createEmployee('MgrCompleted', null);
        User emp = createEmployee('EmpCompleted', mgr.Id);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Completed',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Test');
        Test.stopTest();

        System.assertNotEquals(null, result);
    }

    // ==================== getPastLeaveRequests TESTS ====================
    @isTest static void testGetPastLeaveRequests_Empty() {
        User emp = createEmployee('EmpNoRequests', null);

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getPastLeaveRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(0, requests.size());
    }

    @isTest static void testGetPastLeaveRequests_WithData() {
        User emp = createEmployee('EmpPastRequests', null);
        Leave_Type__c lt = createLeaveType('PastTest', 'PT', null);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today(),
            Total_Days__c = 1,
            Status__c = 'Approved',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getPastLeaveRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(1, requests.size());
    }

    // ==================== getCancellableLeaveRequests TESTS ====================
    @isTest static void testGetCancellableLeaveRequests_Valid() {
        User emp = createEmployee('EmpCancellable', null);
        Leave_Type__c lt = createLeaveType('Cancellable', 'CAN', null);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(2),
            Total_Days__c = 2,
            Status__c = 'Pending',
            Is_Active__c = true
        );
        insert lr;

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getCancellableLeaveRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(1, requests.size());
    }

    @isTest static void testGetCancellableLeaveRequests_Empty() {
        User emp = createEmployee('EmpNoCancellable', null);

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getCancellableLeaveRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(0, requests.size());
    }
}