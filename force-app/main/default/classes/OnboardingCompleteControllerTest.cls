@IsTest
private class OnboardingCompleteControllerTest {

    // Utility method: create a candidate with a known token
    private static Candidate__c createCandidateWithToken() {
        Candidate__c cand = new Candidate__c(
            First_Name__c = 'John',
            Last_Name__c = 'Doe',
            Personal_Email__c = 'john@test.com',
            Phone_No__c = '9999999999',
            Source_Of_Applicant__c = 'Referred',
            Offer_Acceptance_Token__c = 'ABC123TOKEN'
        );
        insert cand;
        return cand;
    }

    @IsTest
    static void testOnboardingComplete_WithValidToken() {
        // Arrange (Test Data)
        Candidate__c cand = createCandidateWithToken();

        // Simulate VF page request with token parameter
        PageReference pageRef = Page.OnboardingCompletepage; 
        pageRef.getParameters().put('token', 'ABC123TOKEN');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        new OnboardingCompleteController();
        Test.stopTest();

        // Reload updated candidate
        Candidate__c updated = [SELECT Onboarding_Status__c, Onboarding_Submitted_Date__c
                                FROM Candidate__c WHERE Id = :cand.Id];

        System.assertEquals('Submitted', updated.Onboarding_Status__c, 'Status should be updated');
        System.assertNotEquals(null, updated.Onboarding_Submitted_Date__c, 'Submitted date must be set');
        System.assertEquals(Date.today(), updated.Onboarding_Submitted_Date__c, 'Submitted date must be today');
    }

    @IsTest
    static void testOnboardingComplete_NoToken() {
        // No Candidate created, no token provided

        PageReference pageRef = Page.OnboardingCompletepage; // replace with your VF page name
        Test.setCurrentPage(pageRef);

        Test.startTest();
        new OnboardingCompleteController();
        Test.stopTest();

        // No exception expected — nothing to assert
        System.assert(true, 'Controller should run without exceptions even if no token is passed.');
    }
}