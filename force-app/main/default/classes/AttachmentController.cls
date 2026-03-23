/*public with sharing class AttachmentController {

    @AuraEnabled
    public static String createparent(String fileName) {
        Service__c sr = new Service__c();

        if (String.isNotBlank(fileName)) {
            sr.Name = fileName.length() > 80
                ? fileName.substring(0, 80)
                : fileName;
            sr.Email_Subject__c = fileName;
        } else {
            sr.Name = 'Uploaded Resume';
        }

        insert sr;
        return sr.Id;
    }

    @AuraEnabled
    public static String uploadFile(String base64, String filename, String recordId) {

        ContentVersion cv = new ContentVersion();
        cv.VersionData = EncodingUtil.base64Decode(base64);
        cv.Title = filename;
        cv.PathOnClient = filename;
        insert cv;

        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [
            SELECT ContentDocumentId
            FROM ContentVersion
            WHERE Id = :cv.Id
        ].ContentDocumentId;

        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V';
        cdl.Visibility = 'AllUsers';

        insert cdl;
        return cdl.Id;
    }

    @AuraEnabled
    public static List<String> getPrompt(String recordId) {

        Database.executeBatch(
            new AsynCandidateCreationBatch(recordId),
            1
        );

        return new List<String>{ 'Batch Started' };
    }

    @AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getTodayUploadedFiles() {

    List<Map<String, Object>> result = new List<Map<String, Object>>();

    // 1️⃣ Get today's Accounts
    List<Account> accList = [
        SELECT Id, Name
        FROM Account
        WHERE CreatedDate = TODAY
    ];

    if (accList.isEmpty()) {
        return result;
    }

    Map<Id, String> accNameMap = new Map<Id, String>();
    for (Account a : accList) {
        accNameMap.put(a.Id, a.Name);
    }

    // 2️⃣ Get files linked to those Accounts
    List<ContentDocumentLink> links = [
        SELECT LinkedEntityId,
               ContentDocumentId,
               ContentDocument.Title,
               ContentDocument.CreatedDate
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :accNameMap.keySet()
    ];

    // 3️⃣ Prepare response
    for (ContentDocumentLink cdl : links) {

        Map<String, Object> row = new Map<String, Object>();
        row.put('id', cdl.ContentDocumentId);

        // Account
        row.put('accountName', accNameMap.get(cdl.LinkedEntityId));
        row.put('accountUrl', '/' + cdl.LinkedEntityId);

        // File
        row.put('fileName', cdl.ContentDocument.Title);
        row.put('createdDate', cdl.ContentDocument.CreatedDate);

        result.add(row);
    }

    return result;
}
}   */



 
public class AttachmentController {
    @AuraEnabled 
   

public static List<String> getPrompt(String recordId) {
    try {
        if (String.isBlank(recordId)) {
            throw new AuraHandledException('Service Id is required');
        }

        // (Optional but STRONGLY recommended)
        // Lock record to avoid double processing

        Database.executeBatch(
            new AsynCandidateCreationBatch((Id) recordId),
            1   // 🔑 DO NOT CHANGE THIS
        );

        return new List<String>{ 'Batch Started Successfully' };

    } catch (Exception e) {
        UtilityClass.createElog(e);
        throw new AuraHandledException(
            'Error while generating prompt: ' + e.getMessage()
        );
    }
}
 
    




  /*  added the below logic in line 43 to 56
@AuraEnabled
    public static String createparent(String fileName){
        Service__c Sr =new Service__c();
        Sr.Name=fileName;
        Insert SR;
        return Sr.Id;
    }
   */

@AuraEnabled
public static String createparent(String fileName){
    Service__c Sr = new Service__c();
    
    if (String.isNotBlank(fileName)) {
        Sr.Name = fileName.length() > 80 ? fileName.substring(0, 80) : fileName;
        Sr.Email_Subject__c = fileName; // <-- preserve full fileName
    } else {
        Sr.Name = 'No File Name';
    }
    
    insert Sr;
    return Sr.Id;
}





      /*
   * @method uploadFile() 
   * @desc Creates a content version from a given file's base64 and name
   * 
   * @param {String} base64 - base64 string that represents the file
   * @param {String} filename - full file name with extension, i.e. 'products.csv'
   * @param {String} recordId - Id of the record you want to attach this file to
   * 
   * @return {ContentVersion} - returns the created ContentDocumentLink Id if the
   *   upload was successful, otherwise returns null
   */
   @AuraEnabled
  public static String uploadFile(String base64, String filename, String recordId) {
        ContentVersion cv = createContentVersion(base64, filename);
        ContentDocumentLink cdl = createContentLink(cv.Id, recordId);
        if (cv == null || cdl == null) { return null; }
        return cdl.Id;
  }
  /*
   * @method createContentVersion() [private]
   * @desc Creates a content version from a given file's base64 and name
   * 
   * @param {String} base64 - base64 string that represents the file
   * @param {String} filename - full file name with extension, i.e. 'products.csv'
   * 
   * @return {ContentVersion} - returns the newly created ContentVersion, or null
   *   if there was an error inserting the record
   */
  private static ContentVersion createContentVersion(String base64, String filename) {
    ContentVersion cv = new ContentVersion();
    cv.VersionData = EncodingUtil.base64Decode(base64);
    cv.Title = filename;
    cv.PathOnClient = filename;
    try {
      insert cv;
      return cv;
    } catch(DMLException e) {
      System.debug(e);
      return null;
    }
  }

   /*
   * @method createContentLink() [private]
   * @desc Creates a content link for a given ContentVersion and record
   * 
   * @param {String} contentVersionId - Id of the ContentVersion of the file
   * @param {String} recordId - Id of the record you want to attach this file to
   * 
   * @return {ContentDocumentLink} - returns the newly created ContentDocumentLink, 
   *   or null if there was an error inserting the record
   */
  public static ContentDocumentLink createContentLink(String contentVersionId, String recordId) {
              if (contentVersionId == null || recordId == null) { return null; }
    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = [
      SELECT ContentDocumentId 
      FROM ContentVersion 
      WHERE Id =: contentVersionId
    ].ContentDocumentId;
    cdl.LinkedEntityId = recordId;
    // ShareType is either 'V', 'C', or 'I'
    // V = Viewer, C = Collaborator, I = Inferred
    cdl.ShareType = 'V';
      cdl.Visibility='AllUsers';
    try {
      insert cdl;  
      return cdl;
    } catch(DMLException e) {
      System.debug(e);
      return null;
    }
  }
    
    public static ContentDocumentLink createContentLinkwhatsapp(String contentVersionId, String recordId) {
              if (contentVersionId == null || recordId == null) { return null; }
    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = [
      SELECT ContentDocumentId 
      FROM ContentVersion 
      WHERE Id =: contentVersionId
    ].ContentDocumentId;
    cdl.LinkedEntityId = recordId;
    // ShareType is either 'V', 'C', or 'I'
    // V = Viewer, C = Collaborator, I = Inferred
    cdl.ShareType = 'V';
      cdl.Visibility='AllUsers';
    try {
      insert cdl;       
      return cdl;
    } catch(DMLException e) {
      System.debug(e);
      //return null;
throw e;
    }
  }

@AuraEnabled(cacheable=true)
public static List<Map<String, Object>> getTodayUploadedFiles() {

    List<Map<String, Object>> result = new List<Map<String, Object>>();

    // 1️⃣ Get today's Accounts
    List<Account> accList = [
        SELECT Id, Name
        FROM Account
        WHERE CreatedDate = TODAY
    ];

    if (accList.isEmpty()) {
        return result;
    }

    Map<Id, String> accNameMap = new Map<Id, String>();
    for (Account a : accList) {
        accNameMap.put(a.Id, a.Name);
    }

    // 2️⃣ Get files linked to those Accounts
    List<ContentDocumentLink> links = [
        SELECT LinkedEntityId,
               ContentDocumentId,
               ContentDocument.Title,
               ContentDocument.CreatedDate
        FROM ContentDocumentLink
        WHERE LinkedEntityId IN :accNameMap.keySet()
    ];

    // 3️⃣ Prepare response
    for (ContentDocumentLink cdl : links) {

        Map<String, Object> row = new Map<String, Object>();
        row.put('id', cdl.ContentDocumentId);

        // Account
        row.put('accountName', accNameMap.get(cdl.LinkedEntityId));
        row.put('accountUrl', '/' + cdl.LinkedEntityId);

        // File
        row.put('fileName', cdl.ContentDocument.Title);
        row.put('createdDate', cdl.ContentDocument.CreatedDate);

        result.add(row);
    }

    return result;
}

}