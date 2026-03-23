public class WhisperTranscriptionService {
    private static final String WHISPER_API_URL = 'https://afrose0719-whisper-api.hf.space/transcribe';
    
    @future(Callout=true)
    public static void transcribeAudioFile(String contentVersionId, String recordId) {
        String errorMessage = '';
        try {
            ContentVersion cv = [
                SELECT VersionData, FileType, Title, ContentSize
                FROM ContentVersion 
                WHERE Id = :contentVersionId 
                LIMIT 1
            ];
            
            System.debug('File Info - Type: ' + cv.FileType + ', Size: ' + cv.ContentSize + ' bytes');
            
            String transcription = callWhisperAPI(cv.VersionData, cv.FileType);
            
            if (String.isNotBlank(transcription)) {
                updateAudioText(transcription, recordId, true, '');
                System.debug('✓ Transcription successful: ' + transcription);
            } else {
                errorMessage = 'Empty transcription returned from API';
                updateAudioText('', recordId, false, errorMessage);
                System.debug('✗ ' + errorMessage);
            }
            
        } catch (Exception e) {
            errorMessage = 'Error: ' + e.getMessage() + ' | Line: ' + e.getLineNumber();
            System.debug('✗ Transcription failed: ' + errorMessage);
            updateAudioText('', recordId, false, errorMessage);
            UtilityClass.createElog(e);
        }
    }
    
    private static String callWhisperAPI(Blob audioData, String fileType) {
        HttpRequest req = new HttpRequest();
        req.setEndpoint(WHISPER_API_URL);
        req.setMethod('POST');
        req.setTimeout(120000);
        
        // Generate unique boundary
        String boundary = 'Boundary' + String.valueOf(Math.abs(Crypto.getRandomLong()));
        
        // Build multipart body using hex encoding (CRITICAL for preserving binary data)
        String header = '--' + boundary + '\r\n' +
                       'Content-Disposition: form-data; name="file"; filename="audio.' + fileType.toLowerCase() + '"\r\n' +
                       'Content-Type: audio/' + fileType.toLowerCase() + '\r\n\r\n';
        
        String footer = '\r\n--' + boundary + '--';
        
        // Convert strings to hex (preserves exact byte structure)
        String headerHex = EncodingUtil.convertToHex(Blob.valueOf(header));
        String audioHex = EncodingUtil.convertToHex(audioData);
        String footerHex = EncodingUtil.convertToHex(Blob.valueOf(footer));
        
        // Combine hex strings
        String combinedHex = headerHex + audioHex + footerHex;
        
        // Convert back to blob
        Blob bodyBlob = EncodingUtil.convertFromHex(combinedHex);
        
        // Set headers and body
        req.setHeader('Content-Type', 'multipart/form-data; boundary=' + boundary);
        req.setHeader('Content-Length', String.valueOf(bodyBlob.size()));
        req.setBodyAsBlob(bodyBlob);
        
        System.debug('→ Request Size: ' + bodyBlob.size() + ' bytes');
        System.debug('→ Boundary: ' + boundary);
        
        // Send request
        Http http = new Http();
        HttpResponse res = http.send(req);
        
        System.debug('← Response Status: ' + res.getStatusCode() + ' ' + res.getStatus());
        System.debug('← Response Body: ' + res.getBody());
        
        if (res.getStatusCode() == 200) {
            Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
            
            // Check for both possible response fields
            String transcription = (String) responseMap.get('text');
            
            if (String.isBlank(transcription)) {
                throw new CalloutException('API returned empty transcription');
            }
            
            return transcription.trim();
            
        } else {
            throw new CalloutException('Whisper API Error [' + res.getStatusCode() + ']: ' + res.getBody());
        }
    }
    
    /**
     * Update record with transcription result
     */
    private static void updateAudioText(String audioData, String recordId, Boolean success, String error) {
        try {
            Service__c ser = [SELECT Id, Email_Body__c FROM Service__c WHERE Id = :recordId LIMIT 1];
            
            if (success) {
                ser.Email_Body__c = audioData;
            } else {
                // Store error for debugging
                ser.Email_Body__c = '[TRANSCRIPTION FAILED] ' + error;
            }
            
            update ser;
            System.debug('Record updated. Success: ' + success);
        } catch (Exception e) {
            System.debug('Failed to update record: ' + e.getMessage());
        }
    }
}