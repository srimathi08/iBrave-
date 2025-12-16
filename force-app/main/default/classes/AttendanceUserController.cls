public with sharing class AttendanceUserController {
    
    /**
     * Get current user information for attendance tracking
     * @return Map<String, Object> User information
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getCurrentUserInfo() {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            String userId = UserInfo.getUserId();
            
            User userRecord = [
                SELECT Id, Name, Email, Profile.Name, ContactId, UserType
                FROM User 
                WHERE Id = :userId
                LIMIT 1
            ];
            
            result.put('userId', userRecord.Id);
            result.put('userName', userRecord.Name);
            result.put('userEmail', userRecord.Email);
            result.put('profileName', userRecord.Profile.Name);
            result.put('contactId', userRecord.ContactId);
            result.put('userType', userRecord.UserType);
            result.put('isExperienceUser', 
                userRecord.UserType == 'PowerCustomerSuccess' || 
                userRecord.UserType == 'CustomerSuccess'
            );
            result.put('success', true);
            
            // Get today's attendance status
            List<Employee_Attendance__c> attendanceList = [
                SELECT Id, Check_In_Time__c, Check_Out_Time__c, Status__c
                FROM Employee_Attendance__c
                WHERE Employee_Name__c = :userId
                AND Date__c = TODAY
                LIMIT 1
            ];
            
            if (attendanceList.size() > 0) {
                Employee_Attendance__c attendance = attendanceList[0];
                result.put('hasCheckedIn', attendance.Check_In_Time__c != null);
                result.put('hasCheckedOut', attendance.Check_Out_Time__c != null);
                result.put('todayStatus', attendance.Status__c);
            } else {
                result.put('hasCheckedIn', false);
                result.put('hasCheckedOut', false);
                result.put('todayStatus', null);
            }
            
        } catch (Exception ex) {
            result.put('success', false);
            result.put('error', ex.getMessage());
            System.debug('Error getting user info: ' + ex.getMessage());
        }
        
        return result;
    }
}