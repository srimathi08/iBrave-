public without sharing class EmployeeProfileController {
    @TestVisible private static Id mockContactId;
	@TestVisible private static Boolean disableFallbackLookup = false;
    
    public class EmployeeData {
        @AuraEnabled public String id;
        @AuraEnabled public String contactId;
        @AuraEnabled public String name;
        @AuraEnabled public String email;
        @AuraEnabled public String phone;
        @AuraEnabled public String mobilePhone;
        @AuraEnabled public String title;
        @AuraEnabled public String department;
        @AuraEnabled public String employeeId;
        @AuraEnabled public String dateOfJoining;
        @AuraEnabled public String status;
        @AuraEnabled public String consultant;
        @AuraEnabled public String address;
        @AuraEnabled public String homePhone;
        @AuraEnabled public String emergencyContact;
        @AuraEnabled public String emergencyContactName;
        @AuraEnabled public String emergencyContactPhone;
        @AuraEnabled public String photoUrl;
        @AuraEnabled public String largePhotoUrl;
        @AuraEnabled public Integer yearsOfExperience;
		@AuraEnabled public String experienceDisplay;
        @AuraEnabled public Integer projectsCompleted;
        @AuraEnabled public Boolean hasPhoto;
        @AuraEnabled public String managerName;
    }
    
    public class EducationWrapper {
        @AuraEnabled public String id;
        @AuraEnabled public String certificateName;
        @AuraEnabled public String certificateType;
        @AuraEnabled public String institution;
        @AuraEnabled public String status;
        @AuraEnabled public String issueDate;
        @AuraEnabled public String expiryDate;
        @AuraEnabled public String certificateNumber;
        @AuraEnabled public List<FileWrapper> attachedFiles;
    }
    
    public class FileWrapper {
        @AuraEnabled public String contentDocumentId;
        @AuraEnabled public String contentVersionId;
        @AuraEnabled public String title;
        @AuraEnabled public String fileExtension;
        @AuraEnabled public String fileType;
        @AuraEnabled public Long contentSize;
        @AuraEnabled public String createdDate;
        @AuraEnabled public String downloadUrl;
    }
    
    @AuraEnabled
    public static EmployeeData getEmployeeProfile() {
        try {
            User currentUser = [
                SELECT Id, ContactId, Name, Email, Phone, Title, 
                       SmallPhotoUrl, FullPhotoUrl, MediumPhotoUrl,
                       MobilePhone, CompanyName, Manager.Name
                FROM User 
                WHERE Id = :UserInfo.getUserId()
                LIMIT 1
            ];
            
            Id effectiveContactId = (Test.isRunningTest() && mockContactId != null) ? mockContactId : currentUser.ContactId;
           if (effectiveContactId == null && !(Test.isRunningTest() && disableFallbackLookup)) {
    List<Contact> linkedContacts = [
        SELECT Id
        FROM Contact
        WHERE Internal_User__c = :currentUser.Id
        LIMIT 1
    ];

    if (!linkedContacts.isEmpty()) {
        effectiveContactId = linkedContacts[0].Id;
    }
}
            EmployeeData empData = new EmployeeData();
            empData.id = currentUser.Id;
            empData.contactId = effectiveContactId;
            
            // Initial defaults from User (will be overridden if Contact exists)
            empData.name = currentUser.Name;
            empData.email = currentUser.Email;
            empData.phone = currentUser.Phone;
            empData.mobilePhone = currentUser.MobilePhone;
            empData.title = currentUser.Title; 
            
            // Get photo from User Record (synced from Contact)
            // if (currentUser.ContactId != null) {
            //    empData.photoUrl = getContactPhotoUrl(currentUser.ContactId);
            // }
            
            // STRICTLY use Standard User Photo
            // The sync logic (Trigger + LWC) ensures User.FullPhotoUrl is updated from Contact
            empData.photoUrl = currentUser.FullPhotoUrl;
            empData.largePhotoUrl = currentUser.FullPhotoUrl;
            
            // HasPhoto logic: 
            // Salesforce default avatars usually contain 'profilephoto/005' or '/005/T' (thumbnails)
            // But if we trust the sync, we can just treat whatever is there as the photo.
            // If we want to show a "placeholder" only if it IS the default, we check for that.
            Boolean isStandardPhoto = String.isBlank(empData.photoUrl) || 
                                     empData.photoUrl.contains('profilephoto/005/');
            
            empData.hasPhoto = !isStandardPhoto;

            if (effectiveContactId != null) {
                // Fetch Contact details
                Contact emp = [
                    SELECT Id, FirstName, LastName, Name, Email, Phone, Title, Department,
                           MailingStreet, MailingCity, MailingState, 
                           MailingPostalCode, MailingCountry,
                           HomePhone, MobilePhone, Birthdate,
                           Description, AccountId, Account.Name,
                           Emergency_Contact_Name__c, Emergency_Contact_Phone__c,
                           Employee_ID__c, Date_of_Joining__c, Employment_Status__c,
                           User_Designation__c, User_Department__c
                    FROM Contact 
                    WHERE Id = :effectiveContactId 
                    LIMIT 1
                ];
                
                // Override with HR Master Record (Contact) values
                empData.name = (String.isNotBlank(emp.FirstName) ? emp.FirstName + ' ' : '') + emp.LastName;
                empData.email = emp.Email;
                empData.phone = emp.Phone;
                empData.mobilePhone = emp.MobilePhone;
                empData.title = emp.User_Designation__c; // Designation mapped from Contact
                empData.department = emp.User_Department__c; // Department mapped from Contact
                empData.consultant = emp.Account?.Name;
                empData.dateOfJoining = emp.Date_of_Joining__c != null ? 
                    emp.Date_of_Joining__c.format() : null;
                empData.status = emp.Employment_Status__c != null ? 
                    emp.Employment_Status__c : 'Full Time';
                empData.employeeId = emp.Employee_ID__c;
                empData.address = buildAddress(emp);
                empData.homePhone = emp.HomePhone;
                empData.emergencyContactName = emp.Emergency_Contact_Name__c;
                empData.emergencyContactPhone = emp.Emergency_Contact_Phone__c;
                empData.emergencyContact = emp.Emergency_Contact_Name__c + 
                    (String.isNotBlank(emp.Emergency_Contact_Phone__c) ? 
                    ' (' + emp.Emergency_Contact_Phone__c + ')' : '');
                
                // Calculate years of experience (full completed years only)
                /*if (emp.Date_of_Joining__c != null) {
                    Date today = Date.today();
                    Integer yearDiff = today.year() - emp.Date_of_Joining__c.year();
                    // Subtract 1 if the joining anniversary has not yet occurred this year
                    if (today.month() < emp.Date_of_Joining__c.month() ||
                        (today.month() == emp.Date_of_Joining__c.month() &&
                         today.day() < emp.Date_of_Joining__c.day())) {
                        yearDiff--;
                    }
                    empData.yearsOfExperience = yearDiff > 0 ? yearDiff : 0;
                }*/
if (emp.Date_of_Joining__c != null) {
    Date today = Date.today();

    Integer years = today.year() - emp.Date_of_Joining__c.year();
    Integer months = today.month() - emp.Date_of_Joining__c.month();

    if (today.day() < emp.Date_of_Joining__c.day()) {
        months--;
    }

    if (months < 0) {
        years--;
        months += 12;
    }

    empData.yearsOfExperience = years > 0 ? years : 0;

    empData.experienceDisplay =
        (years > 0 ? years + ' Year' + (years > 1 ? 's ' : ' ') : '') +
        (months > 0 ? months + ' Month' + (months > 1 ? 's' : '') : '');

    if (String.isBlank(empData.experienceDisplay)) {
        empData.experienceDisplay = '0 Months';
    }
}  
                // Count projects assigned to the current user
                empData.projectsCompleted = [
                    SELECT COUNT()
                    FROM Project_Assignment__c
                    WHERE Employee__c = :UserInfo.getUserId()
                      AND Project__c != null
                ];
                
                empData.managerName = String.isNotBlank(currentUser.Manager?.Name) ? 
                    currentUser.Manager.Name : 'No Manager Assigned';
            }
            
            return empData;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching profile: ' + e.getMessage());
        }

    }
    


    @AuraEnabled
    public static List<EducationWrapper> getEducationDetails() {
        try {
            User currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            Id effectiveContactId = (Test.isRunningTest() && mockContactId != null) ? mockContactId : currentUser.ContactId;
           if (effectiveContactId == null && !(Test.isRunningTest() && disableFallbackLookup)) {
    List<Contact> linkedContacts = [
        SELECT Id
        FROM Contact
        WHERE Internal_User__c = :currentUser.Id
        LIMIT 1
    ];

    if (!linkedContacts.isEmpty()) {
        effectiveContactId = linkedContacts[0].Id;
    }
}
            if (effectiveContactId == null) {
                return new List<EducationWrapper>();
            }
            
            List<EducationWrapper> eduList = new List<EducationWrapper>();
            
            // Query Education_Details__c object
            List<Education_Detail__c> educations = [
                SELECT Id, Name, education_type__c,
                       	institution_name__c,Issue_Date__c, CreatedDate
                FROM Education_Detail__c
                WHERE Contact__c = :effectiveContactId
                ORDER BY CreatedDate DESC
            ];
            
            // Get all ContentDocumentLinks for these education records
            Set<Id> educationIds = new Set<Id>();
            for (Education_Detail__c edu : educations) {
                educationIds.add(edu.Id);
            }
            
            Map<Id, List<FileWrapper>> filesMap = getFilesForRecords(educationIds);
            
            for (Education_Detail__c edu : educations) {
                EducationWrapper wrapper = new EducationWrapper();
                wrapper.id = edu.Id;
                wrapper.certificateName = edu.Name;
                wrapper.certificateType = edu.education_type__c;
                wrapper.institution = edu.institution_name__c;
               
                wrapper.issueDate = edu.Issue_Date__c != null ? 
                    edu.Issue_Date__c.format() : null;
                
               wrapper.attachedFiles = filesMap.get(edu.Id);
                if (wrapper.attachedFiles == null) {
                    wrapper.attachedFiles = new List<FileWrapper>();
                }
                
                eduList.add(wrapper);
            }
            
            return eduList;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching education: ' + e.getMessage());
        }
    }

    
    private static Map<Id, List<FileWrapper>> getFilesForRecords(Set<Id> recordIds) {
        Map<Id, List<FileWrapper>> filesMap = new Map<Id, List<FileWrapper>>();
        
        // Initialize map
        for (Id recordId : recordIds) {
            filesMap.put(recordId, new List<FileWrapper>());
        }
        
        if (recordIds.isEmpty()) {
            return filesMap;
        }
        
        // Query ContentDocumentLinks
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId, LinkedEntityId, ContentDocument.LatestPublishedVersionId,
                   ContentDocument.Title, ContentDocument.FileExtension,
                   ContentDocument.FileType, ContentDocument.ContentSize,
                   ContentDocument.CreatedDate
            FROM ContentDocumentLink
            WHERE LinkedEntityId IN :recordIds
            ORDER BY ContentDocument.CreatedDate DESC
        ];
        
        for (ContentDocumentLink link : links) {
            FileWrapper file = new FileWrapper();
            file.contentDocumentId = link.ContentDocumentId;
            file.contentVersionId = link.ContentDocument.LatestPublishedVersionId;
            file.title = link.ContentDocument.Title;
            file.fileExtension = link.ContentDocument.FileExtension;
            file.fileType = getFileIcon(link.ContentDocument.FileExtension);
            file.contentSize = link.ContentDocument.ContentSize;
            file.createdDate = link.ContentDocument.CreatedDate.format('MMM dd, yyyy');
            file.downloadUrl = '/sfc/servlet.shepherd/document/download/' + 
                link.ContentDocumentId;
            
            filesMap.get(link.LinkedEntityId).add(file);
        }
        
        return filesMap;
    }
    
    private static String getFileIcon(String extension) {
        Map<String, String> iconMap = new Map<String, String>{
            'pdf' => 'doctype:pdf',
            'doc' => 'doctype:word',
            'docx' => 'doctype:word',
            'xls' => 'doctype:excel',
            'xlsx' => 'doctype:excel',
            'jpg' => 'doctype:image',
            'jpeg' => 'doctype:image',
            'png' => 'doctype:image',
            'gif' => 'doctype:image'
        };
        return iconMap.get(extension?.toLowerCase()) != null ? 
            iconMap.get(extension.toLowerCase()) : 'doctype:attachment';
    }
    
    // Create Education_Details__c record with uploaded certificate
    @AuraEnabled
    public static String uploadCertificate(String certificateName, String certificateType, 
                                          String institution, String issueDate, 
                                          String certificateNumber, String base64Data, 
                                          String fileName) {
        try {
            User currentUser = [SELECT ContactId, Name FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            Id effectiveContactId = (Test.isRunningTest() && mockContactId != null) ? mockContactId : currentUser.ContactId;
           if (effectiveContactId == null && !(Test.isRunningTest() && disableFallbackLookup)) {
    List<Contact> linkedContacts = [
        SELECT Id
        FROM Contact
        WHERE Internal_User__c = :currentUser.Id
        LIMIT 1
    ];

    if (!linkedContacts.isEmpty()) {
        effectiveContactId = linkedContacts[0].Id;
    }
}
            if (effectiveContactId == null) {
                throw new AuraHandledException('No contact associated with user');
            }

            // Create Education_Details__c record
            Education_Detail__c eduRecord = new Education_Detail__c();
            eduRecord.Contact__c = effectiveContactId;
            // eduRecord.Name is auto-number, skipping manual assignment
            eduRecord.education_type__c = certificateType;
            eduRecord.institution_name__c = institution;
          
            
            if (String.isNotBlank(issueDate)) {
                eduRecord.Issue_Date__c = Date.valueOf(issueDate);
            }
            
            insert eduRecord;
            
            // Upload file and link to Education record
            if (String.isNotBlank(base64Data) && String.isNotBlank(fileName)) {
                ContentVersion cv = new ContentVersion();
                cv.Title = fileName;
                cv.PathOnClient = fileName;
                cv.VersionData = EncodingUtil.base64Decode(base64Data);
                cv.IsMajorVersion = true;
                
                // Set NetworkId for Community users
                Id networkId = Network.getNetworkId();
                if (networkId != null) {
                    cv.NetworkId = networkId;
                }
                
                insert cv;
                
                Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
                
                ContentDocumentLink cdl = new ContentDocumentLink();
                cdl.ContentDocumentId = conDocId;
                cdl.LinkedEntityId = eduRecord.Id;
                cdl.ShareType = 'V';
                cdl.Visibility = 'AllUsers';
                insert cdl;
            }
            
            // Send HR email notification asynchronously
            sendCertificateUploadAlert(
                currentUser.Name,
                certificateName,
                certificateType,
                institution,
                fileName
            );
            
            return eduRecord.Id;
            
        } catch (Exception e) {
            System.debug('EXCEPTION IN uploadCertificate: ' + e.getMessage());
            System.debug('STACK TRACE: ' + e.getStackTraceString());
            throw new AuraHandledException('Error uploading certificate: ' + e.getMessage());
        }
    }
    
    @future
    private static void sendCertificateUploadAlert(String employeeName, String certName, 
                                                    String certType, String institution,
                                                    String fileName) {
        try {
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            // Testing: priyadharsini.gunasekaran@quadrobay.com 
            // Production: change to it-admin@quadrobay.com
            mail.setToAddresses(new String[]{ 'priyadharsini.gunasekaran@quadrobay.com' });
            mail.setSubject('📄 Document Upload Alert — ' + employeeName);
            mail.setHtmlBody(
                '<html><body style="font-family: Arial, sans-serif; color: #333;">' +
                '<div style="max-width: 600px; margin: 0 auto; border: 1px solid #e0e0e0; border-radius: 8px; overflow: hidden;">' +
                
                // Header
                '<div style="background: linear-gradient(135deg, #1a73e8, #0d47a1); padding: 20px; color: white;">' +
                '<h2 style="margin: 0;">📄 Document Upload Notification</h2>' +
                '</div>' +
                
                // Body
                '<div style="padding: 24px;">' +
                '<p>An employee has uploaded a new document to their profile:</p>' +
                '<table style="width: 100%; border-collapse: collapse; margin: 16px 0;">' +
                '<tr><td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; color: #555; width: 40%;">Employee</td>' +
                '<td style="padding: 10px; border-bottom: 1px solid #eee;">' + employeeName + '</td></tr>' +
                '<tr><td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Certificate Type</td>' +
                '<td style="padding: 10px; border-bottom: 1px solid #eee;">' + (String.isNotBlank(certType) ? certType : 'N/A') + '</td></tr>' +
                '<tr><td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Certificate Name</td>' +
                '<td style="padding: 10px; border-bottom: 1px solid #eee;">' + (String.isNotBlank(certName) ? certName : 'N/A') + '</td></tr>' +
                '<tr><td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">Institution</td>' +
                '<td style="padding: 10px; border-bottom: 1px solid #eee;">' + (String.isNotBlank(institution) ? institution : 'N/A') + '</td></tr>' +
                '<tr><td style="padding: 10px; border-bottom: 1px solid #eee; font-weight: bold; color: #555;">File Name</td>' +
                '<td style="padding: 10px; border-bottom: 1px solid #eee;">' + (String.isNotBlank(fileName) ? fileName : 'N/A') + '</td></tr>' +
                '<tr><td style="padding: 10px; font-weight: bold; color: #555;">Uploaded At</td>' +
                '<td style="padding: 10px;">' + Datetime.now().format('MMM dd, yyyy hh:mm a') + '</td></tr>' +
                '</table>' +
                '<p style="color: #888; font-size: 12px;">This is an automated notification from iBrave HRMS.</p>' +
                '</div>' +
                
                '</div>' +
                '</body></html>'
            );
            mail.setSaveAsActivity(false);
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
        } catch (Exception e) {
            System.debug('Error sending certificate upload HR alert: ' + e.getMessage());
        }
    }
    
    // Upload profile photo to Contact's Files
    @AuraEnabled
    public static String uploadProfilePhoto(String base64Data, String fileName) {
        try {
            User currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            Id conId = (Test.isRunningTest() && mockContactId != null) ? mockContactId : currentUser.ContactId;
           if (conId == null && !(Test.isRunningTest() && disableFallbackLookup)) {
    List<Contact> linkedContacts = [
        SELECT Id
        FROM Contact
        WHERE Internal_User__c = :currentUser.Id
        LIMIT 1
    ];

    if (!linkedContacts.isEmpty()) {
        conId = linkedContacts[0].Id;
    }
}
            if (conId == null) {
                throw new AuraHandledException('No contact associated with user');
            }
            
            // Delete existing profile photos
            List<ContentDocumentLink> existingPhotos = [
                SELECT ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :conId
                AND (ContentDocument.Title LIKE '%Profile%' 
                     OR ContentDocument.Title LIKE '%Photo%'
                     OR ContentDocument.Title = 'ProfilePhoto')
            ];
            
            if (!existingPhotos.isEmpty()) {
                List<Id> docIds = new List<Id>();
                for (ContentDocumentLink link : existingPhotos) {
                    docIds.add(link.ContentDocumentId);
                }
                List<ContentDocument> docsToDelete = [
                    SELECT Id FROM ContentDocument WHERE Id IN :docIds
                ];
                delete docsToDelete;
            }
            
            // Create new profile photo with standardized title
            ContentVersion cv = new ContentVersion();
            cv.Title = 'ProfilePhoto';
            cv.PathOnClient = 'ProfilePhoto.' + (fileName.contains('.') ? fileName.substringAfterLast('.') : 'jpg');
            cv.VersionData = EncodingUtil.base64Decode(base64Data);
            cv.IsMajorVersion = true;
            
            // Set NetworkId for Community users
            Id networkId = Network.getNetworkId();
            if (networkId != null) {
                cv.NetworkId = networkId;
            }
            
            insert cv;
            
            // Get ContentDocument Id
            Id conDocId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
            
            // Use standard HR Profile Photo Service to mark and sync
            HR_ProfilePhotoService.markContactProfilePhoto(conId, conDocId);
            
            return conDocId;
            
        } catch (Exception e) {
            System.debug('EXCEPTION IN uploadProfilePhoto: ' + e.getMessage());
            System.debug('STACK TRACE: ' + e.getStackTraceString());
            throw new AuraHandledException('Error uploading photo: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Boolean deleteFile(String contentDocumentId) {
        try {
            ContentDocument doc = [
                SELECT Id FROM ContentDocument 
                WHERE Id = :contentDocumentId 
                LIMIT 1
            ];
            delete doc;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting file: ' + e.getMessage());
        }
    }
    // NEW: Method to verify contact has photos
    @AuraEnabled
    public static List<String> getContactPhotoFiles() {
        try {
            User currentUser = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            
            Id conId = (Test.isRunningTest() && mockContactId != null) ? mockContactId : currentUser.ContactId;
            if (conId == null && !(Test.isRunningTest() && disableFallbackLookup)) {
    List<Contact> linkedContacts = [
        SELECT Id
        FROM Contact
        WHERE Internal_User__c = :currentUser.Id
        LIMIT 1
    ];

    if (!linkedContacts.isEmpty()) {
        conId = linkedContacts[0].Id;
    }
}
            if (conId == null) {
                return new List<String>{'No contact associated with user'};
            }
            
            List<String> photoInfo = new List<String>();
            photoInfo.add('Contact ID: ' + conId);
            
            List<ContentDocumentLink> allFiles = [
                SELECT ContentDocument.Title,
                       ContentDocument.FileExtension,
                       ContentDocument.CreatedDate,
                       ContentDocument.LatestPublishedVersionId,
                       ContentDocumentId
                FROM ContentDocumentLink
                WHERE LinkedEntityId = :conId
                ORDER BY ContentDocument.CreatedDate DESC
            ];
            
            photoInfo.add('Total files linked to contact: ' + allFiles.size());
            
            for (ContentDocumentLink link : allFiles) {
                String fileInfo = 'File: ' + link.ContentDocument.Title + 
                                ' | Type: ' + link.ContentDocument.FileExtension +
                                ' | Created: ' + link.ContentDocument.CreatedDate +
                                ' | DocId: ' + link.ContentDocumentId;
                photoInfo.add(fileInfo);
            }
            
            return photoInfo;
            
        } catch (Exception e) {
            return new List<String>{'Error: ' + e.getMessage()};
        }
    }
    @AuraEnabled
    public static Boolean deleteEducationRecord(String educationId) {
        try {
            Education_Detail__c edu = [
                SELECT Id FROM Education_Detail__c 
                WHERE Id = :educationId 
                LIMIT 1
            ];
            delete edu;
            return true;
        } catch (Exception e) {
            throw new AuraHandledException('Error deleting education record: ' + e.getMessage());
        }
    }
    
    private static String buildAddress(Contact emp) {
        List<String> addressParts = new List<String>();
        if (String.isNotBlank(emp.MailingStreet)) addressParts.add(emp.MailingStreet);
        if (String.isNotBlank(emp.MailingCity)) addressParts.add(emp.MailingCity);
        if (String.isNotBlank(emp.MailingState)) addressParts.add(emp.MailingState);
        if (String.isNotBlank(emp.MailingPostalCode)) addressParts.add(emp.MailingPostalCode);
        if (String.isNotBlank(emp.MailingCountry)) addressParts.add(emp.MailingCountry);
        
        return !addressParts.isEmpty() ? String.join(addressParts, ', ') : null;
    }
}