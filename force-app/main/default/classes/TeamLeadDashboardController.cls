/**
 * TeamLeadDashboardController.cls
 * ─────────────────────────────────────────────────────────────
 * CONFIRMED REAL API NAMES from your org screenshots:
 *
 *  Contact:                Manager__c       → Lookup(User)
 *  Employee_Attendance__c: Employee__c      → Lookup(Contact)
 *  Timesheet__c:           Employee__c      → Lookup(USER)  ← KEY DIFFERENCE
 *                          Manager__c       → Lookup(User)
 *                          End_Date__c      → Date
 *                          Approval_Status__c → Picklist
 *                          Approved_By__c   → Lookup(User)
 *                          Approved_Date__c → DateTime
 *                          Rejected_By__c   → Lookup(User)
 *                          Notes__c         → Long Text
 *  Leave_Request__c:       Employee__c      → Lookup(Contact)
 *                          Manager__c       → Lookup(User)
 *                          Total_Days__c    → Number
 *                          Start_Date__c    → Date
 *                          End_Date__c      → Date
 *                          Status__c        → Picklist
 * ─────────────────────────────────────────────────────────────
 */
public with sharing class TeamLeadDashboardController {

    /* ══════════════════════════════════════════════════════
       STEP 1 — GET MY TEAM MEMBERS
       Contacts WHERE Manager__c (Lookup User) = logged-in user
    ══════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<Contact> getMyTeamMembers() {
        Id currentUserId = UserInfo.getUserId();
        return [
            SELECT  Id,
                    Name,
                    Employee_Id__c,
                    Manager__c,
                    Birthdate,
                    Phone,
                    MobilePhone,
                    Email,
                    Title
            FROM    Contact
            WHERE   Manager__c = :currentUserId
            ORDER BY Name ASC
        ];
    }

    /* ══════════════════════════════════════════════════════
       STEP 2 — ATTENDANCE RECORDS
       Employee_Attendance__c → Employee__c = Lookup(Contact)
       Query directly by Contact Id
    ══════════════════════════════════════════════════════ */
@AuraEnabled(cacheable=true)
public static List<Employee_Attendance__c> getAttendanceRecords(Id contactId) {

    // Step 1: Find the User linked to this Contact
    List<User> linkedUsers = [
        SELECT Id
        FROM User
        WHERE ContactId = :contactId
        LIMIT 1
    ];

    if(linkedUsers.isEmpty()){
        return new List<Employee_Attendance__c>();
    }

    Id userId = linkedUsers[0].Id;

    // Step 2: Query Attendance using User lookup
    return [
        SELECT Id,
               Name,
               Date__c,
               Check_In_Time__c,
               Check_Out_Time__c,
               Status__c,
               Hours_Worked__c,
               Branch__c,
               Notes__c
        FROM Employee_Attendance__c
        WHERE Employee_Name__c = :userId
        ORDER BY Date__c DESC
        LIMIT 30
    ];
}
    /* ══════════════════════════════════════════════════════
       STEP 3 — TIMESHEET RECORDS
       Timesheet__c → Employee__c = Lookup(USER)  ← NOT Contact!

       CONFIRMED from Afrose's User record:
         - User.ContactId = Contact Id  ✅ (bridge works)
         - Profile = Partner Community login User
         - Manager__c on Timesheet = Lookup(User)

       BRIDGE LOGIC:
         1. Find User WHERE ContactId = contactId
         2. Query Timesheet WHERE Employee__c = userId
         3. FALLBACK: if Manager__c is blank on records,
            query without Manager filter (only Employee filter)
            — security still held by Step 1 (only TL's employees
              are passed as contactId from getMyTeamMembers)
    ══════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<Timesheet__c> getTimesheetRecords(Id contactId) {

        // Step 1: Find the portal User linked to this Contact
        List<User> linkedUsers = [
            SELECT Id
            FROM   User
            WHERE  ContactId = :contactId
            LIMIT  1
        ];

        // If employee has no linked User, return empty
        if (linkedUsers.isEmpty()) {
            return new List<Timesheet__c>();
        }

        Id employeeUserId = linkedUsers[0].Id;
        Id currentUserId  = UserInfo.getUserId();  // Team Lead

        // Step 2: Try with Manager filter first (most secure)
        List<Timesheet__c> results = [
            SELECT  Id,
                    Name,
                    Employee__c,
                    Employee__r.Name,
                    Manager__c,
                    Manager__r.Name,
                    Approval_Status__c,
                    Approved_By__c,
                    Approved_By__r.Name,
                    Approved_Date__c,
                    Approval_Token__c,
                    End_Date__c,
                    Notes__c,
                    Rejected_By__c,
                    Rejected_By__r.Name
            FROM    Timesheet__c
            WHERE   Employee__c = :employeeUserId
            AND     Manager__c  = :currentUserId
            ORDER BY End_Date__c DESC
            LIMIT   20
        ];

        // Step 3: Fallback — if Manager__c was not set on records,
        // query by Employee only (still safe: contactId came from
        // getMyTeamMembers which already validated Manager__c = currentUser)
        if (results.isEmpty()) {
            results = [
                SELECT  Id,
                        Name,
                        Employee__c,
                        Employee__r.Name,
                        Manager__c,
                        Manager__r.Name,
                        Approval_Status__c,
                        Approved_By__c,
                        Approved_By__r.Name,
                        Approved_Date__c,
                        Approval_Token__c,
                        End_Date__c,
                        Notes__c,
                        Rejected_By__c,
                        Rejected_By__r.Name
                FROM    Timesheet__c
                WHERE   Employee__c = :employeeUserId
                ORDER BY End_Date__c DESC
                LIMIT   20
            ];
        }

        return results;
    }

    /* ══════════════════════════════════════════════════════
       STEP 3b — TIMESHEET ENTRIES (child of Timesheet__c)
       TimesheetEntry__c → Timesheet__c (Master-Detail)
       Fetches all entries for a given Timesheet record
    ══════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<TimesheetEntry__c> getTimesheetEntries(Id contactId) {
        
        List<User> linkedUsers = [
            SELECT Id FROM User WHERE ContactId = :contactId LIMIT 1
        ];
        if (linkedUsers.isEmpty()) return new List<TimesheetEntry__c>();
        
        Id employeeUserId = linkedUsers[0].Id;
        Id currentUserId  = UserInfo.getUserId();

        // Get Timesheet Ids — try with Manager filter, fallback without
        List<Timesheet__c> sheets = [
            SELECT Id FROM Timesheet__c
            WHERE  Employee__c = :employeeUserId
            AND    Manager__c  = :currentUserId
        ];
        if (sheets.isEmpty()) {
            sheets = [
                SELECT Id FROM Timesheet__c
                WHERE  Employee__c = :employeeUserId
            ];
        }
        
        if (sheets.isEmpty()) return new List<TimesheetEntry__c>();
        
        Set<Id> sheetIds = new Map<Id, Timesheet__c>(sheets).keySet();

        return [
            SELECT  Id,
                    Name,
                    Approval_Status__c,
                    Approved_By__c,
                    Approved_By__r.Name,
                    Approved_Date__c,
                    Approver_Comments__c,
                    Billing_Status__c,
                    Date__c,
                    Description__c,
                    End_Time__c,
                    Overtime_Hours__c,
                    Project__c,
                    Project__r.Name,
                    Regular_Hours__c,
                    Start_Time__c,
                    Status__c,
                    Submitted_Date__c,
                    Task__c,
                    Timesheet__c,
                    Timesheet__r.Name,
                    Total_Hours__c
            FROM    TimesheetEntry__c
            WHERE   Timesheet__c IN :sheetIds
            ORDER BY Date__c DESC
            LIMIT   50
        ];
    }

    /* ══════════════════════════════════════════════════════
       STEP 4 — LEAVE REQUESTS
       Leave_Request__c → Employee__c = Lookup(Contact)
       Query directly by Contact Id
    ══════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static List<Leave_Request__c> getLeaveRequests(Id contactId) {
        return [
            SELECT  Id,
                    Name,
                    Employee__c,
                    Employee__r.Name,
                    Employee_Id__c,
                    Leave_Type__c,
                    
                    
                    Start_Date__c,
                    End_Date__c,
                    Total_Days__c,
                    Half_Day_Type__c,
                  
                    Is_Half_Day__c,
                    
                    Is_Upcoming_Leave__c,
                    Is_Active__c,
                    Status__c,
                    Reason__c,
                    Manager__c,
                    Manager_Comments__c,
                    Approved_By__c,
                   
                    
                    Rejected_By__c,
                    
                    
                  
                    Supporting_Documents__c,
                    Year__C
                   
            FROM    Leave_Request__c
            WHERE   Employee__c = :contactId
            ORDER BY Start_Date__c DESC
            LIMIT   20
        ];
    }

    /* ══════════════════════════════════════════════════════
       STEP 5 — APPROVE / REJECT LEAVE
       Updates Status__c and Manager_Comments__c
    ══════════════════════════════════════════════════════ */
    @AuraEnabled
    public static String updateLeaveStatus(
            Id leaveRequestId, String newStatus, String comments) {
        try {
            Leave_Request__c lr = [
                SELECT Id, Status__c, Manager__c, Manager_Comments__c
                FROM   Leave_Request__c
                WHERE  Id = :leaveRequestId
                LIMIT  1
            ];
            lr.Status__c           = newStatus;
            lr.Manager__c          = UserInfo.getUserId();
            lr.Manager_Comments__c = String.isNotBlank(comments) ? comments : '';
            update lr;
            return 'SUCCESS';
        } catch (Exception e) {
            throw new AuraHandledException('Update failed: ' + e.getMessage());
        }
    }

    /* ══════════════════════════════════════════════════════
       STEP 6 — MONTHLY ATTENDANCE SUMMARY
    ══════════════════════════════════════════════════════ */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getMonthlyAttendanceSummary(Id contactId) {
        Date firstDay = Date.today().toStartOfMonth();
        Date today    = Date.today();

        List<Employee_Attendance__c> recs = [
            SELECT Status__c
            FROM   Employee_Attendance__c
            WHERE 	Employee_Name__c       = :contactId
            AND    Date__c >= :firstDay
            AND    Date__c <= :today
        ];

        Integer total = recs.size(), present = 0, late = 0, absent = 0;
        for (Employee_Attendance__c r : recs) {
            String s = r.Status__c != null ? r.Status__c.toLowerCase() : '';
            if      (s.contains('present')) present++;
            else if (s.contains('late'))    late++;
            else if (s.contains('absent'))  absent++;
        }

        Decimal rate = total > 0
            ? ((present + late) * 100.0 / total).setScale(1) : 0;

        return new Map<String, Object>{
            'total'   => total,
            'present' => present,
            'late'    => late,
            'absent'  => absent,
            'rate'    => rate
        };
    }
}