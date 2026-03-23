trigger CandidateOnboardingTrigger on Candidate__c (after update) {
    if (Trigger.isAfter && Trigger.isUpdate) {
        CandidateOnboardingHandler.sendOnboardingNotification(Trigger.new, Trigger.oldMap);
    }
}