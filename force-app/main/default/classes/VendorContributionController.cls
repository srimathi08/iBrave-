public with sharing class VendorContributionController {

    @AuraEnabled(cacheable=true)
    public static List<VendorContributionWrapper> getData() {

        Map<String, VendorContributionWrapper> mapData = new Map<String, VendorContributionWrapper>();

        AggregateResult[] arList = [
            SELECT
                Opportunity__r.Account.Name clientName,
                Opportunity__r.Name reqName,
                Candidate_Name__r.Name candidateName,
                Candidate_Name__r.Account_Type__c candidateType,
                Candidate_Name__r.Referred_By1__r.Name referredByName,
                Candidate_Name__r.Referred_By1__r.Account_Type__c referredByType,
                COUNT(Id) cnt
            FROM Presented_Candidate__c
            WHERE Status__c = 'Presented'
            AND Opportunity__r.Account.RecordType.Name
                NOT IN ('Candidate', 'Employee', 'Contractor')
            AND (
                Candidate_Name__r.Account_Type__c = 'Vendor'
                OR Candidate_Name__r.Referred_By1__r.Account_Type__c = 'Vendor'
            )
            GROUP BY
                Opportunity__r.Account.Name,
                Opportunity__r.Name,
                Candidate_Name__r.Name,
                Candidate_Name__r.Account_Type__c,
                Candidate_Name__r.Referred_By1__r.Name,
                Candidate_Name__r.Referred_By1__r.Account_Type__c
        ];

        for (AggregateResult ar : arList) {

            String vendorName;

            // ✅ Vendor resolution logic (Apex, not SOQL)
            if ((String) ar.get('candidateType') == 'Vendor') {
                vendorName = (String) ar.get('candidateName');
            } else {
                vendorName = (String) ar.get('referredByName');
            }

            String key =
                ar.get('clientName') + '|' +
                ar.get('reqName') + '|' +
                vendorName;

            if (!mapData.containsKey(key)) {
                mapData.put(
                    key,
                    new VendorContributionWrapper(
                        (String) ar.get('clientName'),
                        (String) ar.get('reqName'),
                        vendorName,
                        (Integer) ar.get('cnt')
                    )
                );
            } else {
                mapData.get(key).count += (Integer) ar.get('cnt');
            }
        }

        return mapData.values();
    }

    public class VendorContributionWrapper {
        @AuraEnabled public String clientName;
        @AuraEnabled public String reqName;
        @AuraEnabled public String vendorName;
        @AuraEnabled public Integer count;

        public VendorContributionWrapper(String c, String r, String v, Integer cnt) {
            clientName = c;
            reqName = r;
            vendorName = v;
            count = cnt;
        }
    }
}