public class AccountRenewalPromptTemplate {

    @InvocableMethod(label='Get Account Renewal Info')
    public static List<Response> getRenewalInfo(List<Request> requests) {
        List<Response> responses = new List<Response>();
        if (requests == null || requests.isEmpty()) return responses;

        Request input = requests[0];
        String userInput = input.user_input != null ? input.user_input.trim().toLowerCase() : '';
        userInput = userInput.replaceAll('[^a-z0-9\\s]', ''); // Remove punctuation
        String outputText = '';
        Id userId = UserInfo.getUserId();

        // Region map
        List<String> knownRegions = new List<String>{
            'asia', 'europe', 'north america', 'latin america', 'middle east', 'africa', 'australia'
        };
        String region = null;

        for (String r : knownRegions) {
            if (userInput.contains(r)) {
                region = r.capitalize(); // Match picklist case
                break;
            }
        }

        Date today = Date.today();
        Integer currentYear = today.year();
        Integer currentMonth = today.month();
        Integer year = null;
        Integer month = null;
        Date startDate;
        Date endDate;

        Map<String, Integer> monthMap = new Map<String, Integer>{
            'january' => 1, 'february' => 2, 'march' => 3, 'april' => 4,
            'may' => 5, 'june' => 6, 'july' => 7, 'august' => 8,
            'september' => 9, 'october' => 10, 'november' => 11, 'december' => 12
        };

        for (String m : monthMap.keySet()) {
            if (userInput.contains(m)) {
                month = monthMap.get(m);
                break;
            }
        }

        List<String> parts = userInput.split('\\s+');
        for (String p : parts) {
            if (p.isNumeric() && p.length() == 4) {
                year = Integer.valueOf(p);
                break;
            }
        }

        if (userInput.contains('this month')) {
            month = currentMonth;
            year = currentYear;
        }

        if (userInput.contains('next month')) {
            month = currentMonth == 12 ? 1 : currentMonth + 1;
            year = currentMonth == 12 ? currentYear + 1 : currentYear;
        }

        if (userInput.contains('next year') && year == null) {
            year = currentYear + 1;
        }

        if (userInput.contains('this year') && year == null) {
            year = currentYear;
        }

        if (month != null && year == null) {
            year = currentYear;
        }

        if (month != null && year != null) {
            startDate = Date.newInstance(year, month, 1);
            endDate = startDate.addMonths(1).addDays(-1);
        } else if (month == null && year != null) {
            startDate = Date.newInstance(year, 1, 1);
            endDate = Date.newInstance(year, 12, 31);
        } else {
            Response res = new Response();
            res.Prompt = 'Could not recognize the date input. Try "May 2025", "this year", "next month", or "2024".';
            responses.add(res);
            return responses;
        }

        List<Account> accounts;

        if (region != null) {
            accounts = [
                SELECT Name, Renewal_Date__c, Owner.Name, MRR__c
                FROM Account
                WHERE Renewal_Date__c >= :startDate 
                AND Renewal_Date__c <= :endDate
                AND OwnerId = :userId
                AND Region__c = :region
                LIMIT 100
            ];
        } else {
            accounts = [
                SELECT Name, Renewal_Date__c, Owner.Name, MRR__c
                FROM Account
                WHERE Renewal_Date__c >= :startDate 
                AND Renewal_Date__c <= :endDate
                AND OwnerId = :userId
                LIMIT 100
            ];
        }

        Decimal totalMRR = 0;
        for (Account acc : accounts) {
            if (acc.MRR__c != null) {
                totalMRR += acc.MRR__c;
            }
        }

        outputText = '📅 Renewals Scheduled for This ' +
            (month != null && year != null ? 'Month' : 'Period') + '\n\n';

        if (accounts.isEmpty()) {
            outputText += 'No accounts found.\n';
        } else {
            outputText += 'We found ' + accounts.size() + ' account' + (accounts.size() > 1 ? 's' : '') +
                ' scheduled for renewal during this period with a total MRR of $' +
                String.valueOf(totalMRR.setScale(2)) + '.\n\n';

          String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();  

for (Account acc : accounts) {
    Date d = acc.Renewal_Date__c;
    String formattedDate = d.format(); // e.g., "May 14, 2025"
    String accountUrl = baseUrl + '/lightning/r/Account/' + acc.Id + '/view';  

  /*outputText += '🔹 Account: ' + acc.Name + '\n' +
              '    • Renewal Date: ' + formattedDate + '\n' +
              '    • Owner: ' + acc.Owner.Name + '\n' +
              (acc.MRR__c != null ? '    • MRR: $' + String.valueOf(acc.MRR__c.setScale(2)) + '\n' : '') +
              '    • [View Account](' + accountUrl + ')\n\n';*/

// Working in prompt
outputText += '🔹 Account: ' + acc.Name + '\n' +
              '    • Renewal Date: ' + formattedDate + '\n' +
              '    • Owner: ' + acc.Owner.Name + '\n' +
              (acc.MRR__c != null ? '    • MRR: $' + String.valueOf(acc.MRR__c.setScale(2)) + '\n' : '') +
              '    • Account Link: ' + accountUrl + '\n\n';
}

            outputText += 'Let me know if you\'d like a breakdown by region, upcoming renewals for next month, or a summary by owner.';
        }

        Response output = new Response();
        output.Prompt = outputText.trim();
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