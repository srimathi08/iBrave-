public with sharing class SendOpportunityFormEmail {

    @InvocableMethod(label='Send Referral Email')
    public static void sendFormLink(List<Id> oppIds) {
        for (Id oppId : oppIds) {
            sendEmailInternal(oppId);
        }
    }

    private static void sendEmailInternal(Id oppId) {
        Opportunity opp = [
            SELECT Id, Name, Referral_Contact__c, Referral_Contact__r.Email, Referral_Contact__r.Name
            FROM Opportunity
            WHERE Id = :oppId
            LIMIT 1
        ];

        if (opp.Referral_Contact__c == null || String.isBlank(opp.Referral_Contact__r.Email)) {
            throw new AuraHandledException('Referral Contact or Email is missing on this Opportunity.');
        }

        // Generate token with 7-day expiry
        String token = OpportunityFormLinkService.generateToken(
            opp.Id,
            opp.Referral_Contact__c,
            Date.today().addDays(7)
        );

        // ✅ Use ?token= so it matches your Flow input variable and Invocable Apex
        String formUrl = 'https://innovation-dream-9744--uatsandbox.sandbox.my.site.com/JobDescriptionDetails?token=' 
                        + EncodingUtil.urlEncode(token, 'UTF-8');

        // Build and send the email
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { opp.Referral_Contact__r.Email });
        mail.setSubject('Please provide additional information for Opportunity: ' + opp.Name);
        mail.setPlainTextBody(
            'Hi ' + opp.Referral_Contact__r.Name + ',\n\n' +
            'Please click the secure link below to provide additional information:\n' + formUrl + '\n\n' +
            'This link will expire in 7 days.\n\nThank you!'
        );
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
    }
}