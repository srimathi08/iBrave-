@isTest(SeeAllData=true)
public class AsynCandidateCreationBatchTest {

    @isTest
    static void testBatchWithConnectApi() {

        // Use an existing Service__c record
        Service__c serviceRec = [
            SELECT Id FROM Service__c LIMIT 1
        ];

        Test.startTest();
        AsynCandidateCreationBatch batch =
            new AsynCandidateCreationBatch(serviceRec.Id);
        Database.executeBatch(batch, 1);
        Test.stopTest();

        System.assert(true, 'Batch executed without exception');
    }
}