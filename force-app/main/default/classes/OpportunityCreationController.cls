public class OpportunityCreationController {
    public static void CreateOpportunity(String GeneratedContent) {
        // Deserialize JSON input
        List<Job_Description__c> jobDescriptions = (List<Job_Description__c>) JSON.deserialize(GeneratedContent, List<Job_Description__c>.class);
        if (jobDescriptions.isEmpty()) {
            System.debug('No job descriptions to process.');
            return;
        }

        // Collect unique company name prefixes to find or create Accounts
        Set<String> companyPrefixes = new Set<String>();
        Map<String, List<Job_Description__c>> jdByPrefix = new Map<String, List<Job_Description__c>>();

        for (Job_Description__c jd : jobDescriptions) {
            if (String.isBlank(jd.Company_Name__c)) continue;

            String[] parts = jd.Company_Name__c.trim().split('\\s+');
            if (parts.size() == 0) continue;

            String prefix = parts[0];
            companyPrefixes.add(prefix);

            if (!jdByPrefix.containsKey(prefix)) {
                jdByPrefix.put(prefix, new List<Job_Description__c>());
            }
            jdByPrefix.get(prefix).add(jd);
        }

        // Query existing accounts by prefix (assuming name starts with prefix)
        List<Account> existingAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE :('%' + String.join(new List<String>(companyPrefixes), '%') + '%')];

        Map<String, Account> accountMap = new Map<String, Account>();
        for (Account acc : existingAccounts) {
            String[] parts = acc.Name.trim().split('\\s+');
            if (parts.size() > 0) {
                accountMap.put(parts[0], acc);
            }
        }

        // Create missing accounts
        List<Account> accountsToInsert = new List<Account>();
        for (String prefix : companyPrefixes) {
            if (!accountMap.containsKey(prefix)) {
                Account acc = new Account();
                acc.Name = prefix; // or full company name from jd if you want
                acc.Ext_Id__c = DateTime.now().format('yyyyMMddHHmmss');
                accountsToInsert.add(acc);
            }
        }
        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
            for (Account acc : accountsToInsert) {
                String[] parts = acc.Name.trim().split('\\s+');
                if (parts.size() > 0) {
                    accountMap.put(parts[0], acc);
                }
            }
        }

        // Aggregate Key_Responsibilities__c per prefix
        Map<String, String> prefixToResponsibilities = new Map<String, String>();
        for (String prefix : jdByPrefix.keySet()) {
            List<Job_Description__c> jdList = jdByPrefix.get(prefix);
            List<String> allResponsibilities = new List<String>();
            for (Job_Description__c jd : jdList) {
                if (!String.isBlank(jd.Key_Responsibilities__c)) {
                    allResponsibilities.add(jd.Key_Responsibilities__c);
                }
            }
            String combinedResponsibilities = String.join(allResponsibilities, '\n');
            prefixToResponsibilities.put(prefix, combinedResponsibilities);
        }

        // Create Opportunities linked to Accounts, setting Job_Description__c field
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        Map<String, Opportunity> oppMap = new Map<String, Opportunity>();

        for (String prefix : jdByPrefix.keySet()) {
            Account acc = accountMap.get(prefix);
            if (acc != null) {
                Opportunity opp = new Opportunity();
                opp.AccountId = acc.Id;
                opp.Name = prefix + '_' + System.today().format();
                opp.Jd_Ext__c = DateTime.now().format('yyyyMMddHHmmss');
                opp.Amount = 1000;
                opp.StageName = 'Need Analysis';
                opp.CloseDate = System.today().addDays(30);

                // Set combined Key Responsibilities on Opportunity field
                opp.Job_Description__c = prefixToResponsibilities.get(prefix);



                oppsToInsert.add(opp);
            }
        }

        if (!oppsToInsert.isEmpty()) {
            insert oppsToInsert;
            for (Opportunity opp : oppsToInsert) {
                String[] parts = opp.Name.split('_');
                if (parts.size() > 0) {
                    oppMap.put(parts[0], opp);
                }
            }
        }

        // Link Opportunities to Job Descriptions and insert Job Descriptions
        List<Job_Description__c> jdsToInsert = new List<Job_Description__c>();
        for (String prefix : jdByPrefix.keySet()) {
            Opportunity opp = oppMap.get(prefix);
            if (opp != null) {
                for (Job_Description__c jd : jdByPrefix.get(prefix)) {
                    jd.Opportunity__c = opp.Id;
                    jdsToInsert.add(jd);
                }
            }
        }

        if (!jdsToInsert.isEmpty()) {
            insert jdsToInsert;
        }
    }
}



/* working (Modified Deona)
public class OpportunityCreationController {
    public static void CreateOpportunity(String GeneratedContent) {
        // Deserialize JSON input
        List<Job_Description__c> jobDescriptions = (List<Job_Description__c>) JSON.deserialize(GeneratedContent, List<Job_Description__c>.class);
        if (jobDescriptions.isEmpty()) {
            System.debug('No job descriptions to process.');
            return;
        }

        // Collect unique company name prefixes to find or create Accounts
        Set<String> companyPrefixes = new Set<String>();
        Map<String, List<Job_Description__c>> jdByPrefix = new Map<String, List<Job_Description__c>>();

        for (Job_Description__c jd : jobDescriptions) {
            if (String.isBlank(jd.Company_Name__c)) continue;

            String[] parts = jd.Company_Name__c.trim().split('\\s+');
            if (parts.size() == 0) continue;

            String prefix = parts[0];
            companyPrefixes.add(prefix);

            if (!jdByPrefix.containsKey(prefix)) {
                jdByPrefix.put(prefix, new List<Job_Description__c>());
            }
            jdByPrefix.get(prefix).add(jd);
        }

        // Query existing accounts by prefix (assuming name starts with prefix)
        List<Account> existingAccounts = [SELECT Id, Name FROM Account WHERE Name LIKE :('%' + String.join(new List<String>(companyPrefixes), '%') + '%')];

        Map<String, Account> accountMap = new Map<String, Account>();
        for (Account acc : existingAccounts) {
            String[] parts = acc.Name.trim().split('\\s+');
            if (parts.size() > 0) {
                accountMap.put(parts[0], acc);
            }
        }

        // Create missing accounts
        List<Account> accountsToInsert = new List<Account>();
        for (String prefix : companyPrefixes) {
            if (!accountMap.containsKey(prefix)) {
                Account acc = new Account();
                acc.Name = prefix; // or full company name from jd if you want
                acc.Ext_Id__c = DateTime.now().format('yyyyMMddHHmmss');
                accountsToInsert.add(acc);
            }
        }
        if (!accountsToInsert.isEmpty()) {
            insert accountsToInsert;
            for (Account acc : accountsToInsert) {
                String[] parts = acc.Name.trim().split('\\s+');
                if (parts.size() > 0) {
                    accountMap.put(parts[0], acc);
                }
            }
        }

        // Create Opportunities linked to Accounts
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        Map<String, Opportunity> oppMap = new Map<String, Opportunity>();

        for (String prefix : jdByPrefix.keySet()) {
            Account acc = accountMap.get(prefix);
            if (acc != null) {
                Opportunity opp = new Opportunity();
                opp.AccountId = acc.Id;
                opp.Name = prefix + '_' + System.today().format();
                opp.Jd_Ext__c = DateTime.now().format('yyyyMMddHHmmss');
                opp.Amount = 1000;
                opp.StageName = 'Need Analysis';
                opp.CloseDate = System.today().addDays(30);
                oppsToInsert.add(opp);
            }
        }

        if (!oppsToInsert.isEmpty()) {
            insert oppsToInsert;
            for (Opportunity opp : oppsToInsert) {
                String[] parts = opp.Name.split('_');
                if (parts.size() > 0) {
                    oppMap.put(parts[0], opp);
                }
            }
        }

        // Now link Opportunities to Job Descriptions and insert Job Descriptions
        List<Job_Description__c> jdsToInsert = new List<Job_Description__c>();
        for (String prefix : jdByPrefix.keySet()) {
            Opportunity opp = oppMap.get(prefix);
            if (opp != null) {
                for (Job_Description__c jd : jdByPrefix.get(prefix)) {
                    jd.Opportunity__c = opp.Id;
                    jdsToInsert.add(jd);
                }
            }
        }

        if (!jdsToInsert.isEmpty()) {
            insert jdsToInsert;
        }
    }
}*/




/* working but commented for checking JD File Upload (Afrose Created)
public class OpportunityCreationController {
    public static void CreateOpportunity(String GeneratedContent){
        
         List<Job_Description__c> jobdescription = (List<Job_Description__c>)JSON.deserialize(GeneratedContent, List<Job_Description__c>.class);
        System.debug('jobdescription'+jobdescription);
        if(jobdescription.isEmpty()){
            System.debug('Job Description is empty');
         }
        Set<String> CompanyNames =new Set<String>();
        for(Job_Description__c jd:jobdescription){
            if(String.isNotBlank(jd.Company_Name__c)){
                String[] parts = jd.Company_Name__c.trim().split('\\s+'); 
        if (parts.size() > 0) {
            CompanyNames.add('%'+parts[0].toLowerCase()+'%'); 
        }
        		}
            }
        
        
        List<Account> Accts = [select id,Name from  Account where Name like:CompanyNames];
        Map<String,Account> AccountMap = new Map<String,Account>();
        for(Account acc:Accts){
            String[] parts = acc.Name.trim().split('\\s+'); 
        if (parts.size() > 0) {
            AccountMap.put(parts[0],acc);
        }
            
        }
        List<Account> newAcc = new List<Account>();
        List<Opportunity> newopp = new List<Opportunity>();
        for(Job_Description__c jd:jobdescription){
            String[] parts = jd.Company_Name__c.trim().split('\\s+');
            if(AccountMap.containsKey(parts[0])){
                Opportunity opp =new Opportunity();
                opp.AccountId=AccountMap.get(parts[0]).Id;
                opp.Name=Jd.Company_Name__c+'_'+system.today();
                opp.Jd_Ext__c= DateTime.now().format('yyyyMMddHHmmss');
                opp.Amount=1000;
                opp.StageName='Need Analysis';
                opp.CloseDate=system.today()+30;
                newopp.add(opp);
                Opportunity oppReference =new Opportunity(Jd_Ext__c=opp.Jd_Ext__c);
                Jd.Opportunity__r=oppReference;
            }else{
                Account Acc= New Account();
                Acc.Name=jd.Company_Name__c;
                Acc.Ext_Id__c=DateTime.now().format('yyyyMMddHHmmss');
                Account AccReference =new Account(Ext_Id__c=Acc.Ext_Id__c);
                newacc.add(Acc);
                Opportunity opp =new Opportunity();
                opp.Account=accReference;
                opp.Name=Jd.Company_Name__c+'_'+system.today();
                opp.Jd_Ext__c= DateTime.now().format('yyyyMMddHHmmss');
                opp.Amount=1000;
                opp.StageName='Need Analysis';
                opp.CloseDate=system.today()+30;
                newopp.add(opp);
                Opportunity oppReference =new Opportunity(Jd_Ext__c=opp.Jd_Ext__c);
                Jd.Opportunity__r=oppReference;
            }
        }    
      list<SObject> records =new List<Sobject>();
      records.addAll(newacc);
      records.addAll(newopp);
        records.addAll(jobdescription);
   	 insert records;
           
        }    	
}*/