/* Check if field is set to 'Generate Match' and was either:
- newly created with that value
- updated to that value (i.e., it changed from something else) */

trigger OpportunityTrigger on Opportunity (after insert, after update) {

    for (Opportunity opp : Trigger.new) {
        
        if (
            opp.Generate_Match__c == 'Generate Match' &&
            (
                Trigger.isInsert || 
                (Trigger.isUpdate && Trigger.oldMap.get(opp.Id).Generate_Match__c != 'Generate Match')
            )
        ) {
            System.enqueueJob(new OpportunityMatchJob(opp.Id));
        }
    }
    
}