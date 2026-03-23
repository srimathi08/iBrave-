public with sharing class InternalUserContactSyncController {

    public class SyncResponse {
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
        @AuraEnabled public Id contactId;
        @AuraEnabled public Id userId;

        public SyncResponse(Boolean success, String message) {
            this.success = success;
            this.message = message;
        }
    }

    @AuraEnabled
    public static SyncResponse linkAndSyncInternalUser(Id contactId, Id userId) {
        try {
            if (contactId == null || userId == null) {
                return new SyncResponse(false, 'Contact Id and User Id are required.');
            }

            Contact con = [
                SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                       Title, Manager__c, Birthdate,
                       Employee_Id__c, User_Designation__c, User_Department__c,
                       Date_of_Joining__c, Employment_Status__c, Internal_User__c,
                       Marital_Status__c, Probations_End_Date__c, Is_Probation__c,
                       Mode_of_Work__c, GenderIdentity, Number_of_Children__c,
                       Employee_Category__c
                FROM Contact
                WHERE Id = :contactId
                LIMIT 1
            ];

            User usr = [
                SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                       Title, Department, ManagerId,
                       Employee_IDs__c, Designation__c, Marital_Status__c,
                       Date_of_Joining__c, Probation_End_Date__c, Is_Probation__c,
                       Mode_of_Work__c, Gender__c, Number_of_Children__c,
                       Employee_Category__c, Employment_Type__c, Date_Of_Birth__c
                FROM User
                WHERE Id = :userId
                LIMIT 1
            ];

            // Link Contact to User
            con.Internal_User__c = usr.Id;
            update con;

            // Sync Contact -> User
            usr.FirstName              = con.FirstName;
            usr.LastName               = con.LastName;
            usr.Email                  = con.Email;
            usr.Phone                  = con.Phone;
            usr.MobilePhone            = con.MobilePhone;
            usr.Title                  = con.Title;
            usr.Department             = con.User_Department__c;
            usr.ManagerId              = con.Manager__c;

            // Custom fields
            usr.Marital_Status__c      = con.Marital_Status__c;
            usr.Date_of_Joining__c     = con.Date_of_Joining__c;
            usr.Designation__c         = con.User_Designation__c;
            usr.Probation_End_Date__c  = con.Probations_End_Date__c;
            usr.Is_Probation__c        = con.Is_Probation__c;
            usr.Mode_of_Work__c        = con.Mode_of_Work__c;
            usr.Gender__c              = con.GenderIdentity;
            usr.Number_of_Children__c  = con.Number_of_Children__c;
            usr.Employee_IDs__c        = con.Employee_Id__c;
            usr.Employee_Category__c   = con.Employee_Category__c;
            usr.Employment_Type__c     = con.Employment_Status__c;
            usr.Date_Of_Birth__c       = con.Birthdate;

            update usr;

            SyncResponse response = new SyncResponse(true, 'Internal User linked and synced successfully.');
            response.contactId = con.Id;
            response.userId = usr.Id;
            return response;

        } catch (Exception e) {
            return new SyncResponse(false, 'Error linking/syncing User and Contact: ' + e.getMessage());
        }
    }

    public static void syncContactsToUsers(List<Contact> contactList) {
        if (contactList == null || contactList.isEmpty()) {
            return;
        }

        Set<Id> userIds = new Set<Id>();
        for (Contact con : contactList) {
            if (con.Internal_User__c != null) {
                userIds.add(con.Internal_User__c);
            }
        }

        if (userIds.isEmpty()) {
            return;
        }

        Map<Id, User> userMap = new Map<Id, User>([
            SELECT Id, FirstName, LastName, Email, Phone, MobilePhone,
                   Title, Department, ManagerId,
                   Employee_IDs__c, Designation__c, Marital_Status__c,
                   Date_of_Joining__c, Probation_End_Date__c, Is_Probation__c,
                   Mode_of_Work__c, Gender__c, Number_of_Children__c,
                   Employee_Category__c, Employment_Type__c, Date_Of_Birth__c
            FROM User
            WHERE Id IN :userIds
        ]);

        List<User> usersToUpdate = new List<User>();

        for (Contact con : contactList) {
            if (con.Internal_User__c != null && userMap.containsKey(con.Internal_User__c)) {
                User usr = userMap.get(con.Internal_User__c);

                // Standard fields
                usr.FirstName              = con.FirstName;
                usr.LastName               = con.LastName;
                usr.Email                  = con.Email;
                usr.Phone                  = con.Phone;
                usr.MobilePhone            = con.MobilePhone;
                usr.Title                  = con.Title;
                usr.Department             = con.User_Department__c;
                // Safe manager sync
if (con.Manager__c != null) {
    if (con.Manager__c != usr.Id) {
        usr.ManagerId = con.Manager__c;
    }
} else {
    usr.ManagerId = null;
}

                // Custom fields
                usr.Marital_Status__c      = con.Marital_Status__c;
                usr.Date_of_Joining__c     = con.Date_of_Joining__c;
                usr.Designation__c         = con.User_Designation__c;
                usr.Probation_End_Date__c  = con.Probations_End_Date__c;
                usr.Is_Probation__c        = con.Is_Probation__c;
                usr.Mode_of_Work__c        = con.Mode_of_Work__c;
                usr.Gender__c              = con.GenderIdentity;
                usr.Number_of_Children__c  = con.Number_of_Children__c;
                usr.Employee_IDs__c        = con.Employee_Id__c;
                usr.Employee_Category__c   = con.Employee_Category__c;
                usr.Employment_Type__c     = con.Employment_Status__c;
                usr.Date_Of_Birth__c       = con.Birthdate;

                usersToUpdate.add(usr);
            }
        }

        if (!usersToUpdate.isEmpty()) {
            update usersToUpdate;
        }
    }
}