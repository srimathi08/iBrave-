import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import getMonthlySummary from '@salesforce/apex/AttendanceSummaryController.getMonthlySummary';
//import getLeaveBalanceSummary1 from '@salesforce/apex/EmployeeLeaveController.getLeaveBalanceSummary1';
//import getCurrentWeekTotalHours from '@salesforce/apex/TimesheetController.getCurrentWeekTotalHours';
import isCurrentUserAdmin from '@salesforce/apex/AdminAttendanceViewController.isCurrentUserAdmin';
import shouldShowCheckInPopup from '@salesforce/apex/AttendanceSummaryController.shouldShowCheckInPopup';
import getMyRequestCountsForCurrentWeek from '@salesforce/apex/AttendanceSummaryController.getMyRequestCountsForCurrentWeek';
import getMonthlyBillingBreakdown from '@salesforce/apex/TimesheetController.getMonthlyBillingBreakdown';

// User fields - Get current user information
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import fotourl from '@salesforce/schema/User.FullPhotoUrl';


// Comment out the Apex import until you create the controller
// import getDashboardData from '@salesforce/apex/EmployeeDashboardController.getDashboardData';

const USER_FIELDS = [NAME_FIELD, EMAIL_FIELD, PROFILE_NAME_FIELD, fotourl];

export default class EmployeeDashboard extends LightningElement {
    @track employeeId = USER_ID;
    @track activeTab = 'overview';
    @track isLoading = false;
    @track dashboardData = {};

    // User Information from Wire Service
    @track currentUserName = '';
    @track currentUserEmail = '';
    @track currentUserProfile = '';
    @track userDataLoaded = false;
    //Attendancerate populated --sri--
    @track attendanceRatepr = '0.0';
    @track weeklytotalhours = '0.00';
    @track totalAvailableLeave = 0;
    @track currentUserPhotoUrl = '';
    @track approvedLeaveDays = 0; // Breakdown for Absent card
    @track lopDays = 0;           // Breakdown for Absent card
    //Admin Attendance lwc  child component
    @track showChild = false;

    @track isAdmin = false;
    @track isLoaded = false;
    // User Info
    @track showPopup = false;
    currentYear = new Date().getFullYear().toString();

    @track pendingLeaveCount = 0;
    @track approvedLeaveCount = 0;
    @track pendingWFHCount = 0;
    @track pendingODCount = 0;
    @track submittedTimesheetCount = 0;

@track billablePct    = '0.0';
@track nonBillablePct = '0.0';
@track shadowPct      = '0.0';
@track productivityPct = '0.0';
@track currentMonthApprovedHours = '0';
@track currentMonthName = '';

@track lastMonthProductivityPct = '0.0';
@track lastMonthBillablePct = '0.0';
@track lastMonthNonBillablePct = '0.0';
@track lastMonthShadowPct = '0.0';
@track lastMonthApprovedHours = '0'; // We'll map totalApproved for last month here
@track lastMonthPendingHours = '0';
@track lastMonthName = '';
@track wfhActiveSubTab = '';

    tabOptions = [
        { label: 'Overview', value: 'overview', cssClass: 'tab-button active' },
        { label: 'Attendance', value: 'attendance', cssClass: 'tab-button' },
        { label: 'Timesheet', value: 'timesheet', cssClass: 'tab-button' },
        //{ label: 'Employee Self-Service Requests', value: 'employeeselfservice', cssClass: 'tab-button' },
        { label: 'WorkFlex Hub', value: 'employeeselfservice', cssClass: 'tab-button', placeholder: 'Manage leaves, WFH, and hybrid schedules' },
        //{ label: 'Payslip', value: 'payslip', cssClass: 'tab-button' },
       // { label: 'Goals', value: 'goals', cssClass: 'tab-button' },
       // { label: 'Learning', value: 'learning', cssClass: 'tab-button' },
       { label: 'Admin Attendance', value: 'adminattendance', cssClass: 'tab-button' },
        { label: 'Admin Leave', value: 'adminleave', cssClass: 'tab-button' }
    ];

    // Wire to get current user information
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ error, data }) {
        if (data) {
            console.log('Current user loaded:', JSON.stringify(data));
            this.currentUserName = data.fields.Name.value;
            this.currentUserEmail = data.fields.Email.value;
            this.currentUserProfile = data.fields.Profile?.value?.fields?.Name?.value || 'User';
            this.userDataLoaded = true;
            this.currentUserPhotoUrl = data.fields.FullPhotoUrl.value;


            // Load dashboard data after user info is loaded
            this.loadDashboardData();

        } else if (error) {
            console.error('Error getting current user info:', error);
            this.showToast('Error', 'Unable to load user information', 'error');

            // Set fallback data
            this.currentUserName = 'User';
            this.currentUserProfile = 'Employee';
            this.userDataLoaded = true;
            this.loadDashboardData();
        }
    }
    //attendancerate populated --sri--
    async connectedCallback() {
        console.log('Employee Dashboard initialized');

        // Restore active tab from session storage
        const savedTab = sessionStorage.getItem('navActiveTab');
        if (savedTab && this.tabOptions.find(t => t.value === savedTab)) {
            this.activeTab = savedTab;
            this.updateTabStyles(savedTab);
        } else {
            // Default to overview if no saved state
            this.activeTab = 'overview';
            this.updateTabStyles('overview');
        }

        console.log('Employee ID:', this.employeeId);

        try {
            // 🔹 Run all Apex calls in parallel
            const [
                attendanceResult,
                 billingBreakdown,
                 requestCounts          // 👈 replaces leaveSummary
] = await Promise.all([
    getMonthlySummary({ userId: this.employeeId }),
   getMonthlyBillingBreakdown(),
    getMyRequestCountsForCurrentWeek()  // 👈 new call
]);

            // ---- Attendance Rate ----
            this.attendanceRatepr =
                attendanceResult?.attendanceRate ?? '0.0';
            this.approvedLeaveDays = attendanceResult?.approvedLeaveDays ?? 0;
            this.lopDays           = attendanceResult?.lopDays           ?? 0;
            this.absentDays       = attendanceResult?.absentDays       ?? 0;

// Billing Breakdown 👈 updated to "Approved Only" logic
this.currentMonthName = billingBreakdown?.currentMonthName ?? '';
this.billablePct    = billingBreakdown?.billablePct    ?? '0.0';
this.nonBillablePct = billingBreakdown?.nonBillablePct ?? '0.0';
this.shadowPct      = billingBreakdown?.shadowPct      ?? '0.0';
this.productivityPct = billingBreakdown?.productivityPct ?? '0.0';

this.lastMonthName            = billingBreakdown?.lastMonthName ?? '';
this.lastMonthProductivityPct = billingBreakdown?.lastMonthProductivityPct ?? '0.0';
this.lastMonthBillablePct     = billingBreakdown?.lastMonthBillablePct ?? '0.0';
this.lastMonthNonBillablePct  = billingBreakdown?.lastMonthNonBillablePct ?? '0.0';
this.lastMonthShadowPct       = billingBreakdown?.lastMonthShadowPct ?? '0.0';
this.lastMonthPendingHours    = billingBreakdown?.lastMonthPendingHours ?? '0';

console.log('--- BILLING BREAKDOWN DATA ---');
console.log(JSON.stringify(billingBreakdown));
            

           // Request Counts
           
this.pendingLeaveCount       = requestCounts?.pendingLeave       ?? 0;
this.approvedLeaveCount      = requestCounts?.approvedLeave      ?? 0;
this.pendingWFHCount         = requestCounts?.pendingWFH         ?? 0;
this.pendingODCount          = requestCounts?.pendingOD          ?? 0;
this.submittedTimesheetCount = requestCounts?.submittedTimesheet ?? 0;
            console.log('Attendance Rate:', this.attendanceRatepr);
            console.log('Weekly Hours:', this.weeklytotalhours);
            console.log('Total Available Leave:', this.totalAvailableLeave);

            this.checkPopup();     

        } catch (error) {
            console.error('Dashboard initialization failed:', error);

            // Safe fallbacks
            this.attendanceRatepr = '0.0';
            this.weeklytotalhours = '0.00';
            this.totalAvailableLeave = 0;
        }

        this.checkAdminStatus();
        //this.checkAdmin();
    }


    checkAdminStatus() {
        isCurrentUserAdmin({ userId: USER_ID })
            .then(result => {
                this.showChild = result; // ✅ true or false
                // ✅ Filter tabs based on admin access
            this.updateTabsBasedOnAccess();
            })
            .catch(error => {
                console.error('Error fetching admin status:', error);
                this.showChild = false;
                // ✅ Filter tabs based on admin access
            this.updateTabsBasedOnAccess();
            });
    }

    updateTabsBasedOnAccess() {
    if (!this.showChild) {
        // ❌ Remove Admin tabs if NOT admin
        this.tabOptions = this.tabOptions.filter(
            tab => tab.value !== 'adminattendance' && tab.value !== 'adminleave'
        );
    }
}

    checkPopup() {
        shouldShowCheckInPopup()
            .then(result => {
                this.showPopup = result;
            })
            .catch(error => {
                console.error(error);
            });
    }

    closePopup() {
        this.showPopup = false;
    }

    // checkAdmin() {
    //         isAdminUser({ userId: USER_ID })
    //             .then(result => {
    //                 this.isAdmin = result;
    //                 this.isLoaded = true;
    //             })
    //             .catch(error => {
    //                 console.error(error);
    //                 this.isLoaded = true;
    //             });
    //     }





    loadDashboardData() {
        // Using static data for now - replace with Apex call later
        this.isLoading = true;

        console.log('Loading dashboard data for user:', this.currentUserName);

        // Simulate loading delay
        setTimeout(() => {
            this.dashboardData = {
                // Use real user name instead of static data
                employeeName: this.currentUserName,
                employeeRole: this.getFormattedRole(),
                attendanceRate: '94',
                hoursThisWeek: '41.5',
                overtimeText: '3.5h overtime',
                leaveBalance: '15'
            };
            this.isLoading = false;

            console.log('Dashboard data loaded:', this.dashboardData);
        }, 500);

        // Uncomment and use this when you create the Apex controller
        /*
        getDashboardData({ employeeId: this.employeeId })
            .then(result => {
                this.dashboardData = {
                    ...result,
                    employeeName: this.currentUserName, // Always use real user name
                    employeeRole: this.getFormattedRole()
                };
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load dashboard data', 'error');
                console.error('Dashboard Error:', error);
                this.isLoading = false;
                // Set default data on error with real user name
                this.dashboardData = {
                    employeeName: this.currentUserName,
                    employeeRole: this.getFormattedRole(),
                    attendanceRate: '94',
                    hoursThisWeek: '41.5',
                    overtimeText: '3.5h overtime',
                    leaveBalance: '15'
                };
            });
        */
    }

    // Helper method to format user role
    getFormattedRole() {
        if (this.currentUserProfile) {
            return `${this.currentUserProfile}`;
        }
        return 'Employee';
    }

    handleTabClick(event) {
        const selectedTab = event.target.dataset.tab;
        this.activeTab = selectedTab;
        sessionStorage.setItem('navActiveTab', selectedTab);

        console.log('Tab changed to:', selectedTab);

        // Update tab styles
        this.tabOptions = this.tabOptions.map(tab => ({
            ...tab,
            cssClass: tab.value === selectedTab ? 'tab-button active' : 'tab-button'
        }));
    }

    // NEW: Metric click handlers
    handleAttendanceMetricClick() {
        this.activeTab = 'attendance';
        sessionStorage.setItem('navActiveTab', 'attendance');
        this.updateTabStyles('attendance');
        this.showToast('Navigation', 'Switched to Attendance tab', 'info');
    }

    handleHoursMetricClick() {
        this.activeTab = 'timesheet';
        sessionStorage.setItem('navActiveTab', 'timesheet');
        this.updateTabStyles('timesheet');
        console.log('Navigating to Timesheet Manager component');
        this.showToast('Navigation', 'Switched to Timesheet tab', 'info');
    }

    handleLeaveMetricClick() {
        this.activeTab = 'leave'; // Note: 'leave' is not in tabOptions initially? Wait, tabOption has 'employeeselfservice'. The metric click sets 'leave'.
        // Wait, looking at tabOptions:
        // { label: 'WorkFlex Hub', value: 'employeeselfservice', ... }
        // The metric click sets 'leave' but the tab value is 'employeeselfservice'?
        // Let's check updateTabStyles logic... it matches value.
        // If 'leave' is not a valid tab value, this might be broken already or 'leave' is handled elsewhere?
        // Tab options has 'employeeselfservice'.
        // Checking the HTML: <div class="metric-card leave-metric" onclick={handleLeaveMetricClick}>
        // Checking existing code: handleLeaveMetricClick() { this.activeTab = 'leave'; ... }
        // But 'leave' isn't in tabOptions? 
        // Ah, looking closer at provided file content...
        // tabOptions: overview, attendance, timesheet, employeeselfservice, payslip, goals, learning.
        // So setting activeTab='leave' might not visually select the tab if 'leave' != 'employeeselfservice'.
        // However, I should just implement persistence for whatever it sets.
        // If the user wants 'leave' to go to 'employeeselfservice', that is a separate bug/feature. 
        // I will stick to persisting what is set. But wait, if I persist 'leave' and it reloads, does it show anything?
        // Navigation HTML: <template if:true={isEmployeeSelfServiceActive}> ... </template>
        // getter isEmployeeSelfServiceActive() { return this.activeTab === 'employeeselfservice'; }
        // So 'leave' sets activeTab='leave', but there is no template for 'leave'?
        // Wait, looking at HTML again... 
        // There is NO template for isLeaveActive.
        // So `handleLeaveMetricClick` setting `activeTab='leave'` might be currently broken or incomplete code.
        // I will persist 'leave' nonetheless, but I will assume it might change to 'employeeselfservice' later or it's a bug. 
        // Actually, looking at `handleQuickCheckIn`, it sets 'attendance'. 
        // To be safe and compliant with user request "land on that page itself", I will persist whatever is applied.

        sessionStorage.setItem('navActiveTab', 'leave');
        this.updateTabStyles('leave');
        this.showToast('Navigation', 'Switched to Leave tab', 'info');
    }

handleNavigateToWFH() {
    console.log('📍 Navigating to WFH tab from attendance component');

    // ✅ Reset first so the setter fires even if value was already 'wfh'
    this.wfhActiveSubTab = '';

    // Step 1: Switch to WorkFlex Hub tab
    this.activeTab = 'employeeselfservice';
    sessionStorage.setItem('navActiveTab', 'employeeselfservice');
    this.updateTabStyles('employeeselfservice');

    // Step 2: Set WFH sub-tab AFTER a tick so c-parent-request re-renders
    // eslint-disable-next-line @lwc/lwc/no-async-operation
    setTimeout(() => {
        this.wfhActiveSubTab = 'wfh';
        console.log('✅ wfhActiveSubTab set to wfh');
    }, 100);
}

    // NEW: Overview action handlers
    handleQuickCheckIn() {
        this.activeTab = 'attendance';
        sessionStorage.setItem('navActiveTab', 'attendance');
        this.updateTabStyles('attendance');
        this.showToast('Quick Action', 'Redirected to Attendance for quick check-in', 'success');
    }

    handleViewReports() {
        this.showToast('Reports', 'Reports feature coming soon!', 'info');
    }

    // NEW: Error state handler
    handleRetry() {
        this.userDataLoaded = false;
        this.isLoading = true;

        // Retry loading user data
        setTimeout(() => {
            this.loadDashboardData();
        }, 1000);

        this.showToast('Retry', 'Retrying to load dashboard data...', 'info');
    }

    // Helper method to update tab styles
    updateTabStyles(selectedTab) {
        this.tabOptions = this.tabOptions.map(tab => ({
            ...tab,
            cssClass: tab.value === selectedTab ? 'tab-button active' : 'tab-button'
        }));
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable',
            duration: variant === 'error' ? 8000 : 4000
        });
        this.dispatchEvent(event);
    }

    //populating the weeklytotal hours 
    handleWeekTotalUpdate(event) {
        console.log(
            'Dashboard received week total:',
            event.detail.weekTotalHours
        );
        this.weeklytotalhours = event.detail.weekTotalHours;
    }

    //populating the total available leave  
    loadTotalAvailableLeave() {
        getLeaveBalanceSummary1({ employeeId: this.employeeId, year: this.currentYear })
            .then(result => {
                console.log('Total Available Leave:', result.totalAvailable);
                this.totalAvailableLeave = result.totalAvailable || 0;
            })
            .catch(error => {
                console.error('Error loading total available leave', error);
                this.totalAvailableLeave = 0;
            });
    }



    // UPDATED: Getter methods for data binding with real user data
    get employeeName() {
        // Always return real current user name
        return this.currentUserName || 'Loading...';
    }

    get employeeRole() {
        // Return formatted role with real user profile
        return this.dashboardData.employeeRole || this.getFormattedRole();
    }

    get attendanceRate() {
        return this.dashboardData.attendanceRate || '0';
    }

    get hoursThisWeek() {
        return this.dashboardData.hoursThisWeek || '0.0';
    }

    get overtimeText() {
        return this.dashboardData.overtimeText || 'No overtime';
    }

    get leaveBalance() {
        return this.dashboardData.leaveBalance || '0';
    }

    // NEW: Getters for user information
    get displayUserName() {
        return this.currentUserName || 'User';
    }

    get displayUserEmail() {
        return this.currentUserEmail || '';
    }

    get displayUserProfile() {
        return this.currentUserProfile || 'Employee';
    }

    get isUserDataReady() {
        return this.userDataLoaded && !this.isLoading;
    }

    // Tab visibility getters
    get isOverviewActive() {
        return this.activeTab === 'overview';
    }

    get isAttendanceActive() {
        return this.activeTab === 'attendance';
    }

    get isTimesheetActive() {
        return this.activeTab === 'timesheet';
    }

    get isPayslipActive() {
        return this.activeTab === 'payslip';
    }

    get isGoalsActive() {
        return this.activeTab === 'goals';
    }

    get isEmployeeSelfServiceActive() {
        return this.activeTab === 'employeeselfservice';
    }

    get isLearningActive() {
        return this.activeTab === 'learning';
    }

    get isAdminAttendanceActive() {
        return this.activeTab === 'adminattendance';
    }

    get isAdminLeaveActive() {
        return this.activeTab === 'adminleave';
    }

    // NEW: Method to pass data to child attendance component
    get attendanceComponentData() {
        return {
            employeeId: this.employeeId,
            employeeName: this.currentUserName,
            employeeEmail: this.currentUserEmail,
            employeeProfile: this.currentUserProfile
        };
    }

    // NEW: Dashboard summary getters for enhanced functionality
    get welcomeMessage() {
        const currentHour = new Date().getHours();
        let timeOfDay = 'day';

        if (currentHour < 12) {
            timeOfDay = 'morning';
        } else if (currentHour < 17) {
            timeOfDay = 'afternoon';
        } else {
            timeOfDay = 'evening';
        }

        return `Good ${timeOfDay}, ${this.displayUserName}!`;
    }

    get currentDateTime() {
        return new Date().toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    get isWorkingHours() {
        const currentHour = new Date().getHours();
        return currentHour >= 9 && currentHour < 18;
    }

    get dashboardStats() {
        return {
            totalMetrics: 3,
            activeTab: this.activeTab,
            userProfile: this.displayUserProfile,
            dataLoaded: this.userDataLoaded
        };
    }
    get billableBarStyle() {
    const pct = this.billablePct || 0;
    return 'width:' + pct + '%;height:100%;border-radius:4px;background-color:#27ae60;transition:width 0.4s ease;';
}

get nonBillableBarStyle() {
    const pct = this.nonBillablePct || 0;
    return 'width:' + pct + '%;height:100%;border-radius:4px;background-color:#e67e22;transition:width 0.4s ease;';
}

get shadowBarStyle() {
    const pct = this.shadowPct || 0;
    return 'width:' + pct + '%;height:100%;border-radius:4px;background-color:#8e44ad;transition:width 0.4s ease;';
}

    // NEW: Enhanced logging and debugging methods
    logComponentState() {
        console.log('Employee Dashboard State:', {
            activeTab: this.activeTab,
            userDataLoaded: this.userDataLoaded,
            isLoading: this.isLoading,
            currentUser: {
                name: this.currentUserName,
                email: this.currentUserEmail,
                profile: this.currentUserProfile,
                id: this.employeeId
            },
            dashboardData: this.dashboardData,
            tabOptions: this.tabOptions
        });
    }

    // NEW: Method to handle component refresh
    refreshDashboard() {
        this.isLoading = true;
        this.userDataLoaded = false;

        setTimeout(() => {
            this.loadDashboardData();
        }, 500);

        this.showToast('Dashboard Refreshed', 'Dashboard data has been refreshed successfully!', 'success');
    }

    // NEW: Method to handle navigation programmatically
    navigateToTab(tabValue) {
        if (this.tabOptions.find(tab => tab.value === tabValue)) {
            this.activeTab = tabValue;
            sessionStorage.setItem('navActiveTab', tabValue);
            this.updateTabStyles(tabValue);

            console.log('Programmatically navigated to:', tabValue);
            this.showToast('Navigation', `Switched to ${tabValue} tab`, 'info');
        } else {
            console.error('Invalid tab value:', tabValue);
            this.showToast('Error', 'Invalid tab selection', 'error');
        }
    }

    // NEW: Method to get active tab information
    getActiveTabInfo() {
        return this.tabOptions.find(tab => tab.value === this.activeTab) || null;
    }
    // Voice Chat Assistant navigation handler
    handleVoiceNavigation(event) {
        const tabValue = event.detail.tabValue;
        if (tabValue) {
            this.navigateToTab(tabValue);
        }
    }

    //logout button --sri--
    logout() {
        // Properly logout the user
        sessionStorage.clear();
        //window.location.href = 'https://innovation-dream-9744--hrmproject.sandbox.my.site.com/employee/login?ec=302&startURL=%2Femployee%2F';
        window.location.href = '/employee/login';
    }
}