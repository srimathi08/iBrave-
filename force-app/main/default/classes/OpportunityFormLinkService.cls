public with sharing class OpportunityFormLinkService {

    private static final String SECRET_KEY = 'MySecretKey123'; // keep hidden, rotate periodically

    // Generate secure token (used by Apex when sending email, not Flow)
    public static String generateToken(Id oppId, Id contactId, Date expiryDate) {
        System.debug('=== GENERATING TOKEN ===');
        System.debug('Opp Id: ' + oppId);
        System.debug('Contact Id: ' + contactId);
        System.debug('Expiry Date: ' + expiryDate);

        // ✅ Always use yyyy-MM-dd format so Date.valueOf works in validation
       String expiryStr = String.valueOf(expiryDate); 
        System.debug('Expiry Date (formatted): ' + expiryStr);

        // Build raw string
        String raw = oppId + '|' + contactId + '|' + expiryStr + '|' + SECRET_KEY;
        System.debug('Raw String: ' + raw);

        // Generate signature
        Blob hash = Crypto.generateDigest('SHA256', Blob.valueOf(raw));
        String signature = EncodingUtil.convertToHex(hash);
        System.debug('Signature: ' + signature);

        // Final payload
        String payload = oppId + '|' + contactId + '|' + expiryStr + '|' + signature;
        System.debug('Payload: ' + payload);

        // Encode
        String token = EncodingUtil.base64Encode(Blob.valueOf(payload));
        System.debug('Encoded Token: ' + token);

        return token;
    }

    // Wrapper class for input
    public class TokenInput {
        @InvocableVariable(required=true)
        public String token;
    }

    // Wrapper class for output
    public class TokenResult {
        @InvocableVariable public Id opportunityId;
        @InvocableVariable public Id contactId;
        @InvocableVariable public Boolean isValid;
        @InvocableVariable public String message;
    }

    // Method that Flow can call
    @InvocableMethod(label='Validate Opportunity Token' description='Validates token and returns Opportunity + Contact info')
    public static List<TokenResult> validateToken(List<TokenInput> requests) {
        List<TokenResult> results = new List<TokenResult>();

        for (TokenInput req : requests) {
            TokenResult result = new TokenResult();
            try {
                System.debug('=== VALIDATING TOKEN ===');
                System.debug('Incoming Token: ' + req.token);

                Blob decodedBlob = EncodingUtil.base64Decode(req.token);
                String decoded = decodedBlob.toString();
                System.debug('Decoded String: ' + decoded);

                List<String> parts = decoded.split('\\|');
                if (parts.size() < 4) {
                    result.isValid = false;
                    result.message = 'Invalid token format';
                    System.debug('Validation Failed: Invalid token format');
                    results.add(result);
                    continue;
                }

                String oppId = parts[0];
                String contactId = parts[1];
                String expiryStr = parts[2];
                String signature = parts[3];

                System.debug('Opp Id: ' + oppId);
                System.debug('Contact Id: ' + contactId);
                System.debug('Expiry String: ' + expiryStr);
                System.debug('Signature from token: ' + signature);

                // Parse expiry date
                Date expiryDate = Date.valueOf(expiryStr);
                System.debug('Expiry Date parsed: ' + expiryDate);

                if (Date.today() > expiryDate) {
                    result.isValid = false;
                    result.message = 'Token expired';
                    System.debug('Validation Failed: Token expired');
                    results.add(result);
                    continue;
                }

                // Recalculate hash
                String raw = oppId + '|' + contactId + '|' + expiryStr + '|' + SECRET_KEY;
                Blob hash = Crypto.generateDigest('SHA256', Blob.valueOf(raw));
                String expectedSignature = EncodingUtil.convertToHex(hash);

                System.debug('Recalculated Raw: ' + raw);
                System.debug('Expected Signature: ' + expectedSignature);

                if (expectedSignature != signature) {
                    result.isValid = false;
                    result.message = 'Signature mismatch';
                    System.debug('Validation Failed: Signature mismatch');
                    results.add(result);
                    continue;
                }

                // ✅ Success
                result.isValid = true;
                result.opportunityId = Id.valueOf(oppId);
                result.contactId = Id.valueOf(contactId);
                result.message = 'Valid';
                System.debug('Validation Success: ' + result);

            } catch (Exception e) {
                result.isValid = false;
                result.message = 'Error: ' + e.getMessage();
                System.debug('Validation Exception: ' + e.getMessage());
            }
            results.add(result);
        }

        return results;
    }
}