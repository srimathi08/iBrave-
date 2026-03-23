@IsTest
private class OpportunityFileController_Test {

    @TestSetup
    static void setupTestData() {
        // 1️⃣ Create a test Opportunity
        Opportunity opp = new Opportunity(
            Name = 'Test Opportunity',
            StageName = 'Discovery',
            CloseDate = Date.today().addDays(10)
        );
        insert opp;

        // 2️⃣ Create a test ContentVersion
        ContentVersion ver = new ContentVersion(
            Title = 'TestFile',
            PathOnClient = 'TestFile.pdf',
            VersionData = Blob.valueOf('Sample file content'),
            Related_Stage__c = 'Discovery'
        );
        insert ver;

        // 3️⃣ Retrieve the generated ContentDocumentId
        Id docId = [
            SELECT ContentDocumentId FROM ContentVersion WHERE Id = :ver.Id
        ].ContentDocumentId;

        // 4️⃣ Link ContentDocument to the Opportunity
        ContentDocumentLink link = new ContentDocumentLink(
            LinkedEntityId = opp.Id,
            ContentDocumentId = docId,
            ShareType = 'V', // Viewer access
            Visibility = 'AllUsers'
        );
        insert link;
    }

    @IsTest
    static void testGetStageFiles_ReturnsFiles() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];

        Test.startTest();
        List<ContentVersion> result = OpportunityFileController.getStageFiles(opp.Id, opp.StageName);
        Test.stopTest();

        System.assertNotEquals(0, result.size(), 'Expected to find at least one file.');
        System.assertEquals(opp.StageName, result[0].Related_Stage__c, 'Stage should match.');
        System.assertEquals('TestFile', result[0].Title, 'File title should match expected.');
    }

    @IsTest
    static void testGetStageFiles_NoFiles() {
        Opportunity opp2 = new Opportunity(
            Name = 'Empty Opportunity',
            StageName = 'Negotiate',
            CloseDate = Date.today().addDays(5)
        );
        insert opp2;

        Test.startTest();
        List<ContentVersion> result = OpportunityFileController.getStageFiles(opp2.Id, opp2.StageName);
        Test.stopTest();

        System.assertEquals(0, result.size(), 'Should return an empty list when no files are linked.');
    }

    @IsTest
    static void testUpdateFileStage() {
        Opportunity opp = [SELECT Id, StageName FROM Opportunity LIMIT 1];
        ContentVersion ver = [SELECT ContentDocumentId FROM ContentVersion LIMIT 1];

        opp.StageName = 'Closed Won';
        update opp;

        Test.startTest();
        OpportunityFileController.updateFileStage(ver.ContentDocumentId, opp.Id);
        Test.stopTest();

        ContentVersion updatedVer = [
            SELECT Related_Stage__c
            FROM ContentVersion
            WHERE ContentDocumentId = :ver.ContentDocumentId
            LIMIT 1
        ];

        System.assertEquals('Closed Won', updatedVer.Related_Stage__c, 'Stage should be updated correctly.');
    }
}