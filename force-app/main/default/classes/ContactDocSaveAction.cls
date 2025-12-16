public class ContactDocSaveAction {
public class SaveInput {
    @InvocableVariable(required=true)
    public Id contactId;

    @InvocableVariable(required=true)
    public String appointmentFileName;

    @InvocableVariable(required=true)
    public String ndaFileName;

    @InvocableVariable(required=true)
    public String appointmentBase64;

    @InvocableVariable(required=true)
    public String ndaBase64;
}

@InvocableMethod(label='Save Appointment and NDA PDFs to Contact')
public static void saveDocs(List<SaveInput> inputs) {
    if (inputs == null || inputs.isEmpty()) {
        return;
    }

    List<ContentVersion> toInsert = new List<ContentVersion>();

    for (SaveInput inp : inputs) {
        // Appointment PDF
        Blob appBlob = EncodingUtil.base64Decode(inp.appointmentBase64);
        ContentVersion appCv = new ContentVersion();
        appCv.Title = inp.appointmentFileName.endsWith('.pdf')
            ? inp.appointmentFileName.replace('.pdf','')
            : inp.appointmentFileName;
        appCv.PathOnClient = inp.appointmentFileName;
        appCv.VersionData = appBlob;
        appCv.FirstPublishLocationId = inp.contactId;
        toInsert.add(appCv);

        // NDA PDF
        Blob ndaBlob = EncodingUtil.base64Decode(inp.ndaBase64);
        ContentVersion ndaCv = new ContentVersion();
        ndaCv.Title = inp.ndaFileName.endsWith('.pdf')
            ? inp.ndaFileName.replace('.pdf','')
            : inp.ndaFileName;
        ndaCv.PathOnClient = inp.ndaFileName;
        ndaCv.VersionData = ndaBlob;
        ndaCv.FirstPublishLocationId = inp.contactId;
        toInsert.add(ndaCv);
    }

    if (toInsert.isEmpty()) {
        return;
    }

    insert toInsert;

    // Map: Contact Id -> Contact (for update)
    Map<Id, Contact> contactsToUpdate = new Map<Id, Contact>();

    // Requery to get ContentDocumentId and FirstPublishLocationId
    List<ContentVersion> inserted = [
        SELECT Id, ContentDocumentId, FirstPublishLocationId, PathOnClient
        FROM ContentVersion
        WHERE Id IN :toInsert
    ];

    for (ContentVersion cv : inserted) {
        if (cv.FirstPublishLocationId == null) continue;

        Contact c = contactsToUpdate.get(cv.FirstPublishLocationId);
        if (c == null) {
            c = new Contact(Id = cv.FirstPublishLocationId);
            contactsToUpdate.put(c.Id, c);
        }

        if (cv.PathOnClient.startsWith('Appointment_Letter_')) {
            c.Appointment_Letter_File_Id__c = cv.ContentDocumentId;
        } else if (cv.PathOnClient.startsWith('NDA_')) {
            c.NDA_File_Id__c = cv.ContentDocumentId;
        }
    }

    if (!contactsToUpdate.isEmpty()) {
        update contactsToUpdate.values();
    }
}

}