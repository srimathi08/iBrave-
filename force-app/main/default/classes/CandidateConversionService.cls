public with sharing class CandidateConversionService {
 public class CandidateInput {
        @InvocableVariable(required=true)
        public Id candidateId;
    }

    public class CandidateOutput {
        @InvocableVariable
        public String message;
    }
   @InvocableMethod(label='Convert Candidate to Contact' description='Converts Candidate to Contact')
 public static List<CandidateOutput> convertCandidateToContact(List<CandidateInput> inputs) {
        List<CandidateOutput> outputs = new List<CandidateOutput>();

        for(CandidateInput input : inputs) {
            CandidateOutput output = new CandidateOutput();

            try {
                if (input.candidateId == null) {
                    output.message = 'Candidate Id is null';
                    outputs.add(output);
                    continue;
                }
    
        // Query the candidate record with needed fields
        Candidate__c candidate = [SELECT Id, First_Name__c, Last_Name__c, Middle_Name__c, Date_Of_Birth__c,
            Gender__c,  Personal_Email__c, Phone_No__c, Aadhar_Card_Number__c, Blood_Group__c,
            Campus_City__c, Campus_Name__c, Consultancy_Name__c, Joining_Date__c, Designation__c,Department__c,
            Driving_License_Number__c, Emergency_Contact_Name__c, Emergency_Contact_Phone__c, Marital_Status__c,
            Number_of_Children__c, PAN_Number__c, Referred_Person_Name__c,
            Salutation__c, Source_Of_Applicant__c, UAN_Number__c, 
            Communication_Address__Street__s, Communication_Address__City__s, Communication_Address__StateCode__s,
            Communication_Address__PostalCode__s, Communication_Address__CountryCode__s,
            Permanent_Address__Street__s, Permanent_Address__City__s, Permanent_Address__StateCode__s,
            Permanent_Address__PostalCode__s, Permanent_Address__CountryCode__s,Place_of_Posting_Base_Location__c,Work_Location__c
             FROM Candidate__c WHERE Id = :input.candidateId LIMIT 1];

        if (candidate == null) {
                    output.message = 'Candidate not found';
                    outputs.add(output);
                    continue;
                }
        // Create Contact from Candidate data
        Contact con = new Contact();
        con.FirstName = candidate.First_Name__c;
        con.LastName = candidate.Last_Name__c;
        con.MiddleName = candidate.Middle_Name__c;
        con.Birthdate = candidate.Date_Of_Birth__c;
        con.GenderIdentity = candidate.Gender__c;
        con.Department = candidate.Department__c;
        con.Personal_Email__c = candidate.Personal_Email__c;
        con.Phone = candidate.Phone_No__c;
        con.MobilePhone = candidate.Phone_No__c;
        con.Aadhar_Card_Number__c = candidate.Aadhar_Card_Number__c;
        con.Blood_Group__c = candidate.Blood_Group__c;
        con.Campus_City__c = candidate.Campus_City__c;
        con.Campus_Name__c = candidate.Campus_Name__c;
        con.Consultancy_Name__c = candidate.Consultancy_Name__c;
        con.Date_of_joining__c = candidate.Joining_Date__c;
        con.Designation__c = candidate.Designation__c;
        con.Driving_License_Number__c = candidate.Driving_License_Number__c;
        con.Emergency_Contact_Name__c = candidate.Emergency_Contact_Name__c;
        con.Emergency_Contact_Phone__c = candidate.Emergency_Contact_Phone__c;
        con.Marital_Status__c = candidate.Marital_Status__c;
        con.Number_of_Children__c = candidate.Number_of_Children__c;
        con.PAN_Number__c = candidate.PAN_Number__c;
        con.Place_of_Posting_Base_Location__c = candidate.Place_of_Posting_Base_Location__c;
        con.Referred_Person_Name__c = candidate.Referred_Person_Name__c;
        con.Salutation = candidate.Salutation__c;
        con.Source_Of_Applicant__c = candidate.Source_Of_Applicant__c;
        con.UAN_Number__c = candidate.UAN_Number__c;
        con.Work_Location__c = candidate.Work_Location__c;

        // Map address fields
        con.MailingStreet = candidate.Communication_Address__Street__s;
        con.MailingCity = candidate.Communication_Address__City__s;
        con.MailingStateCode = candidate.Communication_Address__StateCode__s;
        con.MailingPostalCode = candidate.Communication_Address__PostalCode__s;
        con.MailingCountryCode = candidate.Communication_Address__CountryCode__s;

        con.OtherStreet = candidate.Permanent_Address__Street__s;
        con.OtherCity = candidate.Permanent_Address__City__s;
        con.OtherStateCode = candidate.Permanent_Address__StateCode__s;
        con.OtherPostalCode = candidate.Permanent_Address__PostalCode__s;
        con.OtherCountryCode = candidate.Permanent_Address__CountryCode__s;

        con.Candidate__c = candidate.Id;

        insert con;

        // Generate Employee Id (Qbay 0001 format) for Contact
        Integer lastNumber = 0;
        List<Contact> lastContacts = [SELECT Employee_ID__c FROM Contact WHERE Employee_ID__c LIKE 'Qbay %' ORDER BY CreatedDate DESC LIMIT 1];
        if (!lastContacts.isEmpty()) {
            String lastEmpId = lastContacts[0].Employee_ID__c;
            lastNumber = Integer.valueOf(lastEmpId.substring(5));
        }
        lastNumber++;
        String numStr = String.valueOf(lastNumber);
        while (numStr.length() < 4) {
            numStr = '0' + numStr;
        }
        con.Employee_ID__c = 'Qbay ' + numStr;
        update con;

        // Update related child records to link with Contact
        Map<Id, Id> candidateToContactMap = new Map<Id, Id>{candidate.Id => con.Id};

        List<Education_Detail__c> edus = [SELECT Id, Candidate__c FROM Education_Detail__c WHERE Candidate__c = :candidate.Id];
        for (Education_Detail__c edu : edus) {
            edu.Contact__c = con.Id;
        }
        update edus;

        List<Family_Members__c> familyList = [SELECT Id, Candidate__c FROM Family_Members__c WHERE Candidate__c = :candidate.Id];
        for (Family_Members__c fam : familyList) {
            fam.Contact__c = con.Id;
        }
        update familyList;

        List<Work_Experience__c> workList = [SELECT Id, Candidate__c FROM Work_Experience__c WHERE Candidate__c = :candidate.Id];
        for (Work_Experience__c work : workList) {
            work.Contact__c = con.Id;
        }
        update workList;

        List<Bank_Details__c> bankList = [SELECT Id, Candidate__c FROM Bank_Details__c WHERE Candidate__c = :candidate.Id];
        for (Bank_Details__c bank : bankList) {
            bank.Contact__c = con.Id;
        }
        update bankList;

        List<CandidateRoleResponsibility__c> roles = [SELECT Id, Candidate__c FROM CandidateRoleResponsibility__c WHERE Candidate__c = :candidate.Id];
        for (CandidateRoleResponsibility__c role : roles) {
            role.Contact__c = con.Id;
        }
        update roles;
		// Update related Salary Details records, replace Salary_Details__c with actual API name
		List<Salary_Details__c> salaryList = [SELECT Id, Candidate__c FROM Salary_Details__c WHERE Candidate__c = :candidate.Id];
		for (Salary_Details__c sal : salaryList) {
    	sal.Contact__c = con.Id;
		}
update salaryList;
          // IT Department Notification email
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                //mail.setToAddresses(new String[] { 'it-team@example.com' }); // Replace with your IT department email
mail.setToAddresses(new String[] { 'gpriyalakshmi@gmail.com' }); 
                mail.setSubject('New Employee Contact Created: ' + con.FirstName + ' ' + con.LastName);
                mail.setPlainTextBody(
                    'Dear IT Team,\n\n'
                    + 'A new employee Contact has been created in Salesforce.\n'
                    + 'Please create an official Outlook email ID and a temporary password for the new employee.\n\n'
                    + 'Employee Name: ' + con.FirstName + ' ' + con.LastName + '\n'
                    + 'Employee ID: ' + con.Employee_ID__c + '\n'
                    + 'Contact Email: ' + con.Personal_Email__c + '\n\n'
                    + 'Thank you.\nHR Team'
                );
                Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
//Intimation to HR for Asset Allocation email
Messaging.SingleEmailMessage hrMail = new Messaging.SingleEmailMessage();
hrMail.setToAddresses(new String[] { 'priyadharsini.gunasekaran@quadrobay.com' }); // Your HR team email
hrMail.setSubject('Intimation to HR Dept for Asset Allocation: ' + con.FirstName + ' ' + con.LastName);
hrMail.setPlainTextBody(
    'Dear HR Team,\n\n'
    + 'A new employee Contact has been created and IT setup is underway.\n'
    + 'Please allocate necessary assets (laptop, ID, phone, etc.) for onboarding.\n\n'
    + 'Employee Name: ' + con.FirstName + ' ' + con.LastName + '\n'
    + 'Employee ID: ' + con.Employee_ID__c + '\n'
    + 'Official Email: ' + con.Email + '\n\n'
    + 'Thank you.\n'
);
Messaging.sendEmail(new Messaging.SingleEmailMessage[] { hrMail });


                output.message = 'Contact created successfully with Employee ID: ' + con.Employee_ID__c;
            } catch (Exception e) {
                output.message = 'Error: ' + e.getMessage();
            }
            outputs.add(output);
        }
        return outputs;
    }
}