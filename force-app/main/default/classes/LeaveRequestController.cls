public without sharing class LeaveRequestController {
    
    /**
     * Get Manager Information
     */
    @AuraEnabled
    public static Map<String, String> getManagerInfo(Id employeeId) {
        try {
            User emp = [
                SELECT Id, ManagerId, Manager.Name, Manager.Email
                FROM User 
                WHERE Id = :employeeId 
                LIMIT 1
            ];
            
            Map<String, String> result = new Map<String, String>();
            
            if (emp.ManagerId != null) {
                result.put('managerId', emp.ManagerId);
                result.put('managerName', emp.Manager.Name);
                result.put('managerEmail', emp.Manager.Email);
            } else {
                result.put('managerId', '');
                result.put('managerName', 'No Manager Assigned');
                result.put('managerEmail', '');
            }
            
            return result;
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Validate if employee is eligible for the leave type
     */
    @AuraEnabled
    public static Map<String, Object> validateLeaveEligibility(Id employeeId, Id leaveTypeId, Decimal requestedDays) {
        try {
            String year = String.valueOf(Date.today().year());
            
            Map<String, Object> result = new Map<String, Object>();
            result.put('isEligible', false);
            result.put('message', '');
            
            // Get balance
            List<Employee_Leave_Balance__c> balances = [
                SELECT Id, Is_Eligible__c, Eligibility_Reason__c, Available__c,
                       Leave_Type__r.Leave_Type_Name__c,
                       Leave_Type__r.Max_Lifetime_Occurrences__c,
                       Lifetime_Usage_Count__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :employeeId
                AND Leave_Type__c = :leaveTypeId
                AND Year__c = :year
                LIMIT 1
            ];
            
            if (balances.isEmpty()) {
                result.put('message', 'You are not eligible for this leave type. Please contact HR.');
                return result;
            }
            
            Employee_Leave_Balance__c balance = balances[0];
            
            if (!balance.Is_Eligible__c) {
                result.put('message', balance.Eligibility_Reason__c);
                return result;
            }
            
            // Check lifetime occurrence limit (Maternity/Paternity)
            if (balance.Leave_Type__r.Max_Lifetime_Occurrences__c != null && 
                balance.Lifetime_Usage_Count__c >= balance.Leave_Type__r.Max_Lifetime_Occurrences__c) {
                result.put('message', 'Maximum lifetime usage reached for ' + balance.Leave_Type__r.Leave_Type_Name__c);
                return result;
            }
            
            if (balance.Available__c < requestedDays) {
                result.put('message', 'Insufficient balance. Available: ' + balance.Available__c + ' days');
                return result;
            }
            
            result.put('isEligible', true);
            result.put('message', 'Eligible');
            result.put('availableBalance', balance.Available__c);
            
            return result;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    
    /**
 * Check if employee already has leave request for the selected dates
 * @param employeeId Employee ID
 * @param startDate Requested start date
 * @param endDate Requested end date
 * @return Map with validation result and overlapping leave details
 */

@AuraEnabled
public static Map<String, Object> checkOverlappingLeave(Id employeeId, Date startDate, Date endDate) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        System.debug('=== CHECKING OVERLAPPING LEAVE ===');
        System.debug('Employee: ' + employeeId);
        System.debug('Start Date: ' + startDate);
        System.debug('End Date: ' + endDate);
        
        // Query for any existing leave requests that overlap with the requested dates
        List<Leave_Request__c> overlappingLeaves = [
            SELECT Id, Name, 
                   Leave_Type__r.Leave_Type_Name__c,
            Leave_Type__r.Leave_Code__c,
                   Start_Date__c, 
                   End_Date__c, 
                   Total_Days__c,
                   Status__c
            FROM Leave_Request__c
            WHERE Employee__c = :employeeId
            AND Is_Active__c = true
            AND Status__c IN ('Pending', 'Approved')
            AND (
                (Start_Date__c <= :endDate AND End_Date__c >= :startDate)
            )
            ORDER BY Start_Date__c ASC
            LIMIT 10
        ];
        
        if (overlappingLeaves.isEmpty()) {
        result.put('hasOverlap', false);
        result.put('conflictCount', 0);
        result.put('conflictingLeaves', new List<Object>());
    } else {
        List<Map<String, String>> conflicts = new List<Map<String, String>>();
        
        for (Leave_Request__c leave : overlappingLeaves) {
            Map<String, String> conflict = new Map<String, String>();
            conflict.put('leaveRequestName', leave.Name);
            conflict.put('leaveType', leave.Leave_Type__r.Leave_Type_Name__c);
            conflict.put('leaveCode', leave.Leave_Type__r.Leave_Code__c);
            conflict.put('startDate', String.valueOf(leave.Start_Date__c));
            conflict.put('endDate', String.valueOf(leave.End_Date__c));
            conflict.put('totalDays', String.valueOf(leave.Total_Days__c));
            conflict.put('status', leave.Status__c);
            conflicts.add(conflict);
        }
        
        result.put('hasOverlap', true);
        result.put('conflictCount', overlappingLeaves.size());
        result.put('conflictingLeaves', conflicts);
    }
    
    return result;
        
    } catch (Exception e) {
        System.debug('❌ Error checking overlapping leave: ' + e.getMessage());
        result.put('hasOverlap', false);
        result.put('error', e.getMessage());
        return result;
    }
}
    
    
    
    /**
     * Submit Leave Request with Email Notification
     */
    @AuraEnabled
    public static String submitLeaveRequest(Leave_Request__c leaveRequest) {
        try {
            // Validate
            if (leaveRequest.Employee__c == null) {
                throw new AuraHandledException('Employee is required');
            }
            
            // Get employee and manager info
            User emp = [
                SELECT Id, Name, Email, ManagerId, Manager.Name, Manager.Email
                FROM User 
                WHERE Id = :leaveRequest.Employee__c 
                LIMIT 1
            ];
            
            if (emp.ManagerId == null) {
                throw new AuraHandledException('You do not have a manager assigned. Please contact HR.');
            }
            
            // Validate eligibility
            Map<String, Object> validation = validateLeaveEligibility(
                leaveRequest.Employee__c, 
                leaveRequest.Leave_Type__c, 
                leaveRequest.Total_Days__c
            );
            
            if (!(Boolean)validation.get('isEligible')) {
                throw new AuraHandledException((String)validation.get('message'));
            }
            
            // Set fields
            leaveRequest.Manager__c = emp.ManagerId;
            leaveRequest.Applied_Date__c = System.now();
            leaveRequest.Status__c = 'Pending';
            leaveRequest.Is_Active__c = true;
            leaveRequest.Year__c = String.valueOf(leaveRequest.Start_Date__c.year());
            
            // Insert
            insert leaveRequest;
            
            // Update balance to Pending
            updateLeaveBalance(leaveRequest.Id, 'Pending', null);
            
            // Send email to manager
            sendEmailToManager(leaveRequest, emp);
            
            return leaveRequest.Id;
            
        } catch (Exception e) {
            System.debug('Error in submitLeaveRequest: ' + e.getMessage());
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
     * Send Email Notification to Manager
     */
    private static void sendEmailToManager(Leave_Request__c request, User employee) {
        try {
            Leave_Type__c leaveType = [
                SELECT Leave_Type_Name__c 
                FROM Leave_Type__c 
                WHERE Id = :request.Leave_Type__c 
                LIMIT 1
            ];
            
            // Get base URL and build approval page URL
            //String baseUrl = System.URL.getOrgDomainUrl().toExternalForm();
         //String baseUrl = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/LeaveApproval';
            String baseUrl = ' https://innovation-dream-9744.my.salesforce-sites.com/LeaveApproval';
           
           // String approvalUrl = baseUrl + '/lightning/r/Leave_Request__c/' + request.Id + '/view';
           //         // ✅ Build Visualforce Approval Page URL
        //String baseUrl = URL.getSalesforceBaseUrl().toExternalForm();
        String approvalUrl = baseUrl + '/apex/LeaveApprovalPage' +'?id=' + request.Id +'&mgr=' + employee.ManagerId;
            
             
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { employee.Manager.Email });
            mail.setSubject('Leave Request from ' + employee.Name);
             // mail.setOrgWideEmailAddressId('0D2fs00000001tl');
	OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
mail.setOrgWideEmailAddressId(owea.Id);
            
            String body = '<html><body style="font-family: Arial, sans-serif;">';
            body += '<h2 style="color: #0176d3;">New Leave Request Pending Approval</h2>';
            body += '<p>Dear ' + employee.Manager.Name + ',</p>';
            body += '<p>' + employee.Name + ' has requested leave. Please review and approve/reject:</p>';
            body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse; width: 100%; max-width: 600px;">';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Employee</strong></td><td>' + employee.Name + '</td></tr>';
            body += '<tr><td><strong>Email</strong></td><td>' + employee.Email + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>Leave Type</strong></td><td>' + leaveType.Leave_Type_Name__c + '</td></tr>';
            body += '<tr><td><strong>Start Date</strong></td><td>' + request.Start_Date__c.format() + '</td></tr>';
            body += '<tr style="background-color: #f3f3f3;"><td><strong>End Date</strong></td><td>' + request.End_Date__c.format() + '</td></tr>';
            body += '<tr><td><strong>Total Days</strong></td><td>' + request.Total_Days__c + '</td></tr>';
            
            if (request.Is_Half_Day__c) {
                body += '<tr style="background-color: #f3f3f3;"><td><strong>Half Day Type</strong></td><td>' + request.Half_Day_Type__c + '</td></tr>';
            }
            
            body += '<tr><td><strong>Reason</strong></td><td>' + request.Reason__c + '</td></tr>';
            body += '<tr style="background-color: #fff3cd;"><td><strong>Status</strong></td><td><span style="color: #f57c00; font-weight: bold;">Pending Approval</span></td></tr>';
            body += '</table>';
            body += '<br/>';
            body += '<div style="text-align: center; margin: 30px 0;">';
            body += '<a href="' + approvalUrl + '" style="background-color: #0176d3; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">Click here to review</a>';
            body += '</div>';
            body += '<p style="color: #666; font-size: 12px;">Click the button above to view the leave request.</p>';
            body += '<p>Thank you,<br/><strong>HR Management System</strong></p>';
            body += '</body></html>';
            
            mail.setHtmlBody(body);
            
           // Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
             Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Error sending email: ' + e.getMessage());
        }
    }
    
    /**
     * Update Leave Balance based on status change
     */
    public static void updateLeaveBalance(Id requestId, String newStatus, String oldStatus) {
        try {
            Leave_Request__c request = [
                SELECT Id, Employee__c, Leave_Type__c, Start_Date__c, Total_Days__c,
                       Leave_Type__r.Max_Lifetime_Occurrences__c,
                       Is_Event_Based_Leave__c
                FROM Leave_Request__c
                WHERE Id = :requestId
                LIMIT 1
            ];
            
            String year = String.valueOf(request.Start_Date__c.year());
            
            Employee_Leave_Balance__c balance = [
                SELECT Id, Pending_Approval__c, Booked__c, Used__c, Lifetime_Usage_Count__c
                FROM Employee_Leave_Balance__c
                WHERE Employee__c = :request.Employee__c
                AND Leave_Type__c = :request.Leave_Type__c
                AND Year__c = :year
                LIMIT 1
            ];
            
            Decimal days = request.Total_Days__c;
            Decimal currentPending = balance.Pending_Approval__c ?? 0;
        Decimal currentBooked  = balance.Booked__c ?? 0;
        Decimal currentUsed    = balance.Used__c ?? 0;
            // Handle status transitions
           /* if (newStatus == 'Pending') {
                // Add to pending
                balance.Pending_Approval__c = (balance.Pending_Approval__c != null ? balance.Pending_Approval__c : 0) + days;
            }
            else if (newStatus == 'Approved' && oldStatus == 'Pending') {
                // Move from Pending to Booked
                balance.Pending_Approval__c = (balance.Pending_Approval__c != null ? balance.Pending_Approval__c : 0) - days;
                balance.Booked__c = (balance.Booked__c != null ? balance.Booked__c : 0) + days;
                
                // Increment lifetime usage count for event-based leaves (Maternity/Paternity)
                if (request.Leave_Type__r.Max_Lifetime_Occurrences__c != null) {
                    balance.Lifetime_Usage_Count__c = (balance.Lifetime_Usage_Count__c != null ? balance.Lifetime_Usage_Count__c : 0) + 1;
                }
            }
            else if (newStatus == 'Rejected' && oldStatus == 'Pending') {
                // Remove from Pending
                balance.Pending_Approval__c = (balance.Pending_Approval__c != null ? balance.Pending_Approval__c : 0) - days;
            }
            else if (newStatus == 'Cancelled' && oldStatus == 'Pending') {
                // Remove from Pending
                balance.Pending_Approval__c = (balance.Pending_Approval__c != null ? balance.Pending_Approval__c : 0) - days;
            }
            else if (newStatus == 'Cancelled' && oldStatus == 'Approved') {
                // Remove from Booked
                balance.Booked__c = (balance.Booked__c != null ? balance.Booked__c : 0) - days;
            }
            else if (newStatus == 'Completed' && oldStatus == 'Approved') {
                // Move from Booked to Used
                balance.Booked__c = (balance.Booked__c != null ? balance.Booked__c : 0) - days;
                balance.Used__c = (balance.Used__c != null ? balance.Used__c : 0) + days;
            } */
			// Handle status transitions
        if (newStatus == 'Pending') {
            // Add to Pending
            balance.Pending_Approval__c = currentPending + days;
        }
        else if (newStatus == 'Approved' && oldStatus == 'Pending') {
            // Move from Pending → Booked
            balance.Pending_Approval__c = Math.max(0, currentPending - days);
            balance.Booked__c           = currentBooked + days;
            
            // Increment lifetime usage for Maternity/Paternity
            if (request.Leave_Type__r.Max_Lifetime_Occurrences__c != null) {
                balance.Lifetime_Usage_Count__c = (balance.Lifetime_Usage_Count__c ?? 0) + 1;
            }
        }
        else if (newStatus == 'Rejected' && oldStatus == 'Pending') {
            // Remove from Pending only — Available increases automatically
            balance.Pending_Approval__c = Math.max(0, currentPending - days);
        }
        else if (newStatus == 'Cancelled' && oldStatus == 'Pending') {
            // ✅ Remove from Pending only — NEVER touch Used
            // Available = Total - Used - Booked - Pending
            // Reducing Pending automatically increases Available
            balance.Pending_Approval__c = Math.max(0, currentPending - days);
        }
        else if (newStatus == 'Cancelled' && oldStatus == 'Approved') {
            // ✅ Remove from Booked only — NEVER touch Used
            balance.Booked__c = Math.max(0, currentBooked - days);
        }
        else if (newStatus == 'Completed' && oldStatus == 'Approved') {
            // Move from Booked → Used (actual leave taken)
            balance.Booked__c = Math.max(0, currentBooked - days);
            balance.Used__c   = currentUsed + days;
        }
            
            update balance;
            
        } catch (Exception e) {
            System.debug('Error updating balance: ' + e.getMessage());
        }
    }
    
    /**
     * Get All Leave Requests
     */
    @AuraEnabled
    public static List<Leave_Request__c> getPastLeaveRequests(Id employeeId) {
        try {
            return [
                SELECT Id, Name,
                       Leave_Type__c, Leave_Type__r.Leave_Type_Name__c, Leave_Type__r.Leave_Code__c,
                       Start_Date__c, End_Date__c, Total_Days__c,
                       Is_Half_Day__c, Half_Day_Type__c,
                       Reason__c, Status__c,
                       Manager__r.Name, Manager_Comments__c,
                       Applied_Date__c,
                       Approved_Date__c, Approved_By__c, Approved_By__r.Name,
                       Rejected_Date__c, Rejection_Reason__c,
                       Cancelled_Date__c, Cancelled_Reason__c
                FROM Leave_Request__c
                WHERE Employee__c = :employeeId
                AND Is_Active__c = true
                ORDER BY Applied_Date__c DESC
                LIMIT 200
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error: ' + e.getMessage());
        }
    }
    
    /**
 * Admin/Manager can cancel leave request to enable attendance check-in
 * @param leaveRequestId Leave Request ID to cancel
 * @param cancelledBy User ID who is cancelling (Admin/Manager)
 * @param cancellationReason Reason for cancellation
 * @return Success message or error
 */
@AuraEnabled
public static Map<String, Object> cancelLeaveRequest(Id leaveRequestId, Id cancelledBy, String cancellationReason) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        System.debug('=== ADMIN CANCELLING LEAVE REQUEST ===');
        System.debug('Leave Request ID: ' + leaveRequestId);
        System.debug('Cancelled By: ' + cancelledBy);
        System.debug('Reason: ' + cancellationReason);
        
        // Get leave request details
        Leave_Request__c leaveRequest = [
            SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Email,
                   Leave_Type__c, Leave_Type__r.Leave_Type_Name__c,
                   Start_Date__c, End_Date__c, Total_Days__c,
                   Status__c, Manager__c, Manager__r.Name,
                   Reason__c, Applied_Date__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            LIMIT 1
        ];
        
        // Validate current status
        if (leaveRequest.Status__c == 'Cancelled') {
            result.put('success', false);
            result.put('message', 'Leave request is already cancelled');
            return result;
        }
        
        if (leaveRequest.Status__c == 'Completed') {
            result.put('success', false);
            result.put('message', 'Cannot cancel completed leave request');
            return result;
        }
        
        if (leaveRequest.Status__c == 'Rejected') {
            result.put('success', false);
            result.put('message', 'Cannot cancel rejected leave request');
            return result;
        }
        
        String oldStatus = leaveRequest.Status__c;
        
        // Update leave request to Cancelled
        leaveRequest.Status__c = 'Cancelled';
        leaveRequest.Cancelled_Date__c = System.now();
        leaveRequest.Cancelled_By__c = cancelledBy;
        leaveRequest.Cancelled_Reason__c = String.isNotBlank(cancellationReason) 
            ? cancellationReason 
            : 'Cancelled by Admin';
        
        update leaveRequest;
        
        // Update leave balance (remove from Pending or Booked)
        updateLeaveBalance(leaveRequestId, 'Cancelled', oldStatus);
        
        // Send notification to employee
        sendCancellationEmailToEmployee(leaveRequest, cancelledBy);
        
        result.put('success', true);
        result.put('message', 'Leave request cancelled successfully. Employee can now check-in for attendance.');
        result.put('leaveRequestName', leaveRequest.Name);
        result.put('employeeName', leaveRequest.Employee__r.Name);
        result.put('leaveType', leaveRequest.Leave_Type__r.Leave_Type_Name__c);
        
        System.debug('✅ Leave request cancelled successfully');
        
    } catch (Exception e) {
        System.debug('❌ Error cancelling leave request: ' + e.getMessage());
        System.debug('Stack trace: ' + e.getStackTraceString());
        result.put('success', false);
        result.put('message', 'Error: ' + e.getMessage());
    }
    
    return result;
}

/**
 * Send email notification to employee about leave cancellation
 */
private static void sendCancellationEmailToEmployee(Leave_Request__c request, Id cancelledById) {
    try {
        User cancelledBy = [
            SELECT Id, Name, Email
            FROM User
            WHERE Id = :cancelledById
            LIMIT 1
        ];
        
        // Get base URL
        String baseUrl =  ' https://innovation-dream-9744.my.salesforce-sites.com/LeaveApproval';
 //String baseUrl = 'https://innovation-dream-9744--uatsandbox.sandbox.my.salesforce-sites.com/LeaveApproval';
        String leaveUrl = baseUrl + '/lightning/r/Leave_Request__c/' + request.Id + '/view';
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { request.Employee__r.Email });
        mail.setSubject('Leave Request Cancelled - ' + request.Name);
        
        String body = '<html><body style="font-family: Arial, sans-serif;">';
        body += '<h2 style="color: #f97316;">Leave Request Cancelled</h2>';
        body += '<p>Dear ' + request.Employee__r.Name + ',</p>';
        body += '<p>Your leave request has been <strong>cancelled</strong> by ' + cancelledBy.Name + '.</p>';
        body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse: collapse; width: 100%; max-width: 600px;">';
        body += '<tr style="background-color: #f3f3f3;"><td><strong>Leave Request</strong></td><td>' + request.Name + '</td></tr>';
        body += '<tr><td><strong>Leave Type</strong></td><td>' + request.Leave_Type__r.Leave_Type_Name__c + '</td></tr>';
        body += '<tr style="background-color: #f3f3f3;"><td><strong>Period</strong></td><td>' + request.Start_Date__c.format() + ' to ' + request.End_Date__c.format() + '</td></tr>';
        body += '<tr><td><strong>Total Days</strong></td><td>' + request.Total_Days__c + '</td></tr>';
        body += '<tr style="background-color: #fff3cd;"><td><strong>Cancelled By</strong></td><td>' + cancelledBy.Name + '</td></tr>';
        
        if (String.isNotBlank(request.Cancelled_Reason__c)) {
            body += '<tr><td><strong>Cancellation Reason</strong></td><td>' + request.Cancelled_Reason__c + '</td></tr>';
        }
        
        body += '</table>';
        body += '<br/>';
        body += '<div style="background: #e8f5e9; padding: 16px; border-radius: 6px; margin: 20px 0;">';
        body += '<p style="margin: 0; color: #2e7d32; font-weight: bold;">✅ Your leave balance has been restored</p>';
        body += '<p style="margin: 8px 0 0 0; color: #2e7d32;">You can now check-in for attendance on these dates</p>';
        body += '</div>';
        body += '<div style="text-align: center; margin: 30px 0;">';
        body += '<a href="' + leaveUrl + '" style="background-color: #0176d3; color: white; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold;">View Leave Request</a>';
        body += '</div>';
        body += '<p>Thank you,<br/><strong>HR Management System</strong></p>';
        body += '</body></html>';
        
        mail.setHtmlBody(body);
        
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
        System.debug('✅ Cancellation email sent to employee');
        
    } catch (Exception e) {
        System.debug('⚠️ Error sending cancellation email: ' + e.getMessage());
    }
}

/**
 * Get leave requests that can be cancelled by admin
 * Shows Approved and Pending leaves only
 */
@AuraEnabled(cacheable=false)
public static List<Leave_Request__c> getCancellableLeaveRequests(Id employeeId) {
    try {
        Date today = Date.today();
        
        return [
            SELECT Id, Name,
                   Leave_Type__c, Leave_Type__r.Leave_Type_Name__c, Leave_Type__r.Leave_Code__c,
                   Start_Date__c, End_Date__c, Total_Days__c,
                   Is_Half_Day__c, Half_Day_Type__c,
                   Reason__c, Status__c,
                   Employee__c, Employee__r.Name, Employee__r.Email,
                   Manager__r.Name, Manager_Comments__c,
                   Applied_Date__c
            FROM Leave_Request__c
            WHERE Employee__c = :employeeId
            AND Status__c IN ('Approved', 'Pending')
            AND End_Date__c >= :today
            AND Is_Active__c = true
            ORDER BY Start_Date__c ASC
            LIMIT 100
        ];
    } catch (Exception e) {
        System.debug('Error getting cancellable requests: ' + e.getMessage());
        throw new AuraHandledException('Error: ' + e.getMessage());
    }
}
    
    /**
 * Check if requested leave dates fall on any public holidays
 * @param startDate - Leave start date
 * @param endDate - Leave end date
 * @return Map with validation result and holiday details
 */
@AuraEnabled
public static Map<String, Object> checkHolidayConflict(Date startDate, Date endDate) {
    Map<String, Object> result = new Map<String, Object>();
    List<Map<String, String>> conflictingHolidays = new List<Map<String, String>>();
    
    try {
        // Query holidays that fall within the requested leave period
        List<Holiday__c> holidays = [
            SELECT Id, Name, Holiday_Date__c
            FROM Holiday__c
            WHERE Holiday_Date__c >= :startDate
            AND Holiday_Date__c <= :endDate
            AND Is_Active__c = true
            ORDER BY Holiday_Date__c ASC
        ];
        
         // Calculate working days (excluding weekends and holidays)
        Integer workingDays = calculateWorkingDays(startDate, endDate, holidays);
        
        if (!holidays.isEmpty()) {
            // Build list of conflicting holidays
            for (Holiday__c holiday : holidays) {
                Map<String, String> holidayInfo = new Map<String, String>();
                holidayInfo.put('name', holiday.Name);
                holidayInfo.put('date', holiday.Holiday_Date__c.format());
                holidayInfo.put('dayOfWeek', getDayOfWeek(holiday.Holiday_Date__c));
                conflictingHolidays.add(holidayInfo);
            }
            
            result.put('hasConflict', true);
            result.put('conflictingHolidays', conflictingHolidays);
            result.put('holidayCount', holidays.size());
        } else {
            result.put('hasConflict', false);
            result.put('conflictingHolidays', new List<Map<String, String>>());
            result.put('holidayCount', 0);
        }
        result.put('workingDays', workingDays);
        return result;
        
    } catch (Exception e) {
        System.debug('Error checking holiday conflict: ' + e.getMessage());
        result.put('hasConflict', false);
        result.put('error', e.getMessage());
        return result;
    }
}

    
    
    /**
 * Calculate working days between two dates excluding weekends and public holidays
 * @param startDate Start date
 * @param endDate End date
 * @param holidays List of holidays in the date range
 * @return Number of working days
 */
private static Integer calculateWorkingDays(Date startDate, Date endDate, List<Holiday__c> holidays) {
    Integer workingDays = 0;
    
    // Create a set of holiday dates for quick lookup
    Set<Date> holidayDates = new Set<Date>();
    for (Holiday__c holiday : holidays) {
        holidayDates.add(holiday.Holiday_Date__c);
    }
    
    // Loop through each day
    Date currentDate = startDate;
    while (currentDate <= endDate) {
        // Get day of week (uses DateTime to get proper day)
        DateTime dt = DateTime.newInstance(currentDate.year(), currentDate.month(), currentDate.day());
        String dayName = dt.format('EEEE');
        
        // Check if it's NOT Saturday or Sunday AND NOT a public holiday
        Boolean isWeekend = (dayName == 'Saturday' || dayName == 'Sunday');
        Boolean isHoliday = holidayDates.contains(currentDate);
        
        if (!isWeekend && !isHoliday) {
            workingDays++;
        }
        
        // Move to next day
        currentDate = currentDate.addDays(1);
    }
    
    return workingDays;
}
    
    
    
/**
 * Helper method to get day of week from date
 */
private static String getDayOfWeek(Date dateValue) {
    DateTime dt = DateTime.newInstance(dateValue.year(), dateValue.month(), dateValue.day());
    String dayName = dt.format('EEEE'); // Returns full day name like 'Monday'
    return dayName;
}
    
    /**
 * Employee self-revoke leave request
 * Rules: Can only revoke Pending or Approved leaves
 * Deadline: Before 9 AM on the leave start date
 */
@AuraEnabled
public static Map<String, Object> revokeLeaveRequest(Id leaveRequestId, String revokeReason) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        Id employeeId = UserInfo.getUserId();
        
        Leave_Request__c leaveRequest = [
            SELECT Id, Name, Employee__c, Employee__r.Name, Employee__r.Email,
                   Leave_Type__c, Leave_Type__r.Leave_Type_Name__c,
                   Start_Date__c, End_Date__c, Total_Days__c,
                   Status__c, Manager__c, Manager__r.Name, Manager__r.Email,
                   Reason__c, Applied_Date__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            AND Employee__c = :employeeId
            LIMIT 1
        ];
        
        // Security: Employee can only revoke their own leave
        if (leaveRequest.Employee__c != employeeId) {
            result.put('success', false);
            result.put('message', 'You can only revoke your own leave requests.');
            return result;
        }
        
        // Validate status
        if (leaveRequest.Status__c == 'Cancelled') {
            result.put('success', false);
            result.put('message', 'This leave request is already cancelled.');
            return result;
        }
        if (leaveRequest.Status__c == 'Completed') {
            result.put('success', false);
            result.put('message', 'Cannot revoke a completed leave request.');
            return result;
        }
        if (leaveRequest.Status__c == 'Rejected') {
            result.put('success', false);
            result.put('message', 'Cannot revoke a rejected leave request.');
            return result;
        }
        if (leaveRequest.Status__c == 'Approved') {
    result.put('success', false);
    result.put('message', 'Approved leave requests cannot be revoked. Please contact your manager.');
    return result;
}
        
        // ===== 9 AM DEADLINE CHECK =====
        // Build the deadline: leave start date at 09:00 AM in org timezone
        DateTime leaveStartDeadline = DateTime.newInstance(
            leaveRequest.Start_Date__c.year(),
            leaveRequest.Start_Date__c.month(),
            leaveRequest.Start_Date__c.day(),
            9, 0, 0  // 9:00:00 AM
        );
        
        DateTime nowUtc = System.now();
        
        // Convert org timezone offset for accurate comparison
        // Using direct DateTime comparison (Salesforce stores in UTC internally)
        // The deadline is 9 AM in the org's local time
        String orgTz = UserInfo.getTimeZone().getId();
        
        // Get current time in org timezone for comparison
        Datetime nowInOrgTz = nowUtc;
        
        // Check if today is already PAST the start date
        Date today = Date.today();
        if (today > leaveRequest.Start_Date__c) {
            result.put('success', false);
            result.put('message', 'Cannot revoke: Your leave has already started on ' + 
                leaveRequest.Start_Date__c.format() + '.');
            return result;
        }
        
        // Check if today IS the start date — enforce 9 AM deadline
        if (today == leaveRequest.Start_Date__c) {
            if (nowUtc >= leaveStartDeadline) {
                result.put('success', false);
                result.put('message', 'Cannot revoke: The 9:00 AM deadline for revoking leave on ' + 
                    leaveRequest.Start_Date__c.format() + ' has passed.');
                return result;
            }
        }
        // If today < start date, revoke is always allowed
        
        String oldStatus = leaveRequest.Status__c;
        
        // Update leave request to Cancelled
        leaveRequest.Status__c = 'Cancelled';
        leaveRequest.Cancelled_Date__c = System.now();
        leaveRequest.Cancelled_By__c = employeeId;
        leaveRequest.Cancelled_Reason__c = String.isNotBlank(revokeReason) 
            ? revokeReason 
            : 'Revoked by employee';
        
        update leaveRequest;
        
        // Restore balance
        updateLeaveBalance(leaveRequestId, 'Cancelled', oldStatus);
        
        // Notify manager
        sendRevokeEmailToManager(leaveRequest, employeeId);
        
        result.put('success', true);
        result.put('message', 'Leave request revoked successfully. Your balance has been restored.');
        result.put('leaveRequestName', leaveRequest.Name);
        
    } catch (Exception e) {
        System.debug('Error revoking leave: ' + e.getMessage());
        result.put('success', false);
        result.put('message', 'Error: ' + e.getMessage());
    }
    
    return result;
}

/**
 * Check if a leave request is revocable by the employee
 * Returns eligibility + reason if not revocable
 */
@AuraEnabled
public static Map<String, Object> canRevokeLeave(Id leaveRequestId) {
    Map<String, Object> result = new Map<String, Object>();
    
    try {
        Id employeeId = UserInfo.getUserId();
        
        Leave_Request__c req = [
            SELECT Id, Employee__c, Start_Date__c, Status__c
            FROM Leave_Request__c
            WHERE Id = :leaveRequestId
            LIMIT 1
        ];
        
        if (req.Employee__c != employeeId) {
            result.put('canRevoke', false);
            result.put('reason', 'Not your leave request');
            return result;
        }
        
        if (req.Status__c != 'Pending') {
            result.put('canRevoke', false);
            result.put('reason', 'Status is ' + req.Status__c);
            return result;
        }
        
        Date today = Date.today();
        
        if (today > req.Start_Date__c) {
            result.put('canRevoke', false);
            result.put('reason', 'Leave has already started');
            return result;
        }
        
        if (today == req.Start_Date__c) {
            DateTime deadline = DateTime.newInstance(
                req.Start_Date__c.year(),
                req.Start_Date__c.month(),
                req.Start_Date__c.day(),
                9, 0, 0
            );
            if (System.now() >= deadline) {
                result.put('canRevoke', false);
                result.put('reason', 'Past 9 AM deadline for today\'s leave');
                return result;
            }
        }
        
        result.put('canRevoke', true);
        result.put('reason', '');
        return result;
        
    } catch (Exception e) {
        result.put('canRevoke', false);
        result.put('reason', e.getMessage());
        return result;
    }
}

/**
 * Send revoke notification email to manager
 */
private static void sendRevokeEmailToManager(Leave_Request__c request, Id employeeId) {
    try {
        User employee = [SELECT Id, Name, Email FROM User WHERE Id = :employeeId LIMIT 1];
        
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { request.Manager__r.Email });
        mail.setSubject('Leave Revoked by ' + employee.Name + ' - ' + request.Name);
        //mail.setOrgWideEmailAddressId('0D2fs00000001tl');
	// ✅ Dynamic org-wide email address
            OrgWideEmailAddress owea = [SELECT Id FROM OrgWideEmailAddress WHERE IsAllowAllProfiles = true LIMIT 1];
            mail.setOrgWideEmailAddressId(owea.Id);
        
        String body = '<html><body style="font-family: Arial, sans-serif;">';
        body += '<h2 style="color: #f97316;">Leave Request Revoked by Employee</h2>';
        body += '<p>Dear ' + request.Manager__r.Name + ',</p>';
        body += '<p><strong>' + employee.Name + '</strong> has revoked their leave request.</p>';
        body += '<table border="1" cellpadding="10" cellspacing="0" style="border-collapse:collapse;width:100%;max-width:600px;">';
        body += '<tr style="background:#f3f3f3;"><td><strong>Request #</strong></td><td>' + request.Name + '</td></tr>';
        body += '<tr><td><strong>Leave Type</strong></td><td>' + request.Leave_Type__r.Leave_Type_Name__c + '</td></tr>';
        body += '<tr style="background:#f3f3f3;"><td><strong>Period</strong></td><td>' + request.Start_Date__c.format() + ' to ' + request.End_Date__c.format() + '</td></tr>';
        body += '<tr><td><strong>Total Days</strong></td><td>' + request.Total_Days__c + '</td></tr>';
        body += '<tr style="background:#fff3cd;"><td><strong>Reason for Revoke</strong></td><td>' + (request.Cancelled_Reason__c ?? 'Not specified') + '</td></tr>';
        body += '</table>';
        body += '<p style="color:#2e7d32;font-weight:bold;">✅ No action needed. This leave has been cancelled.</p>';
        body += '<p>Thank you,<br/><strong>HR Management System</strong></p>';
        body += '</body></html>';
        
        mail.setHtmlBody(body);
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
        
    } catch (Exception e) {
        System.debug('Error sending revoke email: ' + e.getMessage());
    }
}
}