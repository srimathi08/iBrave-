public class ObjectResolver {
	public class ResolutionResult {
        public Boolean resolved;
        public String objectApiName;
        public List<String> candidates = new List<String>();
        public String message;
    }
	 private static Map<String, Schema.SObjectType> globalDescribe  = Schema.getGlobalDescribe();
	
     public static ResolutionResult resolve(String aiObjectName) {
		ResolutionResult result = new ResolutionResult();

		if (String.isBlank(aiObjectName)) {
            result.resolved = false;
            result.message = 'No object provided';
            return result;
        }
         if (globalDescribe.containsKey(aiObjectName)) { 
			result.resolved = true;
            result.objectApiName = aiObjectName;
            System.debug('Entered into exact');
            return result; 
		}
		String normalizedInput = normalize(aiObjectName);
        System.debug('Normalized Input: ' + normalizedInput);
		for (String api : globalDescribe.keySet()) {
            Schema.DescribeSObjectResult d =
                globalDescribe.get(api).getDescribe();
			if (normalize(d.getLabel()) == normalizedInput ||
                normalize(d.getLabelPlural()) == normalizedInput) {
			
                result.resolved = true;
                result.objectApiName = api;	
  				System.debug('Entered into normal match');                  
                return result;
            }
		}

		/* 4️⃣ Fuzzy API normalization */
        for (String api : globalDescribe.keySet()) {
            if (normalize(api) == aiObjectName) {
                result.candidates.add(api);
            }
        }

        if (result.candidates.size() == 1) {
            result.resolved = true;
            result.objectApiName = result.candidates[0];
            return result;
        }

        /* 5️⃣ Ambiguous or not found */
        result.resolved = false;
        result.message =
            result.candidates.isEmpty()
            ? 'No matching object found'
            : 'Multiple objects match: ' + String.join(result.candidates, ', ');

        return result;
		
	}

	private static String normalize(String input) {
        if (input == null) return '';
        return input.toLowerCase()
            .replace('__c', '')
            .replaceAll('[^a-z]', '')
            .replaceAll('s$', '');
    }

	
}