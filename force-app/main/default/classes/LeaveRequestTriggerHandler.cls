public without sharing class LeaveRequestTriggerHandler {

    // ==================== AFTER UPDATE ====================

    public static void handleAfterUpdate(
        List<Leave_Request__c> newList,
        Map<Id, Leave_Request__c> oldMap
    ) {
        for (Leave_Request__c newReq : newList) {
            Leave_Request__c oldReq = oldMap.get(newReq.Id);

            if (newReq.Status__c != oldReq.Status__c) {
                LeaveRequestController.updateLeaveBalance(
                    newReq.Id,
                    newReq.Status__c,
                    oldReq.Status__c
                );
            }
        }
    }

    // ==================== BEFORE DELETE ====================

    public static void handleBeforeDelete(List<Leave_Request__c> deletedRequests) {

        // Only reverse balance impact for statuses that still hold balance
        // Rejected / Cancelled are already reversed at the time of status change
        List<Leave_Request__c> requestsToReverse = new List<Leave_Request__c>();

        for (Leave_Request__c req : deletedRequests) {
            if (req.Status__c == 'Pending' || req.Status__c == 'Approved' || req.Status__c == 'Booked') {
                requestsToReverse.add(req);
            }
        }

        if (requestsToReverse.isEmpty()) return;

        Set<Id>     employeeIds  = new Set<Id>();
        Set<Id>     leaveTypeIds = new Set<Id>();
        Set<String> years        = new Set<String>();

        for (Leave_Request__c req : requestsToReverse) {
            if (req.Start_Date__c != null) {
                employeeIds.add(req.Employee__c);
                leaveTypeIds.add(req.Leave_Type__c);
                years.add(String.valueOf(req.Start_Date__c.year()));
            }
        }

        // Fetch all relevant balances in one query
        List<Employee_Leave_Balance__c> balances = [
            SELECT Id, Employee__c, Leave_Type__c, Year__c,
                   Pending_Approval__c, Booked__c, Used__c
            FROM Employee_Leave_Balance__c
            WHERE Employee__c  IN :employeeIds
            AND   Leave_Type__c IN :leaveTypeIds
            AND   Year__c       IN :years
            AND   Is_Active__c  = true
        ];

        // Build lookup map: employeeId + leaveTypeId + year => balance
        Map<String, Employee_Leave_Balance__c> balanceMap =
            new Map<String, Employee_Leave_Balance__c>();

        for (Employee_Leave_Balance__c bal : balances) {
            String key = bal.Employee__c + '_' + bal.Leave_Type__c + '_' + bal.Year__c;
            balanceMap.put(key, bal);
        }

        // Reverse the balance impact for each deleted request
        for (Leave_Request__c req : requestsToReverse) {
            if (req.Start_Date__c == null || req.Total_Days__c == null) continue;

            String year = String.valueOf(req.Start_Date__c.year());
            String key  = req.Employee__c + '_' + req.Leave_Type__c + '_' + year;

            Employee_Leave_Balance__c bal = balanceMap.get(key);
            if (bal == null) continue;

            Decimal days = req.Total_Days__c;

            if (req.Status__c == 'Pending') {
                bal.Pending_Approval__c = Math.max(0, (bal.Pending_Approval__c ?? 0) - days);

            } else if (req.Status__c == 'Approved' || req.Status__c == 'Booked') {
                bal.Booked__c = Math.max(0, (bal.Booked__c ?? 0) - days);
            }
        }

        if (!balanceMap.values().isEmpty()) {
            update balanceMap.values();
        }
    }
}