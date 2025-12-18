public with sharing class GetLoginUrlController {

    @AuraEnabled(cacheable=true)
    public static String getLoginUrl() {
        // Site.getBaseUrl() already returns String in your org
        return Site.getBaseUrl() + '/login';
    }
}