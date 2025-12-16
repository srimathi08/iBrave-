trigger CandidateConvertToContact on Candidate__c (after update) {
    // Map to hold Candidate Id to new Contact Id for related record updates
    Map<Id, Id> candidateToContactMap = new Map<Id, Id>();
    
    // List to collect new Contacts to insert
    List<Contact> contactsToInsert = new List<Contact>();

    // Map Candidate Id to Candidate record for bulk processing
    Map<Id, Candidate__c> newCandidates = new Map<Id, Candidate__c>();
    for (Candidate__c c : Trigger.new) {
        Candidate__c oldC = Trigger.oldMap.get(c.Id);
        if (c.Converted_To_Contact__c == true && oldC.Converted_To_Contact__c == false) {
            newCandidates.put(c.Id, c);
        }
    }

    // Avoid processing if none to convert
    if (newCandidates.isEmpty()) return;

    // Create Contacts from Candidates
    for (Id candId : newCandidates.keySet()) {
        Candidate__c c = newCandidates.get(candId);
        Contact con = new Contact();

        // Map Candidate fields to Contact fields - carefully mapping as per provided fields:
        con.FirstName = c.First_Name__c;
        con.LastName = c.Last_Name__c;
        con.MiddleName = c.Middle_Name__c;
        con.Birthdate = c.Date_Of_Birth__c;
        con.GenderIdentity = c.Gender__c; // Assuming field API mapping - verify
        con.Department = c.Department__c;
        con.Personal_Email__c = c.Personal_Email__c;
        con.Phone = c.Phone_No__c;
        con.MobilePhone = c.Phone_No__c;
        con.Aadhar_Card_Number__c = c.Aadhar_Card_Number__c;
        con.Blood_Group__c = c.Blood_Group__c;
        con.Campus_City__c = c.Campus_City__c;
        con.Campus_Name__c = c.Campus_Name__c;
        con.Consultancy_Name__c = c.Consultancy_Name__c;
        con.Date_of_joining__c = c.Joining_Date__c;
        con.Designation__c = c.Designation__c;
        con.Driving_License_Number__c = c.Driving_License_Number__c;
        con.Emergency_Contact_Name__c = c.Emergency_Contact_Name__c;
        con.Emergency_Contact_Phone__c = c.Emergency_Contact_Phone__c;
        con.Marital_Status__c = c.Marital_Status__c;
        con.Number_of_Children__c = c.Number_of_Children__c;
        con.PAN_Number__c = c.PAN_Number__c;
        con.Personal_Email__c = c.Personal_Email__c;
        con.Place_of_Posting_Base_Location__c = c.Place_of_Posting_Base_Location__c;
        con.Referred_Person_Name__c = c.Referred_Person_Name__c;
        con.Salutation = c.Salutation__c;
        con.Source_Of_Applicant__c = c.Source_Of_Applicant__c;
        con.UAN_Number__c = c.UAN_Number__c;
        con.Work_Location__c = c.Work_Location__c;
        con.MailingStreet = c.Communication_Address__Street__s;
        con.MailingCity = c.Communication_Address__City__s;
        con.MailingStateCode = c.Communication_Address__StateCode__s;
        con.MailingPostalCode = c.Communication_Address__PostalCode__s;
        con.MailingCountryCode = c.Communication_Address__CountryCode__s;
        con.Candidate__c = c.Id;  // Lookup back to Candidate for traceability

        contactsToInsert.add(con);
    }

    insert contactsToInsert;
// Generate Employee Ids for new Contacts
List<Contact> contactsToUpdate = new List<Contact>();
Integer lastNumber = 0;

// Query highest existing number suffix from Employee_ID__c field
List<Contact> lastContacts = [SELECT Employee_ID__c FROM Contact WHERE Employee_ID__c LIKE 'Qbay %' ORDER BY CreatedDate DESC LIMIT 1];
if (!lastContacts.isEmpty()) {
    String lastEmpId = lastContacts[0].Employee_ID__c;
    Integer num = Integer.valueOf(lastEmpId.substring(5));
    lastNumber = num;
}

for (Contact con : contactsToInsert) {
    lastNumber++;
    // Pad the number with leading zeros to have length 4
    String numStr = String.valueOf(lastNumber);
    while (numStr.length() < 4) {
        numStr = '0' + numStr;
    }
    String newEmpId = 'Qbay ' + numStr;
    con.Employee_ID__c = newEmpId;
    contactsToUpdate.add(con);
}

if (!contactsToUpdate.isEmpty()) {
    update contactsToUpdate;
}


   // Map created Contact Ids back to Candidate Ids - convert Set to List before using index
List<Id> candidateIdList = new List<Id>(newCandidates.keySet());
for (Integer i = 0; i < contactsToInsert.size(); i++) {
    candidateToContactMap.put(candidateIdList[i], contactsToInsert[i].Id);
}

    // Update related Education records
    List<Education_Detail__c> edusToUpdate = [SELECT Id, Candidate__c, Contact__c FROM Education_Detail__c WHERE Candidate__c IN :candidateToContactMap.keySet()];
    for (Education_Detail__c edu : edusToUpdate) {
        edu.Contact__c = candidateToContactMap.get(edu.Candidate__c);
    }
    update edusToUpdate;

    // Update related Family Members records
    List<Family_Members__c> familyToUpdate = [SELECT Id, Candidate__c, Contact__c FROM Family_Members__c WHERE Candidate__c IN :candidateToContactMap.keySet()];
    for (Family_Members__c fm : familyToUpdate) {
        fm.Contact__c = candidateToContactMap.get(fm.Candidate__c);
    }
    update familyToUpdate;

    // Update related Work Experience records
    List<Work_Experience__c> workToUpdate = [SELECT Id, Candidate__c, Contact__c FROM Work_Experience__c WHERE Candidate__c IN :candidateToContactMap.keySet()];
    for (Work_Experience__c work : workToUpdate) {
        work.Contact__c = candidateToContactMap.get(work.Candidate__c);
    }
    update workToUpdate;

    // Update related Bank Details records
    List<Bank_Details__c> bankToUpdate = [SELECT Id, Candidate__c, Contact__c FROM Bank_Details__c WHERE Candidate__c IN :candidateToContactMap.keySet()];
    for (Bank_Details__c bank : bankToUpdate) {
        bank.Contact__c = candidateToContactMap.get(bank.Candidate__c);
    }
    update bankToUpdate;

    // Update related CandidateRoleResponsibility junction records
List<CandidateRoleResponsibility__c> crrToUpdate = [SELECT Id, Candidate__c, Contact__c FROM CandidateRoleResponsibility__c WHERE Candidate__c IN :candidateToContactMap.keySet()];
for (CandidateRoleResponsibility__c crr : crrToUpdate) {
    crr.Contact__c = candidateToContactMap.get(crr.Candidate__c);
}
update crrToUpdate;
}