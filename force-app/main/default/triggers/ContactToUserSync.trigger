trigger ContactToUserSync on Contact (after insert, after update) {
    ContactToUserSyncHandler.syncContactsToUsers(Trigger.new);
}