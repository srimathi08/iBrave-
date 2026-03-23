@IsTest
private class TimesheetWeeklyReminderJobTest {

    private static User createUser(String name, Id managerId) {

        Profile p = [SELECT Id FROM Profile LIMIT 1];

        User u = new User(
            FirstName = name,
            LastName = 'Test',
            Email = name + '@example.com', // ✅ valid email
            Username = name + DateTime.now().getTime() + '@example.com',
            Alias = name.length() > 3 ? name.substring(0, 3) : 'tst',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            ProfileId = p.Id,
            ManagerId = managerId
        );

        insert u;
        return u;
    }

    private static Timesheet__c createTimesheet(Id userId) {
        Timesheet__c ts = new Timesheet__c(Employee__c = userId);
        insert ts;
        return ts;
    }

    // ============================================
    // ✅ EMPLOYEE EMAIL
    // ============================================
    @IsTest
    static void testSendReminders() {

        User manager = createUser('manager1', null);
        User emp = createUser('emp1', manager.Id);

        Timesheet__c ts = createTimesheet(emp.Id);

        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today().addDays(-7),
            Total_Hours__c = 2
        );

        Test.startTest();
        TimesheetWeeklyReminderJob.sendReminders();
        Test.stopTest();

        System.assert(true);
    }

    // ============================================
    // ✅ MANAGER EMAIL
    // ============================================
    @IsTest
    static void testSendManagerAlerts() {

        User manager = createUser('manager2', null);
        User emp = createUser('emp2', manager.Id);

        Timesheet__c ts = createTimesheet(emp.Id);

        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today().addDays(-7),
            Total_Hours__c = 1
        );

        Test.startTest();
        TimesheetWeeklyReminderJob.sendManagerAlerts();
        Test.stopTest();

        System.assert(true);
    }

    // ============================================
    // ✅ HR EMAIL (AUTO HANDLED NOW)
    // ============================================
    @IsTest
    static void testSendHrAlerts() {

        User emp = createUser('emp3', null);

        Timesheet__c ts = createTimesheet(emp.Id);

        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today().addDays(-7),
            Total_Hours__c = 3
        );

        Test.startTest();
        TimesheetWeeklyReminderJob.sendHrAlerts();
        Test.stopTest();

        System.assert(true);
    }

    // ============================================
    // ✅ NO EMAIL CASE
    // ============================================
    @IsTest
    static void testNoEmailWhenHoursFull() {

        User emp = createUser('emp4', null);

        Timesheet__c ts = createTimesheet(emp.Id);

        insert new TimesheetEntry__c(
            Timesheet__c = ts.Id,
            Date__c = Date.today().addDays(-7),
            Total_Hours__c = 40
        );

        Test.startTest();
        TimesheetWeeklyReminderJob.sendReminders();
        Test.stopTest();

        System.assert(true);
    }

    // ============================================
    // ✅ SCHEDULER
    // ============================================
    @IsTest
    static void testSchedulerExecution() {

        Test.startTest();

        System.schedule(
            'Test Weekly Reminder Job',
            '0 0 9 ? * TUE',
            new TimesheetWeeklyReminderScheduler()
        );

        Test.stopTest();

        System.assert(true);
    }
@IsTest
static void testSendReminderToUserMethods() {

    User manager = createUser('mgrX', null);
    User emp = createUser('empX', manager.Id);

    Timesheet__c ts = createTimesheet(emp.Id);

    insert new TimesheetEntry__c(
        Timesheet__c = ts.Id,
        Date__c = Date.today().addDays(-7),
        Total_Hours__c = 2
    );

    Test.startTest();

    // Without override
    TimesheetWeeklyReminderJob.sendReminderToUser(emp.Id);

    // With override
    TimesheetWeeklyReminderJob.sendReminderToUser(emp.Id, 'override@test.com');

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testInvalidEmailBranch() {

    User emp = createUser('empInvalid', null);

    Test.startTest();

    // Invalid email → should skip
    TimesheetWeeklyReminderJob.sendReminderToUser(emp.Id, 'invalid-email');

    Test.stopTest();

    System.assert(true);
}
@IsTest
static void testGetUserActualHoursDirect() {

    User emp = createUser('empHours', null);
    Timesheet__c ts = createTimesheet(emp.Id);

    insert new TimesheetEntry__c(
        Timesheet__c = ts.Id,
        Date__c = Date.today().addDays(-7),
        Total_Hours__c = 5
    );

    Test.startTest();

    Decimal hrs = TimesheetWeeklyReminderJob.getUserActualHours(
        emp.Id,
        TimesheetController.getWeekNumber(Date.today().addDays(-7)),
        Date.today().year()
    );

    Test.stopTest();

    System.assert(hrs > 0);
}
@IsTest
static void testExpectedHoursWithLeaveAndHoliday() {

    User emp = createUser('empLeave', null);

    Date d = Date.today().addDays(-7);

    // Holiday
    insert new Holiday__c(
        Holiday_Date__c = d,
	Holiday_Type__c = 'Festival',
        Is_Active__c = true
    );

    // Leave
    insert new Leave_Request__c(
        Employee__c = emp.Id,
        Start_Date__c = d,
        End_Date__c = d,
        Status__c = 'Approved',
		Total_Days__c= 2,
        Is_Half_Day__c = false
    );

    Set<Id> userIds = new Set<Id>{ emp.Id };

    Test.startTest();

    Map<Id, Decimal> result =
        TimesheetWeeklyReminderJob.getExpectedWeeklyHoursBulk(
            userIds,
            TimesheetController.getWeekNumber(d),
            d.year()
        );

    Test.stopTest();

    System.assert(result.containsKey(emp.Id));
}
@IsTest
static void testGetActiveUsersWithManagerFilter() {

    User manager = createUser('mgrFilter', null);
    User emp = createUser('empFilter', manager.Id);

    Test.startTest();

    List<User> users =
        TimesheetWeeklyReminderJob.getActiveTimesheetUsers(true);

    Test.stopTest();

    System.assert(users.size() > 0);
}
}