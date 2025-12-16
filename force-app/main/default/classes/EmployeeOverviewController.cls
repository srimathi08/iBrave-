public with sharing class EmployeeOverviewController {
    
    @AuraEnabled(cacheable=true)
    public static User getUserDetails(String userId) {
        try {
            return [
                SELECT Id, Name, Username, Email, Phone, MobilePhone, 
                       EmployeeNumber, Department, Title, Street, City, 
                       State, PostalCode, Country, TimeZoneSidKey, 
                       LanguageLocaleKey, IsActive,
                       Manager.Name, Profile.Name, UserRole.Name
                FROM User 
                WHERE Id = :userId 
                LIMIT 1
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching user details: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static void updateUserDetails(String userId, Map<String, Object> userDetails) {
        try {
            User userToUpdate = new User(Id = userId);
            
            // Update only editable fields
            if (userDetails.containsKey('Name')) {
                String fullName = (String)userDetails.get('Name');
                List<String> nameParts = fullName.split(' ', 2);
                userToUpdate.FirstName = nameParts[0];
                userToUpdate.LastName = nameParts.size() > 1 ? nameParts[1] : nameParts[0];
            }
            if (userDetails.containsKey('Email')) {
                userToUpdate.Email = (String)userDetails.get('Email');
            }
            if (userDetails.containsKey('Phone')) {
                userToUpdate.Phone = (String)userDetails.get('Phone');
            }
            if (userDetails.containsKey('MobilePhone')) {
                userToUpdate.MobilePhone = (String)userDetails.get('MobilePhone');
            }
            if (userDetails.containsKey('EmployeeNumber')) {
                userToUpdate.EmployeeNumber = (String)userDetails.get('EmployeeNumber');
            }
            if (userDetails.containsKey('Department')) {
                userToUpdate.Department = (String)userDetails.get('Department');
            }
            if (userDetails.containsKey('Title')) {
                userToUpdate.Title = (String)userDetails.get('Title');
            }
            if (userDetails.containsKey('Street')) {
                userToUpdate.Street = (String)userDetails.get('Street');
            }
            if (userDetails.containsKey('City')) {
                userToUpdate.City = (String)userDetails.get('City');
            }
            if (userDetails.containsKey('State')) {
                userToUpdate.State = (String)userDetails.get('State');
            }
            if (userDetails.containsKey('PostalCode')) {
                userToUpdate.PostalCode = (String)userDetails.get('PostalCode');
            }
            if (userDetails.containsKey('TimeZoneSidKey')) {
                userToUpdate.TimeZoneSidKey = (String)userDetails.get('TimeZoneSidKey');
            }
            if (userDetails.containsKey('LanguageLocaleKey')) {
                userToUpdate.LanguageLocaleKey = (String)userDetails.get('LanguageLocaleKey');
            }
            
            update userToUpdate;
        } catch (Exception e) {
            throw new AuraHandledException('Error updating user details: ' + e.getMessage());
        }
    }
}