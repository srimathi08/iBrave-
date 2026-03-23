/*public class EmailTemplate {
    public static string HtmlBody(list<String> Response,Boolean checkCandidate,Boolean CheckJD){
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm(); // Replaces deprecated URL.getSalesforceBaseUrl()
       	String htmlBody = 'Thank you for your email. The following';
        if(checkCandidate){
          for (String res : Response) {
        List<String> parts = res.split(':');
        if (parts.size() >= 2) {
            htmlBody=+' Candidates Created Successfully\n';
            String accId = parts[0].trim()+'\n';
            String accName = parts[1].trim()+'\n';
            String accLink = baseUrl + '/' + accId+'\n';
            htmlBody += '<a href="' + accLink + '">' + accName + '</a> (ID: ' + accId + ')';
        }
    }
        }
        if(CheckJD){
          htmlBody=+' Opportunities Created Successully\n';
          
            String OppId = response[3] != null?response[3].trim()+'\n':'';
            String oppName =response[2] != null?response[2].trim()+'\n':'';
            String Opplink = baseUrl + '/' + OppId+'\n';
           
            htmlBody += 'Opportunity Name:' +' ' + OppName;
            htmlBody += 'Opportunity Link:' +' '+OppLink;
         
        
        }
        return htmlBody;
    }
} */

//working but only for success message
public class EmailTemplate {
    public static String HtmlBody(List<String> response, Boolean checkCandidate, Boolean checkJD) {
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
        
        String body = '';
        body += 'We have successfully received the information you shared, and it has been securely stored in our system.' + '\n\n';
        body += 'Below are the details of the records created for your reference.' + '\n\n';
        
        // Candidates
        if (checkCandidate) {
            body += 'Candidates Created Successfully' + '\n';
            for (String res : response) {
                List<String> parts = res.split(':');
                if (parts.size() >= 2 && parts[0].startsWith('001')) {
                    String accId = parts[0].trim();
                    String accName = parts[1].trim();
                    
                    body += 'Name - ' + accName + '\n';
                    body += 'URL - ' + baseUrl + '/' + accId + '\n\n';
                }
            }
        }
        
        //Opportunities
         if (checkJD) {
            body += 'Opportunities Created Successfully' + '\n';
            for (String res : response) {
                List<String> parts = res.split(':');
                if (parts.size() >= 1 && parts[0].startsWith('006')) {
                    String oppId = parts[0].trim();
                    body += 'URL - ' + baseUrl + '/' + oppId + '\n';
                }
            }
            body += '\n';
        }
        
        body += 'This is an automated message from Salesforce.';
        
        return body;
    }
}

/*Added Success and Error toast message
public class EmailTemplate {
    public static String HtmlBody(List<String> response, Boolean checkCandidate, Boolean checkJD) {
        String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
        String body = '';

        // ============================
        // ✅ Candidate Handling
        // ============================
        if (checkCandidate) {
            Boolean candidateSuccess = false;
            Boolean candidateFailure = false;

            for (String res : response) {
                List<String> parts = res.split(':');

                if (parts.size() >= 2 && parts[0].startsWith('001')) {
                    // Success
                    candidateSuccess = true;
                    String accId = parts[0].trim();
                    String accName = parts[1].trim();

                    body += 'We have successfully received the information you shared, and it has been securely stored in our system.' + '\n\n';
                    body += 'Below are the details of the records created for your reference.' + '\n\n';
                    body += 'Candidates Created Successfully' + '\n';
                    body += 'Name - ' + accName + '\n';
                    body += 'URL - ' + baseUrl + '/' + accId + '\n\n';
                }
                else if (parts.size() == 1 && parts[0].startsWith('001') && !candidateFailure) {
                    // Failure (only once)
                    candidateFailure = true;
                    body += 'We have successfully received the information you shared, but record was not stored in our system' + '\n';
                    body += 'Candidates Created Unsuccessful ' + '\n';
                    body += '⚠️ Candidate creation failed: Candidate name is missing.' + '\n';
                    body += '👉 Please update the candidate name and resend the file/message again.' + '\n\n';
                }
            }

            if (candidateSuccess) {
                body += 'This is an automated message from Salesforce.';
            }
        }

        // ============================
        // ✅ Opportunity Handling
        // ============================
        if (checkJD) {
            Boolean oppSuccess = false;
            Boolean oppFailure = false;

            for (String res : response) {
                List<String> parts = res.split(':');

                if (parts.size() >= 2 && parts[0].startsWith('006')) {
                    // Success
                    oppSuccess = true;
                    String oppId = parts[0].trim();
                    String oppName = parts[1].trim();

                    body += 'We have successfully received the information you shared, and it has been securely stored in our system.' + '\n\n';
                    body += 'Below are the details of the records created for your reference.' + '\n\n';
                    body += 'Opportunities Created Successfully ' + '\n';
                    body += 'Name - ' + oppName + '\n';
                    body += 'URL - ' + baseUrl + '/' + oppId + '\n\n';
                }
                else if (parts.size() == 1 && parts[0].startsWith('006') && !oppFailure) {
                    // Failure (only once)
                    oppFailure = true;
                    body += 'We have successfully received the information you shared, but record was not stored in our system' + '\n';
                    body += 'Opportunity Created Unsuccessful ' + '\n';
                    body += '⚠️ Opportunity creation failed: Company name is missing.' + '\n';
                    body += '👉 Please update the company name and resend the file/message again.' + '\n\n';
                }
            }

            if (oppSuccess) {
                body += 'This is an automated message from Salesforce.';
            }
        }

        return body;
    }
} */