public with sharing class CandidateOnboardingHandler {

    // Send HR notification email when onboarding status changes to 'Submitted'
    public static void sendOnboardingNotification(List<Candidate__c> newList, Map<Id, Candidate__c> oldMap) {
        List<Candidate__c> submittedCandidates = new List<Candidate__c>();

        for (Candidate__c cand : newList) {
            Candidate__c oldCand = (oldMap != null) ? oldMap.get(cand.Id) : null;
            // Only fire when status changes TO 'Submitted' (not on every update)
            if (cand.Onboarding_Status__c == 'Submitted' &&
                (oldCand == null || oldCand.Onboarding_Status__c != 'Submitted')) {
                submittedCandidates.add(cand);
            }
        }

        if (submittedCandidates.isEmpty()) {
            return;
        }

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();

        for (Candidate__c cand : submittedCandidates) {
            try {
                Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
                mail.setToAddresses(new String[] {'it-admin@quadrobay.com'});
                mail.setSubject('Onboarding Completed - ' + cand.First_Name__c + ' ' + cand.Last_Name__c);
                mail.setSaveAsActivity(false);

                String link = baseUrl + '/lightning/r/Candidate__c/' + cand.Id + '/view';

                String htmlBody = 
                    '<div style="font-family: Arial, sans-serif; max-width: 600px;">' +
                    '<h2 style="color: #2c3e50;">Onboarding Form Submitted</h2>' +
                    '<p>Hello HR Team,</p>' +
                    '<p>The following candidate has completed the onboarding form:</p>' +
                    '<table style="border-collapse: collapse; margin: 15px 0;">' +
                    '<tr><td style="padding: 8px; font-weight: bold;">Name:</td>' +
                    '<td style="padding: 8px;">' + cand.First_Name__c + ' ' + cand.Last_Name__c + '</td></tr>' +
                    '<tr><td style="padding: 8px; font-weight: bold;">Date:</td>' +
                    '<td style="padding: 8px;">' + String.valueOf(Date.today()) + '</td></tr>' +
                    '</table>' +
                    '<p><a href="' + link + '" style="background-color: #3498db; color: white; padding: 10px 20px; ' +
                    'text-decoration: none; border-radius: 5px; display: inline-block;">View Candidate Record</a></p>' +
                    '<br/><p>Regards,<br/>HR Automation System</p>' +
                    '</div>';

                mail.setHtmlBody(htmlBody);

                String plainBody =
                    'Hello HR Team,\n\n' +
                    'The following candidate has completed the onboarding form:\n\n' +
                    'Name: ' + cand.First_Name__c + ' ' + cand.Last_Name__c + '\n' +
                    'Date: ' + String.valueOf(Date.today()) + '\n\n' +
                    'View record: ' + link + '\n\n' +
                    'Regards,\nHR Automation System';
                mail.setPlainTextBody(plainBody);

                emails.add(mail);
            } catch (Exception ex) {
                System.debug('⚠️ Error building email for candidate ' + cand.Id + ': ' + ex.getMessage());
            }
        }

        if (!emails.isEmpty()) {
            try {
                List<Messaging.SendEmailResult> results = Messaging.sendEmail(emails);
                for (Integer i = 0; i < results.size(); i++) {
                    if (!results[i].isSuccess()) {
                        System.debug('⚠️ HR notification email failed for candidate: ' + results[i].getErrors()[0].getMessage());
                    } else {
                        System.debug('✅ HR notification email sent for onboarding submission');
                    }
                }
            } catch (Exception ex) {
                System.debug('⚠️ Failed to send HR onboarding notification(s): ' + ex.getMessage());
                // Don't re-throw - email failure should not block the record update
            }
        }
    }
}