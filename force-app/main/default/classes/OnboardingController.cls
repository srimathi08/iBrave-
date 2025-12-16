public with sharing class OnboardingController {
    
    @AuraEnabled
    public static String submitOnboardingForm(String formData) {
        try {
            Map<String, Object> dataMap = (Map<String, Object>) JSON.deserializeUntyped(formData);
            
            Employee_Onboarding__c onboarding = new Employee_Onboarding__c();
            onboarding.First_Name__c = (String) dataMap.get('firstName');
            onboarding.Last_Name__c = (String) dataMap.get('lastName');
            onboarding.Email__c = (String) dataMap.get('email');
            onboarding.Phone__c = (String) dataMap.get('phone');
            onboarding.Mobile_Phone__c = (String) dataMap.get('mobilePhone');
            onboarding.Date_of_Birth__c = Date.valueOf((String) dataMap.get('dateOfBirth'));
            onboarding.Street_Address__c = (String) dataMap.get('streetAddress');
            onboarding.City__c = (String) dataMap.get('city');
            onboarding.State__c = (String) dataMap.get('state');
            onboarding.Postal_Code__c = (String) dataMap.get('postalCode');
            onboarding.Country__c = (String) dataMap.get('country');
            onboarding.Emergency_Contact_Name__c = (String) dataMap.get('emergencyContactName');
            onboarding.Emergency_Contact_Phone__c = (String) dataMap.get('emergencyContactPhone');
            onboarding.Emergency_Contact_Relationship__c = (String) dataMap.get('emergencyContactRelationship');
            onboarding.Position_Title__c = (String) dataMap.get('positionTitle');
            onboarding.Department__c = (String) dataMap.get('department');
            onboarding.Start_Date__c = Date.valueOf((String) dataMap.get('startDate'));
            onboarding.Employment_Type__c = (String) dataMap.get('employmentType');
            onboarding.Bank_Name__c = (String) dataMap.get('bankName');
            onboarding.Account_Number__c = (String) dataMap.get('accountNumber');
            //onboarding.Routing_Number__c = (String) dataMap.get('routingNumber');
            onboarding.PAN_number__c = (String) dataMap.get('taxId');
            onboarding.Highest_Education__c = (String) dataMap.get('highestEducation');
            onboarding.Previous_Employer__c = (String) dataMap.get('previousEmployer');
            onboarding.Years_of_Experience__c = Integer.valueOf(dataMap.get('yearsOfExperience'));
            onboarding.Status__c = 'Submitted';
            onboarding.Form_Submitted_Date__c = System.now();
            onboarding.Converted_to_Contact__c = false;
            onboarding.Unique_Token__c = generateUniqueToken();
            
            insert onboarding;
            
            // Send confirmation email
            sendConfirmationEmail(onboarding);
            
            return onboarding.Id;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting form: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void convertToContact(String onboardingId) {
        try {
            Employee_Onboarding__c onboarding = [
                SELECT Id, First_Name__c, Last_Name__c, Email__c, Phone__c, 
                       Mobile_Phone__c, Street_Address__c, City__c, State__c, 
                       Postal_Code__c, Country__c, Department__c, Position_Title__c,
                       Date_of_Birth__c, Start_Date__c, Employment_Type__c,
                       Converted_to_Contact__c, Status__c
                FROM Employee_Onboarding__c 
                WHERE Id = :onboardingId 
                LIMIT 1
            ];
            
            // Check if already converted
            if (onboarding.Converted_to_Contact__c) {
                throw new AuraHandledException('This onboarding record has already been converted to a Contact.');
            }
            
            // Create Contact record
            Contact newContact = new Contact();
            newContact.FirstName = onboarding.First_Name__c;
            newContact.LastName = onboarding.Last_Name__c;
            newContact.Email = onboarding.Email__c;
            newContact.Phone = onboarding.Phone__c;
            newContact.MobilePhone = onboarding.Mobile_Phone__c;
            newContact.MailingStreet = onboarding.Street_Address__c;
            newContact.MailingCity = onboarding.City__c;
            newContact.MailingState = onboarding.State__c;
            newContact.MailingPostalCode = onboarding.Postal_Code__c;
            newContact.MailingCountry = onboarding.Country__c;
            newContact.Department = onboarding.Department__c;
            newContact.Title = onboarding.Position_Title__c;
            newContact.Birthdate = onboarding.Date_of_Birth__c;
            
            insert newContact;
            
            // Update Onboarding record
            onboarding.Converted_to_Contact__c = true;
            onboarding.Contact_Record_ID__c = newContact.Id;
            onboarding.Status__c = 'Converted';
            
            update onboarding;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error converting to Contact: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static List<Employee_Onboarding__c> getOnboardingRecords(String status) {
        try {
            String query = 'SELECT Id, Name, First_Name__c, Last_Name__c, Email__c, ' +
                          'Position_Title__c, Department__c, Status__c, ' +
                          'Converted_to_Contact__c, Form_Submitted_Date__c, ' +
                          'Contact_Record_ID__c ' +
                          'FROM Employee_Onboarding__c ';
            
            if (String.isNotBlank(status) && status != 'All') {
                query += 'WHERE Status__c = :status ';
            }
            
            query += 'ORDER BY Form_Submitted_Date__c DESC';
            
            return Database.query(query);
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching records: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateOnboardingStatus(String onboardingId, String newStatus) {
        try {
            Employee_Onboarding__c onboarding = new Employee_Onboarding__c(
                Id = onboardingId,
                Status__c = newStatus
            );
            update onboarding;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating status: ' + e.getMessage());
        }
    }
    
    private static String generateUniqueToken() {
        Blob randomBlob = Crypto.generateAesKey(128);
        String token = EncodingUtil.base64Encode(randomBlob);
        return token.substring(0, 32);
    }
    
    private static void sendConfirmationEmail(Employee_Onboarding__c onboarding) {
        try {
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { onboarding.Email__c });
            email.setSubject('Onboarding Form Submission Confirmation');
            
            String emailBody = 'Dear ' + onboarding.First_Name__c + ',\n\n' +
                              'Thank you for completing the employee onboarding form. ' +
                              'Your application has been received and is under review.\n\n' +
                              'Reference Number: ' + onboarding.Id + '\n\n' +
                              'Our HR team will contact you shortly.\n\n' +
                              'Best regards,\n' +
                              'HR Team';
            
            email.setPlainTextBody(emailBody);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
}