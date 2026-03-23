@isTest
public class ResumePdfController_Test {

    @testSetup
    static void setupData() {
        // Create Account with Resume HTML
        Account acc = new Account(
            Name = 'Test Employee',
            Resume_Html__c = '<p>This is a test resume HTML.</p>'
        );
        insert acc;

        // Create Certifications for that Account
        List<Certification__c> certList = new List<Certification__c>();
        certList.add(new Certification__c(
            Name = 'Cert 1',
            Candidate_Name__c = acc.Id,
            Badge_Resource_Name__c = 'Badge1.png'
        ));
        certList.add(new Certification__c(
            Name = 'Cert 2',
            Candidate_Name__c = acc.Id,
            Badge_Resource_Name__c = 'Badge2.png'
        ));
        insert certList;
    }

    @isTest
    static void testWithRecordIdAndNoBadgeParam() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        // ✅ Create a mock Visualforce page
        PageReference pageRef = new PageReference('/apex/ResumePdfPage');
        Test.setCurrentPage(pageRef);

        // ✅ Add recordId param (no badgeNames)
        ApexPages.currentPage().getParameters().put('recordId', acc.Id);

        Test.startTest();
        ResumePdfController controller = new ResumePdfController();
        Test.stopTest();

        // ✅ Assertions
        System.assertNotEquals(null, controller.resumeHtml, 'Resume HTML should be fetched.');
        System.assert(controller.badgeList.size() > 0, 'Badges should be fetched from Certification__c.');
    }

    @isTest
    static void testWithBadgeNamesParamOnly() {
        // ✅ Mock Visualforce page
        PageReference pageRef = new PageReference('/apex/ResumePdfPage');
        Test.setCurrentPage(pageRef);

        // ✅ Add badgeNames param
        ApexPages.currentPage().getParameters().put('badgeNames', 'BadgeX,BadgeY,BadgeZ');

        Test.startTest();
        ResumePdfController controller = new ResumePdfController();
        Test.stopTest();

        // ✅ Assertions
        System.assertEquals(3, controller.badgeList.size(), 'All badges from param should be added.');
        System.assertEquals('BadgeX', controller.badgeList[0]);
    }

    @isTest
    static void testWithRecordIdAndEmptyBadgeNames() {
        Account acc = [SELECT Id FROM Account LIMIT 1];

        PageReference pageRef = new PageReference('/apex/ResumePdfPage');
        Test.setCurrentPage(pageRef);

        ApexPages.currentPage().getParameters().put('recordId', acc.Id);
        ApexPages.currentPage().getParameters().put('badgeNames', '');

        Test.startTest();
        ResumePdfController controller = new ResumePdfController();
        Test.stopTest();

        System.assert(controller.badgeList.size() > 0, 'Should load badges from Certification__c.');
    }

    @isTest
    static void testWithoutRecordIdOrBadgeNames() {
        // ✅ Page with no parameters
        PageReference pageRef = new PageReference('/apex/ResumePdfPage');
        Test.setCurrentPage(pageRef);

        Test.startTest();
        ResumePdfController controller = new ResumePdfController();
        Test.stopTest();

        System.assertEquals(0, controller.badgeList.size(), 'No badges expected without parameters.');
        System.assertEquals(null, controller.resumeHtml, 'No resume HTML expected.');
    }

    @isTest
    static void testInvalidRecordId() {
        // ✅ Page with invalid recordId
        PageReference pageRef = new PageReference('/apex/ResumePdfPage');
        Test.setCurrentPage(pageRef);

        ApexPages.currentPage().getParameters().put('recordId', '001000000000000'); // Invalid
        Test.startTest();
        ResumePdfController controller = new ResumePdfController();
        Test.stopTest();

        System.assertEquals(null, controller.resumeHtml, 'Invalid recordId should not return HTML.');
    }
}