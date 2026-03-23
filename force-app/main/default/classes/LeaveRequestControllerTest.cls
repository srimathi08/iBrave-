@isTest
public class LeaveRequestControllerTest {

    // ==================== HELPER METHODS ====================
    
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

    private static Leave_Type__c createLeaveType(String name, String code) {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c = name,
            Leave_Code__c = code,
            Is_Active__c = true,
            Is_Fallback_Leave__c = false,
            Max_Lifetime_Occurrences__c = null
        );
        insert lt;
        return lt;
    }
    
    private static Leave_Type__c createLeaveTypeWithLifetimeLimit(String name, String code, Decimal maxOccurrences) {
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

    private static Employee_Leave_Balance__c createLeaveBalance(Id empId, Id ltId, String year) {
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = empId,
            Leave_Type__c = ltId,
            Year__c = year,
            Is_Eligible__c = true,
            Total_Allocated__c = 20,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 0,
            Is_Active__c = true
        );
        insert lb;
        return lb;
    }
    
    private static Holiday__c createHoliday(String name, Date holidayDate) {
        Holiday__c h = new Holiday__c(
            Name = name,
            Holiday_Date__c = holidayDate,
            Is_Active__c = true,
            Holiday_Type__c='Festival'
        );
        insert h;
        return h;
    }

    // ==================== getManagerInfo TESTS ====================
    
    @isTest 
    static void testGetManagerInfo_HasManager() {
        User mgr = createEmployee('Manager', null);
        User emp = createEmployee('Employee', mgr.Id);

        Test.startTest();
        Map<String,String> result = LeaveRequestController.getManagerInfo(emp.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assertNotEquals('', result.get('managerId'));
        System.assert(result.get('managerName') != null);
        System.assert(result.get('managerName') != 'No Manager Assigned');
        System.assert(result.get('managerEmail') != '');
    }

    @isTest 
    static void testGetManagerInfo_NoManager() {
        User emp = createEmployee('NoManager', null);

        Test.startTest();
        Map<String,String> result = LeaveRequestController.getManagerInfo(emp.Id);
        Test.stopTest();

        System.assertEquals('', result.get('managerId'));
        System.assertEquals('No Manager Assigned', result.get('managerName'));
        System.assertEquals('', result.get('managerEmail'));
    }

    // ==================== validateLeaveEligibility TESTS ====================
    
    @isTest 
    static void testValidateLeaveEligibility_Eligible() {
        User mgr = createEmployee('MgrValid', null);
        User emp = createEmployee('EmpValid', mgr.Id);
        Leave_Type__c lt = createLeaveType('Annual', 'AL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('isEligible'));
        System.assertEquals('Eligible', (String)result.get('message'));
        System.assertNotEquals(null, result.get('availableBalance'));
    }

    @isTest 
    static void testValidateLeaveEligibility_NotEligible() {
        User mgr = createEmployee('MgrInvalid', null);
        User emp = createEmployee('EmpInvalid', mgr.Id);
        Leave_Type__c lt = createLeaveType('Sick', 'SL');
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = false,
            Eligibility_Reason__c = 'Not eligible for this leave type',
            Total_Allocated__c = 0,
            Is_Active__c = true
        );
        insert lb;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
    }
    
    @isTest 
    static void testValidateLeaveEligibility_NoBalanceRecord() {
        User mgr = createEmployee('MgrNoBalance', null);
        User emp = createEmployee('EmpNoBalance', mgr.Id);
        Leave_Type__c lt = createLeaveType('NoBalance', 'NB');
        // Do NOT create a balance record

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
        System.assertEquals('You are not eligible for this leave type. Please contact HR.', (String)result.get('message'));
    }
    
    @isTest 
    static void testValidateLeaveEligibility_InsufficientBalance() {
        User mgr = createEmployee('MgrInsuff', null);
        User emp = createEmployee('EmpInsuff', mgr.Id);
        Leave_Type__c lt = createLeaveType('LowBalance', 'LB');
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 2,
            Used__c = 1,
            Booked__c = 0,
            Pending_Approval__c = 0,
            Is_Active__c = true
        );
        insert lb;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 5); // Request 5 days
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
        System.assert(((String)result.get('message')).contains('Insufficient balance'));
    }
    
    @isTest 
    static void testValidateLeaveEligibility_LifetimeLimitReached() {
        User mgr = createEmployee('MgrLife', null);
        User emp = createEmployee('EmpLife', mgr.Id);
        Leave_Type__c lt = createLeaveTypeWithLifetimeLimit('Maternity', 'MAT', 2);
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 90,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 0,
            Lifetime_Usage_Count__c = 2, // Already used 2 times
            Is_Active__c = true
        );
        insert lb;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.validateLeaveEligibility(emp.Id, lt.Id, 1);
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('isEligible'));
        System.assert(((String)result.get('message')).contains('Maximum lifetime usage reached'));
    }

    // ==================== checkOverlappingLeave TESTS ====================
    
    @isTest 
    static void testCheckOverlappingLeave_HasOverlap() {
        User mgr = createEmployee('MgrOverlap', null);
        User emp = createEmployee('EmpOverlap', mgr.Id);
        Leave_Type__c lt = createLeaveType('OverlapLeave', 'OL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));
        
        // Create existing leave request
        Leave_Request__c existingLeave = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(10),
            Total_Days__c = 6,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert existingLeave;

        Test.startTest();
        // Request dates that overlap with existing leave
        Map<String,Object> result = LeaveRequestController.checkOverlappingLeave(
            emp.Id, 
            Date.today().addDays(8), // Overlaps with existing 5-10
            Date.today().addDays(15)
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('hasOverlap'));
        System.assertEquals(1, (Integer)result.get('conflictCount'));
    }
    
    @isTest 
    static void testCheckOverlappingLeave_NoOverlap() {
        User mgr = createEmployee('MgrNoOverlap', null);
        User emp = createEmployee('EmpNoOverlap', mgr.Id);
        Leave_Type__c lt = createLeaveType('NoOverlapLeave', 'NOL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));
        
        // Create existing leave request
        Leave_Request__c existingLeave = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(10),
            Total_Days__c = 6,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert existingLeave;

        Test.startTest();
        // Request dates that do NOT overlap
        Map<String,Object> result = LeaveRequestController.checkOverlappingLeave(
            emp.Id, 
            Date.today().addDays(15), 
            Date.today().addDays(20)
        );
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('hasOverlap'));
        System.assertEquals(0, (Integer)result.get('conflictCount'));
    }
    
    @isTest 
    static void testCheckOverlappingLeave_PendingStatus() {
        User mgr = createEmployee('MgrPending', null);
        User emp = createEmployee('EmpPending', mgr.Id);
        Leave_Type__c lt = createLeaveType('PendingLeave', 'PEN');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));
        
        // Create pending leave request
        Leave_Request__c pendingLeave = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(5),
            End_Date__c = Date.today().addDays(10),
            Total_Days__c = 6,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert pendingLeave;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.checkOverlappingLeave(
            emp.Id, 
            Date.today().addDays(5), 
            Date.today().addDays(10)
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('hasOverlap'));
    }

    // ==================== submitLeaveRequest TESTS ====================
    
    @isTest 
    static void testSubmitLeaveRequest_Success() {
        User mgr = createEmployee('MgrSubmit', null);
        User emp = createEmployee('EmpSubmit', mgr.Id);
        Leave_Type__c lt = createLeaveType('TestLeave', 'TL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Reason__c = 'Test'
        );

        Test.startTest();
        String lrId = LeaveRequestController.submitLeaveRequest(lr);
        Test.stopTest();

        System.assertNotEquals(null, lrId);
        
        // Verify the leave request was created correctly
        Leave_Request__c createdLr = [SELECT Status__c, Manager__c, Is_Active__c FROM Leave_Request__c WHERE Id = :lrId];
        System.assertEquals('Pending', createdLr.Status__c);
        System.assertEquals(mgr.Id, createdLr.Manager__c);
        System.assertEquals(true, createdLr.Is_Active__c);
    }
    
    @isTest 
    static void testSubmitLeaveRequest_HalfDay() {
        User mgr = createEmployee('MgrHalf', null);
        User emp = createEmployee('EmpHalf', mgr.Id);
        Leave_Type__c lt = createLeaveType('HalfDayLeave', 'HD');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 0.5,
            Is_Half_Day__c = true,
            Half_Day_Type__c = 'First Half',
            Reason__c = 'Half day test'
        );

        Test.startTest();
        String lrId = LeaveRequestController.submitLeaveRequest(lr);
        Test.stopTest();

        System.assertNotEquals(null, lrId);
    }
    
    @isTest 
    static void testSubmitLeaveRequest_NoManager() {
        User emp = createEmployee('EmpNoMgr', null); // No manager
        Leave_Type__c lt = createLeaveType('NoMgrLeave', 'NML');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Reason__c = 'Test'
        );

        Test.startTest();
        try {
            LeaveRequestController.submitLeaveRequest(lr);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('manager') || e.getMessage().contains('Manager'));
        }
        Test.stopTest();
    }
    
    @isTest 
    static void testSubmitLeaveRequest_NotEligible() {
        User mgr = createEmployee('MgrNotElig', null);
        User emp = createEmployee('EmpNotElig', mgr.Id);
        Leave_Type__c lt = createLeaveType('NotEligLeave', 'NEL');
        // Create balance with insufficient days
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 1,
            Used__c = 1, // All used up
            Booked__c = 0,
            Pending_Approval__c = 0,
            Is_Active__c = true
        );
        insert lb;

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(5),
            Total_Days__c = 5,
            Reason__c = 'Test'
        );

        Test.startTest();
        try {
            LeaveRequestController.submitLeaveRequest(lr);
            System.assert(false, 'Expected AuraHandledException');
        } catch (AuraHandledException e) {
            //System.assert(e.getMessage().contains('Insufficient') || e.getMessage().contains('Error'));
        }
        Test.stopTest();
    }

    // ==================== cancelLeaveRequest TESTS ====================
    
    @isTest 
    static void testCancelLeaveRequest_Success() {
        User mgr = createEmployee('MgrCancel', null);
        User emp = createEmployee('EmpCancel', mgr.Id);
        Leave_Type__c lt = createLeaveType('CancelLeave', 'CL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Test cancel');
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('success'));
    }
    
    @isTest 
    static void testCancelLeaveRequest_PendingStatus() {
        User mgr = createEmployee('MgrCancelPend', null);
        User emp = createEmployee('EmpCancelPend', mgr.Id);
        Leave_Type__c lt = createLeaveType('CancelPending', 'CP');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Cancel pending');
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('success'));
    }
    
    @isTest 
    static void testCancelLeaveRequest_AlreadyCancelled() {
        User mgr = createEmployee('MgrAlreadyCancel', null);
        User emp = createEmployee('EmpAlreadyCancel', mgr.Id);
        Leave_Type__c lt = createLeaveType('AlreadyCancelled', 'AC');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Cancelled',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Try cancel again');
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('success'));
        System.assert(((String)result.get('message')).contains('already cancelled'));
    }
    
    @isTest 
    static void testCancelLeaveRequest_Completed() {
        User mgr = createEmployee('MgrCompleted', null);
        User emp = createEmployee('EmpCompleted', mgr.Id);
        Leave_Type__c lt = createLeaveType('CompletedLeave', 'COM');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(-3),
            Total_Days__c = 3,
            Status__c = 'Completed',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Try cancel completed');
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('success'));
        System.assert(((String)result.get('message')).contains('completed'));
    }
    
    @isTest 
    static void testCancelLeaveRequest_Rejected() {
        User mgr = createEmployee('MgrRejected', null);
        User emp = createEmployee('EmpRejected', mgr.Id);
        Leave_Type__c lt = createLeaveType('RejectedLeave', 'REJ');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(1),
            Total_Days__c = 1,
            Status__c = 'Rejected',
            Is_Active__c = true,
            Rejection_Reason__c='Insufficient Balance',
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.cancelLeaveRequest(lr.Id, mgr.Id, 'Try cancel rejected');
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('success'));
        System.assert(((String)result.get('message')).contains('rejected'));
    }

    // ==================== updateLeaveBalance TESTS ====================
    
    @isTest 
    static void testUpdateLeaveBalance_ApprovedToCompleted() {
        User mgr = createEmployee('MgrComplete', null);
        User emp = createEmployee('EmpComplete', mgr.Id);
        Leave_Type__c lt = createLeaveType('CompleteLeave', 'CMP');
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 20,
            Used__c = 0,
            Booked__c = 5,
            Pending_Approval__c = 0,
            Is_Active__c = true
        );
        insert lb;

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(-5),
            End_Date__c = Date.today().addDays(-1),
            Total_Days__c = 5,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        LeaveRequestController.updateLeaveBalance(lr.Id, 'Completed', 'Approved');
        Test.stopTest();

        Employee_Leave_Balance__c updatedLb = [SELECT Used__c, Booked__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id];
        System.assertEquals(5, updatedLb.Used__c);
        System.assertEquals(0, updatedLb.Booked__c);
    }
    
    @isTest 
    static void testUpdateLeaveBalance_PendingToRejected() {
        User mgr = createEmployee('MgrReject', null);
        User emp = createEmployee('EmpReject', mgr.Id);
        Leave_Type__c lt = createLeaveType('RejectLeave', 'RJT');
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 20,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 3,
            Is_Active__c = true
        );
        insert lb;

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(3),
            Total_Days__c = 3,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        LeaveRequestController.updateLeaveBalance(lr.Id, 'Rejected', 'Pending');
        Test.stopTest();

        Employee_Leave_Balance__c updatedLb = [SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id];
        System.assertEquals(0, updatedLb.Pending_Approval__c);
    }
    
    @isTest 
    static void testUpdateLeaveBalance_PendingToApproved() {
        User mgr = createEmployee('MgrApprove', null);
        User emp = createEmployee('EmpApprove', mgr.Id);
        Leave_Type__c lt = createLeaveType('ApproveLeave', 'APR');
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 20,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 2,
            Is_Active__c = true
        );
        insert lb;

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(2),
            Total_Days__c = 2,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        LeaveRequestController.updateLeaveBalance(lr.Id, 'Approved', 'Pending');
        Test.stopTest();

        Employee_Leave_Balance__c updatedLb = [SELECT Pending_Approval__c, Booked__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id];
        System.assertEquals(0, updatedLb.Pending_Approval__c);
        System.assertEquals(2, updatedLb.Booked__c);
    }
    
    @isTest 
    static void testUpdateLeaveBalance_LifetimeIncrement() {
        User mgr = createEmployee('MgrLifeInc', null);
        User emp = createEmployee('EmpLifeInc', mgr.Id);
        Leave_Type__c lt = createLeaveTypeWithLifetimeLimit('Paternity', 'PAT', 2);
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Year__c = String.valueOf(Date.today().year()),
            Is_Eligible__c = true,
            Total_Allocated__c = 15,
            Used__c = 0,
            Booked__c = 0,
            Pending_Approval__c = 15,
            Lifetime_Usage_Count__c = 0,
            Is_Active__c = true
        );
        insert lb;

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(15),
            Total_Days__c = 15,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        LeaveRequestController.updateLeaveBalance(lr.Id, 'Approved', 'Pending');
        Test.stopTest();

        Employee_Leave_Balance__c updatedLb = [SELECT Lifetime_Usage_Count__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id];
        System.assertEquals(1, updatedLb.Lifetime_Usage_Count__c);
    }

    // ==================== getPastLeaveRequests TESTS ====================
    
    @isTest 
    static void testGetPastLeaveRequests() {
        User mgr = createEmployee('MgrPast', null);
        User emp = createEmployee('EmpPast', mgr.Id);
        Leave_Type__c lt = createLeaveType('PastLeave', 'PL');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today(),
            End_Date__c = Date.today(),
            Total_Days__c = 1,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getPastLeaveRequests(emp.Id);
        Test.stopTest();

        System.assert(requests.size() >= 1);
    }
    
    @isTest 
    static void testGetPastLeaveRequests_Empty() {
        User mgr = createEmployee('MgrEmpty', null);
        User emp = createEmployee('EmpEmpty', mgr.Id);

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getPastLeaveRequests(emp.Id);
        Test.stopTest();

        System.assertEquals(0, requests.size());
    }

    // ==================== getCancellableLeaveRequests TESTS ====================
    
    @isTest 
    static void testGetCancellableLeaveRequests() {
        User mgr = createEmployee('MgrCancelList', null);
        User emp = createEmployee('EmpCancelList', mgr.Id);
        Leave_Type__c lt = createLeaveType('Cancellable', 'CAN');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(2),
            Total_Days__c = 2,
            Status__c = 'Pending',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getCancellableLeaveRequests(emp.Id);
        Test.stopTest();

        System.assert(requests.size() >= 1);
    }
    
    @isTest 
    static void testGetCancellableLeaveRequests_ApprovedStatus() {
        User mgr = createEmployee('MgrCancelAppr', null);
        User emp = createEmployee('EmpCancelAppr', mgr.Id);
        Leave_Type__c lt = createLeaveType('CancellableAppr', 'CAA');
        createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c = emp.Id,
            Leave_Type__c = lt.Id,
            Start_Date__c = Date.today().addDays(1),
            End_Date__c = Date.today().addDays(2),
            Total_Days__c = 2,
            Status__c = 'Approved',
            Is_Active__c = true,
            Year__c = String.valueOf(Date.today().year())
        );
        insert lr;

        Test.startTest();
        List<Leave_Request__c> requests = LeaveRequestController.getCancellableLeaveRequests(emp.Id);
        Test.stopTest();

        System.assert(requests.size() >= 1);
    }

    // ==================== checkHolidayConflict TESTS ====================
    
    @isTest 
    static void testCheckHolidayConflict_HasConflict() {
        // Create holiday within the leave period
        Date holidayDate = Date.today().addDays(5);
        createHoliday('Test Holiday', holidayDate);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.checkHolidayConflict(
            Date.today().addDays(3),
            Date.today().addDays(7)
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('hasConflict'));
        System.assertEquals(1, (Integer)result.get('holidayCount'));
        System.assertNotEquals(null, result.get('workingDays'));
    }
    
    @isTest 
    static void testCheckHolidayConflict_NoConflict() {
        // Create holiday outside the leave period
        Date holidayDate = Date.today().addDays(20);
        createHoliday('Far Holiday', holidayDate);

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.checkHolidayConflict(
            Date.today().addDays(1),
            Date.today().addDays(5)
        );
        Test.stopTest();

        System.assertEquals(false, (Boolean)result.get('hasConflict'));
        System.assertEquals(0, (Integer)result.get('holidayCount'));
    }
    
    @isTest 
    static void testCheckHolidayConflict_MultipleHolidays() {
        // Create multiple holidays within the leave period
        createHoliday('Holiday 1', Date.today().addDays(5));
        createHoliday('Holiday 2', Date.today().addDays(7));
        createHoliday('Holiday 3', Date.today().addDays(9));

        Test.startTest();
        Map<String,Object> result = LeaveRequestController.checkHolidayConflict(
            Date.today().addDays(3),
            Date.today().addDays(10)
        );
        Test.stopTest();

        System.assertEquals(true, (Boolean)result.get('hasConflict'));
        System.assertEquals(3, (Integer)result.get('holidayCount'));
    }
    
    @isTest 
    static void testCheckHolidayConflict_WorkingDaysCalculation() {
        // Test working days calculation (excludes weekends and holidays)
        Test.startTest();
        Map<String,Object> result = LeaveRequestController.checkHolidayConflict(
            Date.today(),
            Date.today().addDays(14) // 2 weeks
        );
        Test.stopTest();

        System.assertNotEquals(null, result.get('workingDays'));
        Integer workingDays = (Integer)result.get('workingDays');
        // Should be less than 15 due to weekends
        System.assert(workingDays <= 15);
    }
// ==================== revokeLeaveRequest TESTS ====================

@isTest
static void testRevokeLeaveRequest_Success_PendingFutureDate() {
    User mgr = createEmployee('MgrRevoke1', null);
    User emp = createEmployee('EmpRevoke1', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave1', 'RV1');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(5),
        End_Date__c   = Date.today().addDays(7),
        Total_Days__c = 3,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Personal reasons');
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('success'),
            'Expected success=true but got: ' + result.get('message'));
        System.assert(((String) result.get('message')).contains('revoked successfully'));

        Leave_Request__c updated = [SELECT Status__c, Cancelled_Reason__c FROM Leave_Request__c WHERE Id = :lr.Id];
        System.assertEquals('Cancelled', updated.Status__c);
        System.assertEquals('Personal reasons', updated.Cancelled_Reason__c);
    }
}

@isTest
static void testRevokeLeaveRequest_DefaultReason_WhenBlank() {
    User mgr = createEmployee('MgrRevoke2', null);
    User emp = createEmployee('EmpRevoke2', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave2', 'RV2');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(3),
        End_Date__c   = Date.today().addDays(5),
        Total_Days__c = 3,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, '');
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('success'));
        Leave_Request__c updated = [SELECT Cancelled_Reason__c FROM Leave_Request__c WHERE Id = :lr.Id];
        System.assertEquals('Revoked by employee', updated.Cancelled_Reason__c);
    }
}

@isTest
static void testRevokeLeaveRequest_BalanceRestored() {
    User mgr = createEmployee('MgrRevoke3', null);
    User emp = createEmployee('EmpRevoke3', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave3', 'RV3');
    Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
        Employee__c        = emp.Id,
        Leave_Type__c      = lt.Id,
        Year__c            = String.valueOf(Date.today().year()),
        Is_Eligible__c     = true,
        Total_Allocated__c = 20,
        Used__c            = 0,
        Booked__c          = 0,
        Pending_Approval__c = 3,
        Is_Active__c       = true
    );
    insert lb;

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(4),
        End_Date__c   = Date.today().addDays(6),
        Total_Days__c = 3,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        LeaveRequestController.revokeLeaveRequest(lr.Id, 'Changed plans');
        Test.stopTest();
    }

    Employee_Leave_Balance__c updated = [SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id];
    System.assertEquals(0, updated.Pending_Approval__c, 'Pending balance should be fully restored to 0');
}

@isTest
static void testRevokeLeaveRequest_AlreadyCancelled() {
    User mgr = createEmployee('MgrRevoke4', null);
    User emp = createEmployee('EmpRevoke4', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave4', 'RV4');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(3),
        End_Date__c   = Date.today().addDays(5),
        Total_Days__c = 3,
        Status__c     = 'Cancelled',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Try again');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('already cancelled'));
    }
}

@isTest
static void testRevokeLeaveRequest_CompletedStatus() {
    User mgr = createEmployee('MgrRevoke5', null);
    User emp = createEmployee('EmpRevoke5', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave5', 'RV5');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(-5),
        End_Date__c   = Date.today().addDays(-3),
        Total_Days__c = 3,
        Status__c     = 'Completed',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Try revoke completed');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('completed'));
    }
}

@isTest
static void testRevokeLeaveRequest_RejectedStatus() {
    User mgr = createEmployee('MgrRevoke6', null);
    User emp = createEmployee('EmpRevoke6', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave6', 'RV6');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(3),
        End_Date__c   = Date.today().addDays(5),
        Total_Days__c = 3,
        Status__c     = 'Rejected',
        Is_Active__c  = true,
        Rejection_Reason__c = 'Not enough balance',
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Try revoke rejected');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('rejected'));
    }
}

@isTest
static void testRevokeLeaveRequest_ApprovedStatus_Blocked() {
    User mgr = createEmployee('MgrRevoke7', null);
    User emp = createEmployee('EmpRevoke7', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave7', 'RV7');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(3),
        End_Date__c   = Date.today().addDays(5),
        Total_Days__c = 3,
        Status__c     = 'Approved',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Try revoke approved');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('Approved leave requests cannot be revoked'));
    }
}

@isTest
static void testRevokeLeaveRequest_LeaveAlreadyStarted() {
    User mgr = createEmployee('MgrRevoke8', null);
    User emp = createEmployee('EmpRevoke8', mgr.Id);
    Leave_Type__c lt = createLeaveType('RevokeLeave8', 'RV8');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    // Start date is in the PAST — leave has already started
    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(-2),
        End_Date__c   = Date.today().addDays(2),
        Total_Days__c = 5,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.revokeLeaveRequest(lr.Id, 'Late revoke');
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('success'));
        System.assert(((String) result.get('message')).contains('already started'));
    }
}

// ==================== canRevokeLeave TESTS ====================

@isTest
static void testCanRevokeLeave_True_PendingFutureLeave() {
    User mgr = createEmployee('MgrCanRevoke1', null);
    User emp = createEmployee('EmpCanRevoke1', mgr.Id);
    Leave_Type__c lt = createLeaveType('CanRevokeLeave1', 'CR1');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(5),
        End_Date__c   = Date.today().addDays(7),
        Total_Days__c = 3,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.canRevokeLeave(lr.Id);
        Test.stopTest();

        System.assertEquals(true, (Boolean) result.get('canRevoke'));
        System.assertEquals('', (String) result.get('reason'));
    }
}

@isTest
static void testCanRevokeLeave_False_NotPendingStatus() {
    User mgr = createEmployee('MgrCanRevoke2', null);
    User emp = createEmployee('EmpCanRevoke2', mgr.Id);
    Leave_Type__c lt = createLeaveType('CanRevokeLeave2', 'CR2');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(5),
        End_Date__c   = Date.today().addDays(7),
        Total_Days__c = 3,
        Status__c     = 'Approved',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.canRevokeLeave(lr.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('canRevoke'));
        System.assert(((String) result.get('reason')).contains('Approved'));
    }
}

@isTest
static void testCanRevokeLeave_False_LeaveAlreadyStarted() {
    User mgr = createEmployee('MgrCanRevoke3', null);
    User emp = createEmployee('EmpCanRevoke3', mgr.Id);
    Leave_Type__c lt = createLeaveType('CanRevokeLeave3', 'CR3');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(-3),
        End_Date__c   = Date.today().addDays(2),
        Total_Days__c = 6,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.canRevokeLeave(lr.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('canRevoke'));
        System.assert(((String) result.get('reason')).contains('already started'));
    }
}

@isTest
static void testCanRevokeLeave_False_WrongEmployee() {
    User mgr  = createEmployee('MgrCanRevoke4', null);
    User emp1 = createEmployee('EmpCanRevoke4A', mgr.Id);
    User emp2 = createEmployee('EmpCanRevoke4B', mgr.Id);
    Leave_Type__c lt = createLeaveType('CanRevokeLeave4', 'CR4');
    createLeaveBalance(emp1.Id, lt.Id, String.valueOf(Date.today().year()));

    // Leave belongs to emp1
    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp1.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(5),
        End_Date__c   = Date.today().addDays(7),
        Total_Days__c = 3,
        Status__c     = 'Pending',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    // emp2 tries to check revocability on emp1's leave
    System.runAs(emp2) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.canRevokeLeave(lr.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('canRevoke'));
        System.assert(((String) result.get('reason')).contains('Not your leave request'));
    }
}

@isTest
static void testCanRevokeLeave_False_CancelledStatus() {
    User mgr = createEmployee('MgrCanRevoke5', null);
    User emp = createEmployee('EmpCanRevoke5', mgr.Id);
    Leave_Type__c lt = createLeaveType('CanRevokeLeave5', 'CR5');
    createLeaveBalance(emp.Id, lt.Id, String.valueOf(Date.today().year()));

    Leave_Request__c lr = new Leave_Request__c(
        Employee__c = emp.Id,
        Leave_Type__c = lt.Id,
        Start_Date__c = Date.today().addDays(5),
        End_Date__c   = Date.today().addDays(7),
        Total_Days__c = 3,
        Status__c     = 'Cancelled',
        Is_Active__c  = true,
        Year__c       = String.valueOf(Date.today().year())
    );
    insert lr;

    System.runAs(emp) {
        Test.startTest();
        Map<String, Object> result = LeaveRequestController.canRevokeLeave(lr.Id);
        Test.stopTest();

        System.assertEquals(false, (Boolean) result.get('canRevoke'));
        System.assert(((String) result.get('reason')).contains('Cancelled'));
    }
}
}