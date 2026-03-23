@isTest
public class LeaveRequestTriggerHandlerTest {

    // ==================== HELPER METHODS ====================

    private static User createEmployee(String lastName, Id managerId) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        User u = new User(
            FirstName         = 'Test',
            LastName          = lastName,
            Email             = lastName.toLowerCase() + '@test.com',
            Username          = lastName.toLowerCase() + System.currentTimeMillis() + '@test.com',
            Alias             = (lastName.length() > 4 ? lastName.substring(0, 4) : lastName).toUpperCase(),
            TimeZoneSidKey    = 'Asia/Kolkata',
            LocaleSidKey      = 'en_US',
            EmailEncodingKey  = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId         = p.Id,
            ManagerId         = managerId
        );
        insert u;
        return u;
    }

    private static Leave_Type__c createLeaveType(String name, String code) {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c          = name,
            Leave_Code__c               = code,
            Is_Active__c                = true,
            Is_Fallback_Leave__c        = false,
            Max_Lifetime_Occurrences__c = null
        );
        insert lt;
        return lt;
    }

    private static Leave_Type__c createLeaveTypeWithLifetimeLimit(String name, String code, Decimal maxOcc) {
        Leave_Type__c lt = new Leave_Type__c(
            Leave_Type_Name__c          = name,
            Leave_Code__c               = code,
            Is_Active__c                = true,
            Is_Fallback_Leave__c        = false,
            Max_Lifetime_Occurrences__c = maxOcc
        );
        insert lt;
        return lt;
    }

    private static Employee_Leave_Balance__c createLeaveBalance(
        Id empId, Id ltId, String year,
        Decimal pending, Decimal booked, Decimal used, Decimal allocated
    ) {
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c         = empId,
            Leave_Type__c       = ltId,
            Year__c             = year,
            Is_Eligible__c      = true,
            Total_Allocated__c  = allocated,
            Used__c             = used,
            Booked__c           = booked,
            Pending_Approval__c = pending,
            Is_Active__c        = true
        );
        insert lb;
        return lb;
    }

    private static Leave_Request__c createLeaveRequest(
        Id empId, Id ltId, String status,
        Date startDate, Date endDate, Decimal totalDays
    ) {
        Leave_Request__c lr = new Leave_Request__c(
            Employee__c   = empId,
            Leave_Type__c = ltId,
            Start_Date__c = startDate,
            End_Date__c   = endDate,
            Total_Days__c = totalDays,
            Status__c     = status,
            Is_Active__c  = true,
            Year__c       = String.valueOf(startDate.year())
        );
        insert lr;
        return lr;
    }

    // ==================== AFTER UPDATE — STATUS CHANGE TESTS ====================

    @isTest
    static void testAfterUpdate_PendingToApproved_MovesToBooked() {
        User mgr = createEmployee('MgrUpd1', null);
        User emp = createEmployee('EmpUpd1', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave1', 'UL1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 3, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );

        Test.startTest();
        lr.Status__c = 'Approved';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending should be cleared after approval');
        System.assertEquals(3, updated.Booked__c,           'Days should move to Booked after approval');
    }

    @isTest
    static void testAfterUpdate_PendingToRejected_ClearsPending() {
        User mgr = createEmployee('MgrUpd2', null);
        User emp = createEmployee('EmpUpd2', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave2', 'UL2');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 4, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(3), Date.today().addDays(6), 4
        );

        Test.startTest();
        lr.Status__c        = 'Rejected';
        lr.Rejection_Reason__c = 'Insufficient balance';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending should be cleared after rejection');
        System.assertEquals(0, updated.Booked__c,           'Booked should remain 0 after rejection');
        System.assertEquals(0, updated.Used__c,             'Used should remain 0 after rejection');
    }

    @isTest
    static void testAfterUpdate_PendingToCancelled_ClearsPending() {
        User mgr = createEmployee('MgrUpd3', null);
        User emp = createEmployee('EmpUpd3', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave3', 'UL3');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 2, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(6), 2
        );

        Test.startTest();
        lr.Status__c         = 'Cancelled';
        lr.Cancelled_Reason__c = 'Change of plans';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending should be cleared after cancellation');
        System.assertEquals(0, updated.Booked__c,           'Booked should remain 0 after cancellation from Pending');
    }

    @isTest
    static void testAfterUpdate_ApprovedToCancelled_ClearsBooked() {
        User mgr = createEmployee('MgrUpd4', null);
        User emp = createEmployee('EmpUpd4', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave4', 'UL4');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 5, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Approved',
            Date.today().addDays(5), Date.today().addDays(9), 5
        );

        Test.startTest();
        lr.Status__c         = 'Cancelled';
        lr.Cancelled_Reason__c = 'Manager cancelled';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Booked__c, 'Booked should be cleared after cancellation from Approved');
        System.assertEquals(0, updated.Used__c,   'Used should remain 0');
    }

    @isTest
    static void testAfterUpdate_ApprovedToCompleted_MovesToUsed() {
        User mgr = createEmployee('MgrUpd5', null);
        User emp = createEmployee('EmpUpd5', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave5', 'UL5');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 5, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Approved',
            Date.today().addDays(-5), Date.today().addDays(-1), 5
        );

        Test.startTest();
        lr.Status__c = 'Completed';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Booked__c, 'Booked should be cleared after completion');
        System.assertEquals(5, updated.Used__c,   'Used should increase after completion');
    }

    @isTest
    static void testAfterUpdate_NoStatusChange_BalanceUnchanged() {
        // Updating a non-status field should NOT trigger any balance change
        User mgr = createEmployee('MgrUpd6', null);
        User emp = createEmployee('EmpUpd6', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdLeave6', 'UL6');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 3, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );

        Test.startTest();
        lr.Reason__c = 'Updated reason only — status unchanged';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(3, updated.Pending_Approval__c,
            'Balance must not change when status is not updated');
    }

    @isTest
    static void testAfterUpdate_LifetimeCountIncremented_OnApproval() {
        User mgr = createEmployee('MgrUpdLife', null);
        User emp = createEmployee('EmpUpdLife', mgr.Id);
        Leave_Type__c lt = createLeaveTypeWithLifetimeLimit('Maternity', 'MAT', 2);
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = new Employee_Leave_Balance__c(
            Employee__c          = emp.Id,
            Leave_Type__c        = lt.Id,
            Year__c              = year,
            Is_Eligible__c       = true,
            Total_Allocated__c   = 90,
            Used__c              = 0,
            Booked__c            = 0,
            Pending_Approval__c  = 90,
            Lifetime_Usage_Count__c = 0,
            Is_Active__c         = true
        );
        insert lb;

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(10), Date.today().addDays(99), 90
        );

        Test.startTest();
        lr.Status__c = 'Approved';
        update lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Lifetime_Usage_Count__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(1, updated.Lifetime_Usage_Count__c,
            'Lifetime usage count must increment by 1 on approval for event-based leave');
    }

    @isTest
    static void testAfterUpdate_BulkStatusChange_AllBalancesUpdated() {
        User mgr = createEmployee('MgrUpdBulk', null);
        User emp = createEmployee('EmpUpdBulk', mgr.Id);
        Leave_Type__c lt = createLeaveType('UpdBulk', 'BLK');
        String year = String.valueOf(Date.today().year());
        // 6 days pending (3 + 3)
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 6, 0, 0, 20);

        Leave_Request__c lr1 = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );
        Leave_Request__c lr2 = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(10), Date.today().addDays(12), 3
        );

        Test.startTest();
        lr1.Status__c = 'Approved';
        lr2.Status__c = 'Approved';
        update new List<Leave_Request__c>{ lr1, lr2 };
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'All pending days should be cleared');
        System.assertEquals(6, updated.Booked__c,           'All days should move to Booked');
    }

    // ==================== BEFORE DELETE — PENDING TESTS ====================

    @isTest
    static void testDelete_PendingRequest_ReversesPendingBalance() {
        User mgr = createEmployee('MgrDelPend', null);
        User emp = createEmployee('EmpDelPend', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelPending', 'DP1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 5, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(9), 5
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending should be fully reversed on delete');
        System.assertEquals(0, updated.Booked__c,           'Booked should remain unchanged');
        System.assertEquals(0, updated.Used__c,             'Used should remain unchanged');
    }

    @isTest
    static void testDelete_PendingRequest_PartialPendingBalance() {
        User mgr = createEmployee('MgrDelPart', null);
        User emp = createEmployee('EmpDelPart', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelPartial', 'DP2');
        String year = String.valueOf(Date.today().year());
        // 8 days pending total; only deleting 3
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 8, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(5, updated.Pending_Approval__c,
            'Only the deleted request days should be reversed; remaining must stay');
    }

    // ==================== BEFORE DELETE — APPROVED TESTS ====================

    @isTest
    static void testDelete_ApprovedRequest_ReversesBookedBalance() {
        User mgr = createEmployee('MgrDelAppr', null);
        User emp = createEmployee('EmpDelAppr', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelApproved', 'DA1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 4, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Approved',
            Date.today().addDays(3), Date.today().addDays(6), 4
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Booked__c,           'Booked should be fully reversed on delete');
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending should remain unchanged');
        System.assertEquals(0, updated.Used__c,             'Used should remain unchanged');
    }

    @isTest
    static void testDelete_ApprovedRequest_PartialBookedBalance() {
        User mgr = createEmployee('MgrDelApprPart', null);
        User emp = createEmployee('EmpDelApprPart', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelApprPartial', 'DA2');
        String year = String.valueOf(Date.today().year());
        // 10 booked; deleting 6 → 4 remain
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 10, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Approved',
            Date.today().addDays(3), Date.today().addDays(8), 6
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Booked__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(4, updated.Booked__c, 'Only deleted days should be removed from Booked');
    }

    // ==================== BEFORE DELETE — NON-REVERSIBLE STATUSES ====================

    @isTest
    static void testDelete_CancelledRequest_NoBalanceChange() {
        User mgr = createEmployee('MgrDelCancl', null);
        User emp = createEmployee('EmpDelCancl', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelCancelled', 'DC1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 2, 3, 5, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Cancelled',
            Date.today().addDays(1), Date.today().addDays(3), 3
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(2, updated.Pending_Approval__c, 'Pending must not change for Cancelled delete');
        System.assertEquals(3, updated.Booked__c,           'Booked must not change for Cancelled delete');
        System.assertEquals(5, updated.Used__c,             'Used must not change for Cancelled delete');
    }

    @isTest
    static void testDelete_RejectedRequest_NoBalanceChange() {
        User mgr = createEmployee('MgrDelRej', null);
        User emp = createEmployee('EmpDelRej', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelRejected', 'DR1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 1, 2, 4, 20);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c         = emp.Id,
            Leave_Type__c       = lt.Id,
            Start_Date__c       = Date.today().addDays(1),
            End_Date__c         = Date.today().addDays(2),
            Total_Days__c       = 2,
            Status__c           = 'Rejected',
            Rejection_Reason__c = 'Insufficient balance',
            Is_Active__c        = true,
            Year__c             = year
        );
        insert lr;

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(1, updated.Pending_Approval__c, 'Pending must not change for Rejected delete');
        System.assertEquals(2, updated.Booked__c,           'Booked must not change for Rejected delete');
        System.assertEquals(4, updated.Used__c,             'Used must not change for Rejected delete');
    }

    @isTest
    static void testDelete_CompletedRequest_NoBalanceChange() {
        User mgr = createEmployee('MgrDelComp', null);
        User emp = createEmployee('EmpDelComp', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelCompleted', 'DCO');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 0, 6, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Completed',
            Date.today().addDays(-10), Date.today().addDays(-5), 6
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c, 'Pending must not change for Completed delete');
        System.assertEquals(0, updated.Booked__c,           'Booked must not change for Completed delete');
        System.assertEquals(6, updated.Used__c,             'Used must not change for Completed delete');
    }

    // ==================== BEFORE DELETE — FLOOR GUARD ====================

    @isTest
    static void testDelete_PendingRequest_NeverGoesBelowZero() {
        User mgr = createEmployee('MgrDelFloor', null);
        User emp = createEmployee('EmpDelFloor', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelFloor', 'DF1');
        String year = String.valueOf(Date.today().year());
        // Balance has only 2 pending but request claims 5 — Math.max(0,...) must protect
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 2, 0, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(3), Date.today().addDays(7), 5
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c,
            'Math.max(0,...) must floor Pending at 0, never negative');
    }

    @isTest
    static void testDelete_ApprovedRequest_NeverGoesBelowZero() {
        User mgr = createEmployee('MgrDelFloorAppr', null);
        User emp = createEmployee('EmpDelFloorAppr', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelFloorAppr', 'DF2');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0, 1, 0, 20);

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Approved',
            Date.today().addDays(3), Date.today().addDays(10), 8
        );

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Booked__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Booked__c,
            'Math.max(0,...) must floor Booked at 0, never negative');
    }

    // ==================== BEFORE DELETE — BULK / MULTI-RECORD ====================

    @isTest
    static void testDelete_BulkPendingRequests_AllBalancesReversed() {
        User mgr = createEmployee('MgrDelBulk', null);
        User emp = createEmployee('EmpDelBulk', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelBulk', 'BLK');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 10, 0, 0, 20);

        Leave_Request__c lr1 = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(2), Date.today().addDays(5), 4
        );
        Leave_Request__c lr2 = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(10), Date.today().addDays(15), 6
        );

        Test.startTest();
        delete new List<Leave_Request__c>{ lr1, lr2 };
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c,
            'Both pending requests (4+6=10) should be reversed in a single bulk delete');
    }

    @isTest
    static void testDelete_BulkMixedStatuses_OnlyActiveImpacted() {
        User mgr = createEmployee('MgrDelMixed', null);
        User emp = createEmployee('EmpDelMixed', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelMixed', 'MIX');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 3, 0, 0, 20);

        Leave_Request__c pendingLr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );
        Leave_Request__c cancelledLr = createLeaveRequest(
            emp.Id, lt.Id, 'Cancelled',
            Date.today().addDays(10), Date.today().addDays(12), 3
        );

        Test.startTest();
        delete new List<Leave_Request__c>{ pendingLr, cancelledLr };
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c,
            'Only Pending request should reduce balance; Cancelled should be ignored');
    }

    @isTest
    static void testDelete_MultipleEmployees_EachBalanceIndependent() {
        User mgr  = createEmployee('MgrDelMulti', null);
        User emp1 = createEmployee('EmpDelMulti1', mgr.Id);
        User emp2 = createEmployee('EmpDelMulti2', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelMultiEmp', 'ME1');
        String year = String.valueOf(Date.today().year());

        Employee_Leave_Balance__c lb1 = createLeaveBalance(emp1.Id, lt.Id, year, 5, 0, 0, 20);
        Employee_Leave_Balance__c lb2 = createLeaveBalance(emp2.Id, lt.Id, year, 3, 0, 0, 20);

        Leave_Request__c lr1 = createLeaveRequest(
            emp1.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(9), 5
        );
        Leave_Request__c lr2 = createLeaveRequest(
            emp2.Id, lt.Id, 'Pending',
            Date.today().addDays(5), Date.today().addDays(7), 3
        );

        Test.startTest();
        delete new List<Leave_Request__c>{ lr1, lr2 };
        Test.stopTest();

        Employee_Leave_Balance__c updatedLb1 = [SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb1.Id];
        Employee_Leave_Balance__c updatedLb2 = [SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb2.Id];

        System.assertEquals(0, updatedLb1.Pending_Approval__c, 'Emp1 balance should be fully reversed');
        System.assertEquals(0, updatedLb2.Pending_Approval__c, 'Emp2 balance should be reversed independently');
    }

    @isTest
    static void testDelete_NoBalanceRecord_HandledGracefully() {
        User mgr = createEmployee('MgrDelNoBal', null);
        User emp = createEmployee('EmpDelNoBal', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelNoBal', 'NB1');
        // Intentionally no balance record

        Leave_Request__c lr = createLeaveRequest(
            emp.Id, lt.Id, 'Pending',
            Date.today().addDays(3), Date.today().addDays(5), 3
        );

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            delete lr;
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assertEquals(false, exceptionThrown,
            'Handler should silently skip missing balance records without throwing');
    }

    @isTest
    static void testDelete_HalfDayRequest_FractionalDaysReversed() {
        User mgr = createEmployee('MgrDelHalf', null);
        User emp = createEmployee('EmpDelHalf', mgr.Id);
        Leave_Type__c lt = createLeaveType('DelHalfDay', 'HD1');
        String year = String.valueOf(Date.today().year());
        Employee_Leave_Balance__c lb = createLeaveBalance(emp.Id, lt.Id, year, 0.5, 0, 0, 20);

        Leave_Request__c lr = new Leave_Request__c(
            Employee__c      = emp.Id,
            Leave_Type__c    = lt.Id,
            Start_Date__c    = Date.today().addDays(3),
            End_Date__c      = Date.today().addDays(3),
            Total_Days__c    = 0.5,
            Is_Half_Day__c   = true,
            Half_Day_Type__c = 'First Half',
            Status__c        = 'Pending',
            Is_Active__c     = true,
            Year__c          = year
        );
        insert lr;

        Test.startTest();
        delete lr;
        Test.stopTest();

        Employee_Leave_Balance__c updated = [
            SELECT Pending_Approval__c FROM Employee_Leave_Balance__c WHERE Id = :lb.Id
        ];
        System.assertEquals(0, updated.Pending_Approval__c,
            'Half-day (0.5) pending balance should be fully reversed on delete');
    }
}