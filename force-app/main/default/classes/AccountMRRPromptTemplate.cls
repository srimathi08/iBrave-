/*  Without Fitering Region 
public class AccountMRRPromptTemplate {

    @InvocableMethod(label='Get MRR Information')
    public static List<Response> getMRRInfo(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        // Remove punctuation like '?' or '.' that might confuse matching
        userInput = userInput.replaceAll('[^a-z0-9 ,]', '');
        
        String outputText = '';
        Id userId = UserInfo.getUserId();

        // Query all user-owned accounts
        List<Account> userAccounts = [
            SELECT Name, MRR__c 
            FROM Account 
            WHERE Name != null 
            AND OwnerId = :userId
        ];

        Decimal totalMRR = 0;
        List<String> matchedNames = new List<String>();

        for (Account acc : userAccounts) {
            if (userInput.contains(acc.Name.toLowerCase())) {
                totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                matchedNames.add(acc.Name);
            }
        }

      if (!matchedNames.isEmpty()) {
    outputText = 'Total MRR for Accounts: ' + String.join(matchedNames, ', ') + ' is $' + String.valueOf(totalMRR.setScale(2));
} else if (userInput.contains('account')) {
    // User tried to mention an account, but none matched
    totalMRR = 0;
    for (Account acc : userAccounts) {
        totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
    }
    outputText = 'No specific matching accounts found. Total MRR for your accounts is $' + String.valueOf(totalMRR.setScale(2));
} else {
    // Generic MRR request like "total MRR"
    totalMRR = 0;
    for (Account acc : userAccounts) {
        totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
    }
    outputText = 'Total MRR for your accounts is $' + String.valueOf(totalMRR.setScale(2));
}

        Response output = new Response();
        output.Prompt = outputText.trim();
        responses.add(output);
        return responses;
    }

    public class Request {
        @InvocableVariable(label='User Input (e.g., "total MRR", "MRR for Account A")' required=true)
        public String user_input;
    }

    public class Response {
        @InvocableVariable(label='Prompt Output')
        public String Prompt;
    }
}*/


/*public class AccountMRRPromptTemplate {

    @InvocableMethod(label='Get MRR Information')
    public static List<Response> getMRRInfo(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        userInput = userInput.replaceAll('[^a-z0-9 ,]', ''); // Remove punctuation

        String outputText = '';
        Id userId = UserInfo.getUserId();

        // Possible regions to detect
        List<String> regions = new List<String>{'asia', 'europe', 'north america', 'south america', 'africa', 'australia', 'middle east'};
        String targetRegion = null;
        for (String regionKeyword : regions) {
            if (userInput.contains(regionKeyword)) {
                targetRegion = regionKeyword;
                break;
            }
        }

        // Extract mentioned account names like "account 7", "account 16"
        Set<String> mentionedAccounts = new Set<String>();
        Pattern accountPattern = Pattern.compile('account\\s+\\d+');
        Matcher matcher = accountPattern.matcher(userInput);
        while (matcher.find()) {
            mentionedAccounts.add(matcher.group().toLowerCase().trim());
        }
        Boolean specificAccountMentioned = !mentionedAccounts.isEmpty();

        // Query user's accounts
        List<Account> userAccounts = [
            SELECT Name, MRR__c, Region__c
            FROM Account
            WHERE OwnerId = :userId
        ];

        Decimal totalMRR = 0;
        List<Account> matchedAccounts = new List<Account>();

        for (Account acc : userAccounts) {
            Boolean regionMatch = true;
            if (targetRegion != null) {
                regionMatch = acc.Region__c != null && acc.Region__c.toLowerCase() == targetRegion;
            }
            if (!regionMatch) continue;

            String accountNameLower = acc.Name != null ? acc.Name.toLowerCase().trim() : '';

            if (specificAccountMentioned) {
                if (mentionedAccounts.contains(accountNameLower)) {
                    totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                    matchedAccounts.add(acc);
                }
            } else {
                totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                matchedAccounts.add(acc);
            }
        }

        if (!matchedAccounts.isEmpty()) {
            outputText = '✅ Total MRR' + (targetRegion != null ? ' for ' + targetRegion.capitalize() + ' Region' : '') +
                         ': $' + String.valueOf(totalMRR.setScale(2)) + '\n\n';
            outputText += 'Accounts contributing to this MRR:\n';
            for (Account acc : matchedAccounts) {
                Decimal mrrValue = acc.MRR__c != null ? acc.MRR__c.setScale(2) : 0;
                outputText += '- ' + acc.Name + ': $' + String.valueOf(mrrValue) + '\n';
            }
        } else {
            outputText = 'No matching accounts found' + (targetRegion != null ? ' in ' + targetRegion.capitalize() + ' Region.' : '.') +
                         ' Total MRR is $0.00.';
        }

        Response output = new Response();
        output.Prompt = outputText.trim();
        responses.add(output);
        return responses;
    }

    public class Request {
        @InvocableVariable(label='User Input (e.g., "total MRR", "MRR for Account 7 in Asia")' required=true)
        public String user_input;
    }

    public class Response {
        @InvocableVariable(label='Prompt Output')
        public String Prompt;
    }
}*/


//Updating the code
/*public class AccountMRRPromptTemplate {

    @InvocableMethod(label='Get MRR Information')
    public static List<Response> getMRRInfo(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        userInput = userInput.replaceAll('[^a-z0-9 ,]', ''); // Remove punctuation

        String outputText = '';
        Id userId = UserInfo.getUserId();

        // Possible regions to detect
        List<String> regions = new List<String>{'asia', 'europe', 'north america', 'south america', 'africa', 'australia', 'middle east'};
        String targetRegion = null;
        for (String regionKeyword : regions) {
            if (userInput.contains(regionKeyword)) {
                targetRegion = regionKeyword;
                break;
            }
        }

        // Extract mentioned account names like "account 7", "account 16"
        Set<String> mentionedAccounts = new Set<String>();
        Pattern accountPattern = Pattern.compile('account\\s+\\d+');
        Matcher matcher = accountPattern.matcher(userInput);
        while (matcher.find()) {
            mentionedAccounts.add(matcher.group().toLowerCase().trim());
        }
        Boolean specificAccountMentioned = !mentionedAccounts.isEmpty();

        // Query user's accounts
        List<Account> userAccounts = [
            SELECT Name, MRR__c, Region__c
            FROM Account
            WHERE OwnerId = :userId
        ];

        Decimal totalMRR = 0;
        List<Account> matchedAccounts = new List<Account>();

        for (Account acc : userAccounts) {
            Boolean regionMatch = true;
            if (targetRegion != null) {
                regionMatch = acc.Region__c != null && acc.Region__c.toLowerCase() == targetRegion;
            }
            if (!regionMatch) continue;

            String accountNameLower = acc.Name != null ? acc.Name.toLowerCase().trim() : '';

            if (specificAccountMentioned) {
                if (mentionedAccounts.contains(accountNameLower)) {
                    totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                    matchedAccounts.add(acc);
                }
            } else {
                totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                matchedAccounts.add(acc);
            }
        }

        if (!matchedAccounts.isEmpty()) {
            String regionText = (targetRegion != null) ? ' for the ' + toTitleCase(targetRegion) + ' region' : '';
            outputText = '✅ Total MRR' + regionText + ': $' + String.valueOf(totalMRR.setScale(2)) + '\n\n';
            outputText += 'Accounts contributing to this MRR:\n';
            for (Account acc : matchedAccounts) {
                Decimal mrrValue = acc.MRR__c != null ? acc.MRR__c.setScale(2) : 0;
                outputText += '- ' + acc.Name + ': $' + String.valueOf(mrrValue) + '\n';
            }
        } else {
            String regionText = (targetRegion != null) ? ' in the ' + toTitleCase(targetRegion) + ' region' : '';
            outputText = 'No matching accounts found' + regionText + '. Total MRR is $0.00.';
        }

        Response output = new Response();
        output.Prompt = outputText.trim();
        responses.add(output);
        return responses;
    }

    // Helper method to convert strings to Title Case
    public static String toTitleCase(String str) {
        if (String.isBlank(str)) return str;
        List<String> words = str.split(' ');
        for (Integer i = 0; i < words.size(); i++) {
            String w = words[i];
            if (w.length() > 0) {
                words[i] = w.substring(0,1).toUpperCase() + w.substring(1).toLowerCase();
            }
        }
        return String.join(words, ' ');
    }

    public class Request {
        @InvocableVariable(label='User Input (e.g., "total MRR", "MRR for Account 7 in Asia")' required=true)
        public String user_input;
    }

    public class Response {
        @InvocableVariable(label='Prompt Output')
        public String Prompt;
    }
}*/


public class AccountMRRPromptTemplate {

    @InvocableMethod(label='Get MRR Information')
    public static List<Response> getMRRInfo(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        userInput = userInput.replaceAll('[^a-z0-9 \\n]', ''); // remove punctuation

        String outputText = '';
        Id userId = UserInfo.getUserId();

        // Possible regions to detect
        List<String> regions = new List<String>{'asia', 'europe', 'north america', 'south america', 'africa', 'australia', 'middle east'};
        String targetRegion = null;
        for (String regionKeyword : regions) {
            if (userInput.contains(regionKeyword)) {
                targetRegion = regionKeyword;
                break;
            }
        }

        // Query user's accounts
        List<Account> userAccounts = [
            SELECT Name, MRR__c, Region__c
            FROM Account
            WHERE OwnerId = :userId
        ];

        // Build a lookup map of lowercase names to accounts
        Set<String> mentionedAccounts = new Set<String>();
        Map<String, Account> nameToAccountMap = new Map<String, Account>();
        for (Account acc : userAccounts) {
            if (acc.Name != null) {
                String lowerName = acc.Name.toLowerCase();
                nameToAccountMap.put(lowerName, acc);
                if (userInput.contains(lowerName)) {
                    mentionedAccounts.add(lowerName);
                }
            }
        }
        Boolean specificAccountMentioned = !mentionedAccounts.isEmpty();

        Decimal totalMRR = 0;
        List<Account> matchedAccounts = new List<Account>();

        for (Account acc : userAccounts) {
            Boolean regionMatch = true;
            if (targetRegion != null) {
                regionMatch = acc.Region__c != null && acc.Region__c.toLowerCase() == targetRegion;
            }
            if (!regionMatch) continue;

            String accountNameLower = acc.Name != null ? acc.Name.toLowerCase().trim() : '';

            if (specificAccountMentioned) {
                if (mentionedAccounts.contains(accountNameLower)) {
                    totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                    matchedAccounts.add(acc);
                }
            } else {
                totalMRR += acc.MRR__c != null ? acc.MRR__c : 0;
                matchedAccounts.add(acc);
            }
        }

        if (!matchedAccounts.isEmpty()) {
            String regionText = (targetRegion != null) ? ' for the ' + toTitleCase(targetRegion) + ' region' : '';
            outputText = '✅ Total MRR' + regionText + ': $' + String.valueOf(totalMRR.setScale(2)) + '\n\n';
            outputText += 'Accounts contributing to this MRR:\n';
            for (Account acc : matchedAccounts) {
                Decimal mrrValue = acc.MRR__c != null ? acc.MRR__c.setScale(2) : 0;
                outputText += '- ' + acc.Name + ': $' + String.valueOf(mrrValue) + '\n';
            }
        } else {
            String regionText = (targetRegion != null) ? ' in the ' + toTitleCase(targetRegion) + ' region' : '';
            outputText = 'No matching accounts found' + regionText + '. Total MRR is $0.00.';
        }

        Response output = new Response();
        output.Prompt = outputText.trim();
        responses.add(output);
        return responses;
    }

    // Helper method to convert strings to Title Case
    public static String toTitleCase(String str) {
        if (String.isBlank(str)) return str;
        List<String> words = str.split(' ');
        for (Integer i = 0; i < words.size(); i++) {
            String w = words[i];
            if (w.length() > 0) {
                words[i] = w.substring(0,1).toUpperCase() + w.substring(1).toLowerCase();
            }
        }
        return String.join(words, ' ');
    }

    public class Request {
        @InvocableVariable(label='User Input (e.g., "total MRR", "MRR for BioNova Solutions")' required=true)
        public String user_input;
    }

    public class Response {
        @InvocableVariable(label='Prompt Output')
        public String Prompt;
    }
}