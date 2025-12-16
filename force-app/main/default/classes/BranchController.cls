/**
 * @description Controller to manage branch operations for attendance tracking
 * @author Salesforce Developer
 * @date 2025-11-06
 * @version 1.0
 */
public with sharing class BranchController {
    
    /**
     * @description Get all active branches for dropdown selection
     * @return List of Maps containing branch information for combobox
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getActiveBranches() {
        List<Map<String, String>> branchOptions = new List<Map<String, String>>();
        
        try {
            System.debug('=== GETTING ACTIVE BRANCHES FOR DROPDOWN ===');
            
            // Query all active branches
            List<Branch__c> branches = [
                SELECT Id, Name, Branch_Name__c,
                       City__c, State__c, Country__c
                FROM Branch__c
                WHERE Is_Active__c = true
                ORDER BY Branch_Name__c ASC
                LIMIT 200
            ];
            
            System.debug('Found ' + branches.size() + ' active branches');
            
            if (branches.isEmpty()) {
                System.debug('⚠️ WARNING: No active branches found in the system');
            }
            
            // Convert to combobox format
            for (Branch__c branch : branches) {
                Map<String, String> option = new Map<String, String>();
                
                // Label: Show Branch Name with City if available
                String label = branch.Branch_Name__c;
                if (String.isNotBlank(branch.City__c)) {
                    label += ' (' + branch.City__c + ')';
                }
                
                option.put('label', label);
                option.put('value', branch.Id);
                option.put('branchName', branch.Branch_Name__c);
                option.put('city', branch.City__c != null ? branch.City__c : '');
                option.put('state', branch.State__c != null ? branch.State__c : '');
                
                branchOptions.add(option);
                
                System.debug('Branch Option: ' + label + ' | ID: ' + branch.Id);
            }
            
            System.debug('✅ Successfully prepared ' + branchOptions.size() + ' branch options for dropdown');
            
        } catch (Exception e) {
            System.debug('❌ ERROR in getActiveBranches: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            // Return empty list instead of throwing error to prevent UI breakage
        }
        
        return branchOptions;
    }
    
    /**
     * @description Get branch details by ID
     * @param branchId The branch record ID
     * @return Map containing detailed branch information
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getBranchDetails(String branchId) {
        Map<String, Object> branchInfo = new Map<String, Object>();
        
        try {
            System.debug('=== GETTING BRANCH DETAILS ===');
            System.debug('Branch ID: ' + branchId);
            
            if (String.isBlank(branchId)) {
                throw new AuraHandledException('Branch ID is required');
            }
            
            List<Branch__c> branches = [
                SELECT Id, Name, Branch_Name__c, 
                       Branch_Address__c, City__c, State__c, Country__c,
                       Branch_Manager__r.Name
                       
                FROM Branch__c
                WHERE Id = :branchId
                LIMIT 1
            ];
            
            if (branches.isEmpty()) {
                throw new AuraHandledException('Branch not found with ID: ' + branchId);
            }
            
            Branch__c branch = branches[0];
            
            branchInfo.put('success', true);
            branchInfo.put('branchId', branch.Id);
            branchInfo.put('branchName', branch.Branch_Name__c);
            branchInfo.put('branchAddress', branch.Branch_Address__c);
            branchInfo.put('city', branch.City__c);
            branchInfo.put('state', branch.State__c);
            branchInfo.put('country', branch.Country__c);
            branchInfo.put('managerName', branch.Branch_Manager__r?.Name);
            branchInfo.put('managerEmail', branch.Branch_Manager__r?.Email);
            
            System.debug('✅ Branch details retrieved: ' + branch.Branch_Name__c);
            System.debug('Branch Info: ' + JSON.serializePretty(branchInfo));
            
        } catch (AuraHandledException ahe) {
            System.debug('❌ Validation Error: ' + ahe.getMessage());
            branchInfo.put('success', false);
            branchInfo.put('error', ahe.getMessage());
            throw ahe;
            
        } catch (Exception e) {
            System.debug('❌ Error in getBranchDetails: ' + e.getMessage());
            System.debug('Stack Trace: ' + e.getStackTraceString());
            branchInfo.put('success', false);
            branchInfo.put('error', 'Failed to retrieve branch details: ' + e.getMessage());
        }
        
        return branchInfo;
    }
    
    /**
     * @description Test method to verify branch data exists
     * @return Map containing branch count and sample data
     */
    @AuraEnabled
    public static Map<String, Object> testBranchData() {
        Map<String, Object> testResult = new Map<String, Object>();
        
        try {
            System.debug('=== TESTING BRANCH DATA ===');
            
            // Count total branches
            Integer totalBranches = [SELECT COUNT() FROM Branch__c];
            Integer activeBranches = [SELECT COUNT() FROM Branch__c WHERE Is_Active__c = true];
            
            testResult.put('totalBranches', totalBranches);
            testResult.put('activeBranches', activeBranches);
            
            // Get sample branches
            List<Branch__c> samples = [
                SELECT Id, Branch_Name__c, City__c, Is_Active__c
                FROM Branch__c
                LIMIT 5
            ];
            
            List<Map<String, String>> sampleData = new List<Map<String, String>>();
            for (Branch__c branch : samples) {
                Map<String, String> sample = new Map<String, String>();
                sample.put('id', branch.Id);
                sample.put('name', branch.Branch_Name__c);
                sample.put('city', branch.City__c);
                sample.put('isActive', String.valueOf(branch.Is_Active__c));
                sampleData.add(sample);
            }
            
            testResult.put('samples', sampleData);
            testResult.put('success', true);
            testResult.put('message', 'Branch data test completed successfully');
            
            System.debug('✅ Test Results: ' + JSON.serializePretty(testResult));
            
        } catch (Exception e) {
            System.debug('❌ Error in testBranchData: ' + e.getMessage());
            testResult.put('success', false);
            testResult.put('error', e.getMessage());
        }
        
        return testResult;
    }
}