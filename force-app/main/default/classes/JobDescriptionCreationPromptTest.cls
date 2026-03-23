@isTest
public class JobDescriptionCreationPromptTest {

    @testSetup
    static void setupData() {
        // Create a Service__c record (required by code)
        Service__c svc = new Service__c(
            Name = 'JD Service',
            emailfrom__c = 'jdtest@example.com'
        );
        insert svc;
    }

    @isTest
    static void testWithValidRecordId() {
        Service__c svc = [SELECT Id FROM Service__c LIMIT 1];

        JobDescriptionCreationPrompt.InputWrapper input = new JobDescriptionCreationPrompt.InputWrapper();
        input.recordId = svc.Id;

        Test.startTest();
        Boolean exceptionThrown = false;
        try {
            List<String> responses = JobDescriptionCreationPrompt.getJDPromptResponses(
                new List<JobDescriptionCreationPrompt.InputWrapper>{ input }
            );
            // In real org, would return JD strings, but in tests ConnectApi will fail
            System.debug('Responses: ' + responses);
        } catch (AuraHandledException ahe) {
            exceptionThrown = true;
            //System.assert(ahe.getMessage().contains('Error in JD Prompt') || ahe.getMessage().contains('No response generated'),'Expected AuraHandledException from ConnectApi');
        }
        Test.stopTest();

        System.assertEquals(true, exceptionThrown, 'An AuraHandledException should be thrown');
    }

    @isTest
    static void testWithNullInput() {
        Test.startTest();
        List<String> result = JobDescriptionCreationPrompt.getJDPromptResponses(null);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Null input should return empty list');
    }

    @isTest
    static void testWithEmptyInputList() {
        Test.startTest();
        List<String> result = JobDescriptionCreationPrompt.getJDPromptResponses(new List<JobDescriptionCreationPrompt.InputWrapper>());
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Empty input list should return empty list');
    }

    @isTest
    static void testWithNullRecordId() {
        JobDescriptionCreationPrompt.InputWrapper input = new JobDescriptionCreationPrompt.InputWrapper();
        input.recordId = null;

        Boolean caught = false;
        try {
            Test.startTest();
            JobDescriptionCreationPrompt.getJDPromptResponses(new List<JobDescriptionCreationPrompt.InputWrapper>{ input });
            Test.stopTest();
        } catch (AuraHandledException ahe) {
            caught = true;
            //System.assert(ahe.getMessage().contains('No recordId provided'), 'Should throw AuraHandledException for null recordId');
        }

        System.assertEquals(true, caught, 'Expected AuraHandledException for null recordId');
    }
}