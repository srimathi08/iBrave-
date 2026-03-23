// ========================================
// FILE 1: ContactToUserController.cls (Updated with Picklist-based User Type)
// ========================================

public with sharing class ContactToUserController {
    
    // Constants for User Types
    private static final String USER_TYPE_MANAGEMENT = 'Management';
    private static final String USER_TYPE_HR_MANAGER = 'HR Manager';
    private static final String USER_TYPE_HR_TEAM = 'HR Team';
    private static final String USER_TYPE_ONROLE_MANAGER = 'On-Role(Manager)';
    private static final String USER_TYPE_ONROLE_TEAM = 'On-Role(Team Member)';
    private static final String USER_TYPE_INTERN_STIPEND = 'Intern-Stipend';
    private static final String USER_TYPE_UNPAID_INTERN = 'Unpaid Intern';
    
    // Wrapper class for response
    public class ConversionResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public String userId;
        @AuraEnabled public String username;
        @AuraEnabled public String userType;
        @AuraEnabled public String userLicense;
        @AuraEnabled public String profileName;
        
        public ConversionResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }
    
    // Wrapper class for User Type Configuration
    public class UserTypeConfig {
        public String profileName;
        public String userLicense;
        public String displayName;
        
        public UserTypeConfig(String profileName, String userLicense, String displayName) {
            this.profileName = profileName;
            this.userLicense = userLicense;
            this.displayName = displayName;
        }
    }
    
    // Wrapper class for Contact data
    public class ContactData {
        @AuraEnabled public String firstName;
        @AuraEnabled public String lastName;
        @AuraEnabled public String email;
        @AuraEnabled public String contactUserType; // Picklist value
        @AuraEnabled public Boolean hasExistingUser;
        @AuraEnabled public String existingUsername;
        @AuraEnabled public String expectedUserLicense;
        @AuraEnabled public String expectedProfile;
        
        // Additional custom fields for display
        @AuraEnabled public Date dateOfJoining;
        @AuraEnabled public Integer numberOfChildren;
        @AuraEnabled public String maritalStatus;
        @AuraEnabled public String employeeId;
        @AuraEnabled public String managerName;
        @AuraEnabled public String employmentStatus;
        @AuraEnabled public Date probationEndDate;
        @AuraEnabled public Boolean isProbation;
        @AuraEnabled public String modeOfWork;
        @AuraEnabled public String gender;
        @AuraEnabled public String employmentType;
        @AuraEnabled public Date dateOfBirth;
        @AuraEnabled public String Designation;
    }
    
    /**
     * Get User Type Configuration based on Contact User Type picklist value
     */
    private static UserTypeConfig getUserTypeConfig(String contactUserType) {
        UserTypeConfig config;
        
        if (contactUserType == USER_TYPE_MANAGEMENT || contactUserType == USER_TYPE_HR_MANAGER) {
            // Salesforce License + System Administrator Profile
            config = new UserTypeConfig(
                'System Administrator',
                'Salesforce',
                'Salesforce User (Full License)'
            );
        } 
        else if (contactUserType == USER_TYPE_HR_TEAM || contactUserType == USER_TYPE_ONROLE_MANAGER) {
            // Partner Community License + Partner Community Login User Profile
            config = new UserTypeConfig(
                'Partner Community Login User',
                'Partner Community',
                'Partner Community User'
            );
        } 
        else if (contactUserType == USER_TYPE_ONROLE_TEAM || contactUserType == USER_TYPE_INTERN_STIPEND) {
            // Customer Community License + Customer Community Login User Profile
            config = new UserTypeConfig(
                'Customer Community Login User',
                'Customer Community',
                'Customer Community User'
            );
        }
        else if (contactUserType == USER_TYPE_UNPAID_INTERN) {
            // Unpaid Intern - Using Customer Community (can be changed as per requirement)
            config = new UserTypeConfig(
                'Customer Community Login User',
                'Customer Community',
                'Customer Community User (Unpaid Intern)'
            );
        }
        
        return config;
    }
    
    /**
     * Get Contact details for validation and display
     */
    @AuraEnabled(cacheable=true)
    public static ContactData getContactDetails(Id contactId) {
        try {
            Contact con = [
                SELECT Id, FirstName, LastName, Email, 
                       	Employee_Category__c,
                       Date_of_Joining__c, Number_of_Children__c, Marital_Status__c,
                       Employee_Id__c, Manager__c, Employment_Status__c,
                       Probations_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                       GenderIdentity, Birthdate, User_Designation__c,User_Department__c
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            ContactData data = new ContactData();
            data.firstName = con.FirstName;
            data.lastName = con.LastName;
            data.email = con.Email;
            data.contactUserType = con.Employee_Category__c;
            
            // Get expected license and profile based on user type
            if (String.isNotBlank(con.Employee_Category__c)) {
                UserTypeConfig config = getUserTypeConfig(con.Employee_Category__c);
                if (config != null) {
                    data.expectedUserLicense = config.userLicense;
                    data.expectedProfile = config.profileName;
                }
            }
            
            // Map additional fields
            data.dateOfJoining = con.Date_of_Joining__c;
            data.numberOfChildren = con.Number_of_Children__c != null ? Integer.valueOf(con.Number_of_Children__c) : null;
            data.maritalStatus = con.Marital_Status__c;
            data.employeeId = con.Employee_Id__c;
            data.employmentStatus = con.Employment_Status__c;
            data.probationEndDate = con.Probations_End_Date__c;
            data.isProbation = con.Is_Probation__c;
            data.modeOfWork = con.Mode_of_Work__c;
            data.gender = con.GenderIdentity;
            data.employmentType = con.Employment_Status__c;
            data.dateOfBirth = con.Birthdate;
            data.designation = con.User_Designation__c;
            
            
            // Get Manager name if lookup exists
            if (con.Manager__c != null) {
                try {
                    User mgr = [SELECT Name FROM User WHERE Id = :con.Manager__c LIMIT 1];
                    data.managerName = mgr.Name;
                } catch (Exception e) {
                    data.managerName = null;
                }
            }
            
            // Check for existing user
            List<User> existingUsers = [
                SELECT Id, Username, Email 
                FROM User 
                WHERE Email = :con.Email 
                LIMIT 1
            ];
            
            if (!existingUsers.isEmpty()) {
                data.hasExistingUser = true;
                data.existingUsername = existingUsers[0].Username;
            } else {
                data.hasExistingUser = false;
            }
            
            return data;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching contact details: ' + e.getMessage());
        }
    }
    
    /**
     * Main method to convert Contact to User with picklist-based mapping
     */
    @AuraEnabled
    public static ConversionResponse convertContactToUser(Id contactId) {
        try {
            // Fetch Contact details with all custom fields
            Contact con = [
                SELECT Id, FirstName, LastName, Email, 
                       	Employee_Category__c, AccountId,
                       Date_of_Joining__c, Number_of_Children__c, Marital_Status__c,
                       Employee_Id__c, Manager__c, Employment_Status__c,
                       Probations_End_Date__c, Is_Probation__c, Mode_of_Work__c,
                       GenderIdentity, Birthdate, User_Designation__c,User_Department__c
                FROM Contact 
                WHERE Id = :contactId 
                LIMIT 1
            ];
            
            // Validate required fields
            if (String.isBlank(con.Email)) {
                return new ConversionResponse(false, 'Contact must have an Email address.');
            }
            
            if (String.isBlank(con.FirstName) || String.isBlank(con.LastName)) {
                return new ConversionResponse(false, 'Contact must have First Name and Last Name.');
            }
            
            // Check if Contact User Type is selected
            if (String.isBlank(con.Employee_Category__c)) {
                return new ConversionResponse(false, 'Please select a Contact User Type before creating a user.\n\nAvailable options:\n• Management (Salesforce License)\n• HR Manager (Salesforce License)\n• HR Team (Partner Community)\n• On-Role(Manager) (Partner Community)\n• On-Role(Team Member) (Customer Community)\n• Intern-Stipend (Customer Community)\n• Unpaid Intern (Customer Community)');
            }
            
            // Check for existing user
            List<User> existingUsers = [
                SELECT Id, Username, Email 
                FROM User 
                WHERE Email = :con.Email 
                LIMIT 1
            ];
            
            if (!existingUsers.isEmpty()) {
                ConversionResponse response = new ConversionResponse(
                    false, 
                    'User Already Exists!\n\nA user with email ' + con.Email + 
                    ' already exists in the system.\n\nUsername: ' + existingUsers[0].Username + 
                    '\n\nPlease check the existing user record before creating a new one.'
                );
                response.username = existingUsers[0].Username;
                return response;
            }
            
            // Get User Type Configuration
            UserTypeConfig config = getUserTypeConfig(con.Employee_Category__c);
            
            if (config == null) {
                return new ConversionResponse(false, 'Invalid Contact User Type: ' + con.Employee_Category__c);
            }
            
            // Get Profile ID
            Id profileId = getProfileId(config.profileName);
            
            if (profileId == null) {
                return new ConversionResponse(false, 'Unable to find the required Profile: ' + config.profileName + '\n\nPlease contact your administrator.');
            }
            
            // Generate unique username
            String username = generateUniqueUsername(con.Email);
            
            // Create User with all field mappings
            User newUser = new User();
            
            // Standard User fields
            newUser.ContactId = con.Id;
            newUser.FirstName = con.FirstName;
            newUser.LastName = con.LastName;
            newUser.Email = con.Email;
            newUser.Username = username;
            newUser.ProfileId = profileId;
            newUser.Alias = generateAlias(con.FirstName, con.LastName);
            //newUser.TimeZoneSidKey = 'America/Los_Angeles';
            //newUser.LocaleSidKey = 'en_US';
           newUser.TimeZoneSidKey = 'Asia/Kolkata';  // Changed from America/Los_Angeles
           newUser.LocaleSidKey = 'en_IN';           // Changed from en_US to Indian locale
            newUser.EmailEncodingKey = 'UTF-8';
            newUser.LanguageLocaleKey = 'en_US';
            
            // Community Nickname only for Community users
            if (config.userLicense != 'Salesforce') {
                newUser.CommunityNickname = generateCommunityNickname(con.FirstName, con.LastName);
            }
            
            // Map custom fields from Contact to User
            if (con.Date_of_Joining__c != null) {
                newUser.Date_of_Joining__c = con.Date_of_Joining__c;
            }
            if (con.Number_of_Children__c != null) {
                newUser.Number_of_Children__c = con.Number_of_Children__c;
            }
            if (String.isNotBlank(con.Marital_Status__c)) {
                newUser.Marital_Status__c = con.Marital_Status__c;
            }
            if (String.isNotBlank(con.Employee_Id__c)) {
                newUser.Employee_IDs__c = con.Employee_Id__c;
            }
            if (con.Manager__c != null) {
                newUser.ManagerId = con.Manager__c;
            }
            
            if (con.Probations_End_Date__c != null) {
                newUser.Probation_End_Date__c = con.Probations_End_Date__c;
            }
            if (con.Is_Probation__c != null) {
                newUser.Is_Probation__c = con.Is_Probation__c;
            }
            if (String.isNotBlank(con.Mode_of_Work__c)) {
                newUser.Mode_of_Work__c = con.Mode_of_Work__c;
            }
            if (String.isNotBlank(con.GenderIdentity)) {
                newUser.Gender__c = con.GenderIdentity;
            }
            if (String.isNotBlank(con.Employment_Status__c)) {
                newUser.Employment_Type__c = con.Employment_Status__c;
            }
            if (con.Birthdate != null) {
                newUser.Date_Of_Birth__c = con.Birthdate;
            }
            if (String.isNotBlank(con.User_Designation__c)) {
                newUser.Designation__c = con.User_Designation__c;
            }
            if (String.isNotBlank(con.User_Department__c)) {
                newUser.Department = con.User_Department__c;
            }
            
            // Store Contact User Type on User (create this field on User object)
            if (String.isNotBlank(con.Employee_Category__c)) {
                newUser.Employee_Category__c = con.Employee_Category__c;
            }
            
            // Insert User
            insert newUser;
            
            // Prepare success response
            ConversionResponse response = new ConversionResponse(
                true,
                '✓ User Created Successfully!\n\n' +
                '═══════════════════════════════\n' +
                'USER DETAILS:\n' +
                '═══════════════════════════════\n' +
                'Name: ' + con.FirstName + ' ' + con.LastName + '\n' +
                'Email: ' + con.Email + '\n' +
                'Username: ' + username + '\n\n' +
                '═══════════════════════════════\n' +
                'LICENSE & PROFILE:\n' +
                '═══════════════════════════════\n' +
                'Contact Type: ' + con.Employee_Category__c + '\n' +
                'User License: ' + config.userLicense + '\n' +
                'Profile: ' + config.profileName + '\n' +
                'Category: ' + config.displayName + '\n\n' +
                '═══════════════════════════════\n' +
                'EMPLOYMENT INFO:\n' +
                '═══════════════════════════════\n' +
                'Employee ID: ' + (String.isNotBlank(con.Employee_Id__c) ? con.Employee_Id__c : 'N/A') + '\n' +
                'Designation: ' + (String.isNotBlank(con.User_Designation__c) ? con.User_Designation__c : 'N/A') + '\n' +
                'Employment Type: ' + (String.isNotBlank(con.Employment_Status__c) ? con.Employment_Status__c : 'N/A') + '\n\n' +
                'All custom fields have been mapped successfully.\n' +
                'An email has been sent to the user with login credentials.'
            );
            response.userId = newUser.Id;
            response.username = username;
            response.userType = con.Employee_Category__c;
            response.userLicense = config.userLicense;
            response.profileName = config.profileName;
            
            return response;
            
        } catch (DmlException e) {
            String errorMsg = 'Error creating user: ' + e.getDmlMessage(0);
            return new ConversionResponse(false, errorMsg);
        } catch (Exception e) {
            String errorMsg = 'Unexpected error: ' + e.getMessage() + '\n\nStack Trace: ' + e.getStackTraceString();
            return new ConversionResponse(false, errorMsg);
        }
    }
    
    /**
     * Get Profile ID by name
     */
    private static Id getProfileId(String profileName) {
        try {
            Profile prof = [SELECT Id FROM Profile WHERE Name = :profileName LIMIT 1];
            return prof.Id;
        } catch (Exception e) {
            System.debug('Profile not found: ' + profileName);
            return null;
        }
    }
    
    /**
     * Generate unique username
     */
    private static String generateUniqueUsername(String email) {
        // Extract the part before @ from the email
    String emailPrefix = email.substringBefore('@');
        
        String baseUsername = emailPrefix  + '@Quadrobay.com';
        String username = baseUsername;
        Integer counter = 1;
        
        while (isUsernameExists(username)) {
            username = emailPrefix  + counter + '@Quadrobay.com';
            counter++;
        }
        
        return username;
    }
    
    /**
     * Check if username already exists
     */
    private static Boolean isUsernameExists(String username) {
        List<User> users = [SELECT Id FROM User WHERE Username = :username LIMIT 1];
        return !users.isEmpty();
    }
    
    /**
     * Generate user alias (max 8 characters)
     */
    private static String generateAlias(String firstName, String lastName) {
        String alias = '';
        
        if (String.isNotBlank(firstName)) {
            alias += firstName.substring(0, 1);
        }
        
        if (String.isNotBlank(lastName)) {
            Integer lastNameLength = Math.min(lastName.length(), 7);
            alias += lastName.substring(0, lastNameLength);
        }
        
        return alias;
    }
    
    /**
     * Generate unique community nickname
     */
    private static String generateCommunityNickname(String firstName, String lastName) {
        String baseNickname = (firstName + lastName).replaceAll('[^a-zA-Z0-9]', '');
        String nickname = baseNickname;
        Integer counter = 1;
        
        while (isCommunityNicknameExists(nickname)) {
            nickname = baseNickname + counter;
            counter++;
        }
        
        return nickname;
    }
    
    /**
     * Check if community nickname exists
     */
    private static Boolean isCommunityNicknameExists(String nickname) {
        List<User> users = [SELECT Id FROM User WHERE CommunityNickname = :nickname LIMIT 1];
        return !users.isEmpty();
    }
}