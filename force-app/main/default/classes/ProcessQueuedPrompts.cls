global class ProcessQueuedPrompts implements Schedulable  {
	 global void execute(SchedulableContext sc) {
        List<Service__c> unprocessed = [SELECT Id,whatsappfrom__c  FROM Service__c WHERE Whatsapp__c = true];
        for (Service__c svc : unprocessed) {
            System.enqueueJob(new CandidatePromptQueueable(svc.Id,svc.whatsappfrom__c));
            svc.Whatsapp__c = false;
        }
        update unprocessed;
    }
}