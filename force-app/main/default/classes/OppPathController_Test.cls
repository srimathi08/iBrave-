@isTest
public class OppPathController_Test {
    
    @isTest
    static void testGetOpportunityInfo() {
        // Query any active RecordType for Opportunity
        RecordType rt = [
            SELECT Id, DeveloperName 
            FROM RecordType 
            WHERE SObjectType = 'Opportunity' 
            LIMIT 1
        ];

        // Create test Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Prospecting',
            CloseDate = System.today().addDays(30),
            RecordTypeId = rt.Id
        );
        insert opp;

        // Execute test
        Test.startTest();
        Map<String, String> result = OppPathController.getOpportunityInfo(opp.Id);
        Test.stopTest();

        // Validate returned values
        System.assertNotEquals(null, result, 'Result should not be null');
        System.assertEquals('Prospecting', result.get('StageName'), 'StageName should match');
        System.assertEquals(rt.DeveloperName, result.get('RecordType'), 'RecordType DeveloperName should match');

        // Test null recordId branch
        Map<String, String> nullResult = OppPathController.getOpportunityInfo(null);
        System.assertEquals(null, nullResult, 'Result should be null when Id is null');
    }
}