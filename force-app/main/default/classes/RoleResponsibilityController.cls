public with sharing class RoleResponsibilityController {

    @AuraEnabled(cacheable=true)
    public static List<Role_Category__c> getRoleCategories() {
        return [
            SELECT Id, Name
            FROM Role_Category__c
            WHERE Is_Active__c = TRUE
            ORDER BY Name
        ];
    }

    @AuraEnabled(cacheable=true)
    public static List<Role_Responsibilities__c> getResponsibilities(List<Id> roleIds) {
        return [
            SELECT Id, Name, Responsibility_Text__c, Role_Category__c, Role_Category__r.Name, Sequence__c
            FROM Role_Responsibilities__c
            WHERE Role_Category__c IN :roleIds
            AND Is_Active__c = TRUE
            ORDER BY Role_Category__r.Name, Sequence__c
        ];
    }

   @AuraEnabled
public static void saveResponsibilities(Id recordId, String objectApiName, List<Id> responsibilityIds) {

    Set<Id> existingResponsibilities = new Set<Id>();

    if(objectApiName == 'Candidate__c') {
        for(Person_Responsibility__c pr : [
            SELECT Role_Responsibilities__c
            FROM Person_Responsibility__c
            WHERE Candidate__c = :recordId
        ]) {
            existingResponsibilities.add(pr.Role_Responsibilities__c);
        }
    }
    else if(objectApiName == 'Contact') {
        for(Person_Responsibility__c pr : [
            SELECT Role_Responsibilities__c
            FROM Person_Responsibility__c
            WHERE Contact__c = :recordId
        ]) {
            existingResponsibilities.add(pr.Role_Responsibilities__c);
        }
    }

    List<Person_Responsibility__c> recordsToInsert = new List<Person_Responsibility__c>();

    List<Role_Responsibilities__c> responsibilities = [
        SELECT Id, Responsibility_Text__c, Role_Category__c, Sequence__c
        FROM Role_Responsibilities__c
        WHERE Id IN :responsibilityIds
    ];

    for(Role_Responsibilities__c rr : responsibilities) {

        if(existingResponsibilities.contains(rr.Id)) {
            continue; // ⭐⭐⭐⭐⭐ SKIP DUPLICATES
        }

        Person_Responsibility__c pr = new Person_Responsibility__c();

        if(objectApiName == 'Candidate__c') {
            pr.Candidate__c = recordId;
        } else {
            pr.Contact__c = recordId;
        }

        pr.Role_Category__c = rr.Role_Category__c;
        pr.Role_Responsibilities__c = rr.Id;
        pr.Responsibility_Text__c = rr.Responsibility_Text__c;
        pr.Sequence__c = rr.Sequence__c;
        pr.Is_Selected__c = TRUE;

        recordsToInsert.add(pr);
    }

    if(!recordsToInsert.isEmpty()) {
        insert recordsToInsert;
    }
}

@AuraEnabled(cacheable=true)
public static List<Id> getAssignedResponsibilities(Id recordId, String objectApiName) {

    Set<Id> assignedIds = new Set<Id>();

    if(objectApiName == 'Candidate__c') {

        for(Person_Responsibility__c pr : [
            SELECT 	Role_Responsibilities__c
            FROM Person_Responsibility__c
            WHERE Candidate__c = :recordId
        ]) {
            assignedIds.add(pr.Role_Responsibilities__c);
        }
    }
    else if(objectApiName == 'Contact') {

        for(Person_Responsibility__c pr : [
            SELECT 	Role_Responsibilities__c
            FROM Person_Responsibility__c
            WHERE Contact__c = :recordId
        ]) {
            assignedIds.add(pr.Role_Responsibilities__c);
        }
    }

    return new List<Id>(assignedIds);  // FIX
}

}