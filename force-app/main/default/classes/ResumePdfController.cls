/*public with sharing class ResumePdfController {
    // Public list exposed to Visualforce page
    public List<String> badgeList { get; set; }

    public ResumePdfController() {
        // Get the badgeNames parameter from the VF page URL
        String param = ApexPages.currentPage().getParameters().get('badgeNames');

        // If the parameter is not empty, split it into list
        if (String.isNotBlank(param)) {
            // Remove any extra spaces and split by comma
            badgeList = new List<String>();
            for (String b : param.split(',')) {
                if (String.isNotBlank(b)) {
                    badgeList.add(b.trim());
                }
            }
        } else {
            badgeList = new List<String>(); // empty list
        }
    }
} */


/*public with sharing class ResumePdfController {
    public List<String> badgeList { get; set; }
    public String resumeHtml { get; set; }

    public ResumePdfController() {
        badgeList = new List<String>();

        Id recordId = ApexPages.currentPage().getParameters().get('recordId');
        if (recordId != null) {
            try {
                Account acc = [
                    SELECT Resume_Html__c
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                resumeHtml = sanitizeHtml(acc.Resume_Html__c);
            } catch (Exception e) {
                System.debug('No Account Resume HTML found: ' + e.getMessage());
            }
        }

        // ✅ Handle badge names from param
        String badgeParam = ApexPages.currentPage().getParameters().get('badgeNames');
        if (!String.isBlank(badgeParam)) {
            for (String b : badgeParam.split(',')) {
                if (String.isNotBlank(b)) {
                    badgeList.add(b.trim());
                }
            }
        } else if (recordId != null) {
            try {
                List<Certification__c> certs = [
                    SELECT Badge_Resource_Name__c
                    FROM Certification__c
                    WHERE Candidate_Name__c = :recordId
                ];
                for (Certification__c c : certs) {
                    if (String.isNotBlank(c.Badge_Resource_Name__c)) {
                        badgeList.add(c.Badge_Resource_Name__c.trim());
                    }
                }
            } catch (Exception e) {
                System.debug('No Certifications found: ' + e.getMessage());
            }
        }
    }

   private String sanitizeHtml(String inputHtml) {
        if (String.isBlank(inputHtml)) return '';

        String cleaned = inputHtml;

        cleaned = cleaned.replaceAll('[^\\x00-\\x7F]', ' ');
        cleaned = cleaned.replaceAll('style="[^"]*"', '');
        cleaned = cleaned.replaceAll('<span[^>]*>', '');
        cleaned = cleaned.replaceAll('</span>', '');
        cleaned = cleaned.replaceAll('–', '-');
        cleaned = cleaned.replaceAll('—', '-');
        cleaned = cleaned.replaceAll('<p>\\s*</p>', '');

        System.debug('Cleaned HTML >>> ' + cleaned);
        return cleaned;
    }
}*/

//working code for AKSHAYA Record

public with sharing class ResumePdfController {
    public List<String> badgeList { get; set; }
    public String resumeHtml { get; set; }

    public ResumePdfController() {
  System.debug('🚀 Entering ResumePdfController constructor');

        badgeList = new List<String>();

        Id recordId = ApexPages.currentPage().getParameters().get('recordId');
 System.debug('📌 recordId received: ' + recordId);

        if (recordId != null) {
            try {
                Account acc = [
                    SELECT Resume_Html__c
                    FROM Account
                    WHERE Id = :recordId
                    LIMIT 1
                ];
                // ⚡ Directly assign raw HTML (no sanitization)
                resumeHtml = acc.Resume_Html__c;
System.debug('✅ Resume HTML fetched for Account: ' + resumeHtml);
            } catch (Exception e) {
                System.debug('No Account Resume HTML found: ' + e.getMessage());
            }
        }

        // ✅ Handle badge names from param
       String badgeParam = ApexPages.currentPage().getParameters().get('badgeNames');
 System.debug('📌 badgeParam received: ' + badgeParam);
        if (!String.isBlank(badgeParam)) {
            for (String b : badgeParam.split(',')) {
                if (String.isNotBlank(b)) {
                    badgeList.add(b.trim());
  System.debug('🏷️ Added badge from param: ' + b.trim());
                }
            }
        } else if (recordId != null) {
            try {
                List<Certification__c> certs = [
                    SELECT Badge_Resource_Name__c
                    FROM Certification__c
                    WHERE Candidate_Name__c = :recordId
                ];
 System.debug('📌 Certifications fetched count: ' + certs.size());

                for (Certification__c c : certs) {
                    if (String.isNotBlank(c.Badge_Resource_Name__c)) {
                        badgeList.add(c.Badge_Resource_Name__c.trim());
 System.debug('🏷️ Added badge from Certification: ' + c.Badge_Resource_Name__c.trim());
                    }
                }
            } catch (Exception e) {
                System.debug('No Certifications found: ' + e.getMessage());
            }
        }

  System.debug('✅ Final badgeList: ' + badgeList);
    }
}