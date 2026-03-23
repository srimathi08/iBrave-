@IsTest
public class EmployeeProfileControllerTest {

    private static User createTestUser(String emailPrefix) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        String uniqueVal = String.valueOf(DateTime.now().getTime()) + String.valueOf(Math.abs(Crypto.getRandomInteger()));

        User u = new User(
            Alias = emailPrefix.length() > 8 ? emailPrefix.substring(0, 8) : emailPrefix,
            Email = emailPrefix + uniqueVal + '@example.com',
            EmailEncodingKey = 'UTF-8',
            LastName = 'Employee',
            LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US',
            ProfileId = p.Id,
            TimeZoneSidKey = 'America/Los_Angeles',
            UserName = emailPrefix + uniqueVal + '@example.com',
            Title = 'Legacy Title'
        );
        insert u;
        return u;
    }

    @TestSetup
    static void setupData() {
        Account acc = new Account(Name = 'Test Consultant');
        insert acc;

        Contact con = new Contact(
            FirstName = 'Test',
            LastName = 'Employee',
            Email = 'testemployee@example.com',
            Phone = '1234567890',
            MobilePhone = '0987654321',
            HomePhone = '1122334455',
            MailingStreet = '123 Main St',
            MailingCity = 'San Francisco',
            MailingState = 'California',
            MailingPostalCode = '94105',
            MailingCountry = 'United States',
            Date_of_Joining__c = Date.today().addYears(-2).addDays(-1),
            Employment_Status__c = 'Full Time',
            Emergency_Contact_Name__c = 'Emergency Name',
            Emergency_Contact_Phone__c = '9988776655',
            User_Designation__c = 'Software Engineer',
            User_Department__c = 'Salesforce',
            Employee_ID__c = 'EMP001',
            AccountId = acc.Id
        );
        insert con;

        User u = createTestUser('testemp');
        u.Email = 'testemployee@example.com';
        update u;

        con.Internal_User__c = u.Id;
        update con;

        Project__c proj = new Project__c(
            Name = 'Test Project',
            Status__c = 'Active'
        );
        insert proj;

        Project_Assignment__c pa = new Project_Assignment__c(
            Employee__c = u.Id,
            Project__c = proj.Id
        );
        insert pa;
    }

    @IsTest
    static void testGetEmployeeProfile() {
        User u = [SELECT Id, Email, Title FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = con.Id;
        EmployeeProfileController.disableFallbackLookup = false;

        try {
            System.runAs(u) {
                Test.startTest();
                EmployeeProfileController.EmployeeData data = EmployeeProfileController.getEmployeeProfile();
                Test.stopTest();

                System.assertNotEquals(null, data);
                System.assertEquals(u.Id, data.id);
                System.assertEquals(con.Id, data.contactId);
                System.assertEquals('Test Employee', data.name);
                System.assertEquals('testemployee@example.com', data.email);
                System.assertEquals('1234567890', data.phone);
                System.assertEquals('0987654321', data.mobilePhone);
                System.assertEquals('Software Engineer', data.title);
                System.assertEquals('Salesforce', data.department);
                System.assertEquals('EMP001', data.employeeId);
                System.assertEquals('Full Time', data.status);
                System.assertEquals('Test Consultant', data.consultant);
                System.assertEquals('1122334455', data.homePhone);
                System.assertEquals('Emergency Name', data.emergencyContactName);
                System.assertEquals('9988776655', data.emergencyContactPhone);
                System.assert(data.emergencyContact.contains('Emergency Name'));
                System.assertEquals(2, data.yearsOfExperience);
				System.assert(data.experienceDisplay.contains('Year'));
                System.assertEquals(1, data.projectsCompleted);
                System.assertNotEquals(null, data.address);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
            EmployeeProfileController.disableFallbackLookup = false;
        }
    }

    @IsTest
    static void testGetEmployeeProfile_WithFallbackLookup() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = null;
        EmployeeProfileController.disableFallbackLookup = false;

        try {
            System.runAs(u) {
                Test.startTest();
                EmployeeProfileController.EmployeeData data = EmployeeProfileController.getEmployeeProfile();
                Test.stopTest();

                System.assertNotEquals(null, data);
                System.assertNotEquals(null, data.contactId);
                System.assertEquals('Test Employee', data.name);
                System.assertEquals('Salesforce', data.department);
                System.assertEquals('Software Engineer', data.title);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
            EmployeeProfileController.disableFallbackLookup = false;
        }
    }

    @IsTest
    static void testGetEducationDetails_AndUploadCertificate() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = con.Id;
        EmployeeProfileController.disableFallbackLookup = false;

        try {
            System.runAs(u) {
                Test.startTest();
                String eduId = EmployeeProfileController.uploadCertificate(
                    'Java Certification',
                    'Certification',
                    'Oracle',
                    String.valueOf(Date.today()),
                    'CERT123',
                    EncodingUtil.base64Encode(Blob.valueOf('Test Content')),
                    'cert.pdf'
                );
                Test.stopTest();

                System.assertNotEquals(null, eduId);

                Education_Detail__c edu = [
                    SELECT Id, Contact__c, education_type__c, institution_name__c, Issue_Date__c
                    FROM Education_Detail__c
                    WHERE Id = :eduId
                    LIMIT 1
                ];

                System.assertEquals(con.Id, edu.Contact__c);
                System.assertEquals('Certification', edu.education_type__c);
                System.assertEquals('Oracle', edu.institution_name__c);
                System.assertEquals(Date.today(), edu.Issue_Date__c);

                List<EmployeeProfileController.EducationWrapper> eduList =
                    EmployeeProfileController.getEducationDetails();

                System.assertEquals(1, eduList.size());
                System.assertEquals(eduId, eduList[0].id);
                System.assertNotEquals(null, eduList[0].certificateName);
                System.assertEquals('Certification', eduList[0].certificateType);
                System.assertEquals('Oracle', eduList[0].institution);
                System.assertNotEquals(null, eduList[0].attachedFiles);
                System.assertEquals(1, eduList[0].attachedFiles.size());

                Boolean deleted = EmployeeProfileController.deleteEducationRecord(eduId);
                System.assertEquals(true, deleted);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
            EmployeeProfileController.disableFallbackLookup = false;
        }
    }

    @IsTest
    static void testGetEducationDetails_WithFallbackLookup() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = null;
        EmployeeProfileController.disableFallbackLookup = false;

        try {
            System.runAs(u) {
                Test.startTest();
                String eduId = EmployeeProfileController.uploadCertificate(
                    'Fallback Cert',
                    'Certification',
                    'Oracle',
                    String.valueOf(Date.today()),
                    'CERT456',
                    EncodingUtil.base64Encode(Blob.valueOf('Fallback Content')),
                    'fallback.pdf'
                );

                List<EmployeeProfileController.EducationWrapper> eduList =
                    EmployeeProfileController.getEducationDetails();
                Test.stopTest();

                System.assertNotEquals(null, eduId);
                System.assert(eduList.size() > 0);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
            EmployeeProfileController.disableFallbackLookup = false;
        }
    }

    @IsTest
    static void testGetEducationDetails_NoContact() {
        User u2 = createTestUser('nocont');

        EmployeeProfileController.mockContactId = null;
        EmployeeProfileController.disableFallbackLookup = true;

        try {
            System.runAs(u2) {
                Test.startTest();
                List<EmployeeProfileController.EducationWrapper> eduList =
                    EmployeeProfileController.getEducationDetails();
                Test.stopTest();

                System.assertEquals(0, eduList.size());
            }
        } finally {
            EmployeeProfileController.disableFallbackLookup = false;
            EmployeeProfileController.mockContactId = null;
        }
    }

    @IsTest
    static void testProfileWithoutContact() {
        User u2 = createTestUser('nocontact');

        EmployeeProfileController.mockContactId = null;
        EmployeeProfileController.disableFallbackLookup = true;

        try {
            System.runAs(u2) {
                Test.startTest();
                EmployeeProfileController.EmployeeData data = EmployeeProfileController.getEmployeeProfile();
                Test.stopTest();

                System.assertNotEquals(null, data);
                System.assertEquals(u2.Id, data.id);
                System.assertEquals(null, data.contactId);
                System.assertEquals('Employee', data.name);
                System.assertEquals(u2.Email, data.email);
                System.assertEquals(u2.Title, data.title);
                System.assertEquals(null, data.department);
                System.assertEquals(null, data.employeeId);
            }
        } finally {
            EmployeeProfileController.disableFallbackLookup = false;
            EmployeeProfileController.mockContactId = null;
        }
    }

    @IsTest
    static void testDeleteFile() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = con.Id;

        try {
            System.runAs(u) {
                ContentVersion cv = new ContentVersion(
                    Title = 'DeleteTestFile',
                    PathOnClient = 'DeleteTestFile.pdf',
                    VersionData = Blob.valueOf('File body'),
                    IsMajorVersion = true
                );
                insert cv;

                Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = con.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                insert cdl;

                Test.startTest();
                Boolean deleted = EmployeeProfileController.deleteFile(docId);
                Test.stopTest();

                System.assertEquals(true, deleted);

                Integer countDoc = [SELECT COUNT() FROM ContentDocument WHERE Id = :docId];
                System.assertEquals(0, countDoc);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
        }
    }

    @IsTest
    static void testGetContactPhotoFiles() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = con.Id;

        try {
            System.runAs(u) {
                ContentVersion cv = new ContentVersion(
                    Title = 'ProfilePhoto',
                    PathOnClient = 'ProfilePhoto.jpg',
                    VersionData = Blob.valueOf('Fake image'),
                    IsMajorVersion = true
                );
                insert cv;

                Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

                ContentDocumentLink cdl = new ContentDocumentLink(
                    ContentDocumentId = docId,
                    LinkedEntityId = con.Id,
                    ShareType = 'V',
                    Visibility = 'AllUsers'
                );
                insert cdl;

                Test.startTest();
                List<String> photoFiles = EmployeeProfileController.getContactPhotoFiles();
                Test.stopTest();

                System.assertNotEquals(null, photoFiles);
                System.assert(photoFiles.size() >= 2);
                System.assert(photoFiles[0].contains('Contact ID'));
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
        }
    }

    @IsTest
    static void testGetContactPhotoFiles_NoContact() {
        User u2 = createTestUser('nophoto');

        EmployeeProfileController.mockContactId = null;
        EmployeeProfileController.disableFallbackLookup = true;

        try {
            System.runAs(u2) {
                Test.startTest();
                List<String> result = EmployeeProfileController.getContactPhotoFiles();
                Test.stopTest();

                System.assertEquals(1, result.size());
                System.assertEquals('No contact associated with user', result[0]);
            }
        } finally {
            EmployeeProfileController.disableFallbackLookup = false;
            EmployeeProfileController.mockContactId = null;
        }
    }

    @IsTest
    static void testUploadProfilePhoto_Success() {
        User u = [SELECT Id, Email FROM User WHERE Email = 'testemployee@example.com' LIMIT 1];
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        EmployeeProfileController.mockContactId = con.Id;
        EmployeeProfileController.disableFallbackLookup = false;
        HR_ProfilePhotoService.mockUserId = u.Id;

        try {
            System.runAs(u) {
                Test.startTest();
                String docId = EmployeeProfileController.uploadProfilePhoto(
                    EncodingUtil.base64Encode(Blob.valueOf('fake image body')),
                    'profile.jpg'
                );
                Test.stopTest();

                System.assertNotEquals(null, docId);

                Contact updatedCon = [
                    SELECT Id, Profile_Photo_File_Id__c
                    FROM Contact
                    WHERE Id = :con.Id
                ];
                System.assertEquals(docId, updatedCon.Profile_Photo_File_Id__c);
            }
        } finally {
            EmployeeProfileController.mockContactId = null;
            EmployeeProfileController.disableFallbackLookup = false;
            HR_ProfilePhotoService.mockUserId = null;
        }
    }

    @IsTest
    static void testDeleteEducationRecord_Direct() {
        Contact con = [SELECT Id FROM Contact WHERE Email = 'testemployee@example.com' LIMIT 1];

        Education_Detail__c edu = new Education_Detail__c(
            Contact__c = con.Id,
            education_type__c = 'Certification',
            institution_name__c = 'Test Institute',
            Issue_Date__c = Date.today()
        );
        insert edu;

        Test.startTest();
        Boolean deleted = EmployeeProfileController.deleteEducationRecord(edu.Id);
        Test.stopTest();

        System.assertEquals(true, deleted);
        System.assertEquals(0, [SELECT COUNT() FROM Education_Detail__c WHERE Id = :edu.Id]);
    }
}