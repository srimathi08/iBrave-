@IsTest
private class OnboardingFormControllerTest {

    // --------- TEST DATA SETUP ---------
    @TestSetup
    static void setupTestData() {
        Candidate__c cand = new Candidate__c(
            First_Name__c = 'Test',
            Last_Name__c  = 'User',
            Salutation__c = 'Mr.',
            Gender__c     = 'Male',
            Blood_Group__c = 'O+',
            Source_Of_Applicant__c = 'Referred',
            Marital_Status__c      = 'Single'
        );
        insert cand;

        Education_Detail__c edu = new Education_Detail__c(
            Candidate__c = cand.Id,
            Education_Type__c = 'UG',
            Institution_Name__c = 'Test University',
            Board_University__c = 'Test Board',
            Course_Stream__c = 'Science',
            Mode_of_Study__c = 'Full-time',
            Year_of_Completion__c = Date.newInstance(2020, 1, 1),
            Percentage__c = 75
        );
        insert edu;

        Family_Members__c fam = new Family_Members__c(
            Candidate__c = cand.Id,
            Name__c = 'Parent',
            Relationship__c = 'Father',
            Date_Of_Birth__c = Date.newInstance(1960, 1, 1),
            Age__c = 60,
            Contact_No__c = '1234567890',
            Occupation__c = 'Retired'
        );
        insert fam;

        Work_Experience__c work = new Work_Experience__c(
            Candidate__c = cand.Id,
            Company_Name__c = 'Test Corp',
            Designation__c = 'Engineer',
            Employment_Type__c = 'Full-time',
            Start_Date__c = Date.newInstance(2021, 1, 1),
            End_Date__c   = Date.newInstance(2022, 12, 31),
            Currently_Working__c = false,
            Experience_Years__c  = 2,
            Skills_Technologies_Used__c = 'Apex, Salesforce'
        );
        insert work;

        Bank_Details__c bank = new Bank_Details__c(
            Candidate__c = cand.Id,
            Bank_Name__c = 'Test Bank',
            Branch_Name__c = 'Main',
            Account_Number__c = '123456789',
            Account_Holder_Name__c = 'Test User',
            IFSC_Code__c = 'TEST0001234',
            Account_Type__c = 'Savings',
            Primary_Account__c = true,
            Status__c = 'Active',
            Remarks__c = 'Primary'
        );
        insert bank;
    }

    // --------- getCandidateData ---------
    @IsTest
    static void testGetCandidateDataSuccess() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

        Test.startTest();
        Map<String, Object> result = OnboardingFormController.getCandidateData(cand.Id);
        Test.stopTest();

        System.assertNotEquals(null, result);
        System.assert(result.containsKey('candidate'));
        System.assert(result.containsKey('educationRecords'));
        System.assert(result.containsKey('familyRecords'));
        System.assert(result.containsKey('workRecords'));
        System.assert(result.containsKey('bankRecords'));
    }
@IsTest
static void testGetCandidateDataInvalidId() {
    Boolean threw = false;
    Test.startTest();
    try {
        OnboardingFormController.getCandidateData('notARealId');
    } catch (AuraHandledException e) {
        threw = true;                 // we only care that it throws
        System.debug('Expected: ' + e.getMessage());
    }
    Test.stopTest();
    System.assert(threw, 'Expected AuraHandledException for invalid Id');
}

 @IsTest
static void testGetCandidateDataBlankId() {
    Boolean threw = false;
    Test.startTest();
    try {
        OnboardingFormController.getCandidateData(null);
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('Expected: ' + e.getMessage());
    }
    Test.stopTest();
    System.assert(threw, 'Expected AuraHandledException for blank Id');
}

    // --------- getPicklistValues ---------
    @IsTest
    static void testGetPicklistValues() {
        Test.startTest();
        Map<String, List<Map<String, String>>> m = OnboardingFormController.getPicklistValues();
        Test.stopTest();

        System.assertNotEquals(null, m);
        System.assert(m.containsKey('salutation'));
        System.assert(m.containsKey('gender'));
        System.assert(m.containsKey('educationType'));
    }

    // --------- saveCandidateData (update only) ---------
    @IsTest
    static void testSaveCandidateDataUpdateOnly() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

        Map<String, Object> candidateMap = new Map<String, Object>{
            'Id' => cand.Id,
            'First_Name__c' => 'Updated',
            'Last_Name__c'  => 'User',
            'Middle_Name__c' => null,
            'Salutation__c' => 'Ms.',
            'Personal_Email__c' => 'test@example.com',
            'Phone_No__c' => '9876543210',
            'Date_Of_Birth__c' => null,
            'Gender__c' => 'Female',
            'Blood_Group__c' => 'A+',
            'Aadhar_Card_Number__c' => '111122223333',
            'PAN_Number__c' => 'ABCDE1234F',
            'UAN_Number__c' => 'UAN123',
            'Driving_License_Number__c' => 'DL123',
            'Communication_Address__Street__s' => 'Comm St',
            'Communication_Address__City__s' => 'City',
            'Communication_Address__CountryCode__s' => 'IN',
            'Communication_Address__StateCode__s' => null,
            'Communication_Address__PostalCode__s' => '123456',
            'Permanent_Address__Street__s' => 'Perm St',
            'Permanent_Address__City__s' => 'City',
            'Permanent_Address__CountryCode__s' => 'IN',
            'Permanent_Address__StateCode__s' => null,
            'Permanent_Address__PostalCode__s' => '654321',
            'Emergency_Contact_Name__c' => 'EC',
            'Emergency_Contact_Phone__c' => '9999999999',
            'Source_Of_Applicant__c' => 'Referred',
            'Mode_Of_Advertising__c' => 'Online',
            'Campus_Name__c' => 'Campus',
            'Campus_City__c' => 'City',
            'Marital_Status__c' => 'Single',
            'Referred_Person_Name__c' => 'Ref',
            'Consultancy_Name__c' => 'Consult',
            'Reference_Name__c' => 'RefName',
            'Reference_Contact_Info__c' => 'ref@test.com',
            'Anniversary_Date__c' => null,
            'Number_of_Children__c' => null
        };

        String emptyList = '[]';

        Test.startTest();
        String res = OnboardingFormController.saveCandidateData(
            JSON.serialize(candidateMap),
            emptyList, emptyList, emptyList, emptyList
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', res);
    }

    // --------- saveCandidateData (insert + update child rows) ---------
    @IsTest
    static void testSaveCandidateDataWithChildren() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

        Education_Detail__c existingEdu =
            [SELECT Id, Candidate__c FROM Education_Detail__c WHERE Candidate__c = :cand.Id LIMIT 1];

        Map<String, Object> candidateMap = new Map<String, Object>{
            'Id' => cand.Id,
            'First_Name__c' => 'Child',
            'Last_Name__c'  => 'Update'
        };

        List<Object> eduList = new List<Object>{
            new Map<String, Object>{
                'Id' => existingEdu.Id,
                'Education_Type__c' => 'UG',
                'Institution_Name__c' => 'Updated Inst',
				'Certificate_Attached__c'=>true
            },
            new Map<String, Object>{
                'Education_Type__c' => 'PG',
                'Institution_Name__c' => 'New Inst',
				'Certificate_Attached__c'=>true
            }
        };

        List<Object> famList = new List<Object>{
            new Map<String,Object>{
                'Name__c' => 'Mother',
                'Relationship__c' => 'Mother',
                'Age__c' => 55
            }
        };

        List<Object> workList = new List<Object>{
            new Map<String,Object>{
                'Company_Name__c' => 'New Co',
                'Designation__c' => 'Dev',
                'Employment_Type__c' => 'Contract',
                'Experience_Years__c' => 1,
				'Currently_Working__c' => true
            }
        };

        List<Object> bankList = new List<Object>{
            new Map<String,Object>{
                'Bank_Name__c' => 'New Bank',
                'Account_Number__c' => '99999',
                'Account_Holder_Name__c' => 'Test User',
                'IFSC_Code__c' => 'TEST0001111',
                'Account_Type__c' => 'Savings',
                'Primary_Account__c' => false,
                'Status__c' => 'Active'
            }
        };

        Test.startTest();
        String res = OnboardingFormController.saveCandidateData(
            JSON.serialize(candidateMap),
            JSON.serialize(eduList),
            JSON.serialize(famList),
            JSON.serialize(workList),
            JSON.serialize(bankList)
        );
        Test.stopTest();

        System.assertEquals('SUCCESS', res);
    }

   @IsTest
static void testSaveCandidateDataMissingId() {
    // Candidate map without Id
    Map<String,Object> candidateMap = new Map<String,Object>{
        'First_Name__c' => 'NoId'
    };

    Boolean threw = false;

    Test.startTest();
    try {
        OnboardingFormController.saveCandidateData(
            JSON.serialize(candidateMap),
            '[]', '[]', '[]', '[]'
        );
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('Expected exception in saveCandidateDataMissingId: ' + e.getMessage());
    }
    Test.stopTest();

    System.assert(threw, 'Expected AuraHandledException when Candidate Id is missing');
}


    // --------- markOnboardingCompleted ---------
    @IsTest
    static void testMarkOnboardingCompleted() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

        Test.startTest();
        String res = OnboardingFormController.markOnboardingCompleted(cand.Id);
        Test.stopTest();

        System.assertEquals('SUCCESS', res);

        Candidate__c updated =
            [SELECT Onboarding_Status__c, Onboarding_Submitted_Date__c
             FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals('Submitted', updated.Onboarding_Status__c);
        System.assertEquals(Date.today(), updated.Onboarding_Submitted_Date__c);
    }

   @IsTest
static void testMarkOnboardingCompletedNullId() {
    Boolean threw = false;
    Test.startTest();
    try {
        OnboardingFormController.markOnboardingCompleted(null);
    } catch (AuraHandledException e) {
        threw = true;
        System.debug('Expected: ' + e.getMessage());
    }
    Test.stopTest();
    System.assert(threw, 'Expected AuraHandledException for null Id');
}

    // --------- Files: getRelatedFiles, deleteFile, uploadFile, checkFileUploadPermissions ---------
  @IsTest
static void testFileMethods() {
    Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];

    String base64Data = EncodingUtil.base64Encode(Blob.valueOf('Test Content'));

    // Single startTest/stopTest pair
    Test.startTest();

    String contentDocId = OnboardingFormController.uploadFile(
        cand.Id, 'TestFile.txt', base64Data, 'text/plain'
    );

    List<Map<String,String>> files =
        OnboardingFormController.getRelatedFiles(cand.Id);
    System.assert(files.size() > 0);

    Map<String,Boolean> perms =
        OnboardingFormController.checkFileUploadPermissions(cand.Id);
    System.assert(perms.containsKey('canUpload'));
    System.assert(perms.containsKey('canDelete'));
    System.assertEquals(true, perms.get('recordExists'));

    OnboardingFormController.deleteFile((Id)contentDocId);

    Test.stopTest();

    System.assertEquals(
        0,
        [SELECT count() FROM ContentDocument WHERE Id = :contentDocId]
    );
}

}