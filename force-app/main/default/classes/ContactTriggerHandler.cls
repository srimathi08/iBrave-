public with sharing class ContactTriggerHandler {

    public static void handleAfter(
        List<Contact> newList,
        Map<Id, Contact> oldMap,
        Boolean isInsert,
        Boolean isUpdate
    ) {
        if (newList == null || newList.isEmpty()) {
            return;
        }

        List<Contact> contactsToSync = new List<Contact>();

        for (Contact con : newList) {
            if (con.Internal_User__c == null) {
                continue;
            }

            if (isInsert) {
                contactsToSync.add(con);
            } else if (isUpdate) {
                Contact oldCon = oldMap != null ? oldMap.get(con.Id) : null;

                if (oldCon == null) {
                    contactsToSync.add(con);
                    continue;
                }

                if (
                    con.FirstName != oldCon.FirstName ||
                    con.LastName != oldCon.LastName ||
                    con.Email != oldCon.Email ||
                    con.Phone != oldCon.Phone ||
                    con.MobilePhone != oldCon.MobilePhone ||
                    con.Title != oldCon.Title ||
                    con.User_Department__c != oldCon.User_Department__c ||
                    con.Manager__c != oldCon.Manager__c ||
                    con.Marital_Status__c != oldCon.Marital_Status__c ||
                    con.Date_of_Joining__c != oldCon.Date_of_Joining__c ||
                    con.User_Designation__c != oldCon.User_Designation__c ||
                    con.Probations_End_Date__c != oldCon.Probations_End_Date__c ||
                    con.Is_Probation__c != oldCon.Is_Probation__c ||
                    con.Mode_of_Work__c != oldCon.Mode_of_Work__c ||
                    con.GenderIdentity != oldCon.GenderIdentity ||
                    con.Number_of_Children__c != oldCon.Number_of_Children__c ||
                    con.Employee_Id__c != oldCon.Employee_Id__c ||
                    con.Employee_Category__c != oldCon.Employee_Category__c ||
                    con.Employment_Status__c != oldCon.Employment_Status__c ||
                    con.Birthdate != oldCon.Birthdate ||
                    con.Internal_User__c != oldCon.Internal_User__c
                ) {
                    contactsToSync.add(con);
                }
            }
        }

        if (!contactsToSync.isEmpty()) {
            InternalUserContactSyncController.syncContactsToUsers(contactsToSync);
        }
    }
}