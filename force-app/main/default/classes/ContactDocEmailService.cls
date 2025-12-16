public with sharing class ContactDocEmailService {
    @InvocableMethod(label='Send Appointment & NDA Email')
    public static void sendAppointmentAndNDA(List<Id> contactIds) {
        if (contactIds == null || contactIds.isEmpty()) return;
        
        List<Contact> contacts = [
            SELECT Id, Name, Email, FirstName,
                   Appointment_Letter_File_Id__c,
                   NDA_File_Id__c,
                   Designation__c
            FROM Contact
            WHERE Id IN :contactIds
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        List<Contact> toUpdate = new List<Contact>();
        
        for (Contact c : contacts) {
            if (String.isBlank(c.Email)) continue;
            if (String.isBlank(c.Appointment_Letter_File_Id__c) ||
                String.isBlank(c.NDA_File_Id__c)) {
                continue;
            }
            
            // Get latest versions of both documents
            ContentVersion appCv = [
                SELECT VersionData, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :c.Appointment_Letter_File_Id__c
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];
            
            ContentVersion ndaCv = [
                SELECT VersionData, Title
                FROM ContentVersion
                WHERE ContentDocumentId = :c.NDA_File_Id__c
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];
            
            // Create email attachments
            Messaging.EmailFileAttachment appAtt = new Messaging.EmailFileAttachment();
            appAtt.setFileName(
                appCv.Title.endsWith('.pdf') ? appCv.Title : appCv.Title + '.pdf'
            );
            appAtt.setBody(appCv.VersionData);
            appAtt.setContentType('application/pdf');
            
            Messaging.EmailFileAttachment ndaAtt = new Messaging.EmailFileAttachment();
            ndaAtt.setFileName(
                ndaCv.Title.endsWith('.pdf') ? ndaCv.Title : ndaCv.Title + '.pdf'
            );
            ndaAtt.setBody(ndaCv.VersionData);
            ndaAtt.setContentType('application/pdf');
            
            // Create HTML email body
            String htmlBody = buildHtmlEmailBody(c);
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { c.Email });
            mail.setSubject('Welcome to Quadrobay Technologies - Your Appointment Letter & NDA');
            mail.setHtmlBody(htmlBody);
            mail.setFileAttachments(new Messaging.EmailFileAttachment[] { appAtt, ndaAtt });
            
            emails.add(mail);
            
            // Reset checkbox
            toUpdate.add(new Contact(
                Id = c.Id,
                Send_Appointment_Letter__c = false
            ));
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
        if (!toUpdate.isEmpty()) {
            update toUpdate;
        }
    }
    
    private static String buildHtmlEmailBody(Contact c) {
        String firstName = String.isNotBlank(c.FirstName) ? c.FirstName : c.Name;
        String designation = String.isNotBlank(c.Designation__c) ? c.Designation__c : 'Team Member';
        
        return 
            '<html>' +
            '<head>' +
            '<style>' +
            'body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; margin: 0; padding: 0; }' +
            '.container { max-width: 600px; margin: 0 auto; background-color: #ffffff; }' +
            '.header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 40px 20px; text-align: center; }' +
            '.header h1 { color: #ffffff; margin: 0; font-size: 28px; }' +
            '.header p { color: #f0f0f0; margin: 10px 0 0 0; font-size: 16px; }' +
            '.content { padding: 40px 30px; }' +
            '.welcome-box { background-color: #f8f9fa; border-left: 4px solid #667eea; padding: 20px; margin: 20px 0; }' +
            '.welcome-box h2 { margin-top: 0; color: #667eea; font-size: 24px; }' +
            '.info-section { margin: 30px 0; }' +
            '.info-section h3 { color: #333; font-size: 18px; margin-bottom: 15px; }' +
            '.attachment-box { background-color: #fff3cd; border: 1px solid #ffc107; border-radius: 5px; padding: 15px; margin: 10px 0; }' +
            '.attachment-box strong { color: #856404; }' +
            '.checklist { background-color: #d1ecf1; border-left: 4px solid #17a2b8; padding: 20px; margin: 20px 0; }' +
            '.checklist h3 { color: #0c5460; margin-top: 0; }' +
            '.checklist ul { margin: 10px 0; padding-left: 20px; }' +
            '.checklist li { margin: 8px 0; color: #0c5460; }' +
            '.next-steps { background-color: #d4edda; border-left: 4px solid #28a745; padding: 20px; margin: 20px 0; }' +
            '.next-steps h3 { color: #155724; margin-top: 0; }' +
            '.next-steps ol { margin: 10px 0; padding-left: 20px; }' +
            '.next-steps li { margin: 8px 0; color: #155724; }' +
            '.footer { background-color: #f8f9fa; padding: 30px; text-align: center; color: #6c757d; font-size: 14px; }' +
            '.footer strong { color: #333; display: block; margin-bottom: 5px; }' +
            '.highlight { color: #667eea; font-weight: bold; }' +
            '.emoji { font-size: 24px; }' +
            '</style>' +
            '</head>' +
            '<body>' +
            '<div class="container">' +
            
            // Header
            '<div class="header">' +
            '<h1>🎉 Welcome to Quadrobay Technologies!</h1>' +
            '<p>We\'re excited to have you join our team</p>' +
            '</div>' +
            
            // Main Content
            '<div class="content">' +
            '<div class="welcome-box">' +
            '<h2>Dear ' + firstName + ',</h2>' +
            '<p>Congratulations on your appointment as <strong>' + designation + '</strong> at Quadrobay Technologies Private Limited!</p>' +
            '<p>We are thrilled to welcome you to our dynamic team. Your skills and experience will be valuable assets to our organization, and we look forward to your contributions to our continued success.</p>' +
            '</div>' +
            
            // Attachments Section
            '<div class="info-section">' +
            '<h3>📄 Important Documents Attached</h3>' +
            '<p>Please find the following documents attached to this email:</p>' +
            '<div class="attachment-box">' +
            '<strong>1. Appointment Letter</strong><br/>' +
            'Your official appointment letter containing employment terms, compensation details, and role responsibilities.' +
            '</div>' +
            '<div class="attachment-box">' +
            '<strong>2. Non-Disclosure Agreement (NDA)</strong><br/>' +
            'Confidentiality agreement to protect company and client information.' +
            '</div>' +
            '</div>' +
            
            // Next Steps
            '<div class="next-steps">' +
            '<h3>✅ Next Steps</h3>' +
            '<ol>' +
            '<li><strong>Review Documents:</strong> Carefully read both the Appointment Letter and NDA</li>' +
            '<li><strong>Sign & Return:</strong> Print, sign, and return scanned copies of both documents</li>' +
            '<li><strong>Prepare Documents:</strong> Gather all required documents mentioned in your appointment letter</li>' +
            '<li><strong>Contact HR:</strong> Reach out if you have any questions or need clarification</li>' +
            '</ol>' +
            '</div>' +
            
            // Required Documents Checklist
            '<div class="checklist">' +
            '<h3>📋 Documents Checklist for Joining</h3>' +
            '<p>Please keep ready the following documents (originals for verification):</p>' +
            '<ul>' +
            '<li>Proof of Age, ID & Address (Aadhar Card, PAN Card, etc.)</li>' +
            '<li>Educational Certificates with Mark Sheets</li>' +
            '<li>Experience Certificates (if applicable)</li>' +
            '<li>Relieving Letter from previous employer (if applicable)</li>' +
            '<li>Passport size photographs</li>' +
            '<li>Signed copy of Appointment Letter</li>' +
            '<li>Signed copy of NDA</li>' +
            '</ul>' +
            '</div>' +
            
            '<p style="margin-top: 30px;">If you have any questions or need any assistance, please don\'t hesitate to reach out to our HR team. We\'re here to help make your onboarding process as smooth as possible.</p>' +
            
            '<p style="margin-top: 20px;">Once again, welcome aboard! We\'re excited to see the great things we\'ll achieve together.</p>' +
            
            '<p style="margin-top: 30px;">Warm regards,<br/>' +
            '<strong>HR Team</strong><br/>' +
            '<strong>Quadrobay Technologies Private Limited</strong><br/>' +
            'Plot No. 4B1, KSR Nagar Main Road,<br/>' +
            'KSR Nagar, Ambattur, Chennai - 600 053</p>' +
            
            '</div>' +
            
            // Footer
            '<div class="footer">' +
            '<strong>Quadrobay Technologies Private Limited</strong>' +
            '<p>This is an automated email. Please do not reply directly to this message.</p>' +
            '<p>For any queries, please contact: hr@quadrobay.com</p>' +
            '</div>' +
            
            '</div>' +
            '</body>' +
            '</html>';
    }
}