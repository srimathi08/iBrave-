public class LinkedInService {
    
    private static final String AUTH_URL = 'https://www.linkedin.com/oauth/v2/authorization';
    private static final String TOKEN_URL = 'https://www.linkedin.com/oauth/v2/accessToken';
    private static final String API_URL = 'https://api.linkedin.com/v2';
    
    // Generate authorization URL
    public static String getAuthorizationUrl(String state) {
        String clientId = LinkedInConfig.getClientId();
        String redirectUri = LinkedInConfig.getRedirectUri();
        String scope = 'r_liteprofile r_emailaddress w_member_social';
        
        return AUTH_URL 
            + '?response_type=code'
            + '&client_id=' + EncodingUtil.urlEncode(clientId, 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(redirectUri, 'UTF-8')
            + '&state=' + EncodingUtil.urlEncode(state, 'UTF-8')
            + '&scope=' + EncodingUtil.urlEncode(scope, 'UTF-8');
    }
    
    // Exchange authorization code for access token
    public static String getAccessToken(String authCode) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(TOKEN_URL);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/x-www-form-urlencoded');
        
        String body = 'grant_type=authorization_code'
            + '&code=' + EncodingUtil.urlEncode(authCode, 'UTF-8')
            + '&client_id=' + EncodingUtil.urlEncode(LinkedInConfig.getClientId(), 'UTF-8')
            + '&client_secret=' + EncodingUtil.urlEncode(LinkedInConfig.getClientSecret(), 'UTF-8')
            + '&redirect_uri=' + EncodingUtil.urlEncode(LinkedInConfig.getRedirectUri(), 'UTF-8');
        
        req.setBody(body);
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            return (String) result.get('access_token');
        } else {
            throw new LinkedInException('Failed to get access token: ' + res.getBody());
        }
    }
    
    // Get user profile
    public static Map<String, Object> getUserProfile(String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_URL + '/me');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('X-Restli-Protocol-Version', '2.0.0');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            return (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
        } else {
            throw new LinkedInException('Failed to get profile: ' + res.getBody());
        }
    }
    
    // Get email address
    public static String getEmailAddress(String accessToken) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(API_URL + '/emailAddress?q=members&projection=(elements*(handle~))');
        req.setMethod('GET');
        req.setHeader('Authorization', 'Bearer ' + accessToken);
        req.setHeader('X-Restli-Protocol-Version', '2.0.0');
        
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> result = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            List<Object> elements = (List<Object>) result.get('elements');
            if (elements != null && !elements.isEmpty()) {
                Map<String, Object> element = (Map<String, Object>) elements[0];
                Map<String, Object> handle = (Map<String, Object>) element.get('handle~');
                return (String) handle.get('emailAddress');
            }
        }
        return null;
    }
    
    // Custom exception class
    public class LinkedInException extends Exception {}
}