@IsTest
private class AppSettingsTest {

    @IsTest
    static void testGetHrEmail_OverrideBranch() {

        AppSettings.setTestHrEmail('hr@test.com');

        Test.startTest();
        String email = AppSettings.getHrEmail();
        Test.stopTest();

        System.assertEquals('hr@test.com', email);

        // Cleanup
        AppSettings.setTestHrEmail(null);
    }

    @IsTest
    static void testGetHrEmail_FallbackBranch() {

        AppSettings.setTestHrEmail(null);

        Test.startTest();
        String email = AppSettings.getHrEmail();
        Test.stopTest();

        System.assert(String.isNotBlank(email));
    }
}