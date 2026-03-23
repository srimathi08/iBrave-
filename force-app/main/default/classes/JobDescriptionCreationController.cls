public without sharing class JobDescriptionCreationController {

    // 🔹 Normalize phone numbers (keep only digits)
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        return phone.replaceAll('[^0-9]', '');
    }

    // 🔹 Extract all currency and amount mentions from JD text
    private static List<Map<String, String>> extractAllCurrencyBlocks(String text) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(text)) return results;

        text = text.replaceAll('[\\(\\)]', ' ');
        text = text.replaceAll('\\s+', ' ').trim();

        // Matches patterns like: "2 month onsite @1500 OMR" or "Budget: USD 3000"
        Pattern p = Pattern.compile('(?i)([0-9]+\\s*(?:month|months)?[^@]{0,20})?@?\\s*([0-9]{2,}(?:\\.[0-9]+)?)\\s*(USD|OMR|EUR|GBP|INR)');
        Matcher m = p.matcher(text);

        while (m.find()) {
            Map<String, String> rec = new Map<String, String>();
            rec.put('duration', String.isBlank(m.group(1)) ? '' : m.group(1).trim());
            rec.put('amount', m.group(2));
            rec.put('currency', m.group(3).toUpperCase());
            results.add(rec);
        }

        return results;
    }

    public static List<String> createJobDescriptions(String jsonText, Id jdSampleId) {
        List<String> createdRecords = new List<String>();
        System.debug('==== START createJobDescriptions ====');

        // 🧹 Clean incoming JSON text
        String cleanedJson = jsonText
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
        } catch (Exception e) {
            System.debug('❌ JSON parse error: ' + e.getMessage());
            return null;
        }

        if (parsed == null || !parsed.containsKey('jobs')) {
            System.debug('⚠ No "jobs" found in JSON');
            return null;
        }

        List<Object> jobs = (List<Object>) parsed.get('jobs');
        System.debug('📌 Jobs count: ' + jobs.size());

        // 🔹 Pre-fetch Service record (email/whatsapp source)
        Service__c serviceRec;
        if (jdSampleId != null) {
            try {
                serviceRec = [
                    SELECT Id, EmailFrom__c, WhatsappFrom__c, Email_Body__c
                    FROM Service__c
                    WHERE Id = :jdSampleId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('⚠ No Service__c found for Id: ' + jdSampleId);
            }
        }

        // 👉 NEW: Pre-fetch all files attached to Service__c (once)
        List<ContentDocumentLink> serviceFiles = new List<ContentDocumentLink>();
        if (serviceRec != null) {
            try {
                serviceFiles = [
                    SELECT ContentDocumentId
                    FROM ContentDocumentLink
                    WHERE LinkedEntityId = :serviceRec.Id
                ];
                System.debug('📎 Service files found: ' + serviceFiles.size());
            } catch (Exception e) {
                System.debug('⚠ Error fetching Service__c files: ' + e.getMessage());
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        // 👉 NEW: Collect all new ContentDocumentLink records to insert in one go
        List<ContentDocumentLink> allNewLinks = new List<ContentDocumentLink>();

        // 🔁 Loop through each JD record
        for (Object jobObj : jobs) {
            Map<String, Object> jdWrapper = (Map<String, Object>) jobObj;
            Map<String, Object> jdData = (Map<String, Object>) jdWrapper.get('jobDescription');
            if (jdData == null) continue;             

// ✅ NEW - Extract skills from JSON
String mustHaveSkills   = jdData.get('musthaveskills') != null ? (String) jdData.get('musthaveskills') : '';
String secondarySkills  = jdData.get('secondaryskills') != null ? (String) jdData.get('secondaryskills') : '';
String goodToHaveSkills = jdData.get('Goodtohaveskills') != null ? (String) jdData.get('Goodtohaveskills') : '';
          
            // --- Company setup
            String companyName = jdData.get('companyName') != null ? String.valueOf(jdData.get('companyName')).trim() : null;
            if (String.isBlank(companyName)) continue;

            Account relatedAccount;
            List<Account> accList = [SELECT Id, Name FROM Account WHERE Name = :companyName LIMIT 1];
            if (!accList.isEmpty()) {
                relatedAccount = accList[0];
            } else {
                relatedAccount = new Account(Name = companyName);
                insert relatedAccount;
            }

            createdRecords.add(relatedAccount.Name);

            // --- Extract JD fields
            String roleRequired     = (String) jdData.get('opportunityName');
            String responsibilities = (String) jdData.get('responsibilities');
            String prefLocation     = (String) jdData.get('preferredLocation');
            String skillsRequired   = (String) jdData.get('skillsRequired');
            String duration         = (String) jdData.get('duration');

            Decimal expValue = !String.isBlank((String) jdData.get('experience'))
                ? Decimal.valueOf((String) jdData.get('experience'))
                : null;
                
               // ✅ ADD THIS
Decimal resourceNeeded = null;
if (jdData.get('ar') != null && String.isNotBlank(String.valueOf(jdData.get('ar')))) {
    try {
        resourceNeeded = Decimal.valueOf(String.valueOf(jdData.get('ar')));
    } catch (Exception e) {}
}

            // --- Fetch existing Opps for same account
            List<Opportunity> existingOpps = [
                SELECT Id, Name, AccountId, JD_Lookup__c, Job_Description__c,
                       Role_Required__c, Skills_Required__c, Experience_Required__c,
                       Job_Location__c, Source_Content__c, Source_Of_Requirement__c,
                       StageName, Start_Date__c, Amount,
                       Budget_In_JD__c, Currency_Mentioned_In_JD__c,
                       Original_Budget_Amount__c, Original_Currency__c
                FROM Opportunity
                WHERE AccountId = :relatedAccount.Id
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            Opportunity oppMatch;

            // --- Enhanced JD Matching Logic
            for (Opportunity o : existingOpps) {
                Boolean jdSimilar = false;
                Boolean roleSimilar = false;
                Boolean skillSimilar = false;

                if (!String.isBlank(o.Job_Description__c) && !String.isBlank(responsibilities)) {
                    String oldJD = o.Job_Description__c.toLowerCase();
                    String newJD = responsibilities.toLowerCase();

                    List<String> dashVariants = new List<String>{'—', '–', '−', '―'};
                    for (String dash : dashVariants) {
                        oldJD = oldJD.replace(dash, '-');
                        newJD = newJD.replace(dash, '-');
                    }

                    oldJD = oldJD.replaceAll('\\s+', ' ').trim();
                    newJD = newJD.replaceAll('\\s+', ' ').trim();

                    if (oldJD.equalsIgnoreCase(newJD)) {
                        jdSimilar = true;
                    } else {
                        Set<String> set1 = new Set<String>();
                        for (String w : oldJD.split('\\s+')) {
                            if (w.length() > 3) set1.add(w);
                        }
                        Set<String> set2 = new Set<String>();
                        for (String w : newJD.split('\\s+')) {
                            if (w.length() > 3) set2.add(w);
                        }
                        Integer common = 0;
                        for (String w : set2) {
                            if (set1.contains(w)) common++;
                        }
                        Decimal overlap = (set2.size() > 0) ? Decimal.valueOf(common) / set2.size() : 0;
                        jdSimilar = overlap >= 0.4;
                    }
                }

                if (!String.isBlank(o.Role_Required__c) && !String.isBlank(roleRequired)) {
                    roleSimilar = o.Role_Required__c.trim().equalsIgnoreCase(roleRequired.trim());
                } else {
                    roleSimilar = true;
                }

                if (!String.isBlank(o.Skills_Required__c) && !String.isBlank(skillsRequired)) {
                    String oldSkills = o.Skills_Required__c.toLowerCase();
                    String newSkills = skillsRequired.toLowerCase();
                    skillSimilar = oldSkills.contains(newSkills) || newSkills.contains(oldSkills);
                } else {
                    skillSimilar = true;
                }

                if (jdSimilar && (roleSimilar && skillSimilar)) {
                    oppMatch = o;
                    System.debug('✅ Match found (JD + Role + Skills): ' + o.Id);
                    break;
                }

                if (oppMatch == null && jdSimilar) {
                    oppMatch = o;
                    System.debug('⚙ JD-only match (ignoring Source): ' + o.Id);
                    break;
                }
            }

            Opportunity opp;
            if (oppMatch != null) {
                opp = oppMatch;
            } else {
                opp = new Opportunity();
                opp.Name = !String.isBlank(roleRequired) ? roleRequired : companyName + ' - ' + Date.today().format();
                opp.AccountId = relatedAccount.Id;
                opp.StageName = 'Discovery';
                opp.CloseDate = Date.today().addMonths(1);
            }

            // --- Basic JD field mapping
            opp.Role_Required__c = roleRequired;

// ✅ NEW - Map skills to Opportunity
opp.Must_Have_Skills__c    = mustHaveSkills;
opp.Secondary_Skills__c    = secondarySkills;
opp.Good_to_Have_Skills__c = goodToHaveSkills;

            opp.Skills_Required__c = skillsRequired;
            opp.Job_Location__c = prefLocation;
            opp.Job_Duration__c = duration;
            if (expValue != null) opp.Experience_Required__c = String.valueOf(expValue);

             // ✅ ADD THIS
if (resourceNeeded != null) {
    opp.Resource_Needed__c = resourceNeeded;
}

           
            if (!String.isBlank((String) jdData.get('opportunityStartDate'))) {
                opp.Start_Date__c = Date.valueOf((String) jdData.get('opportunityStartDate'));
            }

            // 🔹 Currency extraction (Clean Version — avoids duplicate EUR/USD)
            String jdTextCombined =
                (responsibilities != null ? responsibilities : '') + ' ' +
                (String.valueOf(jdData.get('qualifications')) != null ? String.valueOf(jdData.get('qualifications')) : '') + ' ' +
                (String.valueOf(jdData.get('skillsRequired')) != null ? String.valueOf(jdData.get('skillsRequired')) : '');

            // Fetch CMDT conversion rates
            Map<String, Decimal> rates = new Map<String, Decimal>();
            for (Currency_Rates__mdt c : [
                SELECT Currency_Code__c, INR_Conversion_Rate__c 
                FROM Currency_Rates__mdt
            ]) {
                if (c.Currency_Code__c != null && c.INR_Conversion_Rate__c != null) {
                    rates.put(c.Currency_Code__c.trim().toUpperCase(), c.INR_Conversion_Rate__c);
                }
            }

            if (rates.isEmpty()) {
                rates.put('INR', 1);
                rates.put('USD', 88.33);
                rates.put('OMR', 229.78);
                rates.put('EUR', 102.76);
                rates.put('GBP', 117.95);
            }

            List<Map<String, String>> jdCurrencyBlocks = extractAllCurrencyBlocks(jdTextCombined);

            if (!jdCurrencyBlocks.isEmpty()) {
                List<String> allDurations = new List<String>();
                List<String> allAmounts = new List<String>();
                String commonCurrency = '';
                Decimal totalINR = 0;

                for (Map<String, String> block : jdCurrencyBlocks) {
                    String currencyCode = block.get('currency');
                    String amtStr = block.get('amount');
                    if (String.isBlank(amtStr)) continue; // skip stray currency-only matches
                    Decimal amount = Decimal.valueOf(amtStr);
                    String durationText = block.get('duration');

                    allDurations.add(durationText);
                    allAmounts.add(amount + ' ' + currencyCode);
                    if (String.isBlank(commonCurrency)) commonCurrency = currencyCode;

                    Decimal rate = rates.containsKey(currencyCode) ? rates.get(currencyCode) : 1;
                    totalINR += (amount * rate);
                }

                opp.Job_Duration__c = String.join(allDurations, ', ');
                opp.Budget_In_JD__c = String.join(allAmounts, ', ');
                opp.Currency_Mentioned_In_JD__c = commonCurrency;
                opp.Original_Budget_Amount__c = Decimal.valueOf(jdCurrencyBlocks[0].get('amount'));
                opp.Original_Currency__c = jdCurrencyBlocks[0].get('currency');
                opp.Amount = totalINR;
                opp.CurrencyIsoCode = 'INR';
            }

            // 🔹 Fallback: use JSON if regex didn't find any currency
            if (jdCurrencyBlocks.isEmpty()) {
                String budgetMentioned   = (String) jdData.get('budgetMentioned');
                String currencyMentioned = (String) jdData.get('currencyMentioned');

                if (!String.isBlank(budgetMentioned) && !String.isBlank(currencyMentioned)) {
                    Decimal amountVal = 0;
                    try {
                        amountVal = Decimal.valueOf(budgetMentioned);
                    } catch (Exception e) {
                        // ignore parse error
                    }

                    Decimal rate = rates.containsKey(currencyMentioned.toUpperCase())
                        ? rates.get(currencyMentioned.toUpperCase())
                        : 1;

                    Decimal totalINR = amountVal * rate;

                    opp.Budget_In_JD__c = budgetMentioned + ' ' + currencyMentioned;
                    opp.Currency_Mentioned_In_JD__c = currencyMentioned;
                    opp.Original_Budget_Amount__c = amountVal;
                    opp.Original_Currency__c = currencyMentioned;
                    opp.Amount = totalINR;
                    opp.CurrencyIsoCode = 'INR';
                }
            }

            opp.Budget_Confirmed__c = (opp.Amount != null && opp.Amount > 0);
            opp.Date_Received__c = Date.today();
            //opp.Generate_Match__c = 'Generate Match';
            opp.Job_Type__c = (String) jdData.get('jobType');
            opp.Required_Qualifications__c = (String) jdData.get('qualifications');

            if (!String.isBlank((String) jdData.get('opportunityCloseDate'))) {
                opp.CloseDate = Date.valueOf((String) jdData.get('opportunityCloseDate'));
            }

            if (serviceRec != null) {
                opp.Source_Content__c = serviceRec.Email_Body__c;
                if (!String.isBlank(serviceRec.EmailFrom__c)) {
                    opp.Source_Of_Requirement__c = 'Email';
                } else if (!String.isBlank(serviceRec.WhatsappFrom__c)) {
                    opp.Source_Of_Requirement__c = 'Whatsapp';
                }
            }

            if (serviceRec != null) {
                User oppOwner;
                if (!String.isBlank(serviceRec.EmailFrom__c)) {
                    List<User> usersByEmail = [SELECT Id FROM User WHERE Email = :serviceRec.EmailFrom__c LIMIT 1];
                    if (!usersByEmail.isEmpty()) oppOwner = usersByEmail[0];
                }
                if (oppOwner == null && !String.isBlank(serviceRec.WhatsappFrom__c)) {
                    String servicePhone = normalizePhone(serviceRec.WhatsappFrom__c);
                    for (User u : [SELECT Id, Phone, MobilePhone FROM User WHERE Phone != null OR MobilePhone != null]) {
                        if (normalizePhone(u.Phone) == servicePhone || normalizePhone(u.MobilePhone) == servicePhone) {
                            oppOwner = u;
                            break;
                        }
                    }
                }
                opp.OwnerId = (oppOwner != null) ? oppOwner.Id : UserInfo.getUserId();
            }

            // Insert/update Opportunity before we use its Id
            if (opp.Id == null) {
                insert opp;
            } else {
                update opp;
            }
            createdRecords.add(String.valueOf(opp.Id));

            // --- Job Description (Custom Object)
            Job_Description__c jd;
            if (opp.JD_Lookup__c != null) {
                jd = [
                    SELECT Id
                    FROM Job_Description__c
                    WHERE Id = :opp.JD_Lookup__c
                    LIMIT 1
                ];
            } else {
                jd = new Job_Description__c(
                    Opportunity__c = opp.Id,
                    Company_Name__c = companyName
                );
            }

            jd.Name                   = ((String) jdData.get('title')) != null ? ((String) jdData.get('title')).left(80) : null;
            jd.Key_Responsibilities__c = responsibilities;
            jd.Preferred_Location__c   = prefLocation;
            jd.Experience__c           = expValue;
            jd.Skills__c               = skillsRequired;

            // ✅ NEW - Map skills to Job Description
            jd.Must_Have_Skills__c    = mustHaveSkills;
            jd.Secondary_Skills__c    = secondarySkills;
            jd.Good_to_Have_Skills__c = goodToHaveSkills;

            if (jd.Id == null) {
                insert jd;
                opp.JD_Lookup__c = jd.Id;
            } else {
                update jd;
            }

            // Sync plain text JD back to Opportunity
            opp.Job_Description__c = jd.Key_Responsibilities__c;
             // ✅ Generate Match logic
if (String.isBlank(opp.Job_Description__c)) {
    opp.Generate_Match__c = 'None';
} else {
    opp.Generate_Match__c = 'Generate Match';
}
           
            oppsToUpdate.add(opp);

            // 👉 NEW: Attach Service__c files to this Opportunity and Job_Description__c
            if (!serviceFiles.isEmpty()) {
                for (ContentDocumentLink sFile : serviceFiles) {
                    // Link to Opportunity
                    allNewLinks.add(new ContentDocumentLink(
                        ContentDocumentId = sFile.ContentDocumentId,
                        LinkedEntityId    = opp.Id,
                        ShareType         = 'I',       // Inferred permission
                        Visibility        = 'AllUsers'
                    ));

                    // Link to Job Description
                    allNewLinks.add(new ContentDocumentLink(
                        ContentDocumentId = sFile.ContentDocumentId,
                        LinkedEntityId    = jd.Id,
                        ShareType         = 'I',
                        Visibility        = 'AllUsers'
                    ));
                }
            }
        }

        // Final update for Opportunities (JD lookup / JD text, etc.)
        if (!oppsToUpdate.isEmpty()) {
            update oppsToUpdate;
        }

        // 👉 NEW: Insert all ContentDocumentLink records in bulk
        if (!allNewLinks.isEmpty()) {
            insert allNewLinks;
        }

        System.debug('==== END createJobDescriptions ====');
        return createdRecords;
    }
}






/*  Working code But the File from Service Object is Linked to Opp/JD Object
public without sharing class JobDescriptionCreationController {

    // 🔹 Normalize phone numbers (keep only digits)
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        return phone.replaceAll('[^0-9]', '');
    }

    // 🔹 Extract all currency and amount mentions from JD text
    private static List<Map<String, String>> extractAllCurrencyBlocks(String text) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(text)) return results;

        text = text.replaceAll('[\\(\\)]', ' ');
        text = text.replaceAll('\\s+', ' ').trim();

        // Matches patterns like: "2 month onsite @1500 OMR" or "Budget: USD 3000"
        Pattern p = Pattern.compile('(?i)([0-9]+\\s*(?:month|months)?[^@]{0,20})?@?\\s*([0-9]{2,}(?:\\.[0-9]+)?)\\s*(USD|OMR|EUR|GBP|INR)');
        Matcher m = p.matcher(text);

        while (m.find()) {
            Map<String, String> rec = new Map<String, String>();
            rec.put('duration', String.isBlank(m.group(1)) ? '' : m.group(1).trim());
            rec.put('amount', m.group(2));
            rec.put('currency', m.group(3).toUpperCase());
            results.add(rec);
        }

        return results;
    }

    public static List<String> createJobDescriptions(String jsonText, Id jdSampleId) {
        List<String> createdRecords = new List<String>();
        System.debug('==== START createJobDescriptions ====');

        // 🧹 Clean incoming JSON text
        String cleanedJson = jsonText
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
        } catch (Exception e) {
            System.debug('❌ JSON parse error: ' + e.getMessage());
            return null;
        }

        if (parsed == null || !parsed.containsKey('jobs')) {
            System.debug('⚠ No "jobs" found in JSON');
            return null;
        }

        List<Object> jobs = (List<Object>) parsed.get('jobs');
        System.debug('📌 Jobs count: ' + jobs.size());

        // 🔹 Pre-fetch Service record (email/whatsapp source)
        Service__c serviceRec;
        if (jdSampleId != null) {
            try {
                serviceRec = [
                    SELECT Id, EmailFrom__c, WhatsappFrom__c, Email_Body__c
                    FROM Service__c
                    WHERE Id = :jdSampleId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('⚠ No Service__c found for Id: ' + jdSampleId);
            }
        }

        List<Opportunity> oppsToUpdate = new List<Opportunity>();

        // 🔁 Loop through each JD record
        for (Object jobObj : jobs) {
            Map<String, Object> jdData = (Map<String, Object>) ((Map<String, Object>) jobObj).get('jobDescription');
            if (jdData == null) continue;

            // --- Company setup
            String companyName = jdData.get('companyName') != null ? String.valueOf(jdData.get('companyName')).trim() : null;
            if (String.isBlank(companyName)) continue;

            Account relatedAccount;
            List<Account> accList = [SELECT Id, Name FROM Account WHERE Name = :companyName LIMIT 1];
            if (!accList.isEmpty()) relatedAccount = accList[0];
            else {
                relatedAccount = new Account(Name = companyName);
                insert relatedAccount;
            }

            createdRecords.add(relatedAccount.Name);

            // --- Extract JD fields
            String roleRequired = (String) jdData.get('opportunityName');
            String responsibilities = (String) jdData.get('responsibilities');
            String prefLocation = (String) jdData.get('preferredLocation');
            String skillsRequired = (String) jdData.get('skillsRequired');
            String duration = (String) jdData.get('duration');
            Decimal expValue = !String.isBlank((String) jdData.get('experience'))
                ? Decimal.valueOf((String) jdData.get('experience')) : null;

            // --- Fetch existing Opps for same account
            List<Opportunity> existingOpps = [
                SELECT Id, Name, AccountId, JD_Lookup__c, Job_Description__c,
                       Role_Required__c, Skills_Required__c, Experience_Required__c,
                       Job_Location__c, Source_Content__c, Source_Of_Requirement__c,
                       StageName, Start_Date__c, Amount,
                       Budget_In_JD__c, Currency_Mentioned_In_JD__c,
                       Original_Budget_Amount__c, Original_Currency__c
                FROM Opportunity
                WHERE AccountId = :relatedAccount.Id
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            Opportunity oppMatch;

            // --- Enhanced JD Matching Logic
            for (Opportunity o : existingOpps) {
                Boolean jdSimilar = false;
                Boolean roleSimilar = false;
                Boolean skillSimilar = false;

                if (!String.isBlank(o.Job_Description__c) && !String.isBlank(responsibilities)) {
                    String oldJD = o.Job_Description__c.toLowerCase();
                    String newJD = responsibilities.toLowerCase();

                    List<String> dashVariants = new List<String>{'—', '–', '−', '―'};
                    for (String dash : dashVariants) {
                        oldJD = oldJD.replace(dash, '-');
                        newJD = newJD.replace(dash, '-');
                    }

                    oldJD = oldJD.replaceAll('\\s+', ' ').trim();
                    newJD = newJD.replaceAll('\\s+', ' ').trim();

                    if (oldJD.equalsIgnoreCase(newJD)) jdSimilar = true;
                    else {
                        Set<String> set1 = new Set<String>();
                        for (String w : oldJD.split('\\s+')) if (w.length() > 3) set1.add(w);
                        Set<String> set2 = new Set<String>();
                        for (String w : newJD.split('\\s+')) if (w.length() > 3) set2.add(w);
                        Integer common = 0;
                        for (String w : set2) if (set1.contains(w)) common++;
                        Decimal overlap = (set2.size() > 0) ? Decimal.valueOf(common) / set2.size() : 0;
                        jdSimilar = overlap >= 0.4;
                    }
                }

                if (!String.isBlank(o.Role_Required__c) && !String.isBlank(roleRequired))
                    roleSimilar = o.Role_Required__c.trim().equalsIgnoreCase(roleRequired.trim());
                else roleSimilar = true;

                if (!String.isBlank(o.Skills_Required__c) && !String.isBlank(skillsRequired)) {
                    skillSimilar = o.Skills_Required__c.toLowerCase().contains(skillsRequired.toLowerCase()) ||
                                   skillsRequired.toLowerCase().contains(o.Skills_Required__c.toLowerCase());
                } else skillSimilar = true;

                if (jdSimilar && (roleSimilar && skillSimilar)) {
                    oppMatch = o;
                    System.debug('✅ Match found (JD + Role + Skills): ' + o.Id);
                    break;
                }

                if (oppMatch == null && jdSimilar) {
                    oppMatch = o;
                    System.debug('⚙ JD-only match (ignoring Source): ' + o.Id);
                    break;
                }
            }

            Opportunity opp;
            if (oppMatch != null) opp = oppMatch;
            else {
                opp = new Opportunity();
                opp.Name = !String.isBlank(roleRequired) ? roleRequired : companyName + ' - ' + Date.today().format();
                opp.AccountId = relatedAccount.Id;
                opp.StageName = 'Discovery';
                opp.CloseDate = Date.today().addMonths(1);
            }

            // --- Basic JD field mapping
            opp.Role_Required__c = roleRequired;
            opp.Skills_Required__c = skillsRequired;
            opp.Job_Location__c = prefLocation;
            opp.Job_Duration__c = duration;
            if (expValue != null) opp.Experience_Required__c = String.valueOf(expValue);
            if (!String.isBlank((String) jdData.get('opportunityStartDate')))
                opp.Start_Date__c = Date.valueOf((String) jdData.get('opportunityStartDate'));

            // 🔹 Currency extraction (Clean Version — avoids duplicate EUR/USD)
            String jdTextCombined =
                (responsibilities != null ? responsibilities : '') + ' ' +
                (String.valueOf(jdData.get('qualifications')) != null ? String.valueOf(jdData.get('qualifications')) : '') + ' ' +
                (String.valueOf(jdData.get('skillsRequired')) != null ? String.valueOf(jdData.get('skillsRequired')) : '');

            // Fetch CMDT conversion rates
            Map<String, Decimal> rates = new Map<String, Decimal>();
            for (Currency_Rates__mdt c : [
                SELECT Currency_Code__c, INR_Conversion_Rate__c 
                FROM Currency_Rates__mdt
            ]) {
                if (c.Currency_Code__c != null && c.INR_Conversion_Rate__c != null) {
                    rates.put(c.Currency_Code__c.trim().toUpperCase(), c.INR_Conversion_Rate__c);
                }
            }

            if (rates.isEmpty()) {
                rates.put('INR', 1);
                rates.put('USD', 88.33);
                rates.put('OMR', 229.78);
                rates.put('EUR', 102.76);
                rates.put('GBP', 117.95);
            }

            List<Map<String, String>> jdCurrencyBlocks = extractAllCurrencyBlocks(jdTextCombined);

            if (!jdCurrencyBlocks.isEmpty()) {
                List<String> allDurations = new List<String>();
                List<String> allAmounts = new List<String>();
                String commonCurrency = '';
                Decimal totalINR = 0;

                for (Map<String, String> block : jdCurrencyBlocks) {
                    String currencyCode = block.get('currency');
                    String amtStr = block.get('amount');
                    if (String.isBlank(amtStr)) continue; // skip stray currency-only matches
                    Decimal amount = Decimal.valueOf(amtStr);
                    String durationText = block.get('duration');

                    allDurations.add(durationText);
                    allAmounts.add(amount + ' ' + currencyCode);
                    if (String.isBlank(commonCurrency)) commonCurrency = currencyCode;

                    Decimal rate = rates.containsKey(currencyCode) ? rates.get(currencyCode) : 1;
                    totalINR += (amount * rate);
                }

                opp.Job_Duration__c = String.join(allDurations, ', ');
                opp.Budget_In_JD__c = String.join(allAmounts, ', ');
                opp.Currency_Mentioned_In_JD__c = commonCurrency;
                opp.Original_Budget_Amount__c = Decimal.valueOf(jdCurrencyBlocks[0].get('amount'));
                opp.Original_Currency__c = jdCurrencyBlocks[0].get('currency');
                opp.Amount = totalINR;
                opp.CurrencyIsoCode = 'INR';
            }

            // 🔹 Fallback: use JSON if regex didn't find any currency
            if (jdCurrencyBlocks.isEmpty()) {
                String budgetMentioned = (String) jdData.get('budgetMentioned');
                String currencyMentioned = (String) jdData.get('currencyMentioned');

                if (!String.isBlank(budgetMentioned) && !String.isBlank(currencyMentioned)) {
                    Decimal amountVal = 0;
                    try { amountVal = Decimal.valueOf(budgetMentioned); } catch (Exception e) {}

                    Decimal rate = rates.containsKey(currencyMentioned.toUpperCase()) ? 
                                   rates.get(currencyMentioned.toUpperCase()) : 1;
                    Decimal totalINR = amountVal * rate;

                    opp.Budget_In_JD__c = budgetMentioned + ' ' + currencyMentioned;
                    opp.Currency_Mentioned_In_JD__c = currencyMentioned;
                    opp.Original_Budget_Amount__c = amountVal;
                    opp.Original_Currency__c = currencyMentioned;
                    opp.Amount = totalINR;
                    opp.CurrencyIsoCode = 'INR';
                }
            }

            opp.Budget_Confirmed__c = (opp.Amount != null && opp.Amount > 0);
            opp.Date_Received__c = Date.today();
            opp.Generate_Match__c = 'Generate Match';
            opp.Job_Type__c = (String) jdData.get('jobType');
            opp.Required_Qualifications__c = (String) jdData.get('qualifications');
            if (!String.isBlank((String) jdData.get('opportunityCloseDate')))
                opp.CloseDate = Date.valueOf((String) jdData.get('opportunityCloseDate'));

            if (serviceRec != null) {
                opp.Source_Content__c = serviceRec.Email_Body__c;
                if (!String.isBlank(serviceRec.EmailFrom__c)) opp.Source_Of_Requirement__c = 'Email';
                else if (!String.isBlank(serviceRec.WhatsappFrom__c)) opp.Source_Of_Requirement__c = 'Whatsapp';
            }

            if (serviceRec != null) {
                User oppOwner;
                if (!String.isBlank(serviceRec.EmailFrom__c)) {
                    List<User> usersByEmail = [SELECT Id FROM User WHERE Email = :serviceRec.EmailFrom__c LIMIT 1];
                    if (!usersByEmail.isEmpty()) oppOwner = usersByEmail[0];
                }
                if (oppOwner == null && !String.isBlank(serviceRec.WhatsappFrom__c)) {
                    String servicePhone = normalizePhone(serviceRec.WhatsappFrom__c);
                    for (User u : [SELECT Id, Phone, MobilePhone FROM User WHERE Phone != null OR MobilePhone != null]) {
                        if (normalizePhone(u.Phone) == servicePhone || normalizePhone(u.MobilePhone) == servicePhone) {
                            oppOwner = u;
                            break;
                        }
                    }
                }
                opp.OwnerId = (oppOwner != null) ? oppOwner.Id : UserInfo.getUserId();
            }

            if (opp.Id == null) insert opp; else update opp;
            createdRecords.add(opp.Id);

            Job_Description__c jd;
            if (opp.JD_Lookup__c != null)
                jd = [SELECT Id FROM Job_Description__c WHERE Id = :opp.JD_Lookup__c LIMIT 1];
            else jd = new Job_Description__c(Opportunity__c = opp.Id, Company_Name__c = companyName);

            jd.Name = ((String) jdData.get('title'))?.left(80);
            jd.Key_Responsibilities__c = responsibilities;
            jd.Preferred_Location__c = prefLocation;
            jd.Experience__c = expValue;
            jd.Skills__c = skillsRequired;

            if (jd.Id == null) {
                insert jd;
                opp.JD_Lookup__c = jd.Id;
            } else update jd;

            opp.Job_Description__c = jd.Key_Responsibilities__c;
            oppsToUpdate.add(opp);
        }

        if (!oppsToUpdate.isEmpty()) update oppsToUpdate;
        System.debug('==== END createJobDescriptions ====');
        return createdRecords;
    }
}   */











/*public without sharing class JobDescriptionCreationController {

    // 🔹 Normalize phone numbers (keep only digits)
    private static String normalizePhone(String phone) {
        if (String.isBlank(phone)) return null;
        return phone.replaceAll('[^0-9]', '');
    }

    // 🔹 Extract all currency and amount mentions from JD text
    private static List<Map<String, String>> extractAllCurrencyBlocks(String text) {
        List<Map<String, String>> results = new List<Map<String, String>>();
        if (String.isBlank(text)) return results;

        text = text.replaceAll('[\\(\\)]', ' ');
        text = text.replaceAll('\\s+', ' ').trim();

        // Matches patterns like: "2 month onsite @1500 OMR" or "Budget: USD 3000"
        Pattern p = Pattern.compile('(?i)([0-9]+\\s*(?:month|months)?[^@]{0,20})?@?\\s*([0-9]{2,}(?:\\.[0-9]+)?)\\s*(USD|OMR|EUR|GBP|INR)');
        Matcher m = p.matcher(text);

        while (m.find()) {
            Map<String, String> rec = new Map<String, String>();
            rec.put('duration', String.isBlank(m.group(1)) ? '' : m.group(1).trim());
            rec.put('amount', m.group(2));
            rec.put('currency', m.group(3).toUpperCase());
            results.add(rec);
        }

        return results;
    }

    // 🧩 Main method to create Job Descriptions and related records
    public static List<String> createJobDescriptions(String jsonText, Id jdSampleId) {
        List<String> createdRecords = new List<String>();
        System.debug('==== START createJobDescriptions ====');

        // 🧹 Clean incoming JSON text
        String cleanedJson = jsonText
            .replaceAll('\u00A0', '')
            .replaceAll('```json?', '')
            .replaceAll('```', '')
            .trim();

        Map<String, Object> parsed;
        try {
            parsed = (Map<String, Object>) JSON.deserializeUntyped(cleanedJson);
        } catch (Exception e) {
            System.debug('❌ JSON parse error: ' + e.getMessage());
            return null;
        }

        if (parsed == null || !parsed.containsKey('jobs')) {
            System.debug('⚠ No "jobs" found in JSON');
            return null;
        }

        List<Object> jobs = (List<Object>) parsed.get('jobs');
        System.debug('📌 Jobs count: ' + jobs.size());

        // 🔹 Fetch Service record (Email/WhatsApp source)
        Service__c serviceRec;
        if (jdSampleId != null) {
            try {
                serviceRec = [
                    SELECT Id, EmailFrom__c, WhatsappFrom__c, Email_Body__c
                    FROM Service__c
                    WHERE Id = :jdSampleId
                    LIMIT 1
                ];
            } catch (Exception e) {
                System.debug('⚠ No Service__c found for Id: ' + jdSampleId);
            }
        }

        // 🔹 DML lists for bulk-safe handling
        List<Account> accountsToInsert = new List<Account>();
        List<Opportunity> oppsToInsert = new List<Opportunity>();
        List<Opportunity> oppsToUpdate = new List<Opportunity>();
        List<Job_Description__c> jdsToInsert = new List<Job_Description__c>();
        List<Job_Description__c> jdsToUpdate = new List<Job_Description__c>();

        // 🔁 Process each job
        for (Object jobObj : jobs) {
            Map<String, Object> jdData = (Map<String, Object>) ((Map<String, Object>) jobObj).get('jobDescription');
            if (jdData == null) continue;

            // --- Company setup
            String companyName = jdData.get('companyName') != null ? String.valueOf(jdData.get('companyName')).trim() : null;
            if (String.isBlank(companyName)) continue;

            Account relatedAccount;
            List<Account> accList = [SELECT Id, Name FROM Account WHERE Name = :companyName LIMIT 1];
            if (!accList.isEmpty()) {
                relatedAccount = accList[0];
            } else {
                relatedAccount = new Account(Name = companyName);
                accountsToInsert.add(relatedAccount);
            }

            createdRecords.add(companyName);

            // --- Extract JD fields
            String roleRequired = (String) jdData.get('opportunityName');
            String responsibilities = (String) jdData.get('responsibilities');
            String prefLocation = (String) jdData.get('preferredLocation');
            String skillsRequired = (String) jdData.get('skillsRequired');
            String duration = (String) jdData.get('duration');
            Decimal expValue = !String.isBlank((String) jdData.get('experience'))
                ? Decimal.valueOf((String) jdData.get('experience')) : null;

            // --- Existing Opps (for match logic)
            List<Opportunity> existingOpps = new List<Opportunity>();
            if (relatedAccount.Id != null) {
                existingOpps = [
                    SELECT Id, Name, AccountId, JD_Lookup__c, Job_Description__c,
                           Role_Required__c, Skills_Required__c, Experience_Required__c,
                           Job_Location__c, Source_Content__c, Source_Of_Requirement__c,
                           StageName, Start_Date__c, Amount,
                           Budget_In_JD__c, Currency_Mentioned_In_JD__c,
                           Original_Budget_Amount__c, Original_Currency__c
                    FROM Opportunity
                    WHERE AccountId = :relatedAccount.Id
                    ORDER BY CreatedDate DESC
                    LIMIT 50
                ];
            }

            Opportunity oppMatch;
            // --- JD, Role, Skill match logic
            for (Opportunity o : existingOpps) {
                Boolean jdSimilar = false;
                Boolean roleSimilar = false;
                Boolean skillSimilar = false;

                if (!String.isBlank(o.Job_Description__c) && !String.isBlank(responsibilities)) {
                    String oldJD = o.Job_Description__c.toLowerCase();
                    String newJD = responsibilities.toLowerCase();

                    List<String> dashVariants = new List<String>{'—', '–', '−', '―'};
                    for (String dash : dashVariants) {
                        oldJD = oldJD.replace(dash, '-');
                        newJD = newJD.replace(dash, '-');
                    }

                    oldJD = oldJD.replaceAll('\\s+', ' ').trim();
                    newJD = newJD.replaceAll('\\s+', ' ').trim();

                    if (oldJD.equalsIgnoreCase(newJD)) jdSimilar = true;
                    else {
                        Set<String> set1 = new Set<String>();
                        for (String w : oldJD.split('\\s+')) if (w.length() > 3) set1.add(w);
                        Set<String> set2 = new Set<String>();
                        for (String w : newJD.split('\\s+')) if (w.length() > 3) set2.add(w);
                        Integer common = 0;
                        for (String w : set2) if (set1.contains(w)) common++;
                        Decimal overlap = (set2.size() > 0) ? Decimal.valueOf(common) / set2.size() : 0;
                        jdSimilar = overlap >= 0.4;
                    }
                }

                if (!String.isBlank(o.Role_Required__c) && !String.isBlank(roleRequired))
                    roleSimilar = o.Role_Required__c.trim().equalsIgnoreCase(roleRequired.trim());
                else roleSimilar = true;

                if (!String.isBlank(o.Skills_Required__c) && !String.isBlank(skillsRequired)) {
                    skillSimilar = o.Skills_Required__c.toLowerCase().contains(skillsRequired.toLowerCase()) ||
                                   skillsRequired.toLowerCase().contains(o.Skills_Required__c.toLowerCase());
                } else skillSimilar = true;

                if (jdSimilar && (roleSimilar && skillSimilar)) {
                    oppMatch = o;
                    break;
                }
                if (oppMatch == null && jdSimilar) {
                    oppMatch = o;
                    break;
                }
            }

            Opportunity opp;
            if (oppMatch != null) opp = oppMatch;
            else {
                opp = new Opportunity();
                opp.Name = !String.isBlank(roleRequired) ? roleRequired : companyName + ' - ' + Date.today().format();
                opp.AccountId = relatedAccount.Id;
                opp.StageName = 'Discovery';
                opp.CloseDate = Date.today().addMonths(1);
            }

            // --- Field mapping
            opp.Role_Required__c = roleRequired;
            opp.Skills_Required__c = skillsRequired;
            opp.Job_Location__c = prefLocation;
            opp.Job_Duration__c = duration;
            if (expValue != null) opp.Experience_Required__c = String.valueOf(expValue);
            if (!String.isBlank((String) jdData.get('opportunityStartDate')))
                opp.Start_Date__c = Date.valueOf((String) jdData.get('opportunityStartDate'));

            // --- Currency logic
            String jdTextCombined =
                (responsibilities != null ? responsibilities : '') + ' ' +
                (String.valueOf(jdData.get('qualifications')) != null ? String.valueOf(jdData.get('qualifications')) : '') + ' ' +
                (String.valueOf(jdData.get('skillsRequired')) != null ? String.valueOf(jdData.get('skillsRequired')) : '');

            Map<String, Decimal> rates = new Map<String, Decimal>();
            for (Currency_Rates__mdt c : [
                SELECT Currency_Code__c, INR_Conversion_Rate__c FROM Currency_Rates__mdt
            ]) {
                if (c.Currency_Code__c != null && c.INR_Conversion_Rate__c != null)
                    rates.put(c.Currency_Code__c.trim().toUpperCase(), c.INR_Conversion_Rate__c);
            }

            if (rates.isEmpty()) {
                rates.put('INR', 1);
                rates.put('USD', 88.33);
                rates.put('OMR', 229.78);
                rates.put('EUR', 102.76);
                rates.put('GBP', 117.95);
            }

            List<Map<String, String>> jdCurrencyBlocks = extractAllCurrencyBlocks(jdTextCombined);

            if (!jdCurrencyBlocks.isEmpty()) {
                List<String> allDurations = new List<String>();
                List<String> allAmounts = new List<String>();
                String commonCurrency = '';
                Decimal totalINR = 0;

                for (Map<String, String> block : jdCurrencyBlocks) {
                    String currencyCode = block.get('currency');
                    String amtStr = block.get('amount');
                    if (String.isBlank(amtStr)) continue;
                    Decimal amount = Decimal.valueOf(amtStr);
                    String durationText = block.get('duration');

                    allDurations.add(durationText);
                    allAmounts.add(amount + ' ' + currencyCode);
                    if (String.isBlank(commonCurrency)) commonCurrency = currencyCode;

                    Decimal rate = rates.containsKey(currencyCode) ? rates.get(currencyCode) : 1;
                    totalINR += (amount * rate);
                }

                opp.Job_Duration__c = String.join(allDurations, ', ');
                opp.Budget_In_JD__c = String.join(allAmounts, ', ');
                opp.Currency_Mentioned_In_JD__c = commonCurrency;
                opp.Original_Budget_Amount__c = Decimal.valueOf(jdCurrencyBlocks[0].get('amount'));
                opp.Original_Currency__c = jdCurrencyBlocks[0].get('currency');
                opp.Amount = totalINR;
                opp.CurrencyIsoCode = 'INR';
            }

            // --- Fallback currency
            if (jdCurrencyBlocks.isEmpty()) {
                String budgetMentioned = (String) jdData.get('budgetMentioned');
                String currencyMentioned = (String) jdData.get('currencyMentioned');

                if (!String.isBlank(budgetMentioned) && !String.isBlank(currencyMentioned)) {
                    Decimal amountVal = 0;
                    try { amountVal = Decimal.valueOf(budgetMentioned); } catch (Exception e) {}

                    Decimal rate = rates.containsKey(currencyMentioned.toUpperCase()) ?
                                   rates.get(currencyMentioned.toUpperCase()) : 1;
                    Decimal totalINR = amountVal * rate;

                    opp.Budget_In_JD__c = budgetMentioned + ' ' + currencyMentioned;
                    opp.Currency_Mentioned_In_JD__c = currencyMentioned;
                    opp.Original_Budget_Amount__c = amountVal;
                    opp.Original_Currency__c = currencyMentioned;
                    opp.Amount = totalINR;
                    opp.CurrencyIsoCode = 'INR';
                }
            }

            opp.Budget_Confirmed__c = (opp.Amount != null && opp.Amount > 0);
            opp.Date_Received__c = Date.today();
            opp.Generate_Match__c = 'Generate Match';
            opp.Job_Type__c = (String) jdData.get('jobType');
            opp.Required_Qualifications__c = (String) jdData.get('qualifications');
            if (!String.isBlank((String) jdData.get('opportunityCloseDate')))
                opp.CloseDate = Date.valueOf((String) jdData.get('opportunityCloseDate'));

            if (serviceRec != null) {
                opp.Source_Content__c = serviceRec.Email_Body__c;
                if (!String.isBlank(serviceRec.EmailFrom__c)) opp.Source_Of_Requirement__c = 'Email';
                else if (!String.isBlank(serviceRec.WhatsappFrom__c)) opp.Source_Of_Requirement__c = 'Whatsapp';
            }

            // --- Owner Assignment
            if (serviceRec != null) {
                User oppOwner;
                if (!String.isBlank(serviceRec.EmailFrom__c)) {
                    List<User> usersByEmail = [SELECT Id FROM User WHERE Email = :serviceRec.EmailFrom__c LIMIT 1];
                    if (!usersByEmail.isEmpty()) oppOwner = usersByEmail[0];
                }
                if (oppOwner == null && !String.isBlank(serviceRec.WhatsappFrom__c)) {
                    String servicePhone = normalizePhone(serviceRec.WhatsappFrom__c);
                    for (User u : [SELECT Id, Phone, MobilePhone FROM User WHERE Phone != null OR MobilePhone != null]) {
                        if (normalizePhone(u.Phone) == servicePhone || normalizePhone(u.MobilePhone) == servicePhone) {
                            oppOwner = u;
                            break;
                        }
                    }
                }
                opp.OwnerId = (oppOwner != null) ? oppOwner.Id : UserInfo.getUserId();
            }

            // --- Collect for DML
            if (opp.Id == null) oppsToInsert.add(opp);
            else oppsToUpdate.add(opp);

            // --- Create JD record
            Job_Description__c jd = new Job_Description__c(
                Company_Name__c = companyName,
                Opportunity__c = opp.Id,
                Name = ((String) jdData.get('title'))?.left(80),
                Key_Responsibilities__c = responsibilities,
                Preferred_Location__c = prefLocation,
                Experience__c = expValue,
                Skills__c = skillsRequired
            );
            jdsToInsert.add(jd);
        }

        // 🔹 Perform all DML at once
        if (!accountsToInsert.isEmpty()) insert accountsToInsert;
        if (!oppsToInsert.isEmpty()) insert oppsToInsert;
        if (!oppsToUpdate.isEmpty()) update oppsToUpdate;
        if (!jdsToInsert.isEmpty()) insert jdsToInsert;
        if (!jdsToUpdate.isEmpty()) update jdsToUpdate;

        System.debug('==== END createJobDescriptions ====');
        return createdRecords;
    }
}  */