/**
 * @description Test Data Factory — shared across all AutoCheckout test classes
 * FIXED: User creation now queries an existing active user from the org
 *        instead of creating a new one, avoiding restricted picklist errors
 *        on LanguageLocaleKey, TimeZoneSidKey, LocaleSidKey, EmailEncodingKey
 */
@isTest
public class AutoCheckoutTestDataFactory {

    // ── Get an existing active internal user from the org ─────────
    // This avoids ALL restricted picklist issues on User creation
    public static User getExistingUser() {
        return [
            SELECT Id, Name, Email
            FROM   User
            WHERE  IsActive    = true
            AND    UserType     = 'Standard'
            AND    Email       != null
            ORDER BY CreatedDate ASC
            LIMIT  1
        ];
    }

    // ── Open attendance record (no checkout) ──────────────────────
    public static Employee_Attendance__c createOpenAttendance(Id userId) {
        return new Employee_Attendance__c(
            Employee_Name__c  = userId,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(9, 30, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Office',
            Status__c         = 'Present',
            Notes__c          = 'Morning check-in via test'
        );
    }

    // ── Already-checked-out attendance record ─────────────────────
    public static Employee_Attendance__c createCheckedOutAttendance(Id userId) {
        return new Employee_Attendance__c(
            Employee_Name__c  = userId,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(9, 30, 0, 0)),
            Check_Out_Time__c = DateTime.newInstance(Date.today(), Time.newInstance(18, 0, 0, 0)),
            Work_Location__c  = 'Work from Office',
            Status__c         = 'Present',
            Notes__c          = 'Already checked out'
        );
    }

    // ── Past-date attendance record ───────────────────────────────
    public static Employee_Attendance__c createPastDateAttendance(Id userId) {
        return new Employee_Attendance__c(
            Employee_Name__c  = userId,
            Date__c           = Date.today().addDays(-1),
            Check_In_Time__c  = DateTime.newInstance(Date.today().addDays(-1), Time.newInstance(9, 30, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Home',
            Status__c         = 'Present',
            Notes__c          = 'Yesterday - no checkout'
        );
    }

    // ── Open attendance with no notes ─────────────────────────────
    public static Employee_Attendance__c createOpenAttendanceNoNotes(Id userId) {
        return new Employee_Attendance__c(
            Employee_Name__c  = userId,
            Date__c           = Date.today(),
            Check_In_Time__c  = DateTime.newInstance(Date.today(), Time.newInstance(8, 0, 0, 0)),
            Check_Out_Time__c = null,
            Work_Location__c  = 'Work from Home',
            Status__c         = 'Present',
            Notes__c          = null
        );
    }
}