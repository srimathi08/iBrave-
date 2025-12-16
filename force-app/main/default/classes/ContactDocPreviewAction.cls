/*public class ContactDocPreviewAction {
public class PreviewInput {
    @InvocableVariable(required=true)
    public Id contactId;
}

public class PreviewResult {
    @InvocableVariable
    public String appointmentFileName;
    @InvocableVariable
    public String ndaFileName;
    @InvocableVariable
    public String appointmentBase64;
    @InvocableVariable
    public String ndaBase64;
}

@InvocableMethod(label='Preview Appointment and NDA PDFs')
public static List<PreviewResult> previewDocs(List<PreviewInput> inputs) {
    List<PreviewResult> results = new List<PreviewResult>();

    for (PreviewInput inp : inputs) {
        Id contactId = inp.contactId;
        PreviewResult res = new PreviewResult();

        // Appointment Letter PDF
        PageReference appPage = Page.AppointmentLetterVF;
        appPage.getParameters().put('id', contactId);
        Blob appPdf = appPage.getContentAsPDF();
        res.appointmentFileName = 'Appointment_Letter_' + String.valueOf(contactId) + '.pdf';
        res.appointmentBase64 = EncodingUtil.base64Encode(appPdf);

        // NDA PDF
        PageReference ndaPage = Page.NDADocumentVF;
        ndaPage.getParameters().put('id', contactId);
        Blob ndaPdf = ndaPage.getContentAsPDF();
        res.ndaFileName = 'NDA_' + String.valueOf(contactId) + '.pdf';
        res.ndaBase64 = EncodingUtil.base64Encode(ndaPdf);

        results.add(res);
    }

    return results;
}
}*/
public class ContactDocPreviewAction {

    public class PreviewInput {
        @InvocableVariable(required=true)
        public Id contactId;
    }

    public class PreviewResult {
        @InvocableVariable
        public String appointmentFileName;
        @InvocableVariable
        public String ndaFileName;
        @InvocableVariable
        public String appointmentBase64;
        @InvocableVariable
        public String ndaBase64;
    }

    @InvocableMethod(label='Preview Appointment and NDA PDFs')
    public static List<PreviewResult> previewDocs(List<PreviewInput> inputs) {

        List<PreviewResult> results = new List<PreviewResult>();

        for (PreviewInput inp : inputs) {
            Id contactId = inp.contactId;
            PreviewResult res = new PreviewResult();

            // ----- Appointment PDF -----
            PageReference appPage = Page.AppointmentLetterVF;
            appPage.getParameters().put('id', contactId);

            Blob appPdf;
            if (Test.isRunningTest()) {
                appPdf = Blob.valueOf('Test Appointment PDF');
            } else {
                appPdf = appPage.getContentAsPDF();
            }

            res.appointmentFileName = 'Appointment_Letter_' + contactId + '.pdf';
            res.appointmentBase64 = EncodingUtil.base64Encode(appPdf);

            // ----- NDA PDF -----
            PageReference ndaPage = Page.NDADocumentVF;
            ndaPage.getParameters().put('id', contactId);

            Blob ndaPdf;
            if (Test.isRunningTest()) {
                ndaPdf = Blob.valueOf('Test NDA PDF');
            } else {
                ndaPdf = ndaPage.getContentAsPDF();
            }

            res.ndaFileName = 'NDA_' + contactId + '.pdf';
            res.ndaBase64 = EncodingUtil.base64Encode(ndaPdf);

            results.add(res);
        }

        return results;
    }
}