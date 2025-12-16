/*public with sharing class CustomLoginController {
    @AuraEnabled
    public static String loginUser(String username, String password, String startUrl) {
        try {
            // Use Site.login to authenticate the user on the Experience Cloud site
            PageReference loginPage = Site.login(username, password, startUrl);
            return loginPage.getUrl();
        } catch (Exception ex) {
            return 'FAILED: ' + ex.getMessage();
        }
    }
}*/
public with sharing class CustomLoginController {

    @AuraEnabled
    public static String login(String username, String password) {
        try {
            PageReference loginPage = Site.login(username, password, null);

            if (loginPage != null) {
                return loginPage.getUrl(); // Success redirect
            } else {
                return 'ERROR: Invalid login. Please check your username and password.';
            }
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }

    @AuraEnabled
    public static String forgotPassword(String username) {
        try {
            User u = [SELECT Id, Username FROM User WHERE Username = :username LIMIT 1];
            System.resetPassword(u.Id, true); 
            // true = send email with reset link
            return 'SUCCESS: Password reset instructions sent to registered email.';
        } catch (QueryException qe) {
            return 'ERROR: No user found with that username.';
        } catch (Exception e) {
            return 'ERROR: ' + e.getMessage();
        }
    }
}