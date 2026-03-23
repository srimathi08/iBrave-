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
// *** get Contact name  ***
            Contact c = [
                SELECT FirstName, LastName
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];
            String firstName = c.FirstName != null ? c.FirstName : '';
            String lastName  = c.LastName  != null ? c.LastName  : '';
            String fullName  = (firstName + ' ' + lastName).trim();
            if (String.isBlank(fullName)) {
                fullName = 'Contact';
            }
            fullName = fullName.replaceAll('[^a-zA-Z0-9_\\- ]','');
            // ----- Appointment PDF -----
            PageReference appPage = Page.AppointmentLetterVF;
            appPage.getParameters().put('id', contactId);

            Blob appPdf;
            if (Test.isRunningTest()) {
                appPdf = Blob.valueOf('Test Appointment PDF');
            } else {
                appPdf = appPage.getContentAsPDF();
            }

            res.appointmentFileName = 'Appointment_Letter_' + fullName + '.pdf';
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

            res.ndaFileName = 'NDA_' + fullName + '.pdf';
            res.ndaBase64 = EncodingUtil.base64Encode(ndaPdf);

            results.add(res);
        }

        return results;
    }
}