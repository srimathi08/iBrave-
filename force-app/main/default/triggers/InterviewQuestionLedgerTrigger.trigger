trigger InterviewQuestionLedgerTrigger on Interview_Question__c
(after insert, after update, after delete, after undelete) {
    InterviewQuestionPerOppService.syncForDml();
}