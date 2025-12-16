trigger LeaveRequestTrigger on Leave_Request__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        for (Leave_Request__c newReq : Trigger.new) {
            Leave_Request__c oldReq = Trigger.oldMap.get(newReq.Id);
            
            // Check if status changed
            if (newReq.Status__c != oldReq.Status__c) {
                LeaveRequestController.updateLeaveBalance(
                    newReq.Id,
                    newReq.Status__c,
                    oldReq.Status__c
                );
            }
        }
    }
}