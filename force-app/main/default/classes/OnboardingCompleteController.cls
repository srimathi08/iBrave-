public class OnboardingCompleteController {
    public OnboardingCompleteController() {
        String token = ApexPages.currentPage().getParameters().get('token');
        if (String.isNotBlank(token)) {
            try {
                Candidate__c candidate = [SELECT Id FROM Candidate__c 
                                         WHERE Offer_Acceptance_Token__c = :token LIMIT 1];
                candidate.Onboarding_Status__c = 'Submitted';
                candidate.Onboarding_Submitted_Date__c = Date.today();
                update candidate;
            } catch (Exception e) {
                System.debug('Error updating onboarding status: ' + e.getMessage());
            }
        }
    }
}