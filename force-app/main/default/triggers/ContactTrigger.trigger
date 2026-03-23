trigger ContactTrigger on Contact (after insert, after update) {
    if (Trigger.isAfter) {
        ContactTriggerHandler.handleAfter(Trigger.new, Trigger.oldMap, Trigger.isInsert, Trigger.isUpdate);
    }
}