global class TimesheetWeeklyReminderScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        TimesheetWeeklyReminderJob.sendReminders();
    }
}