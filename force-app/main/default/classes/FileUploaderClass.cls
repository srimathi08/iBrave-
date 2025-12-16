/**
 * @description Simple file uploader for Business Travel documents
 * @author Salesforce Consultant
 * @date 2025-10-08
 */
public with sharing class FileUploaderClass {
    
    /**
     * @description Upload file to Salesforce and link to attendance record
     * @param base64 Base64 encoded file data
     * @param filename File name with extension
     * @param recordId Attendance record ID to link file to
     * @return ContentDocumentLink ID if successful, null otherwise
     */
    @AuraEnabled
    public static String uploadFile(String base64, String filename, String recordId) {
        System.debug('=== UPLOADING BUSINESS TRAVEL FILE ===');
        System.debug('Filename: ' + filename);
        System.debug('Record ID: ' + recordId);
        
        try {
            ContentVersion cv = createContentVersion(base64, filename);
            if (cv == null) {
                System.debug('❌ Failed to create ContentVersion');
                return null;
            }
            
            ContentDocumentLink cdl = createContentLink(cv.Id, recordId);
            if (cdl == null) {
                System.debug('❌ Failed to create ContentDocumentLink');
                return null;
            }
            
            System.debug('✅ File uploaded successfully. CDL ID: ' + cdl.Id);
            return cdl.Id;
            
        } catch (Exception e) {
            System.debug('❌ Error uploading file: ' + e.getMessage());
            throw new AuraHandledException('File upload failed: ' + e.getMessage());
        }
    }
    
    /**
     * @description Create ContentVersion from base64 data
     */
    private static ContentVersion createContentVersion(String base64, String filename) {
        try {
            ContentVersion cv = new ContentVersion();
            cv.VersionData = EncodingUtil.base64Decode(base64);
            cv.Title = filename;
            cv.PathOnClient = filename;
            cv.Description = 'Business Travel Document';
            cv.IsMajorVersion = true;
            
            insert cv;
            
            System.debug('✅ ContentVersion created: ' + cv.Id);
            return cv;
            
        } catch(DMLException e) {
            System.debug('❌ DML Exception creating ContentVersion: ' + e.getMessage());
            return null;
        }
    }

    /**
     * @description Create ContentDocumentLink to attach file to record
     */
    private static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
        if (contentVersionId == null || recordId == null) { 
            return null; 
        }
        
        try {
            ContentDocumentLink cdl = new ContentDocumentLink();
            cdl.ContentDocumentId = [
                SELECT ContentDocumentId 
                FROM ContentVersion 
                WHERE Id = :contentVersionId
                LIMIT 1
            ].ContentDocumentId;
            cdl.LinkedEntityId = recordId;
            cdl.ShareType = 'V'; // Viewer permission
            cdl.Visibility = 'AllUsers';
            
            insert cdl;
            
            System.debug('✅ ContentDocumentLink created: ' + cdl.Id);
            return cdl;
            
        } catch(DMLException e) {
            System.debug('❌ DML Exception creating ContentDocumentLink: ' + e.getMessage());
            return null;
        }
    }
}