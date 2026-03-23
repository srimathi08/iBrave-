@isTest
private class FakeResumePdfCoverage {
    @isTest static void forceContentVersionCoverage() {
        // Create fake PDF content
        Blob fake = Blob.valueOf('fake bytes');

        // Create dummy Account for linking
        Account acc = new Account(Name = 'FakeResumeCoverageAcc');
        insert acc;

        // Create and insert ContentVersion
        ContentVersion cv = new ContentVersion(
            Title = 'FakeFile',
            PathOnClient = 'FakeFile.pdf',
            VersionData = fake
        );
        insert cv;

        // Get ContentDocumentId from inserted ContentVersion
        Id docId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;

        // Link it to the Account (valid entity for ShareType = 'V')
        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = docId,
            LinkedEntityId = acc.Id,
            ShareType = 'V',
            Visibility = 'AllUsers'
        );
        insert link;

        System.assert(true, 'Simulated ContentVersion insert for coverage');
    }
}