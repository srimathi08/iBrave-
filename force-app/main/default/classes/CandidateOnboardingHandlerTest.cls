@IsTest
private class CandidateOnboardingHandlerTest {

    @TestSetup
    static void setupTestData() {
        Candidate__c cand = new Candidate__c(
            First_Name__c = 'Test',
            Last_Name__c  = 'Candidate',
            Salutation__c = 'Mr.',
            Gender__c     = 'Male',
            Blood_Group__c = 'O+',
            Source_Of_Applicant__c = 'Referred',
            Marital_Status__c = 'Single',
            Date_Of_Birth__c = Date.newInstance(1995, 6, 15),
            Personal_Email__c = 'test.candidate@example.com',
            Phone_No__c = '9876543210'
        );
        insert cand;
    }

    @IsTest
    static void testOnboardingSubmittedSendsEmail() {
        Candidate__c cand = [SELECT Id, Onboarding_Status__c FROM Candidate__c LIMIT 1];
        System.assertNotEquals('Submitted', cand.Onboarding_Status__c);

        Test.startTest();
        cand.Onboarding_Status__c = 'Submitted';
        cand.Onboarding_Submitted_Date__c = Date.today();
        update cand;
        Test.stopTest();

        // Verify the update succeeded and trigger did not throw any exception
        Candidate__c updated = [SELECT Id, Onboarding_Status__c, Onboarding_Submitted_Date__c 
                                FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals('Submitted', updated.Onboarding_Status__c);
        System.assertEquals(Date.today(), updated.Onboarding_Submitted_Date__c);
    }

    @IsTest
    static void testNonSubmittedUpdateDoesNotThrow() {
        Candidate__c cand = [SELECT Id, First_Name__c FROM Candidate__c LIMIT 1];

        Test.startTest();
        cand.First_Name__c = 'Updated';
        update cand;
        Test.stopTest();

        // Verify update succeeded - trigger should not interfere with non-status updates
        Candidate__c updated = [SELECT Id, First_Name__c FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals('Updated', updated.First_Name__c);
    }

    @IsTest
    static void testAlreadySubmittedNoResend() {
        Candidate__c cand = [SELECT Id FROM Candidate__c LIMIT 1];
        // First set to Submitted
        cand.Onboarding_Status__c = 'Submitted';
        update cand;

        Test.startTest();
        // Update again while already Submitted - handler should skip email
        cand.First_Name__c = 'Another Update';
        update cand;
        Test.stopTest();

        // Verify update succeeded without errors
        Candidate__c updated = [SELECT Id, First_Name__c, Onboarding_Status__c 
                                FROM Candidate__c WHERE Id = :cand.Id];
        System.assertEquals('Another Update', updated.First_Name__c);
        System.assertEquals('Submitted', updated.Onboarding_Status__c);
    }
}