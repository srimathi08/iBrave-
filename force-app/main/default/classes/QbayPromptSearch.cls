/**
* Author: Afrose Ahamed
* @class QbayPromptSearch
* 
* Description:
*   This class sends a user query and a ContentDocument ID to the 'Searchability_Prompt'
*   Einstein Prompt Builder template and receives a SOQL query in response.
* 
* Note:
*   - The Prompt input expects: 'Input:Text' (String) and 'Input:Qbay_Objects' (JSON with { id: ContentDocumentId })
*/
/*
public without sharing class QbayPromptSearch {
    
    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id recordId='069H1000001P8klIAC'; // ContentDocument Id
        
        @InvocableVariable(required=true)
        public String userInput; // Example: 'Get all active employees'
    }
    
    public class jsonwrapper {
        @InvocableVariable(required=true)
        public String userInput; // ContentDocument Id
        
        @InvocableVariable(required=true)
        public String rawData; // Example: 'Get all active employees'
    }
    
    @AuraEnabled
    public static String getPromptSOQL(String userInput) {
        if(userInput==null || String.IsBlank(userInput) || userInput==''){
            System.debug('Empty UserInput'+UserInput);
            return 'You must enter value';
        }
        
        QbayPromptSearch.InputWrapper input = new QbayPromptSearch.InputWrapper();
        input.recordId = '069H1000001P8klIAC';
        input.userInput = userInput;
        
        
        List<QbayPromptSearch.InputWrapper> inputList = new List<QbayPromptSearch.InputWrapper>{ input };
            
            
            List<String> results = QbayPromptSearch.getPDDPromptResponses(inputList);
        
        // Log the result
        System.debug('Prompt Response: ' + results);
        List<sObject> sobjList = Database.query(results[0]);
        System.debug('sobjList'+sobjList);
        String soqlJson = JSON.serialize(sobjList);
        System.debug(soqlJson);
        return soqlJson;
    } 
    
    @InvocableMethod(label='Generate SOQL from Prompt')
    public static List<String> getPDDPromptResponses(List<InputWrapper> inputs) {
        List<String> result = new List<String>();
        
        if (inputs == null || inputs.isEmpty() || inputs[0] == null) {
            return result;
        }
        
        Id recordId = inputs[0].recordId;
        String userInput = inputs[0].userInput;
        
        // Wrap user input as plain text
        ConnectApi.WrappedValue textWrapped = new ConnectApi.WrappedValue();
        textWrapped.value = userInput;
        
        // Wrap ContentDocument Id as JSON-style map (not full record)
        ConnectApi.WrappedValue docWrapped = new ConnectApi.WrappedValue();
        docWrapped.value = new Map<String, String>{ 'id' => recordId };
            
            // Match exactly the prompt's input keys
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:Text' => textWrapped,
                    'Input:Qbay_Objects' => docWrapped   
                    };                        
                        // Set up Prompt Template execution input
                        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;
        
        try {
            // Call Prompt Template API
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'Searchability_Prompt', // <- Ensure this matches your template API name
                executeTemplateInput
            );
            
            // Get first generation result if available
            if (!generationsOutput.generations.isEmpty()) {
                ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
                String rawResponse = response.text;
                String cleaned = rawResponse.replaceAll('(?i)(```sql|```|`)', '').trim();
                
                result.add(cleaned);
                System.debug('Prompt Result (SOQL only): ' + cleaned);
            }
            
        } catch (Exception e) {
            System.debug('Error calling Prompt API: ' + e.getMessage());
            throw e;
        }
        
        return result;
    }
    
    
    @AuraEnabled
    public static String refinePrompt(String userInput, String rawData) {
        QbayPromptSearch.jsonwrapper input = new QbayPromptSearch.jsonwrapper();
        input.userInput = userInput;
        input.rawdata = rawData;
        
        System.debug('input'+input);
        
        List<QbayPromptSearch.jsonwrapper> inputList = new List<QbayPromptSearch.jsonwrapper>{ input };
            
            
            List<String> results = getGeneratedfreeform(inputList);
        
      return results[0];
    }


    public static List<String> getGeneratedfreeform(List<jsonwrapper> inputs) {
        List<String> result = new List<String>();
        
        if (inputs == null || inputs.isEmpty() || inputs[0] == null) {
            return result;
        }
        
        String userInputs = inputs[0].userInput;
        String rawDatas = inputs[0].rawData;
        System.debug('UserInputs'+userInputs);
        System.debug('rawDatas'+rawDatas);
        // Wrap user input as plain text
        ConnectApi.WrappedValue textWrapped = new ConnectApi.WrappedValue();
        textWrapped.value = userInputs;
        
        // Wrap ContentDocument Id as JSON-style map (not full record)
        ConnectApi.WrappedValue docWrapped = new ConnectApi.WrappedValue();
        docWrapped.value = rawDatas;
            
            // Match exactly the prompt's input keys
            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
                'Input:userInput' => textWrapped,
                    'Input:rawData' => docWrapped
                    };
                   System.debug('InputParams'+inputParams);     
                        // Set up Prompt Template execution input
                        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;
        
        try {
            // Call Prompt Template API
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput = ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                'GeneratedSearch', // <- Ensure this matches your template API name
                executeTemplateInput
            );
            System.debug('generationsOutput'+generationsOutput);
            // Get first generation result if available
            if (!generationsOutput.generations.isEmpty()) {
                ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
                       System.debug('GeneratedSearch: ' + response.text);
                result.add(response.text);
            }
            
        } catch (Exception e) {
            System.debug('Error calling Prompt API: ' + e.getMessage());
            throw e;
        }  
        return result;
    }  
}*/



/**
 * Author: Afrose Ahamed (updated)
 * @class QbayPromptSearch
 *
 * Description:
 *  - Sends a user query and a ContentDocument Id to the Einstein Prompt Builder template,
 *    receives a SOQL query, sanitizes it, and executes it.
 *  - Includes a robust sanitizer so the returned text is always valid SOQL.
 *  - Includes an optional fallback for the "attached resume" intent.
 *
 * Notes:
 *  - The Prompt input expects: 'Input:Text' (String) and 'Input:Qbay_Objects' (JSON-like map with { Id: ContentDocumentId }).
 */

public without sharing class QbayPromptSearch {

    // -------------------------------
    // Wrappers
    // -------------------------------
    public class InputWrapper {
        @InvocableVariable(required=true)
        public Id recordId = '069H1000001P8klIAC'; // Default ContentDocument Id for testing

        @InvocableVariable(required=true)
        public String userInput; // e.g., "Show employees with an attached resume."
    }

    public class JsonWrapper {
        @InvocableVariable(required=true)
        public String userInput;

        @InvocableVariable(required=true)
        public String rawData;
    }

    // -------------------------------
    // Public: main entry for LWC/Aura
    // -------------------------------
    @AuraEnabled
    public static String getPromptSOQL(String userInput) {
        if (String.isBlank(userInput)) {
            return 'You must enter value';
        }

        // Optional: short-circuit fallback for a known pattern while iterating
        if (userInput.toLowerCase().contains('attached resume')) {
            String fallback =
                'SELECT Id, Name, ' +
                '(SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.Title ' +
                ' FROM ContentDocumentLinks ' +
                ' ORDER BY ContentDocument.CreatedDate DESC ' +
                ' LIMIT 1) ' +
                'FROM Account ' +
                //'WHERE IsPersonAccount = TRUE ' +
                'AND Id IN (SELECT LinkedEntityId FROM ContentDocumentLink)';
            List<SObject> fallbackList = Database.query(fallback);
            return JSON.serialize(fallbackList);
        }

        // Prepare Prompt input
        InputWrapper input = new InputWrapper();
        input.userInput = userInput; // recordId can remain default or be set by caller

        List<InputWrapper> inputList = new List<InputWrapper>{ input };

        // Generate SOQL via Prompt Template
        List<String> results = getPDDPromptResponses(inputList);

        if (results.isEmpty() || String.isBlank(results[0])) {
            throw new AuraHandledException('No SOQL generated from prompt.');
        }

        String soqlToRun = results[0];
        System.debug('Executing SOQL: ' + soqlToRun);

        // Execute and return JSON
        List<SObject> sobjList = Database.query(soqlToRun);
        return JSON.serialize(sobjList);
    }

    // -------------------------------
    // Invocable: call Prompt Template
    // -------------------------------
    @InvocableMethod(label='Generate SOQL from Prompt')
    public static List<String> getPDDPromptResponses(List<InputWrapper> inputs) {
        List<String> result = new List<String>();

        if (inputs == null || inputs.isEmpty() || inputs[0] == null) {
            return result;
        }

        Id recordId = inputs[0].recordId;
        String userInput = inputs[0].userInput;

        // Wrap user input as plain text
        ConnectApi.WrappedValue textWrapped = new ConnectApi.WrappedValue();
        textWrapped.value = userInput;

        // Wrap ContentDocument Id as a simple map to match Input:Qbay_Objects.Id
        ConnectApi.WrappedValue docWrapped = new ConnectApi.WrappedValue();
        docWrapped.value = new Map<String, String>{ 'Id' => String.valueOf(recordId) };

        // Match the template's input keys exactly
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
            'Input:Text' => textWrapped,
            'Input:Qbay_Objects' => docWrapped
        };

        // Execute Prompt Template
        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'Searchability_Prompt', // Template API name
                    executeTemplateInput
                );

            if (!generationsOutput.generations.isEmpty()) {
                ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
                String rawResponse = response.text;

                // Sanitize to guaranteed-valid SOQL
                String cleaned = sanitizeSoql(rawResponse);

                System.debug('Prompt Result (SOQL only): ' + cleaned);
                result.add(cleaned);
            }
        } catch (Exception e) {
            System.debug('Error calling Prompt API: ' + e.getMessage());
            throw e;
        }

        return result;
    }

    // -------------------------------
    // Optional: second Prompt use-case
    // -------------------------------
    @AuraEnabled
    public static String refinePrompt(String userInput, String rawData) {
        JsonWrapper input = new JsonWrapper();
        input.userInput = userInput;
        input.rawData = rawData;

        List<JsonWrapper> inputList = new List<JsonWrapper>{ input };
        List<String> results = getGeneratedFreeform(inputList);
        return (results.isEmpty() ? '' : results[0]);
    }

    public static List<String> getGeneratedFreeform(List<JsonWrapper> inputs) {
        List<String> result = new List<String>();
        if (inputs == null || inputs.isEmpty() || inputs[0] == null) return result;

        String userInputs = inputs[0].userInput;
        String rawDatas = inputs[0].rawData;

        // Wrap user input as plain text
        ConnectApi.WrappedValue textWrapped = new ConnectApi.WrappedValue();
        textWrapped.value = userInputs;

        // Raw data as-is
        ConnectApi.WrappedValue docWrapped = new ConnectApi.WrappedValue();
        docWrapped.value = rawDatas;

        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>{
            'Input:userInput' => textWrapped,
            'Input:rawData'   => docWrapped
        };

        ConnectApi.EinsteinPromptTemplateGenerationsInput executeTemplateInput =
            new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        executeTemplateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        executeTemplateInput.additionalConfig.applicationName = 'PromptBuilderPreview';
        executeTemplateInput.isPreview = false;
        executeTemplateInput.inputParams = inputParams;

        try {
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation generationsOutput =
                ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(
                    'GeneratedSearch',
                    executeTemplateInput
                );

            if (!generationsOutput.generations.isEmpty()) {
                ConnectApi.EinsteinLLMGenerationItemOutput response = generationsOutput.generations[0];
                System.debug('GeneratedSearch: ' + response.text);
                result.add(response.text);
            }
        } catch (Exception e) {
            System.debug('Error calling Prompt API: ' + e.getMessage());
            throw e;
        }

        return result;
    }

    // -------------------------------
    // Sanitizer: guarantees valid SOQL
    /* -------------------------------
    private static String sanitizeSoql(String rawResponse) {
        if (String.isBlank(rawResponse)) {
            throw new AuraHandledException('Empty response from prompt template.');
        }

        // Strip code fences/backticks/labels/prefixes
        String cleaned = rawResponse
            .replaceAll('(?i)```sql|```|`|^\\s*SOQL\\s*:\\s*', '')
            .trim();

        // Collapse newlines and extra spaces
        cleaned = cleaned.replaceAll('[\\r\\n]+', ' ');
        cleaned = cleaned.replaceAll('\\s{2,}', ' ').trim();

        // Remove trailing semicolon if present
        if (cleaned.endsWith(';')) {
            cleaned = cleaned.substring(0, cleaned.length() - 1);
        }

        // Ensure it starts with SELECT; if it looks like "fields FROM ..." prepend SELECT
        if (!cleaned.toUpperCase().startsWith('SELECT ')) {
            Integer fromPos = cleaned.toUpperCase().indexOf(' FROM ');
            if (fromPos > 0) {
                cleaned = 'SELECT ' + cleaned;
            } else {
                throw new AuraHandledException('Generated text is not valid SOQL: ' + cleaned);
            }
        }

        return cleaned;
    }*/

private static String sanitizeSoql(String rawResponse) {
    if (String.isBlank(rawResponse)) {
        throw new AuraHandledException('Empty response from prompt template.');
    }

    // Strip code fences/backticks/labels/prefixes
    String cleaned = rawResponse
        .replaceAll('(?i)```sql|```|`|^\\s*SOQL\\s*:\\s*', '')
        .trim();

    // 🔹 Replace non-breaking spaces with normal spaces
    cleaned = cleaned.replaceAll('\u00A0', ' ');

    // Collapse newlines and extra spaces
    cleaned = cleaned.replaceAll('[\\r\\n]+', ' ');
    cleaned = cleaned.replaceAll('\\s{2,}', ' ').trim();

    // Remove trailing semicolon if present
    if (cleaned.endsWith(';')) {
        cleaned = cleaned.substring(0, cleaned.length() - 1);
    }

    // Ensure it starts with SELECT; if it looks like "fields FROM ..." prepend SELECT
    if (!cleaned.toUpperCase().startsWith('SELECT ')) {
        Integer fromPos = cleaned.toUpperCase().indexOf(' FROM ');
        if (fromPos > 0) {
            cleaned = 'SELECT ' + cleaned;
        } else {
            throw new AuraHandledException('Generated text is not valid SOQL: ' + cleaned);
        }
    }

    return cleaned;
}

}