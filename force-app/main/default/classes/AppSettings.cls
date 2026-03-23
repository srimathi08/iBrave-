public class AppSettings {
    @TestVisible
    private static String testHrEmail;
    // Proper Setter for Tests
    @TestVisible
    static void setTestHrEmail(String email) {
        testHrEmail = email;
    }
    public static String getHrEmail() {

        // Test Override (Now Guaranteed)
        if (Test.isRunningTest() && String.isNotBlank(testHrEmail)) {
            return testHrEmail;
        }

        Application_Settings__mdt settings =
            Application_Settings__mdt.getInstance('Default');

        if (settings != null && String.isNotBlank(settings.HR_Email__c)) {
            return settings.HR_Email__c;
        }

        return UserInfo.getUserEmail();
    }
}