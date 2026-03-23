public with sharing class ResumePDFController1 {
  @AuraEnabled
  public static void saveResumePDF(Id recordId, String base64Data, String fileName) {
    if (String.isBlank(base64Data) || recordId == null) return;

    ContentVersion cv = new ContentVersion();
    cv.Title = fileName;
    cv.PathOnClient = fileName;
    cv.VersionData = EncodingUtil.base64Decode(base64Data);
    insert cv;

    Id contentDocumentId = [
      SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id
    ].ContentDocumentId;

    insert new ContentDocumentLink(
      ContentDocumentId = contentDocumentId,
      LinkedEntityId    = recordId,
      ShareType         = 'V',
      Visibility        = 'AllUsers'
    );
  }

@AuraEnabled(cacheable=true)
public static String getRecordName(Id recordId) {
    if (recordId == null) return null;

    // Get the object type and describe
    Schema.SObjectType t = recordId.getSObjectType();
    Schema.DescribeSObjectResult d = t.getDescribe();

    // Check if the object has a "Name" field
    if (d.fields.getMap().containsKey('Name')) {
        SObject so = Database.query('SELECT Name FROM ' + d.getName() + ' WHERE Id = :recordId LIMIT 1');
        return (String)so.get('Name');
    }
    // Fallback for objects without Name (like Case → CaseNumber, Task → Subject)
    else if (d.fields.getMap().containsKey('CaseNumber')) {
        SObject so = Database.query('SELECT CaseNumber FROM ' + d.getName() + ' WHERE Id = :recordId LIMIT 1');
        return (String)so.get('CaseNumber');
    }
    else if (d.fields.getMap().containsKey('Subject')) {
        SObject so = Database.query('SELECT Subject FROM ' + d.getName() + ' WHERE Id = :recordId LIMIT 1');
        return (String)so.get('Subject');
    }
    // Fallback to Id if nothing else
    return String.valueOf(recordId);
}



}