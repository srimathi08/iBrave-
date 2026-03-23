trigger PresentedCandidateTrigger on Presented_Candidate__c (
    after insert,
    after update,
    after delete,
    after undelete
) {
    PresentedCandidateRollupHelper.updateOpportunityRollups(
        Trigger.new,
        Trigger.old
    );
}