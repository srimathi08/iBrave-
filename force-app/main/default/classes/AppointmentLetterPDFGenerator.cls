public with sharing class AppointmentLetterPDFGenerator {

    @InvocableMethod(label='Generate Appointment Letter PDF for Contacts')
    public static void generateAppointmentLetters(List<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) {
            return;
        }

        // Query contacts for email and name (no salary here – that’s in VF controller)
        Map<Id, Contact> contactMap = new Map<Id, Contact>(
            [SELECT Id, Name, Email
             FROM Contact
             WHERE Id IN :contactIds]
        );

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (Id cId : contactIds) {
            Contact con = contactMap.get(cId);
            if (con == null || String.isBlank(con.Email)) {
                continue; // skip if no email
            }

            // 1) Render Appointment Letter VF as PDF
            PageReference appPage = Page.AppointmentLetterVF;
            appPage.getParameters().put('id', cId);
            Blob appPdf;
            try {
                if (Test.isRunningTest()) {
        // In tests, avoid real PDF rendering
        appPdf = Blob.valueOf('Dummy PDF');
    } else {
        appPdf = appPage.getContentAsPDF();
    }
            } catch (Exception e) {
                // If PDF generation fails for one contact, skip that record
                continue;
            }

            String fileName = 'Appointment_Letter_' + con.Name.replace(' ', '_') +
                              '_' + Date.today().format() + '.pdf';

            // 2) Store as Salesforce File (ContentVersion) on Contact
            ContentVersion cv = new ContentVersion();
            cv.Title = fileName;
            cv.PathOnClient = fileName;
            cv.VersionData = appPdf;
            cv.FirstPublishLocationId = cId; // links file to Contact
            cv.IsMajorVersion = true;
            insert cv;

            // 3) Build email with PDF attachment
            Messaging.EmailFileAttachment appAttach = new Messaging.EmailFileAttachment();
            appAttach.setFileName(fileName);
            appAttach.setBody(appPdf);
            appAttach.setContentType('application/pdf');

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[] { con.Email });
            email.setSubject('Appointment Letter - ' + con.Name);
            email.setPlainTextBody(
                'Dear ' + con.Name + ',\n\n' +
                'Please find attached your Appointment Letter.\n\n' +
                'Regards,\nHR Team'
            );
            email.setFileAttachments(new Messaging.EmailFileAttachment[] { appAttach });

            emails.add(email);
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
}