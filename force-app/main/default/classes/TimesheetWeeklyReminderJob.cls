/*public class TimesheetWeeklyReminderJob {

    public static void sendReminders() {

        Integer weekNumber = TimesheetController.getWeekNumber(Date.today());
		Integer year = Date.today().year();
        

        List<User> employees = [
            SELECT Id, Email, Name
            FROM User
            WHERE IsActive = true
            AND Profile.Name LIKE '%Community%'    // adjust with your profile names
        ];

        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();

        for (User emp : employees) {

            Decimal expectedHours = TimesheetController.getExpectedWeeklyHours(emp.Id, weekNumber, year);
            Decimal actualHours   = getUserActualHours(emp.Id, weekNumber, year);

            if (actualHours < expectedHours) {

                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new String[] { emp.Email });
                msg.setSubject('Weekly Timesheet Reminder');
                msg.setPlainTextBody(
                    'Hi ' + emp.Name + ',\n\n' +
                    'You have logged ' + actualHours + ' of ' + expectedHours + ' required hours this week.\n' +
                    'Please complete your timesheet.\n\nThank you.'
                );

                emails.add(msg);
            }
        }

        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
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
}*/
public class TimesheetWeeklyReminderJob {
    
    // Original method - sends to all employees
    public static void sendReminders() {
        Integer weekNumber = TimesheetController.getWeekNumber(Date.today());
        Integer year = Date.today().year();
        
        List<User> employees = [
            SELECT Id, Email, Name, FirstName
            FROM User
            WHERE IsActive = true
            AND Profile.Name LIKE '%Community%'
        ];
        
        List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
        
        for (User emp : employees) {
            Decimal expectedHours = TimesheetController.getExpectedWeeklyHours(emp.Id, weekNumber, year);
            Decimal actualHours = getUserActualHours(emp.Id, weekNumber, year);
            
            if (actualHours < expectedHours) {
                Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
                msg.setToAddresses(new String[] { emp.Email });
                msg.setSubject('Weekly Timesheet Reminder - Action Required');
                msg.setHtmlBody(buildHtmlEmail(emp, actualHours, expectedHours, weekNumber, year));
                emails.add(msg);
            }
        }
        
        if (!emails.isEmpty()) {
            Messaging.sendEmail(emails);
        }
    }
    
    // NEW: Send reminder to a single user by Id
    public static void sendReminderToUser(Id userId) {
        sendReminderToUser(userId, null);
    }
    
    // NEW: Send reminder to a single user with optional email override
    public static void sendReminderToUser(Id userId, String overrideEmail) {
        Integer weekNumber = TimesheetController.getWeekNumber(Date.today());
        Integer year = Date.today().year();
        
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
        
        Messaging.SingleEmailMessage msg = new Messaging.SingleEmailMessage();
        msg.setToAddresses(new String[] { targetEmail });
        msg.setSubject('Weekly Timesheet Reminder - Action Required');
        msg.setHtmlBody(buildHtmlEmail(emp, actualHours, expectedHours, weekNumber, year));
        
        Messaging.sendEmail(new List<Messaging.SingleEmailMessage> { msg });
        
        System.debug('✅ Email sent successfully to: ' + targetEmail);
        System.debug('📊 Hours - Actual: ' + actualHours + ', Expected: ' + expectedHours);
    }
    
    // NEW: Preview HTML without sending (for debugging)
    public static String previewEmailHtml(Id userId) {
        Integer weekNumber = TimesheetController.getWeekNumber(Date.today());
        Integer year = Date.today().year();
        
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
        '                    <a href="' + timesheetUrl + '" style="display:inline-block; background: linear-gradient(135deg, #1a73e8 0%, #0d47a1 100%); color:#ffffff; text-decoration:none; padding:14px 40px; border-radius:25px; font-size:15px; font-weight:600;">Complete Timesheet Now</a>' +
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
}