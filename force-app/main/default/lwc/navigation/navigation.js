import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import getMonthlySummary from '@salesforce/apex/AttendanceSummaryController.getMonthlySummary';

// User fields - Get current user information
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';

// Comment out the Apex import until you create the controller
// import getDashboardData from '@salesforce/apex/EmployeeDashboardController.getDashboardData';

const USER_FIELDS = [NAME_FIELD, EMAIL_FIELD, PROFILE_NAME_FIELD];

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
    @track attendanceRatepr

    tabOptions = [
        { label: 'Overview', value: 'overview', cssClass: 'tab-button active' },
        { label: 'Attendance', value: 'attendance', cssClass: 'tab-button' },
        { label: 'Timesheet', value: 'timesheet', cssClass: 'tab-button' },
        { label: 'Payslip', value: 'payslip', cssClass: 'tab-button' },
        { label: 'Goals', value: 'goals', cssClass: 'tab-button' },
        { label: 'Leave', value: 'leave', cssClass: 'tab-button' },
        { label: 'Learning', value: 'learning', cssClass: 'tab-button' }
    ];

    // Wire to get current user information
    @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
    wiredUser({ error, data }) {
        if (data) {
            this.currentUserName = data.fields.Name.value;
            this.currentUserEmail = data.fields.Email.value;
            this.currentUserProfile = data.fields.Profile?.value?.fields?.Name?.value || 'User';
            this.userDataLoaded = true;
            
            console.log('Current User loaded:', {
                name: this.currentUserName,
                email: this.currentUserEmail,
                profile: this.currentUserProfile,
                id: USER_ID
            });
            
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
   async  connectedCallback() {
        console.log('Employee Dashboard component initialized');
        console.log('Employee ID:', this.employeeId);
        const result = await getMonthlySummary({ userId: this.employeeId });
            console.log('Monthly Summary Result1:', result);
            if(result.attendanceRate) {
                this.attendanceRatepr= result.attendanceRate
          }
        
        // loadDashboardData will be called after user wire service completes
    }

    
                
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
        this.updateTabStyles('attendance');
        this.showToast('Navigation', 'Switched to Attendance tab', 'info');
    }

    handleHoursMetricClick() {
        this.activeTab = 'timesheet';
        this.updateTabStyles('timesheet');
        console.log('Navigating to Timesheet Manager component');
        this.showToast('Navigation', 'Switched to Timesheet tab', 'info');
    }

    handleLeaveMetricClick() {
        this.activeTab = 'leave';
        this.updateTabStyles('leave');
        this.showToast('Navigation', 'Switched to Leave tab', 'info');
    }

    // NEW: Overview action handlers
    handleQuickCheckIn() {
        this.activeTab = 'attendance';
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
    
    get isLeaveActive() { 
        return this.activeTab === 'leave'; 
    }
    
    get isLearningActive() { 
        return this.activeTab === 'learning'; 
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
//logout button --sri--
        logout() {
        // Properly logout the user
        //window.location.href = 'https://innovation-dream-9744--hrmproject.sandbox.my.site.com/employee/login?ec=302&startURL=%2Femployee%2F';
        window.location.href = '/employee/login';
    }
}