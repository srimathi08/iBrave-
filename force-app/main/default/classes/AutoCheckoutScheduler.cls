/**
 * @description Scheduled Apex - Triggers auto checkout every night at 11:59 PM
 * 
 * TO ACTIVATE, run in Developer Console → Execute Anonymous:
 *   System.schedule('HRMS Auto Checkout', '0 59 23 * * ?', new AutoCheckoutScheduler());
 */
global class AutoCheckoutScheduler implements Schedulable {
    global void execute(SchedulableContext sc) {
        System.debug('=== AUTO CHECKOUT SCHEDULER TRIGGERED: ' + DateTime.now() + ' ===');
        Database.executeBatch(new AutoCheckoutBatch(), 200);
    }
}