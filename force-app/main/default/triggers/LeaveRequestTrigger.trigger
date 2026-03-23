trigger LeaveRequestTrigger on Leave_Request__c (after update, before delete) {

    // ==================== AFTER UPDATE ====================
    if (Trigger.isAfter && Trigger.isUpdate) {
        LeaveRequestTriggerHandler.handleAfterUpdate(Trigger.new, Trigger.oldMap);
    }

    // ==================== BEFORE DELETE ====================
    if (Trigger.isBefore && Trigger.isDelete) {
        LeaveRequestTriggerHandler.handleBeforeDelete(Trigger.old);
    }
}