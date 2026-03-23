public without sharing class OnboardingFormController {
     
    @AuraEnabled
    public static Map<String, Object> getCandidateData(String candidateId) {
        try {
            System.debug('getCandidateData called with candidateId: ' + candidateId);
            
            if (String.isBlank(candidateId)) {
                System.debug('ERROR: Candidate ID is blank or null');
                throw new AuraHandledException('Candidate ID is required. Please ensure you are accessing this page with a valid Candidate record.');
            }
            
            // Validate the ID format
            /*if (!candidateId.startsWith('a0') || candidateId.length() != 18) {
                System.debug('ERROR: Invalid Candidate ID format: ' + candidateId);
                throw new AuraHandledException('Invalid Candidate ID format');
            }*/
            Id candidateRecId;
try {
    candidateRecId = Id.valueOf(candidateId);
} catch (Exception ex) {
    System.debug('ERROR: Invalid Candidate ID format: ' + candidateId);
    throw new AuraHandledException('Invalid Candidate ID format');
}

            List<Candidate__c> candidates = [
                SELECT Id, First_Name__c, Last_Name__c, Middle_Name__c, 
                       Salutation__c, Personal_Email__c, Phone_No__c,
                       Date_Of_Birth__c, Gender__c, Blood_Group__c,
                       Aadhar_Card_Number__c, PAN_Number__c, UAN_Number__c,
                       Driving_License_Number__c,
                       Communication_Address__Street__s, Communication_Address__City__s,
                       Communication_Address__StateCode__s, Communication_Address__CountryCode__s,
                       Communication_Address__PostalCode__s,
                       Permanent_Address__Street__s, Permanent_Address__City__s,
                       Permanent_Address__StateCode__s, Permanent_Address__CountryCode__s,
                       Permanent_Address__PostalCode__s,
                       Emergency_Contact_Name__c, Emergency_Contact_Phone__c,
                       Source_Of_Applicant__c, Mode_Of_Advertising__c,
                       Campus_Name__c, Campus_City__c, Marital_Status__c, Referred_Person_Name__c,
                       Anniversary_Date__c, Number_of_Children__c, Consultancy_Name__c,
                       Reference_Name__c, Reference_Contact_Info__c
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];
            
            if (candidates.isEmpty()) {
                System.debug('ERROR: No Candidate found with ID: ' + candidateId);
                throw new AuraHandledException('Candidate record not found with ID: ' + candidateId);
            }
            
            Candidate__c candidate = candidates[0];
            System.debug('Candidate found: ' + candidate.First_Name__c + ' ' + candidate.Last_Name__c);
            
            // Get existing education records
            List<Education_Detail__c> educationRecords = [
                SELECT Id, Education_Type__c, Institution_Name__c, 
                       Board_University__c, Course_Stream__c, Mode_of_Study__c,
                       Year_of_Completion__c, Percentage__c, Certificate_Attached__c
                FROM Education_Detail__c
                WHERE Candidate__c = :candidateId
            ];
            
            // Get existing family records
            List<Family_Members__c> familyRecords = [
                SELECT Id, Name__c, Relationship__c, Date_Of_Birth__c,
                       Age__c, Contact_No__c, Occupation__c
                FROM Family_Members__c
                WHERE Candidate__c = :candidateId
            ];
            
            // Get existing work experience records
            List<Work_Experience__c> workRecords = [
                SELECT Id, Company_Name__c, Designation__c, Employment_Type__c,
                       Start_Date__c, End_Date__c, Currently_Working__c,
                       Experience_Years__c, Skills_Technologies_Used__c                  
                FROM Work_Experience__c
                WHERE Candidate__c = :candidateId
            ];
            
            // Get existing bank records
            List<Bank_Details__c> bankRecords = [
                SELECT Id, Bank_Name__c, Branch_Name__c, Account_Number__c,
                       Account_Holder_Name__c, IFSC_Code__c, Account_Type__c,
                       Primary_Account__c, Status__c, Remarks__c
                FROM Bank_Details__c
                WHERE Candidate__c = :candidateId
            ];
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('candidate', candidate);
            result.put('educationRecords', educationRecords);
            result.put('familyRecords', familyRecords);
            result.put('workRecords', workRecords);
            result.put('bankRecords', bankRecords);
            
            return result;
            
        } catch (Exception e) {
            System.debug('Error in getCandidateData: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching candidate data: ' + e.getMessage());
        }
    }
    
    @AuraEnabled(cacheable=true)
    public static Map<String, List<Map<String, String>>> getPicklistValues() {
        try {
            Map<String, List<Map<String, String>>> picklistMap = new Map<String, List<Map<String, String>>>();
            
            // Candidate picklists
            picklistMap.put('salutation', getPicklistValuesHelper('Candidate__c', 'Salutation__c'));
            picklistMap.put('gender', getPicklistValuesHelper('Candidate__c', 'Gender__c'));
            picklistMap.put('bloodGroup', getPicklistValuesHelper('Candidate__c', 'Blood_Group__c'));
            picklistMap.put('sourceOfApplicant', getPicklistValuesHelper('Candidate__c', 'Source_Of_Applicant__c'));
            picklistMap.put('maritalStatus', getPicklistValuesHelper('Candidate__c', 'Marital_Status__c'));
            
            // Education picklists
            picklistMap.put('educationType', getPicklistValuesHelper('Education_Detail__c', 'Education_Type__c'));
            picklistMap.put('modeOfStudy', getPicklistValuesHelper('Education_Detail__c', 'Mode_of_Study__c'));
            
            // Family picklists
            picklistMap.put('relationship', getPicklistValuesHelper('Family_Members__c', 'Relationship__c'));
            
            // Work Experience picklists
            picklistMap.put('employmentType', getPicklistValuesHelper('Work_Experience__c', 'Employment_Type__c'));
            
            // Bank picklists
            picklistMap.put('accountType', getPicklistValuesHelper('Bank_Details__c', 'Account_Type__c'));
            picklistMap.put('bankStatus', getPicklistValuesHelper('Bank_Details__c', 'Status__c'));
            
            return picklistMap;
            
        } catch (Exception e) {
            System.debug('Error in getPicklistValues: ' + e.getMessage());
            throw new AuraHandledException('Error fetching picklist values: ' + e.getMessage());
        }
    }

    private static List<Map<String, String>> getPicklistValuesHelper(String objectName, String fieldName) {
        List<Map<String, String>> picklistValues = new List<Map<String, String>>();
        
        try {
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if (objType == null) {
                System.debug('Object not found: ' + objectName);
                return picklistValues;
            }
            
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            if (!fieldMap.containsKey(fieldName)) {
                System.debug('Field not found: ' + fieldName + ' on object: ' + objectName);
                return picklistValues;
            }
            
            Schema.DescribeFieldResult fieldDescribe = fieldMap.get(fieldName).getDescribe();
            
            for (Schema.PicklistEntry entry : fieldDescribe.getPicklistValues()) {
                if (entry.isActive()) {
                    Map<String, String> option = new Map<String, String>();
                    option.put('label', entry.getLabel());
                    option.put('value', entry.getValue());
                    picklistValues.add(option);
                }
            }
        } catch (Exception e) {
            System.debug('Error getting picklist for ' + objectName + '.' + fieldName + ': ' + e.getMessage());
        }
        
        return picklistValues;
    }

    @AuraEnabled
    public static String saveCandidateData(
        String candidateData, String educationData, String familyData, String workData, String bankData
    ) {
        Savepoint sp = Database.setSavepoint();
        try {
            System.debug('=== saveCandidateData called ===');
            System.debug('candidateData: ' + candidateData);
            
            // ---- Candidate Update ----
            Map<String, Object> candidateMap = (Map<String, Object>) JSON.deserializeUntyped(candidateData);
            
            // Validate that we have a candidate ID
            String candidateId = (String) candidateMap.get('Id');
            if (String.isBlank(candidateId)) {
                System.debug('ERROR: Candidate ID is missing from candidateData');
                throw new AuraHandledException('Candidate ID is required for update. Cannot proceed without valid Candidate ID.');
            }
            
            System.debug('Updating Candidate with ID: ' + candidateId);
            
            Candidate__c candidate = new Candidate__c(Id = candidateId);
            
            // Map all candidate fields
            candidate.First_Name__c = (String) candidateMap.get('First_Name__c');
            candidate.Last_Name__c = (String) candidateMap.get('Last_Name__c');
            candidate.Middle_Name__c = (String) candidateMap.get('Middle_Name__c');
            candidate.Salutation__c = (String) candidateMap.get('Salutation__c');
            candidate.Personal_Email__c = (String) candidateMap.get('Personal_Email__c');
            candidate.Phone_No__c = (String) candidateMap.get('Phone_No__c');
            
            if (candidateMap.get('Date_Of_Birth__c') != null) {
                candidate.Date_Of_Birth__c = Date.valueOf((String) candidateMap.get('Date_Of_Birth__c'));
            }
            
            candidate.Gender__c = (String) candidateMap.get('Gender__c');
            candidate.Blood_Group__c = (String) candidateMap.get('Blood_Group__c');
            candidate.Aadhar_Card_Number__c = (String) candidateMap.get('Aadhar_Card_Number__c');
            candidate.PAN_Number__c = (String) candidateMap.get('PAN_Number__c');
            candidate.UAN_Number__c = (String) candidateMap.get('UAN_Number__c');
            candidate.Driving_License_Number__c = (String) candidateMap.get('Driving_License_Number__c');
            
            // Address fields
            candidate.Communication_Address__Street__s = (String) candidateMap.get('Communication_Address__Street__s');
            candidate.Communication_Address__City__s = (String) candidateMap.get('Communication_Address__City__s');
            candidate.Communication_Address__StateCode__s = (String) candidateMap.get('Communication_Address__StateCode__s');
            candidate.Communication_Address__CountryCode__s = (String) candidateMap.get('Communication_Address__CountryCode__s');
            candidate.Communication_Address__PostalCode__s = (String) candidateMap.get('Communication_Address__PostalCode__s');
            
            candidate.Permanent_Address__Street__s = (String) candidateMap.get('Permanent_Address__Street__s');
            candidate.Permanent_Address__City__s = (String) candidateMap.get('Permanent_Address__City__s');
            candidate.Permanent_Address__StateCode__s = (String) candidateMap.get('Permanent_Address__StateCode__s');
            candidate.Permanent_Address__CountryCode__s = (String) candidateMap.get('Permanent_Address__CountryCode__s');
            candidate.Permanent_Address__PostalCode__s = (String) candidateMap.get('Permanent_Address__PostalCode__s');
            
            // Emergency contact
            candidate.Emergency_Contact_Name__c = (String) candidateMap.get('Emergency_Contact_Name__c');
            candidate.Emergency_Contact_Phone__c = (String) candidateMap.get('Emergency_Contact_Phone__c');
            
            // Additional fields
            candidate.Source_Of_Applicant__c = (String) candidateMap.get('Source_Of_Applicant__c');
            candidate.Mode_Of_Advertising__c = (String) candidateMap.get('Mode_Of_Advertising__c');
            candidate.Campus_Name__c = (String) candidateMap.get('Campus_Name__c');
            candidate.Campus_City__c = (String) candidateMap.get('Campus_City__c');
            candidate.Marital_Status__c = (String) candidateMap.get('Marital_Status__c');
            candidate.Referred_Person_Name__c = (String) candidateMap.get('Referred_Person_Name__c');
            candidate.Consultancy_Name__c = (String) candidateMap.get('Consultancy_Name__c');
            candidate.Reference_Name__c = (String) candidateMap.get('Reference_Name__c');
            candidate.Reference_Contact_Info__c = (String) candidateMap.get('Reference_Contact_Info__c');
            
            if (candidateMap.get('Anniversary_Date__c') != null) {
                candidate.Anniversary_Date__c = Date.valueOf((String) candidateMap.get('Anniversary_Date__c'));
            }
            
            if (candidateMap.get('Number_of_Children__c') != null) {
                candidate.Number_of_Children__c = Decimal.valueOf(String.valueOf(candidateMap.get('Number_of_Children__c')));
            }
            
            update candidate;

            // ---- Education Records ----
            // Track all records in original input order for ID mapping back to LWC
            List<Education_Detail__c> allEduRecords = new List<Education_Detail__c>();
            List<Education_Detail__c> eduToInsert = new List<Education_Detail__c>();
            List<Education_Detail__c> eduToUpdate = new List<Education_Detail__c>();
            if (String.isNotBlank(educationData)) {
                List<Object> educationList = (List<Object>) JSON.deserializeUntyped(educationData);
                
                for (Object eduObj : educationList) {
                    Map<String, Object> eduMap = (Map<String, Object>) eduObj;
                    Education_Detail__c edu = new Education_Detail__c();
                    
                    String eduId = (String)eduMap.get('Id');
                    // Check if Id exists AND is a valid 18-char Salesforce ID (not a temp/unique ID)
                    if (String.isNotBlank(eduId) && eduId.length() == 18 && eduId.startsWith('a0')) {
                        edu.Id = eduId;
                        Education_Detail__c mapped = mapEducationFields(edu, eduMap, candidate.Id);
                        eduToUpdate.add(mapped);
                        allEduRecords.add(mapped);
                    } else {
                        Education_Detail__c mapped = mapEducationFields(edu, eduMap, candidate.Id);
                        eduToInsert.add(mapped);
                        allEduRecords.add(mapped);
                    }
                }
                
                if (!eduToInsert.isEmpty()) {
                    insert eduToInsert;
                    System.debug('Inserted ' + eduToInsert.size() + ' education records');
                }
                if (!eduToUpdate.isEmpty()) {
                    update eduToUpdate;
                    System.debug('Updated ' + eduToUpdate.size() + ' education records');
                }
            }

            // ---- Family Records ----
            if (String.isNotBlank(familyData)) {
                List<Object> familyList = (List<Object>) JSON.deserializeUntyped(familyData);
                List<Family_Members__c> famToInsert = new List<Family_Members__c>();
                List<Family_Members__c> famToUpdate = new List<Family_Members__c>();
                
                for (Object famObj : familyList) {
                    Map<String, Object> famMap = (Map<String, Object>) famObj;
                    Family_Members__c fam = new Family_Members__c();
                    
                    String famId = (String)famMap.get('Id');
                    // Check if Id exists AND is a valid 18-char Salesforce ID
                    if (String.isNotBlank(famId) && famId.length() == 18 && famId.startsWith('a0')) {
                        fam.Id = famId;
                        famToUpdate.add(mapFamilyFields(fam, famMap, candidate.Id));
                    } else {
                        // New record - don't set Id
                        famToInsert.add(mapFamilyFields(fam, famMap, candidate.Id));
                    }
                }
                
                if (!famToInsert.isEmpty()) {
                    insert famToInsert;
                    System.debug('Inserted ' + famToInsert.size() + ' family records');
                }
                if (!famToUpdate.isEmpty()) {
                    update famToUpdate;
                    System.debug('Updated ' + famToUpdate.size() + ' family records');
                }
            }

            // ---- Work Experience Records ----
            List<Work_Experience__c> allWorkRecords = new List<Work_Experience__c>();
            List<Work_Experience__c> workToInsert = new List<Work_Experience__c>();
            List<Work_Experience__c> workToUpdate = new List<Work_Experience__c>();
            if (String.isNotBlank(workData)) {
                List<Object> workList = (List<Object>) JSON.deserializeUntyped(workData);
                
                for (Object workObj : workList) {
                    Map<String, Object> workMap = (Map<String, Object>) workObj;
                    Work_Experience__c work = new Work_Experience__c();
                    
                    String workId = (String)workMap.get('Id');
                    // Check if Id exists AND is a valid 18-char Salesforce ID
                    if (String.isNotBlank(workId) && workId.length() == 18 && workId.startsWith('a0')) {
                        work.Id = workId;
                        Work_Experience__c mapped = mapWorkFields(work, workMap, candidate.Id);
                        workToUpdate.add(mapped);
                        allWorkRecords.add(mapped);
                    } else {
                        Work_Experience__c mapped = mapWorkFields(work, workMap, candidate.Id);
                        workToInsert.add(mapped);
                        allWorkRecords.add(mapped);
                    }
                }
                
                if (!workToInsert.isEmpty()) {
                    insert workToInsert;
                    System.debug('Inserted ' + workToInsert.size() + ' work records');
                }
                if (!workToUpdate.isEmpty()) {
                    update workToUpdate;
                    System.debug('Updated ' + workToUpdate.size() + ' work records');
                }
            }

            // ---- Bank Records ----
            List<Bank_Details__c> allBankRecords = new List<Bank_Details__c>();
            List<Bank_Details__c> bankToInsert = new List<Bank_Details__c>();
            List<Bank_Details__c> bankToUpdate = new List<Bank_Details__c>();
            if (String.isNotBlank(bankData)) {
                List<Object> bankList = (List<Object>) JSON.deserializeUntyped(bankData);
                
                for (Object bankObj : bankList) {
                    Map<String, Object> bankMap = (Map<String, Object>) bankObj;
                    Bank_Details__c bank = new Bank_Details__c();
                    
                    String bankId = (String)bankMap.get('Id');
                    // Check if Id exists AND is a valid 18-char Salesforce ID
                    if (String.isNotBlank(bankId) && bankId.length() == 18 && bankId.startsWith('a0')) {
                        bank.Id = bankId;
                        Bank_Details__c mapped = mapBankFields(bank, bankMap, candidate.Id);
                        bankToUpdate.add(mapped);
                        allBankRecords.add(mapped);
                    } else {
                        Bank_Details__c mapped = mapBankFields(bank, bankMap, candidate.Id);
                        bankToInsert.add(mapped);
                        allBankRecords.add(mapped);
                    }
                }
                
                if (!bankToInsert.isEmpty()) {
                    insert bankToInsert;
                    System.debug('Inserted ' + bankToInsert.size() + ' bank records');
                }
                if (!bankToUpdate.isEmpty()) {
                    update bankToUpdate;
                    System.debug('Updated ' + bankToUpdate.size() + ' bank records');
                }
            }

            // Return record IDs in original input order so LWC can attach files to correct records
            Map<String, Object> resultMap = new Map<String, Object>();
            resultMap.put('status', 'SUCCESS');
            resultMap.put('educationIds', collectOrderedIds(allEduRecords));
            resultMap.put('workIds', collectOrderedIds(allWorkRecords));
            resultMap.put('bankIds', collectOrderedIds(allBankRecords));
            return JSON.serialize(resultMap);

        } catch (Exception e) {
            Database.rollback(sp);
            System.debug('Error in saveCandidateData: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving data: ' + e.getMessage() + ' | Line: ' + e.getLineNumber());
        }
    }

    // Field mapping helpers for child objects
    private static Education_Detail__c mapEducationFields(Education_Detail__c edu, Map<String, Object> eduMap, Id candidateId) {
        edu.Candidate__c = candidateId;
        edu.Education_Type__c = (String) eduMap.get('Education_Type__c');
        edu.Institution_Name__c = (String) eduMap.get('Institution_Name__c');
        edu.Board_University__c = (String) eduMap.get('Board_University__c');
        edu.Course_Stream__c = (String) eduMap.get('Course_Stream__c');
        edu.Mode_of_Study__c = (String) eduMap.get('Mode_of_Study__c');
        
        if (eduMap.get('Year_of_Completion__c') != null) {
            edu.Year_of_Completion__c = Date.valueOf((String) eduMap.get('Year_of_Completion__c'));
        }
        if (eduMap.get('Percentage__c') != null) {
            edu.Percentage__c = Decimal.valueOf(String.valueOf(eduMap.get('Percentage__c')));
        }
        
        edu.Certificate_Attached__c = (Boolean) eduMap.get('Certificate_Attached__c');
        return edu;
    }

    private static Family_Members__c mapFamilyFields(Family_Members__c fam, Map<String, Object> famMap, Id candidateId) {
        fam.Candidate__c = candidateId;
        fam.Name__c = (String) famMap.get('Name__c');
        fam.Relationship__c = (String) famMap.get('Relationship__c');
        
        if (famMap.get('Date_Of_Birth__c') != null) {
            fam.Date_Of_Birth__c = Date.valueOf((String) famMap.get('Date_Of_Birth__c'));
        }
        if (famMap.get('Age__c') != null) {
            fam.Age__c = Decimal.valueOf(String.valueOf(famMap.get('Age__c')));
        }
        
        fam.Contact_No__c = (String) famMap.get('Contact_No__c');
        fam.Occupation__c = (String) famMap.get('Occupation__c');
        
        return fam;
    }

    private static Work_Experience__c mapWorkFields(Work_Experience__c work, Map<String, Object> workMap, Id candidateId) {
        work.Candidate__c = candidateId;
        work.Company_Name__c = (String) workMap.get('Company_Name__c');
        work.Designation__c = (String) workMap.get('Designation__c');
        work.Employment_Type__c = (String) workMap.get('Employment_Type__c');
        
        if (workMap.get('Start_Date__c') != null) {
            work.Start_Date__c = Date.valueOf((String) workMap.get('Start_Date__c'));
        }
        if (workMap.get('End_Date__c') != null) {
            work.End_Date__c = Date.valueOf((String) workMap.get('End_Date__c'));
        }
        
        work.Currently_Working__c = (Boolean) workMap.get('Currently_Working__c');
        
        if (workMap.get('Experience_Years__c') != null) {
            work.Experience_Years__c = Decimal.valueOf(String.valueOf(workMap.get('Experience_Years__c')));
        }
        
        work.Skills_Technologies_Used__c = (String) workMap.get('Skills_Technologies_Used__c');
        return work;
    }

    private static Bank_Details__c mapBankFields(Bank_Details__c bank, Map<String, Object> bankMap, Id candidateId) {
        bank.Candidate__c = candidateId;
        bank.Bank_Name__c = (String) bankMap.get('Bank_Name__c');
        bank.Branch_Name__c = (String) bankMap.get('Branch_Name__c');
        bank.Account_Number__c = (String) bankMap.get('Account_Number__c');
        bank.Account_Holder_Name__c = (String) bankMap.get('Account_Holder_Name__c');
        bank.IFSC_Code__c = (String) bankMap.get('IFSC_Code__c');
        bank.Account_Type__c = (String) bankMap.get('Account_Type__c');
        bank.Primary_Account__c = (Boolean) bankMap.get('Primary_Account__c');
        bank.Status__c = (String) bankMap.get('Status__c');
        bank.Remarks__c = (String) bankMap.get('Remarks__c');
        return bank;
    }

    // Collect record IDs in original input order (after DML, inserted records will have their IDs populated)
    private static List<String> collectOrderedIds(List<SObject> records) {
        List<String> ids = new List<String>();
        for (SObject rec : records) {
            ids.add(rec.Id);
        }
        return ids;
    }

     // File upload helpers
    @AuraEnabled
    public static List<Map<String, String>> getRelatedFiles(Id recordId) {
        try {
            System.debug('Getting files for recordId: ' + recordId);
            List<Map<String, String>> results = new List<Map<String, String>>();
            
            List<ContentDocumentLink> cdlList = [
                SELECT ContentDocumentId, ContentDocument.Title, ContentDocument.FileExtension,
                       ContentDocument.ContentSize, ContentDocument.CreatedDate
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :recordId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            System.debug('Found ' + cdlList.size() + ' files');
            
            for (ContentDocumentLink cdl : cdlList) {
                results.add(new Map<String, String>{
                    'documentId' => cdl.ContentDocumentId,
                    'fileName' => cdl.ContentDocument.Title + '.' + cdl.ContentDocument.FileExtension,
                    'fileSize' => String.valueOf(cdl.ContentDocument.ContentSize),
                    'createdDate' => String.valueOf(cdl.ContentDocument.CreatedDate)
                });
            }
            
            return results;
        } catch (Exception e) {
            System.debug('Error in getRelatedFiles: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching files: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static void deleteFile(Id documentId) {
        try {
            System.debug('Deleting file with documentId: ' + documentId);
            
            // Delete the ContentDocument (this will cascade delete ContentDocumentLinks)
            List<ContentDocument> docs = [SELECT Id FROM ContentDocument WHERE Id = :documentId LIMIT 1];
            
            if (!docs.isEmpty()) {
                delete docs;
                System.debug('File deleted successfully');
            } else {
                System.debug('No file found with documentId: ' + documentId);
            }
        } catch (Exception e) {
            System.debug('Error in deleteFile: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
    
    // Verify file upload permissions
    @AuraEnabled
    public static Map<String, Boolean> checkFileUploadPermissions(Id recordId) {
        try {
            Map<String, Boolean> permissions = new Map<String, Boolean>();
            
            // Check if user can create ContentDocumentLink
            permissions.put('canUpload', Schema.sObjectType.ContentDocumentLink.isCreateable());
            permissions.put('canDelete', Schema.sObjectType.ContentDocument.isDeletable());
            
            // Check if record exists and is accessible
            List<Candidate__c> candidates = [SELECT Id FROM Candidate__c WHERE Id = :recordId LIMIT 1];
            permissions.put('recordExists', !candidates.isEmpty());
            
            System.debug('File upload permissions: ' + permissions);
            return permissions;
            
        } catch (Exception e) {
            System.debug('Error checking permissions: ' + e.getMessage());
            throw new AuraHandledException('Error checking permissions: ' + e.getMessage());
        }
    }
    
    // Manual file upload method (alternative to lightning-file-upload)
    @AuraEnabled
    public static String uploadFile(Id recordId, String fileName, String base64Data, String contentType) {
        try {
            System.debug('Uploading file: ' + fileName + ' to recordId: ' + recordId);
            
            // Create ContentVersion
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            
            insert cv;
            System.debug('ContentVersion created with Id: ' + cv.Id);
            
            // Get ContentDocumentId
            cv = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id LIMIT 1];
            
            // Create ContentDocumentLink
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = cv.ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            System.debug('ContentDocumentLink created');
            
            return cv.ContentDocumentId;
            
        } catch (Exception e) {
            System.debug('Error in uploadFile: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error uploading file: ' + e.getMessage());
        }
    }
    // ✅ Marks onboarding as completed
    @AuraEnabled
    public static String markOnboardingCompleted(Id candidateId) {
        try {
            if (candidateId == null) {
                throw new AuraHandledException('Candidate Id is missing.');
            }

            Candidate__c cand = [
                SELECT Id, Onboarding_Status__c
                FROM Candidate__c
                WHERE Id = :candidateId
                LIMIT 1
            ];

            // Update onboarding completion fields
            cand.Onboarding_Status__c = 'Submitted';
            cand.Onboarding_Submitted_Date__c = Date.today();
            update cand;
            // HR notification email is handled by CandidateOnboardingTrigger (runs in system context)

            return 'SUCCESS';
        } catch (Exception e) {
            System.debug('❌ Error in markOnboardingCompleted: ' + e.getMessage());
            throw new AuraHandledException('Error marking onboarding as complete: ' + e.getMessage());
        }
    }

}