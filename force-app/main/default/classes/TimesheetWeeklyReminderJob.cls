public class TimesheetWeeklyReminderJob {
    
    private static Map<String, Integer> getLastWeekAndYear() {
    Date today = Date.today();

    // Go back 7 days to safely land in last week
    Date lastWeekDate = today.addDays(-7);

    Integer lastWeekNumber = TimesheetController.getWeekNumber(lastWeekDate);
    Integer lastWeekYear   = lastWeekDate.year();

    return new Map<String, Integer>{
        'week' => lastWeekNumber,
        'year' => lastWeekYear
    };
}
private static Boolean isValidEmail(String email) {
    return String.isNotBlank(email) && email.contains('@') && email.contains('.');
}
public static List<User> getActiveTimesheetUsers(Boolean onlyWithManager) {

   String baseQuery =
        'SELECT Id, Email, Name, FirstName, LastName, ManagerId, ' +
        'Manager.Email, Manager.Name, Manager.FirstName, Manager.LastName ' +
        'FROM User WHERE IsActive = true ';

    // ✅ ONLY APPLY FILTER IN PROD
    if (!Test.isRunningTest()) {
        baseQuery +=
            'AND (UserType = \'PowerPartner\' ' +
            'OR UserType = \'CustomerSuccess\' ' +
            'OR UserType = \'CSPLitePortal\') ';
    }

    if (onlyWithManager) {
        baseQuery += ' AND ManagerId != null';
    }

    return Database.query(baseQuery);
}

public static Map<Id, Decimal> getUserActualHoursBulk(
    Set<Id> userIds,
    Integer weekNumber,
    Integer year
) {
    Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
    Date weekEnd   = weekStart.addDays(4);

    Map<Id, Decimal> userHoursMap = new Map<Id, Decimal>();

    for (AggregateResult ar : [
        SELECT Timesheet__r.Employee__c empId, SUM(Total_Hours__c) total
        FROM TimesheetEntry__c
        WHERE Timesheet__r.Employee__c IN :userIds
        AND Date__c >= :weekStart
        AND Date__c <= :weekEnd
        GROUP BY Timesheet__r.Employee__c
    ]) {
        userHoursMap.put(
            (Id) ar.get('empId'),
            (Decimal) ar.get('total')
        );
    }

    return userHoursMap;
} 
public static Map<Id, Decimal> prepareActualHoursMap(
    List<User> employees,
    Integer weekNumber,
    Integer year
) {
    Set<Id> userIds = new Set<Id>();
    for (User u : employees) {
        userIds.add(u.Id);
    }

    return getUserActualHoursBulk(userIds, weekNumber, year);
}
public static Map<Id, Decimal> getExpectedWeeklyHoursBulk(
    Set<Id> userIds,
    Integer weekNumber,
    Integer year
) {
    Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
    Date weekEnd   = weekStart.addDays(4);

    Map<Id, Decimal> result = new Map<Id, Decimal>();

    // Default expected hours
    for (Id uid : userIds) {
        result.put(uid, 40);
    }

    // 🔹 1. Holidays (ONE QUERY)
    Integer holidayCount = [
        SELECT COUNT()
        FROM Holiday__c
        WHERE Is_Active__c = true
        AND Holiday_Date__c >= :weekStart
        AND Holiday_Date__c <= :weekEnd
    ];

    Decimal holidayReduction = holidayCount * 8;

    // Apply holiday reduction to ALL users
    for (Id uid : result.keySet()) {
        result.put(uid, result.get(uid) - holidayReduction);
    }

    // 🔹 2. Leaves (ONE QUERY FOR ALL USERS)
    List<Leave_Request__c> leaves = [
        SELECT Employee__c, Start_Date__c, End_Date__c, Is_Half_Day__c
        FROM Leave_Request__c
        WHERE Employee__c IN :userIds
        AND Status__c = 'Approved'
        AND End_Date__c >= :weekStart
        AND Start_Date__c <= :weekEnd
    ];

    // 🔹 Group leaves by user
    Map<Id, List<Leave_Request__c>> leavesByUser = new Map<Id, List<Leave_Request__c>>();

    for (Leave_Request__c lv : leaves) {
        if (!leavesByUser.containsKey(lv.Employee__c)) {
            leavesByUser.put(lv.Employee__c, new List<Leave_Request__c>());
        }
        leavesByUser.get(lv.Employee__c).add(lv);
    }

    // 🔹 Apply leave logic
    for (Id uid : leavesByUser.keySet()) {

        Decimal expected = result.get(uid);

        for (Leave_Request__c lv : leavesByUser.get(uid)) {

            Date s = lv.Start_Date__c < weekStart ? weekStart : lv.Start_Date__c;
            Date e = lv.End_Date__c > weekEnd   ? weekEnd   : lv.End_Date__c;

            if (lv.Is_Half_Day__c) {
                expected -= 4;
            } else {
                expected -= ((e.daysBetween(s) + 1) * 8);
            }
        }

        result.put(uid, expected < 0 ? 0 : expected);
    }

    // Ensure no negatives
    for (Id uid : result.keySet()) {
        if (result.get(uid) < 0) {
            result.put(uid, 0);
        }
    }

    return result;
}
private static Id getOrgWideEmailId() {

    List<OrgWideEmailAddress> oweaList = [
        SELECT Id
        FROM OrgWideEmailAddress
        WHERE IsAllowAllProfiles = true
        LIMIT 1
    ];

    if (!oweaList.isEmpty()) {
        return oweaList[0].Id;
    }

    return null; // fallback → system email
}
  // Original method - sends to all employees
   public static void sendReminders() {

    Map<String, Integer> weekInfo = getLastWeekAndYear();
    Integer weekNumber = weekInfo.get('week');
    Integer year = weekInfo.get('year');

    List<User> employees = getActiveTimesheetUsers(false);
    Map<Id, Decimal> actualHoursMap = prepareActualHoursMap(employees, weekNumber, year);

    Set<Id> userIds = new Set<Id>();
    for (User u : employees) {
        userIds.add(u.Id);
    }

    Map<Id, Decimal> expectedHoursMap =
        getExpectedWeeklyHoursBulk(userIds, weekNumber, year);

    List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
Id oweaId = getOrgWideEmailId();
    for (User emp : employees) {

        Decimal actualHours = actualHoursMap.get(emp.Id);
        if (actualHours == null) actualHours = 0;

        Decimal expectedHours = expectedHoursMap.get(emp.Id);
        if (expectedHours == null) expectedHours = 40;

        if (actualHours < expectedHours && isValidEmail(emp.Email)) {
			
            Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
            msg.setToAddresses(new String[] { emp.Email });
            msg.setSubject('Weekly Timesheet Reminder - Action Required');
            msg.setHtmlBody(buildHtmlEmail(emp, actualHours, expectedHours, weekNumber, year));
if (oweaId != null) {
    msg.setOrgWideEmailAddressId(oweaId);
        }
            emails.add(msg);

        }
    }

    if (!emails.isEmpty()) {
    if (!Test.isRunningTest()) {
        Messaging.sendEmail(emails);
    }
}
    }

    // NEW: Send reminder to a single user by Id
    public static void sendReminderToUser(Id userId) {
        sendReminderToUser(userId, null);
    }
    
    // NEW: Send reminder to a single user with optional email override
    public static void sendReminderToUser(Id userId, String overrideEmail) {
        
        Map<String, Integer> weekInfo = getLastWeekAndYear();
Integer weekNumber = weekInfo.get('week');
Integer year = weekInfo.get('year');

        User emp = [
            SELECT Id, Email, Name, FirstName
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        Decimal expectedHours = TimesheetController.getExpectedWeeklyHours(emp.Id, weekNumber, year);
        Decimal actualHours = getUserActualHours(emp.Id, weekNumber, year);
        
        // Use override email if provided, otherwise use user's email
        String targetEmail = String.isNotBlank(overrideEmail) ? overrideEmail : emp.Email;

if (!isValidEmail(targetEmail)) {
    System.debug('❌ Invalid user email, skipping');
    return;
}
        Id oweaId = getOrgWideEmailId();
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { targetEmail });
        msg.setSubject('Weekly Timesheet Reminder - Action Required');
        msg.setHtmlBody(buildHtmlEmail(emp, actualHours, expectedHours, weekNumber, year));
         if (oweaId != null) {
    msg.setOrgWideEmailAddressId(oweaId);
}
        if (!Test.isRunningTest()) {
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
}
       
        System.debug('✅ Email sent successfully to: ' + targetEmail);
        System.debug('📊 Hours - Actual: ' + actualHours + ', Expected: ' + expectedHours);
    }
    
    // NEW: Preview HTML without sending (for debugging)
    public static String previewEmailHtml(Id userId) {
        
        Map<String, Integer> weekInfo = getLastWeekAndYear();
Integer weekNumber = weekInfo.get('week');
Integer year = weekInfo.get('year');

        User emp = [
            SELECT Id, Email, Name, FirstName
            FROM User
            WHERE Id = :userId
            LIMIT 1
        ];
        
        Decimal expectedHours = TimesheetController.getExpectedWeeklyHours(emp.Id, weekNumber, year);
        Decimal actualHours = getUserActualHours(emp.Id, weekNumber, year);
        
        String html = buildHtmlEmail(emp, actualHours, expectedHours, weekNumber, year);
        System.debug('HTML Length: ' + html.length());
        System.debug(html);
        return html;
    }
    
    private static String buildHtmlEmail(User emp, Decimal actualHours, Decimal expectedHours, Integer weekNumber, Integer year) {
        String firstName = String.isNotBlank(emp.FirstName) ? emp.FirstName : emp.Name;
        Decimal remainingHours = expectedHours - actualHours;
        Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
        Date weekEnd = weekStart.addDays(4);
        String dateRange = weekStart.format() + ' - ' + weekEnd.format();
        String timesheetUrl = URL.getOrgDomainUrl().toExternalForm() + '/timesheet';
        
        String html = '<!DOCTYPE html>' +
        '<html>' +
        '<head>' +
        '  <meta charset="UTF-8">' +
        '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
        '</head>' +
        '<body style="margin:0; padding:0; background-color:#f4f6f9; font-family: Arial, sans-serif;">' +
        '  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f6f9; padding:40px 20px;">' +
        '    <tr>' +
        '      <td align="center">' +
        '        <table role="presentation" width="600" cellspacing="0" cellpadding="0" style="background-color:#ffffff; border-radius:12px; box-shadow:0 4px 6px rgba(0,0,0,0.1); overflow:hidden;">' +
        
        // Header
        '          <tr>' +
        '            <td style="background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); padding:30px; text-align:center;">' +
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                <tr>' +
        '                  <td align="center">' +
        '                    <div style="width:60px; height:60px; background-color:rgba(255,255,255,0.2); border-radius:50%; display:inline-block; line-height:60px;">' +
        '                      <span style="font-size:28px;">⏰</span>' +
        '                    </div>' +
        '                  </td>' +
        '                </tr>' +
        '                <tr>' +
        '                  <td align="center" style="padding-top:15px;">' +
        '                    <h1 style="color:#ffffff; margin:0; font-size:24px; font-weight:600;">Timesheet Reminder</h1>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        '            </td>' +
        '          </tr>' +
        
        // Body Content
        '          <tr>' +
        '            <td style="padding:40px 30px;">' +
        '              <p style="color:#333333; font-size:16px; margin:0 0 20px 0;">Dear ' + firstName + ',</p>' +
        '              <p style="color:#555555; font-size:15px; line-height:1.6; margin:0 0 25px 0;">' +
        '                This is a friendly reminder that your timesheet for this week is <strong>incomplete</strong>. ' +
        'After completing your hours, please <strong>submit it for approval</strong>.' +
        '              </p>' +
        
        // Warning Box
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:25px;">' +
        '                <tr>' +
        '                  <td style="background-color:#fff8e1; border-left:4px solid #ffc107; border-radius:4px; padding:15px 20px;">' +
        '                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                      <tr>' +
        '                        <td width="30" valign="top">' +
        '                          <span style="font-size:20px;">⚠️</span>' +
        '                        </td>' +
        '                        <td>' +
        '                          <p style="color:#856404; font-size:14px; font-weight:600; margin:0 0 5px 0;">Action Required</p>' +
        '                          <p style="color:#856404; font-size:13px; margin:0;">Please log your remaining hours to complete your timesheet.</p>' +
        '                        </td>' +
        '                      </tr>' +
        '                    </table>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        
        // Hours Summary Box
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f8f9fa; border-radius:8px; margin-bottom:25px;">' +
        '                <tr>' +
        '                  <td style="padding:20px;">' +
        '                    <p style="color:#333333; font-size:14px; font-weight:600; margin:0 0 15px 0;">📊 Hours Summary</p>' +
        '                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                      <tr>' +
        '                        <td style="padding:8px 0; border-bottom:1px solid #e0e0e0;">' +
        '                          <span style="color:#666666; font-size:14px;">Hours Logged</span>' +
        '                        </td>' +
        '                        <td align="right" style="padding:8px 0; border-bottom:1px solid #e0e0e0;">' +
        '                          <span style="color:#1a73e8; font-size:14px; font-weight:600;">' + actualHours + ' hrs</span>' +
        '                        </td>' +
        '                      </tr>' +
        '                      <tr>' +
        '                        <td style="padding:8px 0; border-bottom:1px solid #e0e0e0;">' +
        '                          <span style="color:#666666; font-size:14px;">Expected Hours</span>' +
        '                        </td>' +
        '                        <td align="right" style="padding:8px 0; border-bottom:1px solid #e0e0e0;">' +
        '                          <span style="color:#333333; font-size:14px; font-weight:600;">' + expectedHours + ' hrs</span>' +
        '                        </td>' +
        '                      </tr>' +
        '                      <tr>' +
        '                        <td style="padding:8px 0;">' +
        '                          <span style="color:#666666; font-size:14px;">Remaining Hours</span>' +
        '                        </td>' +
        '                        <td align="right" style="padding:8px 0;">' +
        '                          <span style="color:#d32f2f; font-size:14px; font-weight:600;">' + remainingHours + ' hrs</span>' +
        '                        </td>' +
        '                      </tr>' +
        '                    </table>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        
        // How to Complete Section
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:25px;">' +
        '                <tr>' +
        '                  <td>' +
        '                    <p style="color:#333333; font-size:14px; font-weight:600; margin:0 0 12px 0;">📝 How to Complete:</p>' +
        '                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                      <tr><td style="color:#555555; font-size:14px; padding:5px 0;">1. Login to the Timesheet Portal</td></tr>' +
        '                      <tr><td style="color:#555555; font-size:14px; padding:5px 0;">2. Navigate to <strong>My Timesheet</strong> tab</td></tr>' +
        '                      <tr><td style="color:#555555; font-size:14px; padding:5px 0;">3. Enter your hours for each day</td></tr>' +
        '                      <tr><td style="color:#555555; font-size:14px; padding:5px 0;">4. Click <strong>"Submit"</strong> to save</td></tr>' +
        '                    </table>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        
        // CTA Button
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="margin-bottom:25px;">' +
        '                <tr>' +
        '                  <td align="center">' +
        '                    <span style="display:inline-block; background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); color:#ffffff; text-decoration:none; padding:14px 40px; border-radius:25px; font-size:15px; font-weight:600;">Complete Timesheet Now</a>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        
        // Info Box
        '              <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                <tr>' +
        '                  <td style="background-color:#e3f2fd; border-radius:8px; padding:15px;">' +
        '                    <table role="presentation" width="100%" cellspacing="0" cellpadding="0">' +
        '                      <tr>' +
        '                        <td style="padding:4px 0;"><span style="color:#1565c0; font-size:13px;">📅 <strong>Week:</strong> ' + weekNumber + ' (' + dateRange + ')</span></td>' +
        '                      </tr>' +
        '                      <tr>' +
        '                        <td style="padding:4px 0;"><span style="color:#1565c0; font-size:13px;">⏰ <strong>Time:</strong> ' + Datetime.now().format('hh:mm a') + '</span></td>' +
        '                      </tr>' +
        '                      <tr>' +
        '                        <td style="padding:4px 0;"><span style="color:#1565c0; font-size:13px;">📧 This is an automated reminder</span></td>' +
        '                      </tr>' +
        '                    </table>' +
        '                  </td>' +
        '                </tr>' +
        '              </table>' +
        
        '            </td>' +
        '          </tr>' +
        
        // Footer
        '          <tr>' +
        '            <td style="background-color:#f8f9fa; padding:25px 30px; border-top:1px solid #e0e0e0;">' +
        '              <p style="color:#888888; font-size:12px; text-align:center; margin:0 0 10px 0;">If you have any questions, please contact HR.</p>' +
        '              <p style="color:#aaaaaa; font-size:11px; text-align:center; margin:0;">© ' + year + ' Your Company Name. All rights reserved.</p>' +
        '            </td>' +
        '          </tr>' +
        
        '        </table>' +
        '      </td>' +
        '    </tr>' +
        '  </table>' +
        '</body>' +
        '</html>';
        
        return html;
    }
    
    public static Decimal getUserActualHours(Id userId, Integer weekNumber, Integer year) {
        Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
        Date weekEnd = weekStart.addDays(4);
        Decimal hours = 0;
        
        for (TimesheetEntry__c entry : [
            SELECT Total_Hours__c
            FROM TimesheetEntry__c
            WHERE Timesheet__r.Employee__c = :userId
            AND Date__c >= :weekStart
            AND Date__c <= :weekEnd
        ]) {
            hours += (entry.Total_Hours__c != null ? entry.Total_Hours__c : 0);
        }
        return hours;
    }
   

//  Helper class for under-logged info
public class UnderLoggedInfo {
        public User employee;
        public Decimal actualHours;
        public Decimal expectedHours;
        public Decimal remainingHours;
        public UnderLoggedInfo(User emp, Decimal actualH, Decimal expectedH) {
            employee = emp;
            actualHours = actualH;
            expectedHours = expectedH;
            remainingHours = expectedH - actualH;
        }
    }

  public static void sendManagerAlerts() {

    Map<String, Integer> weekInfo = getLastWeekAndYear();
    Integer weekNumber = weekInfo.get('week');
    Integer year = weekInfo.get('year');

    List<User> employees = getActiveTimesheetUsers(true);
    if (employees.isEmpty()) return;

    Map<Id, Decimal> actualHoursMap =
        prepareActualHoursMap(employees, weekNumber, year);

    Set<Id> userIds = new Set<Id>();
    for (User u : employees) {
        userIds.add(u.Id);
    }

    Map<Id, Decimal> expectedHoursMap =
        getExpectedWeeklyHoursBulk(userIds, weekNumber, year);

    Map<Id, List<UnderLoggedInfo>> managerToTeam =
        new Map<Id, List<UnderLoggedInfo>>();

    for (User emp : employees) {

        Decimal actualHours = actualHoursMap.get(emp.Id);
        if (actualHours == null) actualHours = 0;

        Decimal expectedHours = expectedHoursMap.get(emp.Id);
        if (expectedHours == null) expectedHours = 40;

        if (actualHours < expectedHours) {

            if (!managerToTeam.containsKey(emp.ManagerId)) {
                managerToTeam.put(emp.ManagerId, new List<UnderLoggedInfo>());
            }

            managerToTeam.get(emp.ManagerId)
                .add(new UnderLoggedInfo(emp, actualHours, expectedHours));
        }
    }

    if (managerToTeam.isEmpty()) return;

    Map<Id, User> managers = new Map<Id, User>([
        SELECT Id, Email, Name, FirstName, LastName
        FROM User
        WHERE Id IN :managerToTeam.keySet()
    ]);

    List<Messaging.SingleEmailMessage> emails =
        new List<Messaging.SingleEmailMessage>();
	Id oweaId = getOrgWideEmailId();
    for (Id mgrId : managerToTeam.keySet()) {

        User mgr = managers.get(mgrId);
        if (mgr == null || !isValidEmail(mgr.Email)) continue;

        List<UnderLoggedInfo> teamList = managerToTeam.get(mgrId);
        if (teamList.isEmpty()) continue;

        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { mgr.Email });
        msg.setSubject('Weekly Timesheet Alert - Your Team');
        msg.setHtmlBody(
            buildManagerHtmlEmail(mgr, teamList, weekNumber, year)
        );
if (oweaId != null) {
    msg.setOrgWideEmailAddressId(oweaId);
}
        emails.add(msg);
    }

    if (!emails.isEmpty()) {
    if (!Test.isRunningTest()) {
        Messaging.sendEmail(emails);
    }
}
}
    // NEW: build manager email body
    private static String buildManagerHtmlEmail(
        User managerUser,
        List<UnderLoggedInfo> teamList,
        Integer weekNumber,
        Integer year
    ) {
        String mgrName = String.isNotBlank(managerUser.FirstName)
            ? managerUser.FirstName
            : managerUser.Name;

        Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
        Date weekEnd   = weekStart.addDays(4);
        String dateRange = weekStart.format() + ' - ' + weekEnd.format();

        String rows = '';
        for (UnderLoggedInfo info : teamList) {
            String empName = String.isNotBlank(info.employee.FirstName)
                ? info.employee.FirstName + ' ' + info.employee.LastName
                : info.employee.Name;

            rows +=
                '<tr>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;">' + empName + '</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right">' + info.actualHours + ' hrs</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right">' + info.expectedHours + ' hrs</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right"><strong style="color:#d32f2f;">' + info.remainingHours + ' hrs</strong></td>' +
                '</tr>';
        }

        String html =
            '<html><body style="font-family: Arial, sans-serif; background-color:#f4f6f9; padding:20px;">' +
            '  <table width="100%" cellpadding="0" cellspacing="0" style="max-width:600px; margin:0 auto; background:#ffffff; border-radius:8px; overflow:hidden;">' +
            '    <tr><td style="background:#0d47a1; color:#fff; padding:20px; font-size:18px;">' +
            '      Timesheet Alert - Team Summary' +
            '    </td></tr>' +
            '    <tr><td style="padding:20px;">' +
            '      <p>Dear ' + mgrName + ',</p>' +
            '      <p>The following team members have <strong>incomplete timesheets</strong> for Week ' + weekNumber + ' (' + dateRange + ').</p>' +
            '      <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse; margin-top:15px; font-size:14px;">' +
            '        <tr style="background:#f1f3f4;">' +
            '          <th align="left" style="padding:8px;">Employee</th>' +
            '          <th align="right" style="padding:8px;">Logged</th>' +
            '          <th align="right" style="padding:8px;">Expected</th>' +
            '          <th align="right" style="padding:8px;">Remaining</th>' +
            '        </tr>' +
                     rows +
            '      </table>' +
            '      <p style="margin-top:20px; font-size:13px; color:#555;">' +
            '        Please follow up with your team to ensure timesheets are completed and submitted.' +
            '      </p>' +
            '    </td></tr>' +
            '  </table>' +
            '</body></html>';

        return html;
    }
// ----------------------------------------------------------------------
    // 3) PUBLIC METHOD: Send HR summary for ALL under-logged employees
    // ----------------------------------------------------------------------
public static void sendHrAlerts() {

    Map<String, Integer> weekInfo = getLastWeekAndYear();
    Integer weekNumber = weekInfo.get('week');
    Integer year = weekInfo.get('year');

    List<User> employees = getActiveTimesheetUsers(false);
    if (employees.isEmpty()) return;

    Map<Id, Decimal> actualHoursMap =
        prepareActualHoursMap(employees, weekNumber, year);

    Set<Id> userIds = new Set<Id>();
    for (User u : employees) {
        userIds.add(u.Id);
    }

    Map<Id, Decimal> expectedHoursMap =
        getExpectedWeeklyHoursBulk(userIds, weekNumber, year);

    List<UnderLoggedInfo> underLoggedList =
        new List<UnderLoggedInfo>();

    for (User emp : employees) {

        Decimal actualHours = actualHoursMap.get(emp.Id);
        if (actualHours == null) actualHours = 0;

        Decimal expectedHours = expectedHoursMap.get(emp.Id);
        if (expectedHours == null) expectedHours = 40;

        if (actualHours < expectedHours) {
            underLoggedList.add(
                new UnderLoggedInfo(emp, actualHours, expectedHours)
            );
        }
    }

    if (underLoggedList.isEmpty()) return;
// ✅ FIXED HR EMAIL LOGIC
    String hrEmail;
    if (Test.isRunningTest()) {
        hrEmail = 'hr@test.com';
    } else {
        hrEmail = AppSettings.getHrEmail();
    }

if (!isValidEmail(hrEmail)) {
    System.debug('❌ Invalid HR email, skipping send');
    return;
}
   /* if (String.isBlank(hrEmail) || !hrEmail.contains('@')) {
        System.debug('❌ Invalid HR email, skipping send');
        return;
    }*/
    Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
    msg.setToAddresses(new String[] { hrEmail });
    msg.setSubject('Weekly Timesheet Alert - All Employees');
    msg.setHtmlBody(
        buildHrHtmlEmail(underLoggedList, weekNumber, year)
    );
 Id oweaId = getOrgWideEmailId();
    if (oweaId != null) {
        msg.setOrgWideEmailAddressId(oweaId);
    }
    if (!Test.isRunningTest()) {
    Messaging.sendEmail(new List<Messaging.SingleEmailMessage>{ msg });
}

        System.debug('HR summary email sent to: ' + hrEmail);
    }

    // ----------------------------------------------------------------------
    // 4) PRIVATE METHOD: Build HR HTML email body
    // ----------------------------------------------------------------------
    private static String buildHrHtmlEmail(
        List<UnderLoggedInfo> underLoggedList,
        Integer weekNumber,
        Integer year
    ) {
        Date weekStart = TimesheetController.getWeekStartDate(weekNumber, year);
        Date weekEnd   = weekStart.addDays(4);
        String dateRange = weekStart.format() + ' - ' + weekEnd.format();

        String rows = '';
        for (UnderLoggedInfo info : underLoggedList) {
            String empName;
            if (String.isNotBlank(info.employee.FirstName)) {
                if (String.isNotBlank(info.employee.LastName)) {
                    empName = info.employee.FirstName + ' ' + info.employee.LastName;
                } else {
                    empName = info.employee.FirstName;
                }
            } else {
                empName = info.employee.Name;
            }

            rows +=
                '<tr>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;">' + empName + '</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;">' + info.employee.Email + '</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right">' + info.actualHours + ' hrs</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right">' + info.expectedHours + ' hrs</td>' +
                '  <td style="padding:8px; border-bottom:1px solid #eee;" align="right"><strong style="color:#d32f2f;">' + info.remainingHours + ' hrs</strong></td>' +
                '</tr>';
        }

        String html =
            '<!DOCTYPE html>' +
            '<html>' +
            '<head>' +
            '  <meta charset="UTF-8">' +
            '  <meta name="viewport" content="width=device-width, initial-scale=1.0">' +
            '</head>' +
            '<body style="margin:0; padding:0; background-color:#f4f6f9; font-family: Arial, sans-serif;">' +
            '  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background-color:#f4f6f9; padding:40px 20px;">' +
            '    <tr>' +
            '      <td align="center">' +
            '        <table role="presentation" width="800" cellspacing="0" cellpadding="0" style="background-color:#ffffff; border-radius:12px; box-shadow:0 4px 6px rgba(0,0,0,0.1); overflow:hidden;">' +
            '          <tr>' +
            '            <td style="background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); padding:24px; text-align:left; color:#ffffff;">' +
            '              <h2 style="margin:0; font-size:20px;">Weekly Timesheet Alert - All Employees</h2>' +
            '              <p style="margin:4px 0 0 0; font-size:13px;">Week ' + weekNumber + ' (' + dateRange + ')</p>' +
            '            </td>' +
            '          </tr>' +
            '          <tr>' +
            '            <td style="padding:24px 24px 30px 24px;">' +
            '              <p style="color:#333333; font-size:14px; margin:0 0 16px 0;">Dear HR Team,</p>' +
            '              <p style="color:#555555; font-size:13px; line-height:1.5; margin:0 0 20px 0;">' +
            '                The following employees have <strong>incomplete timesheets</strong> for this week. Please review and follow up as required.' +
            '              </p>' +
            '              <table width="100%" cellpadding="0" cellspacing="0" style="border-collapse:collapse; font-size:12px; margin-top:4px;">' +
            '                <tr style="background-color:#f1f3f4;">' +
            '                  <th align="left"  style="padding:8px;">Employee</th>' +
            '                  <th align="left"  style="padding:8px;">Email</th>' +
            '                  <th align="right" style="padding:8px;">Logged</th>' +
            '                  <th align="right" style="padding:8px;">Expected</th>' +
            '                  <th align="right" style="padding:8px;">Remaining</th>' +
            '                </tr>' +
                             rows +
            '              </table>' +
            '              <p style="color:#999999; font-size:11px; margin-top:20px;">' +
            '                This is an automated summary generated by the Timesheet system.' +
            '              </p>' +
            '            </td>' +
            '          </tr>' +
            '        </table>' +
            '      </td>' +
            '    </tr>' +
            '  </table>' +
            '</body>' +
            '</html>';

        return html;
    }
}