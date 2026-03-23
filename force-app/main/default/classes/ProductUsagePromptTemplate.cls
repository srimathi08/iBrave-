//Working good
public class ProductUsagePromptTemplate {
    @InvocableMethod(label='Get Product Usage Count')
    public static List<Response> getProductUsage(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        Response output = new Response();

        // ✅ Step 1: Match product names from known list
/*List<Product2> productList = [SELECT Name FROM Product2 WHERE IsActive = TRUE];
Set<String> knownProducts = new Set<String>();
for (Product2 p : productList) {
    knownProducts.add(p.Name.toLowerCase());
}*/
        Set<String> knownProducts = new Set<String>{ 'bio tracker', 'banking suite' ,'AquaProof Shield'};
        Set<String> productNames = new Set<String>();
        for (String prod : knownProducts) {
            if (userInput.contains(prod.toLowerCase())) {
                productNames.add(prod.toLowerCase());
            }
        }

        if (productNames.isEmpty()) {
            output.Prompt = 'Please specify a valid product name like "Bio Tracker" or "Banking Suite" in your query.';
            responses.add(output);
            return responses;
        }

        // ✅ Step 2: Extract industry
        String industry = null;
        Pattern industryPattern = Pattern.compile('in\\s+([a-z\\s]+?)(?:\\s+industry|\\?|\\.|$)');
        Matcher industryMatcher = industryPattern.matcher(userInput);
        if (industryMatcher.find()) {
            industry = industryMatcher.group(1).trim().toLowerCase();
        } else {
            output.Prompt = 'Please mention the industry name in your query.';
            responses.add(output);
            return responses;
        }

        // ✅ Step 3: Extract employee threshold
        Integer empThreshold = null;
        Boolean empFilterMentioned = false;
        Boolean isLessThan = false;
        Boolean isGreaterThan = false;
        Boolean isEqualTo = false;

        Matcher lessMatcher = Pattern.compile('(?:less than|under|<)\\s*(\\d+)').matcher(userInput);
        Matcher greaterMatcher = Pattern.compile('(?:more than|greater than|over|>)\\s*(\\d+)').matcher(userInput);
        Matcher equalMatcher = Pattern.compile('(?:exactly|=|is|with)\\s*(\\d+)\\s*(?:employees)?').matcher(userInput);

        if (lessMatcher.find()) {
            empThreshold = Integer.valueOf(lessMatcher.group(1));
            empFilterMentioned = true;
            isLessThan = true;
        } else if (greaterMatcher.find()) {
            empThreshold = Integer.valueOf(greaterMatcher.group(1));
            empFilterMentioned = true;
            isGreaterThan = true;
        } else if (equalMatcher.find()) {
            empThreshold = Integer.valueOf(equalMatcher.group(1));
            empFilterMentioned = true;
            isEqualTo = true;
        }

        // ✅ Step 4: Get candidate accounts
        List<Account> allAccounts = new List<Account>();
        if (empFilterMentioned) {
            if (isLessThan) {
                allAccounts = [
                    SELECT Id, Name, Industry, NumberOfEmployees
                    FROM Account
                    WHERE RecordType.Name = 'Sample Account' AND NumberOfEmployees < :empThreshold
                ];
            } else if (isGreaterThan) {
                allAccounts = [
                    SELECT Id, Name, Industry, NumberOfEmployees
                    FROM Account
                    WHERE RecordType.Name = 'Sample Account' AND NumberOfEmployees > :empThreshold
                ];
            } else if (isEqualTo) {
                allAccounts = [
                    SELECT Id, Name, Industry, NumberOfEmployees
                    FROM Account
                    WHERE RecordType.Name = 'Sample Account' AND NumberOfEmployees = :empThreshold
                ];
            }
        } else {
            allAccounts = [
                SELECT Id, Name, Industry, NumberOfEmployees
                FROM Account
                WHERE RecordType.Name = 'Sample Account'
            ];
        }

        // ✅ Step 5: Filter accounts by industry (case-insensitive)
        List<Account> candidateAccounts = new List<Account>();
        for (Account a : allAccounts) {
            if (a.Industry != null && a.Industry.toLowerCase().contains(industry)) {
                candidateAccounts.add(a);
            }
        }

        if (candidateAccounts.isEmpty()) {
            output.Prompt = 'No accounts found in ' + industry +
                (empFilterMentioned ? 
                    (isLessThan ? ' with fewer than ' + empThreshold + ' employees.' :
                     isGreaterThan ? ' with more than ' + empThreshold + ' employees.' :
                     ' with exactly ' + empThreshold + ' employees.') :
                    '.');
            responses.add(output);
            return responses;
        }

        // ✅ Step 6: Get Assets
        Set<Id> accountIds = new Set<Id>();
        for (Account a : candidateAccounts) {
            accountIds.add(a.Id);
        }

        List<Asset> assets = [
            SELECT AccountId, Product2.Name
            FROM Asset
            WHERE AccountId IN :accountIds
        ];

        // ✅ Step 7: Map Account to Products
        Map<Id, Set<String>> accountToProducts = new Map<Id, Set<String>>();
        for (Asset asset : assets) {
            if (asset.Product2 != null && asset.Product2.Name != null) {
                String prodName = asset.Product2.Name.toLowerCase();
                if (!accountToProducts.containsKey(asset.AccountId)) {
                    accountToProducts.put(asset.AccountId, new Set<String>());
                }
                accountToProducts.get(asset.AccountId).add(prodName);
            }
        }

        // ✅ Step 8: Filter accounts that have all required products
        List<Account> matchedAccounts = new List<Account>();
        for (Account acc : candidateAccounts) {
            if (accountToProducts.containsKey(acc.Id)) {
                Set<String> prods = accountToProducts.get(acc.Id);
                if (prods.containsAll(productNames)) {
                    matchedAccounts.add(acc);
                }
            }
        }

        
// ✅ Step 9: Generate output
String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
String outputText = '';

if (!matchedAccounts.isEmpty()) {
    outputText += '🔍 Product Usage Report\n\n';
    outputText += 'We found ' + matchedAccounts.size() + ' account' + (matchedAccounts.size() > 1 ? 's' : '') + 
                  ' matching your criteria.\n\n';

    for (Account acc : matchedAccounts) {
        Set<String> prods = accountToProducts.get(acc.Id);
        String accountUrl = baseUrl + '/lightning/r/Account/' + acc.Id + '/view';

outputText += '🔹 Account: ' + acc.Name + '\n' +
              '    •  Product Name(s): ' + (prods != null ? String.join(new List<String>(prods), ', ') : 'None') + '\n' +
                      (empFilterMentioned && acc.NumberOfEmployees != null ?  +
              '    • Employee Count: ' + acc.NumberOfEmployees + '\n' : '') +
            ' • Industry Name: ' + (acc.Industry != null ? acc.Industry : 'N/A') + '\n' +
              '    • Account Link: ' + accountUrl + '\n\n';
}

    outputText += 'Let me know if you want to filter by different products, industries, or employee ranges.';
    output.Prompt = outputText.trim();
} else {
    output.Prompt = 'No accounts found in ' + industry + ' industry using all specified products' +
        (empFilterMentioned ?
            (isLessThan ? ' with fewer than ' + empThreshold + ' employees.' :
             isGreaterThan ? ' with more than ' + empThreshold + ' employees.' :
             ' with exactly ' + empThreshold + ' employees.') :
            '.');
}

responses.add(output);
return responses;

    }

    public class Request {
        @InvocableVariable(label='User Input' required=true)
        public String user_input;
    }

    public class Response {
        @InvocableVariable(label='Prompt Output')
        public String Prompt;
    }
}