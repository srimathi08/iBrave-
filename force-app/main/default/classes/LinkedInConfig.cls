public class LinkedInConfig {
    
    public static String getClientId() {
        LinkedIn_Configuration__mdt config = [
            SELECT Client_Id_c__c
            FROM LinkedIn_Configuration__mdt 
            WHERE DeveloperName = 'Default' 
            LIMIT 1
        ];
        return config.Client_Id_c__c;
    }
    
    public static String getClientSecret() {
        LinkedIn_Configuration__mdt config = [
            SELECT Client_Secret_c__c
            FROM LinkedIn_Configuration__mdt 
            WHERE DeveloperName = 'Default' 
            LIMIT 1
        ];
        return config.Client_Secret_c__c;
    }
    
    public static String getRedirectUri() {
        LinkedIn_Configuration__mdt config = [
            SELECT Redirect_URI_c__c
            FROM LinkedIn_Configuration__mdt 
            WHERE DeveloperName = 'Default' 
            LIMIT 1
        ];
        return config.Redirect_URI_c__c;
    }
}