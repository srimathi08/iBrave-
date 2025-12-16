public with sharing class NDADocumentController {
    public Contact contact { get; private set; }

    public NDADocumentController(ApexPages.StandardController controller) {
        Id contactId = ApexPages.currentPage().getParameters().get('id') != null 
            ? ApexPages.currentPage().getParameters().get('id')
            : null;

        if (contactId != null) {
            contact = [
                SELECT Id, Name, Email,Manager__c, MailingStreet, MailingCity, MailingState, MailingPostalCode,
                       Hire_Date__c, Designation__c, Aadhar_Card_Number__c
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
        } else {
            contact = new Contact();
        }
    }
}