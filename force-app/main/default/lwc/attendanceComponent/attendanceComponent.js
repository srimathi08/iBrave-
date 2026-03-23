import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import LightningAlert from 'lightning/alert';

// User fields
import USER_ID from '@salesforce/user/Id';
import NAME_FIELD from '@salesforce/schema/User.Name';
import EMAIL_FIELD from '@salesforce/schema/User.Email';
import PROFILE_NAME_FIELD from '@salesforce/schema/User.Profile.Name';
import MANAGER_FIELD from '@salesforce/schema/User.Manager.Name';

// Import Apex methods
import createAttendance from '@salesforce/apex/NewController.createAttendance';
import updateAttendance from '@salesforce/apex/EditController.updateAttendance';
import getReverseGeocode from '@salesforce/apex/LocationService.getReverseGeocode';
import getMonthlySummary from '@salesforce/apex/AttendanceSummaryController.getMonthlySummary';
import getEmployeeAttendanceRecords from '@salesforce/apex/AttendanceViewController.getEmployeeAttendanceRecords';
//import submitWFHApproval from '@salesforce/apex/WFHApprovalController.submitWFHApproval';
import getTodayAttendanceRecord from '@salesforce/apex/AttendanceViewController.getTodayAttendanceRecord';
import getActiveBranches from '@salesforce/apex/BranchController.getActiveBranches';
import getBranchDetails from '@salesforce/apex/BranchController.getBranchDetails';
import uploadFile from '@salesforce/apex/FileUploaderClass.uploadFile';
import checkLeaveForDate from '@salesforce/apex/AttendanceViewController.checkLeaveForDate';
import checkActiveScheduleForDate from '@salesforce/apex/HybridWorkScheduleController.checkActiveScheduleForDate';
import submitHybridScheduleRequest from '@salesforce/apex/HybridWorkScheduleController.submitHybridScheduleRequest';
import getUserDetails from '@salesforce/apex/AttendanceController.getUserDetails';
import autoCheckOut from '@salesforce/apex/AttendanceViewController.autoCheckOut';
import checkYesterdayAttendance from '@salesforce/apex/AttendanceViewController.checkYesterdayAttendance';
import createODAttendance from '@salesforce/apex/NewController.createODAttendance';
import checkEmployeeWFHRequest from '@salesforce/apex/WFH_Request.checkEmployeeWFHRequest';

const USER_FIELDS = [NAME_FIELD, EMAIL_FIELD, PROFILE_NAME_FIELD, MANAGER_FIELD];

export default class AttendanceComponent extends LightningElement {
    @api employeeId = USER_ID;
    
    @track hasCompletedBothToday = false;
    
    // User Information
    @track currentUserId = USER_ID;
    @track currentUserName = '';
    @track currentUserEmail = '';
    @track currentUserProfile = '';
    @track currentUserManagerName = '';
    
    // Loading states
    @track isLoading = false;
    @track showCheckInModal = false;
    @track showCheckOutModal = false;
    @track isGettingLocation = false;
    @track isCapturingPhoto = false;
    @track isLoadingSummary = false;
    
    // Time and date
    @track currentTime = '';
    @track currentDate = '';
    
    // ✅ UPDATED: Multiple Session Properties
    @track isCheckedIn = false;
    @track isCheckedOut = false;
    @track todayAttendanceId = null;
    @track todayCheckInTime = '';
    @track hoursWorkedToday = '0.0';
    @track actualHoursWorked = '0.0';
    
    // ✅ NEW: Session tracking properties
    @track todaySessionNumber = 0;
    @track currentSessionId = null;
    @track allTodaySessions = [];
    @track canStartNewSession = false;
    @track lastSessionCheckOut = null;
    
    // Work location
    @track selectedWorkLocation = '';
    @track workLocation = 'Not set';

    // Branch Properties
    @track branchOptions = [];
    @track selectedBranchId = '';
    @track selectedBranchName = '';
    @track showBranchDropdown = false;

    // Business Travel Properties
    @track showBusinessTravelSection = false;
    @track businessTravelDetails = '';
    @track businessTravelStartDate = '';
    @track businessTravelEndDate = '';
    @track businessTravelCharCount = 0;
    @track fileData = null;
    @track uploadedFileName = '';
    @track isFileUploaded = false;
    
    // Client Place and Field Work Details
    @track showClientPlaceDetails = false;
    @track showFieldWorkDetails = false;
    @track clientPlaceDetails = '';
    @track fieldWorkDetails = '';
    @track clientPlaceCharCount = 0;
    @track fieldWorkCharCount = 0;
    
    // WFH Approval Properties
    @track showWFHReasonSection = false;
    @track wfhReason = '';
    @track wfhReasonCharCount = 0;
    @track requiresApproval = false;
    
    // Location data
    @track latitude = '';
    @track longitude = '';
    @track locationAccuracy = '';
    @track hasValidLocation = false;
    @track locationErrorMessage = 'Location not captured yet';
    @track locationName = '';
    @track locationState = '';
    @track locationCountry = '';
    @track locationCity = '';
    @track locationArea = '';
    @track displayLocationName = '';
    @track fullLocationAddress = '';
    @track watchId = null;
    
    // Photo data
    @track checkInPhotoPreview = '';
    @track checkOutPhotoPreview = '';
    @track checkInPhotoB64 = '';
    @track checkOutPhotoB64 = '';
    @track checkInPhotoName = '';
    @track checkOutPhotoName = '';
    @track cameraStream = null;
    
    // Notes
    @track checkInNotes = '';
    @track checkOutNotes = '';
    
    // Current photo capture type
    @track currentPhotoType = '';

    // Leave properties
    @track hasLeaveToday = false;
    @track todayLeaveInfo = {};
    @track leaveMessage = '';

    // ✅ Hybrid Work Schedule properties (UNCOMMENTED)
    @track hasActiveHybridSchedule = false;
    @track hybridScheduleId = null;
    @track isScheduledWFH = false;
    @track isScheduledOffice = false;
    @track hybridScheduleMessage = '';
    @track autoApproveWFH = false;
    @track scheduledWFHDays = '';
    @track scheduledOfficeDays = '';

    // ✅ NEW: Previous day OD properties
@track hasMissingYesterdayRecord = false;
@track yesterdayDate = '';
@track yesterdayDisplayDate = '';
@track showODModal = false;
@track odReason = '';
@track odReasonCharCount = 0;
@track odSelectedWorkLocation = '';
@track odShowBranchDropdown = false;
@track odSelectedBranchId = '';
@track odSelectedBranchName = '';
@track odCheckInTime = '';
@track odCheckOutTime = '';
@track odNotes = '';
@track isSubmittingOD = false;
@track isCheckingWFHRequest = false;

    // Hybrid Schedule Modal Properties
    @track showHybridScheduleModal = false;
    @track hybridScheduleMonth = '';
    @track hybridScheduleType = 'Fixed Days';
    @track hybridScheduleReason = '';
    @track hybridDaysOfWeek = [
        { label: 'Monday', value: 'Monday', isWFH: false, isOffice: false },
        { label: 'Tuesday', value: 'Tuesday', isWFH: false, isOffice: false },
        { label: 'Wednesday', value: 'Wednesday', isWFH: false, isOffice: false },
        { label: 'Thursday', value: 'Thursday', isWFH: false, isOffice: false },
        { label: 'Friday', value: 'Friday', isWFH: false, isOffice: false }
    ];
    @track hybridValidationError = false;
    @track hybridValidationErrorMessage = '';
    @track autoCheckoutTimer = null;

    // Work location options
    workLocationOptions = [
        { label: 'Work from Office', value: 'Work from Office' },
        { label: 'Work from Home', value: 'Work from Home' },
        { label: 'Client Place', value: 'Client Place' },
        { label: 'Field Work', value: 'Field Work' },
        //{ label: 'Remote Work', value: 'Remote Work' },
        { label: 'Business Travel', value: 'Business Travel' }
    ];

    // Monthly summary data
    @track summaryData = {
        presentDays: '0',
        lateDays: '0',
        absentDays: '0',
        totalHours: '0.0',
        avgHours: '0.0',
        attendanceRate: '0'
    };
    
    @track monthName = '';
    @track totalWorkingDays = 0;
    @track recordsFound = 0;
    @track summaryError = '';

    // Attendance records with pagination
    @track allAttendanceRecords = [];
    @track attendanceRecords = [];

    // Pagination properties
    @track currentPage = 1;
    @track pageSize = 10;
    @track totalRecords = 0;
    @track totalPages = 0;
    @track showPagination = false;

    


    //ErrorMessage
    @track errorMessage = '';


    // Wire to get current user information
   // @wire(getRecord, { recordId: USER_ID, fields: USER_FIELDS })
   // wiredUser({ error, data }) {
     //   if (data) {
      //      console.log('Afrose',JSON.stringify(data))
       //     this.currentUserName = data.fields.Name.value;
         //   this.currentUserEmail = data.fields.Email.value;
        //    this.currentUserProfile = data.fields.Profile?.value?.fields?.Name?.value || 'User';
         //   this.currentUserManagerName = data.fields.Manager?.value?.fields?.Name?.value || 'No Manager Assigned';
          //  this.employeeId = this.currentUserId;
            
           // console.log('User loaded:', this.currentUserName, 'Manager:', this.currentUserManagerName);
     //   } else if (error) {
           // console.error('Error getting user info:', error);
         ///   this.showToast('Error', 'Unable to load user information', 'error');
       // }
 //   }

    @wire(getUserDetails)
    wiredUser({ error, data }) {
        if (data) { 
            console.log('Afrose User Data:', JSON.stringify(data));
            this.currentUserName = data.Name;

            this.currentUserEmail = data.Email;
            this.currentUserProfile = data.Profile.Name || 'User';
            this.currentUserManagerName = data.Manager.Name || 'No Manager Assigned';
            this.employeeId = data.Id;
        }    
        else if (error) {
            console.error('Error getting user info:', error);
            this.showToast('Error', 'Unable to load user information', error);
        }
        }

    // ===================================================================
    // LIFECYCLE METHODS
    // ===================================================================

    connectedCallback() {
        this.updateCurrentTime();
        this.updateCurrentDate();
        this.startTimeInterval();

        this.loadBranches();
        
        setTimeout(() => {
            this.initializeComponent().then(() => {
             this.scheduleAutoCheckout(); // ← ADD THIS LINE
         });
        }, 1000);

        this.requestPermissions();
    }

    disconnectedCallback() {
        if (this.timeInterval) {
            clearInterval(this.timeInterval);
        }

                 if (this.autoCheckoutTimer) {          // ← ADD THESE 3 LINES
         clearTimeout(this.autoCheckoutTimer);
         this.autoCheckoutTimer = null;
     }
        
        if (this.watchId) {
            navigator.geolocation.clearWatch(this.watchId);
        }
        
        if (this.cameraStream) {
            this.stopCameraStream();
        }
    }

    async checkHybridSchedule() {
        if (!this.employeeId) {
            return;
        }

        try {
            const today = new Date().toISOString().split('T')[0];
            console.log('🔍 Checking hybrid schedule for date:', today);

            const result = await checkActiveScheduleForDate({
                employeeId: this.employeeId,
                checkDate: today
            });

            console.log('Hybrid schedule check result:', JSON.stringify(result, null, 2));

            if (result.hasActiveSchedule) {
                this.hasActiveHybridSchedule = true;
                this.hybridScheduleId = result.scheduleId;
                this.isScheduledWFH = result.isScheduledWFH || false;
                this.isScheduledOffice = result.isScheduledOffice || false;
                this.hybridScheduleMessage = result.message || '';
                this.autoApproveWFH = result.autoApproveWFH || false;
                this.scheduledWFHDays = result.wfhDays || '';
                this.scheduledOfficeDays = result.officeDays || '';

                console.log('✅ Active hybrid schedule found');
            } else {
                this.hasActiveHybridSchedule = false;
                this.hybridScheduleId = null;
                this.isScheduledWFH = false;
                this.isScheduledOffice = false;
                this.hybridScheduleMessage = '';
                this.autoApproveWFH = false;
                this.scheduledWFHDays = '';
                this.scheduledOfficeDays = '';
                console.log('⚠️ No active hybrid schedule for today');
            }

        } catch (error) {
            console.error('❌ Error checking hybrid schedule:', error);
            this.hasActiveHybridSchedule = false;
        }
    }


    // ===================================================================
// ✅ NEW: PREVIOUS DAY OD / MISSED ATTENDANCE FEATURE
// ===================================================================


async checkYesterdayAttendance() {
    try {
        const today = new Date();
        const todayDayOfWeek = today.getDay(); // 0=Sun,1=Mon,2=Tue,3=Wed,4=Thu,5=Fri,6=Sat

        // Sunday → no check at all
        if (todayDayOfWeek === 0) {
            this.hasMissingYesterdayRecord = false;
            console.log('⏭️ Today is Sunday - skipping check');
            return;
        }

        const previousDay = new Date(today);

        if (todayDayOfWeek === 1) {
            // Monday → check Friday (skip Sat & Sun)
            previousDay.setDate(today.getDate() - 3);
            console.log('📅 Today is Monday → checking Friday');

        } else if (todayDayOfWeek === 6) {
            // Saturday → check Friday (yesterday)
            previousDay.setDate(today.getDate() - 1);
            console.log('📅 Today is Saturday → checking Friday');

        } else {
            // Tuesday–Friday → check previous weekday (yesterday)
            previousDay.setDate(today.getDate() - 1);
            console.log('📅 Checking yesterday');
        }

        const previousDayStr = previousDay.toISOString().split('T')[0];
        this.yesterdayDate = previousDayStr;
        this.yesterdayDisplayDate = previousDay.toLocaleDateString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });

        console.log('🔍 Checking attendance for:', previousDayStr);

        const result = await checkYesterdayAttendance({
            employeeId: this.employeeId,
            checkDate: previousDayStr
        });

        console.log('Previous day check result:', JSON.stringify(result));

        if (result.success) {
            this.hasMissingYesterdayRecord = !result.hasRecord
                && !result.hasLeave
                && !result.hasHoliday
                && !result.hasODSubmitted;
        } else {
            this.hasMissingYesterdayRecord = false;
        }

    } catch (error) {
        console.error('Error checking previous working day:', error);
        this.hasMissingYesterdayRecord = false;
    }
}

handleOpenODModal() {
    this.showODModal = true;
    this.odReason = '';
    this.odReasonCharCount = 0;
    this.odSelectedWorkLocation = '';
    this.odShowBranchDropdown = false;
    this.odSelectedBranchId = '';
    this.odSelectedBranchName = '';
    this.odCheckInTime = '';
    this.odCheckOutTime = '';
    this.odNotes = '';
}

closeODModal() {
    this.showODModal = false;
}

handleODWorkLocationChange(event) {
    this.odSelectedWorkLocation = event.detail.value;
    this.odShowBranchDropdown = this.odSelectedWorkLocation === 'Work from Office';
    if (!this.odShowBranchDropdown) {
        this.odSelectedBranchId = '';
        this.odSelectedBranchName = '';
    }
}

async handleODBranchChange(event) {
    this.odSelectedBranchId = event.detail.value;
    if (this.odSelectedBranchId) {
        try {
            const result = await getBranchDetails({ branchId: this.odSelectedBranchId });
            if (result.success) {
                this.odSelectedBranchName = result.branchName;
            }
        } catch (error) {
            console.error('Error getting branch for OD:', error);
        }
    }
}

handleODReasonChange(event) {
    this.odReason = event.detail.value;
    this.odReasonCharCount = this.odReason ? this.odReason.length : 0;
}

handleODNotesChange(event) {
    this.odNotes = event.detail.value;
}

handleODCheckInTimeChange(event) {
    this.odCheckInTime = event.detail.value;
}

handleODCheckOutTimeChange(event) {
    this.odCheckOutTime = event.detail.value;
}



// ✅ Override processPhotoFile to handle OD photo types too
// (update your existing processPhotoFile method to add these cases)
// Inside reader.onload, add:
//   } else if (fieldName === 'od_checkin') {
//       this.odCheckInPhotoPreview = reader.result;
//       this.odCheckInPhotoB64 = base64;
//       this.odCheckInPhotoName = fileName;
//   } else if (fieldName === 'od_checkout') {
//       this.odCheckOutPhotoPreview = reader.result;
//       this.odCheckOutPhotoB64 = base64;
//       this.odCheckOutPhotoName = fileName;
//   }

get isODSubmitDisabled() {
    const base = !this.odSelectedWorkLocation
        || !this.odReason || this.odReason.trim().length < 20
        || !this.odCheckInTime
        || !this.odCheckOutTime
        || this.isSubmittingOD;

    if (this.odSelectedWorkLocation === 'Work from Office') {
        return base || !this.odSelectedBranchId;
    }
    return base;
}

get odCheckInTimeFormatted() {
    if (!this.odCheckInTime) return '--';
    const [h, m] = this.odCheckInTime.split(':');
    const hour = parseInt(h);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const h12 = hour % 12 || 12;
    return `${h12}:${m} ${ampm}`;
}

get odCheckOutTimeFormatted() {
    if (!this.odCheckOutTime) return '--';
    const [h, m] = this.odCheckOutTime.split(':');
    const hour = parseInt(h);
    const ampm = hour >= 12 ? 'PM' : 'AM';
    const h12 = hour % 12 || 12;
    return `${h12}:${m} ${ampm}`;
}


get previousDayLabel() {
    const today = new Date();
    const todayDayOfWeek = today.getDay();
    // Monday or Saturday → previous working day was Friday
    if (todayDayOfWeek === 1 || todayDayOfWeek === 6) {
        return 'Last Friday';
    }
    return 'Yesterday';
}
async confirmODSubmit() {
    if (this.isODSubmitDisabled) return;

    this.isSubmittingOD = true;

    try {
        // Build datetime strings for the previous day
        const checkInDateTime = `${this.yesterdayDate} ${this.odCheckInTime}:00`;
        const checkOutDateTime = `${this.yesterdayDate} ${this.odCheckOutTime}:00`;

        const checkInHour = parseInt(this.odCheckInTime.split(':')[0]);
        const checkInMinute = parseInt(this.odCheckInTime.split(':')[1]);
        const isLate = checkInHour > 9 || (checkInHour === 9 && checkInMinute > 15);

        const payload = {
            Employee_Name__c: this.employeeId,
            Date__c: this.yesterdayDate,
            Check_In_Time__c: checkInDateTime,
            Check_Out_Time__c: checkOutDateTime,
            Work_Location__c: this.odSelectedWorkLocation,
            Status__c: isLate ? 'Late' : 'Present',
            OD_Approval_Status__c: 'Pending',
            Is_OD_Request__c: true,
            OD_Reason__c: this.odReason,
            Submitted_For_Approval__c: true,
            Notes__c: this.odNotes
                || `OD submission by ${this.currentUserName} for ${this.yesterdayDisplayDate}`,
            
        };

        if (this.odSelectedWorkLocation === 'Work from Office' && this.odSelectedBranchId) {
            payload.Branch_Name__c = this.odSelectedBranchId;
        }

        console.log('📤 Submitting OD payload:', JSON.stringify(payload, null, 2));

        const result = await createODAttendance({ payload: payload });

        if (result.success) {
            this.hasMissingYesterdayRecord = false;
            this.showODModal = false;

            await LightningAlert.open({
                label: 'OD Request Submitted',
                message: `Your attendance request for ${this.yesterdayDisplayDate} has been sent to ${this.currentUserManagerName} for approval.`,
                theme: 'success'
            });

            await Promise.allSettled([
                this.loadMonthlySummary().catch(e => console.log(e)),
                this.loadExistingAttendanceRecords().catch(e => console.log(e))
            ]);
        } else {
            throw new Error(result.error || 'Failed to submit OD request');
        }
    } catch (error) {
        console.error('❌ OD submission error:', error);
        await LightningAlert.open({
            label: 'Submission Failed',
            message: error.body?.message || error.message,
            theme: 'error'
        });
    } finally {
        this.isSubmittingOD = false;
    }
}

    // ✅ UPDATED: Reset with session properties
    resetTodayAttendanceState() {
        this.isCheckedIn = false;
        this.isCheckedOut = false;
        this.hasCompletedBothToday = false;
        this.todayAttendanceId = null;
        this.todayCheckInTime = '';
        this.workLocation = 'Not set';
        this.hoursWorkedToday = '0.0';
        this.actualHoursWorked = '0.0';
        
        // Reset session tracking
        this.todaySessionNumber = 0;
        this.currentSessionId = null;
        this.allTodaySessions = [];
        this.canStartNewSession = false;
        this.lastSessionCheckOut = null;
        
        console.log('🔄 Today\'s attendance state reset - ready for new check-in');
    }

    async requestPermissions() {
        try {
            if (navigator.mediaDevices && navigator.mediaDevices.getUserMedia) {
                const stream = await navigator.mediaDevices.getUserMedia({ 
                    video: { facingMode: 'environment' } 
                });
                stream.getTracks().forEach(track => track.stop());
                console.log('✅ Camera permission granted');
            }
        } catch (error) {
            console.log('⚠️ Camera permission denied:', error);
        }
    }

    async loadBranches() {
        try {
            console.log('📍 Loading active branches from database...');
            
            const branches = await getActiveBranches();
            
            if (branches && branches.length > 0) {
                this.branchOptions = branches.map(branch => {
                    return {
                        label: branch.label,
                        value: branch.value
                    };
                });
                
                console.log('✅ Loaded ' + this.branchOptions.length + ' branches for dropdown');
                
            } else {
                console.log('⚠️ No active branches found in the system');
                this.showToast('Warning', 
                    'No branches configured. Please contact your administrator.', 
                    'warning');
            }
            
        } catch (error) {
            console.error('❌ Error loading branches:', error);
            this.showToast('Error', 
                'Failed to load branch list: ' + (error.body?.message || error.message), 
                'error');
        }
    }

    async checkTodayLeave() {
        if (!this.employeeId) {
            return;
        }
        
        try {
            const today = new Date().toISOString().split('T')[0];
            console.log('Checking leave for date:', today);
            
            const result = await checkLeaveForDate({
                employeeId: this.employeeId,
                checkDate: today
            });
            
            if (result.success && result.hasLeave) {
                this.hasLeaveToday = true;
                this.todayLeaveInfo = {
                    leaveId: result.leaveId,
                    leaveName: result.leaveName,
                    leaveType: result.leaveType,
                    leaveCode: result.leaveCode,
                    startDate: result.startDate,
                    endDate: result.endDate,
                    totalDays: result.totalDays,
                    reason: result.reason,
                    status: result.status,
                    isHalfDay: result.isHalfDay,
                    halfDayType: result.halfDayType
                };
                this.leaveMessage = result.message;
                
                console.log('✅ Leave found:', this.leaveMessage);
            } else {
                this.hasLeaveToday = false;
                this.todayLeaveInfo = {};
                this.leaveMessage = '';
                console.log('ℹ️ No leave for today');
            }
        } catch (error) {
            console.error('Error checking leave:', error);
            this.hasLeaveToday = false;
            this.todayLeaveInfo = {};
            this.leaveMessage = '';
        }
    }

    async initializeComponent() {
        try {
            this.isLoading = true;
            console.log('=== Initializing attendance component with multiple sessions support ===');
            this.monthName = new Date().toLocaleDateString('en-US', { 
                month: 'long', 
                year: 'numeric' 
            });

            await Promise.allSettled([
                this.loadTodayAttendance().catch(error => {
                    console.error('Could not load today attendance:', error);
                }),
                this.loadMonthlySummary().catch(error => {
                    console.error('Could not load monthly summary:', error);
                    this.resetSummaryData();
                }),
                this.loadExistingAttendanceRecords().catch(error => {
                    console.error('Could not load existing attendance records:', error);
                    this.allAttendanceRecords = [];
                    this.attendanceRecords = [];
                    this.setupPagination();
                }),
                this.checkTodayLeave().catch(error => {
                    console.error('Could not check today leave:', error);
                }),
                this.checkHybridSchedule().catch(error => {
                    console.error('Could not check hybrid schedule:', error);
                }),

                this.checkYesterdayAttendance().catch(error => {
    console.error('Could not check yesterday attendance:', error);
})
            ]);

            console.log('✅ Component initialization completed');
            
        } catch (error) {
            console.error('Error initializing component:', error);
        } finally {
            this.isLoading = false;
        }
    }

    startTimeInterval() {
        this.timeInterval = setInterval(() => {
            this.updateCurrentTime();
            if (this.isCheckedIn && !this.isCheckedOut && this.todayCheckInTime) {
                this.calculateTotalDailyHours();
            }
        }, 1000);
    }

    updateCurrentTime() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit',
            hour12: true
        });
    }

    updateCurrentDate() {
        const now = new Date();
        this.currentDate = now.toLocaleTimeString('en-US', {
            weekday: 'long',
            year: 'numeric',
            month: 'long',
            day: 'numeric'
        });
    }

    // ✅ NEW: Calculate total hours across all sessions
    calculateTotalDailyHours() {
        let totalHours = 0;
        
        if (this.allTodaySessions && this.allTodaySessions.length > 0) {
            this.allTodaySessions.forEach(session => {
                if (session.hoursWorked && session.hoursWorked > 0) {
                    totalHours += parseFloat(session.hoursWorked);
                }
            });
        }
        
        // Add current session hours if checked in but not checked out
        if (this.isCheckedIn && !this.isCheckedOut && this.todayCheckInTime) {
            const now = new Date();
            const checkInTime = new Date();
            const [time, modifier] = this.todayCheckInTime.split(' ');
            const [hours, minutes] = time.split(':');
            let hour = parseInt(hours);
            
            if (modifier === 'PM' && hour !== 12) {
                hour += 12;
            } else if (modifier === 'AM' && hour === 12) {
                hour = 0;
            }
            
            checkInTime.setHours(hour);
            checkInTime.setMinutes(parseInt(minutes));
            checkInTime.setSeconds(0);
            
            const timeDiff = now.getTime() - checkInTime.getTime();
            const currentSessionHours = (timeDiff / (1000 * 60 * 60));
            totalHours += Math.max(0, currentSessionHours);
        }
        
        this.hoursWorkedToday = totalHours.toFixed(1);
        this.actualHoursWorked = totalHours.toFixed(1);
        
        console.log('⏱️ Total hours worked today across all sessions:', this.actualHoursWorked);
    }

    // ✅ UPDATED: Load today's attendance with multiple sessions support
    async loadTodayAttendance() {
        if (!this.employeeId) {
            console.log('⚠️ No employee ID available');
            return;
        }

        try {
            console.log('📅 Loading today\'s attendance sessions for employee:', this.employeeId);
            
            const result = await getTodayAttendanceRecord({ 
                employeeId: this.employeeId
            });

            console.log('📊 Today\'s attendance result:', JSON.stringify(result, null, 2));

            if (result && result.success) {
                if (result.hasRecords) {
                    console.log('✅ Found ' + result.totalSessions + ' session(s) for today');
                    
                    this.allTodaySessions = result.allSessions || [];
                    this.todaySessionNumber = result.totalSessions || 0;
                    
                    const lastSession = result.lastSession;
                    
                    if (lastSession) {
                        this.currentSessionId = lastSession.recordId;
                        this.isCheckedIn = lastSession.isCheckedIn;
                        this.isCheckedOut = lastSession.isCheckedOut;
                        this.todayAttendanceId = lastSession.recordId;
                        
                        if (this.isCheckedIn && lastSession.checkInTime) {
                            const checkInDateTime = new Date(lastSession.checkInTime);
                            this.todayCheckInTime = checkInDateTime.toLocaleTimeString('en-US', {
                                hour: '2-digit',
                                minute: '2-digit',
                                hour12: true
                            });
                            this.workLocation = lastSession.workLocation || 'Office';
                        }
                        
                        this.canStartNewSession = this.isCheckedIn && this.isCheckedOut;
                        this.lastSessionCheckOut = lastSession.checkOutTime;
                        
                        this.calculateTotalDailyHours();
                        
                        console.log('📊 Session State:', {
                            sessionNumber: this.todaySessionNumber,
                            currentSessionId: this.currentSessionId,
                            isCheckedIn: this.isCheckedIn,
                            isCheckedOut: this.isCheckedOut,
                            canStartNewSession: this.canStartNewSession
                        });
                        
                    } else {
                        console.log('ℹ️ No sessions found for today - ready for first check-in');
                        this.resetTodayAttendanceState();
                    }
                    
                } else {
                    console.log('ℹ️ No attendance record found for today - ready for check-in');
                    this.resetTodayAttendanceState();
                }
            } else {
                console.error('❌ Error in result:', result.error);
                this.resetTodayAttendanceState();
            }

        } catch (error) {
            console.error('❌ Error loading today\'s attendance:', error);
            console.error('Error details:', JSON.stringify(error, null, 2));
            this.resetTodayAttendanceState();
        }
    }


    /**
 * Schedules auto-checkout at 11:59 PM.
 * Call this after every successful check-in.
 */
scheduleAutoCheckout() {
    // Clear any existing timer first
    if (this.autoCheckoutTimer) {
        clearTimeout(this.autoCheckoutTimer);
        this.autoCheckoutTimer = null;
    }

    // Only schedule if currently checked in
    if (!this.isCheckedIn || this.isCheckedOut) {
        console.log('⏰ Auto-checkout not needed - not currently checked in');
        return;
    }

    const now       = new Date();
    const midnight  = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 0, 0);
    const msLeft    = midnight.getTime() - now.getTime();

    if (msLeft <= 0) {
        // Already past 11:59 PM - trigger immediately
        console.log('⚠️ Already past 11:59 PM - triggering auto-checkout now');
        this.triggerAutoCheckout();
        return;
    }

    const h = Math.floor(msLeft / 3600000);
    const m = Math.floor((msLeft % 3600000) / 60000);
    console.log(`⏰ Auto-checkout scheduled in ${h}h ${m}m (at 11:59 PM)`);

    // ── Warning toast 30 minutes before (at ~11:29 PM) ────────────
    const msWarning = msLeft - (30 * 60 * 1000);
    if (msWarning > 0) {
        setTimeout(() => {
            this.showToast(
                '⚠️ Checkout Reminder',
                'You will be automatically checked out in 30 minutes at 11:59 PM. Please check out manually if you have finished work.',
                'warning'
            );
        }, msWarning);
    }

    // ── Main auto-checkout timer ───────────────────────────────────
    this.autoCheckoutTimer = setTimeout(() => {
        console.log('⏰ 11:59 PM reached — triggering auto-checkout...');
        this.triggerAutoCheckout();
    }, msLeft);
}


/**
 * Calls Apex autoCheckOut() and updates the UI.
 */
async triggerAutoCheckout() {
    // Guard: only run if still open
    if (!this.isCheckedIn || this.isCheckedOut) {
        console.log('✅ Already checked out - auto-checkout skipped');
        return;
    }
    if (!this.todayAttendanceId) {
        console.log('⚠️ No attendance record ID - cannot auto-checkout');
        return;
    }

    try {
        this.isLoading = true;
        console.log('📤 Auto-checkout calling Apex for record:', this.todayAttendanceId);

        const result = await autoCheckOut({ recordId: this.todayAttendanceId });

        if (result.success) {
            console.log('✅ Auto-checkout successful:', result.message);

            // Update local state
            this.isCheckedOut       = true;
            this.canStartNewSession = true;
            this.actualHoursWorked  = result.hoursWorked || '0.0';

            this.showToast(
                '🕛 Auto Checkout Complete',
                `You were automatically checked out at 11:59 PM. Hours worked: ${result.hoursWorked}h. Please check out manually next time.`,
                'warning'
            );

            // Refresh UI
            await Promise.allSettled([
                this.loadTodayAttendance(),
                this.loadMonthlySummary().catch(e => console.log('Summary refresh error:', e)),
                this.loadExistingAttendanceRecords().catch(e => console.log('Records refresh error:', e))
            ]);

        } else {
            console.error('❌ Auto-checkout failed:', result.error);
            this.showToast(
                'Auto Checkout Failed',
                result.error || 'Could not auto-checkout. Please check out manually.',
                'error'
            );
        }

    } catch (error) {
        console.error('❌ Auto-checkout error:', error);
        this.showToast(
            'Auto Checkout Error',
            'An error occurred: ' + (error.body?.message || error.message),
            'error'
        );
    } finally {
        this.isLoading         = false;
        this.autoCheckoutTimer = null;
    }
}

    // ===================================================================
    // CONTINUING FROM PREVIOUS MESSAGE...
    // ===================================================================

    async loadMonthlySummary() {
        if (!this.employeeId) return;
        
        try {
            this.isLoadingSummary = true;
            this.summaryError = '';
            
            const result = await getMonthlySummary({ userId: this.employeeId });
            
            if (result.success) {
                this.summaryData = {
                    presentDays: result.presentDays.toString(),
                    lateDays: result.lateDays.toString(),
                    absentDays: result.absentDays.toString(),
                    approvedLeaveDays: result.approvedLeaveDays.toString(),
                    lopDays: result.lopDays.toString(),
                    totalHours: result.totalHours,
                    avgHours: result.avgHoursPerDay,
                    attendanceRate: result.attendanceRate
                };
                
                this.monthName = result.monthName;
                this.totalWorkingDays = result.totalWorkingDays;
                this.recordsFound = result.recordsFound;
                
            } else {
                this.summaryError = result.error || 'Failed to load summary';
                this.resetSummaryData();
            }
        } catch (error) {
            this.summaryError = 'Field access restricted';
            this.resetSummaryData();
        } finally {
            this.isLoadingSummary = false;
        }
    }

    resetSummaryData() {
        this.summaryData = {
            presentDays: '0',
            lateDays: '0',
            absentDays: '0',
            approvedLeaveDays: '0',
            lopDays: '0',
            totalHours: '0.0',
            avgHours: '0.0',
            attendanceRate: '0'
        };
        this.monthName = new Date().toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
        this.totalWorkingDays = 0;
        this.recordsFound = 0;
    }

    async loadExistingAttendanceRecords() {
        if (!this.employeeId) return;
        
        try {
            console.log('📋 Loading existing Employee Attendance records...');
            
            const result = await getEmployeeAttendanceRecords({ 
                employeeId: this.employeeId,
                limitRecords: 200
            });
            
            if (result && result.success && result.records) {
                this.allAttendanceRecords = result.records.map((record, index) => {
                    return {
                        Id: record.recordId || `record-${index}`,
                        displayDate: record.displayDate || record.attendanceDate || '--',
                        displayCheckIn: record.displayCheckIn || record.checkInTime || '--',
                        displayCheckOut: record.displayCheckOut || record.checkOutTime || '--',
                        displayHours: record.displayHours || record.hoursWorked || '--',
                        displayStatus: record.displayStatus || record.status || 'Present',
                        displayLocation: record.displayLocation || record.locationDisplay || 'Office',
                        displayNotes: record.displayNotes || record.notes || '--',

                        // ✅ NEW: Session information
                        sessionNumber: record.sessionNumber || 1,
                        isMultipleSession: record.isMultipleSession || false,
                        sessionDisplay: 'Session ' + (record.sessionNumber || 1),

                        branchName: record.branchName || null,
                        branchCity: record.branchCity || null,
                        branchState: record.branchState || null,
                        hasBranch: record.hasBranch || false,
                        
                        isOfficeWork: record.isOfficeWork || false,
                        isClientPlace: record.isClientPlace || false,
                        isFieldWork: record.isFieldWork || false,
                        isWFH: record.isWFH || false,
                        
                        submittedForApproval: record.submittedForApproval || false,
                        wfhApprovalStatus: record.wfhApprovalStatus || null,
                        wfhApprovalStatusText: record.wfhApprovalStatusText || '--',
                        wfhApprovalBadgeClass: record.wfhApprovalBadgeClass || 'approval-badge approval-none',
                        
                        // ✅ OD Approval Status
                        isODRequest: record.isODRequest || false,
                        odApprovalStatus: record.odApprovalStatus || null,
                        odApprovalStatusText: record.odApprovalStatusText || '--',
                        odApprovalBadgeClass: record.odApprovalBadgeClass || 'approval-badge approval-none',
                        
                        approvalComments: record.approvalComments || null,
                        wfhReason: record.wfhReason || null,
                        
                        clientPlaceDetails: record.clientPlaceDetails || null,
                        fieldWorkDetails: record.fieldWorkDetails || null,
                        
                        statusBadgeClass: this.getStatusClass(record.status || 'Present'),
                        hasData: true,
                        recordNumber: index + 1,
                        createdDate: record.createdDate,
                        lastModified: record.lastModifiedDate
                    };
                });
                
                this.totalRecords = this.allAttendanceRecords.length;
                this.setupPagination();
                
                console.log(`✅ Loaded ${this.totalRecords} existing attendance records`);
                
            } else if (result && result.records && result.records.length === 0) {
                console.log('ℹ️ No existing attendance records found');
                this.allAttendanceRecords = [];
                this.attendanceRecords = [];
                this.totalRecords = 0;
                this.setupPagination();
                
            } else {
                const errorMessage = result ? (result.error || result.message || 'Unknown error') : 'Failed to load records';
                console.error('❌ Apex method returned error:', errorMessage);
                
                this.allAttendanceRecords = [];
                this.attendanceRecords = [];
                this.totalRecords = 0;
                this.setupPagination();
            }
            
        } catch (error) {
            console.error('❌ Error loading existing attendance records:', error);
            
            this.allAttendanceRecords = [];
            this.attendanceRecords = [];
            this.totalRecords = 0;
            this.setupPagination();
        }
    }

    getWFHApprovalStatusText(status) {
        if (!status) return 'Pending';
        
        switch (status.toLowerCase()) {
            case 'approved':
                return 'Approved';
            case 'rejected':
                return 'Rejected';
            case 'pending':
            default:
                return 'Pending';
        }
    }

    getWFHApprovalBadgeClass(status) {
        if (!status) return 'approval-badge approval-pending';
        
        switch (status.toLowerCase()) {
            case 'approved':
                return 'approval-badge approval-approved';
            case 'rejected':
                return 'approval-badge approval-rejected';
            case 'pending':
            default:
                return 'approval-badge approval-pending';
        }
    }

    setupPagination() {
        this.totalPages = Math.ceil(this.totalRecords / this.pageSize);
        this.showPagination = this.totalRecords > this.pageSize;
        
        if (this.currentPage > this.totalPages) {
            this.currentPage = 1;
        }
        
        if (this.currentPage < 1) {
            this.currentPage = 1;
        }
        
        this.updateDisplayedRecords();
    }

    updateDisplayedRecords() {
        if (this.totalRecords === 0) {
            this.attendanceRecords = [];
            return;
        }
        
        const startIndex = (this.currentPage - 1) * this.pageSize;
        const endIndex = startIndex + this.pageSize;
        
        this.attendanceRecords = this.allAttendanceRecords.slice(startIndex, endIndex);
    }

    handleFirstPage() {
        this.currentPage = 1;
        this.updateDisplayedRecords();
    }

    handlePreviousPage() {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.updateDisplayedRecords();
        }
    }

    handleNextPage() {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.updateDisplayedRecords();
        }
    }

    handleLastPage() {
        this.currentPage = this.totalPages;
        this.updateDisplayedRecords();
    }

    handlePageSizeChange(event) {
        const newPageSize = parseInt(event.target.value);
        if (newPageSize && newPageSize > 0) {
            this.pageSize = newPageSize;
            this.currentPage = 1;
            this.setupPagination();
        }
    }

    getStatusClass(status) {
        if (!status) return 'status-badge status-present';
        
        switch (status.toLowerCase().trim()) {
            case 'present':
                return 'status-badge status-present';
            case 'late':
                return 'status-badge status-late';
            case 'half day':
            case 'halfday':
                return 'status-badge status-half-day';
            case 'absent':
                return 'status-badge status-absent';
            default:
                return 'status-badge status-present';
        }
    }

    async refreshUserData() {
        try {
            this.isLoading = true;
            console.log('Refreshing attendance data...');

            await Promise.allSettled([
                this.loadTodayAttendance().catch(error => {
                    console.log('Could not refresh today attendance:', error);
                }),
                this.loadMonthlySummary().catch(error => {
                    console.log('Could not refresh monthly summary:', error);
                }),
                this.loadExistingAttendanceRecords().catch(error => {
                    console.log('Could not refresh existing attendance records:', error);
                }),
                this.checkTodayLeave().catch(error => {
                    console.log('Could not refresh leave check:', error);
                }),
                this.checkHybridSchedule().catch(error => {
                    console.log('Could not refresh hybrid schedule:', error);
                })
            ]);

            const recordCount = this.totalRecords;
            this.showToast('Refresh Complete', `Data refreshed! Showing ${recordCount} records.`, 'success');

        } catch (error) {
            console.error('Error refreshing data:', error);
            this.showToast('Error', 'Failed to refresh data', 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ===================================================================
    // WORK LOCATION HANDLERS
    // ===================================================================

   async handleWorkLocationChange(event) {
    const newLocation = event.detail.value;

    // ── Reset all conditional sections ───────────────────────────────
    this.selectedWorkLocation      = newLocation;
    this.showBranchDropdown        = false;
    this.showWFHReasonSection      = false;
    this.showClientPlaceDetails    = false;
    this.showFieldWorkDetails      = false;
    this.showBusinessTravelSection = false;
    this.requiresApproval          = false;
    this.selectedBranchId          = '';
    this.selectedBranchName        = '';
    this.wfhReason                 = '';
    this.wfhReasonCharCount        = 0;
    this.clientPlaceDetails        = '';
    this.clientPlaceCharCount      = 0;
    this.fieldWorkDetails          = '';
    this.fieldWorkCharCount        = 0;
    this.businessTravelDetails     = '';
    this.businessTravelStartDate   = '';
    this.businessTravelEndDate     = '';
    this.businessTravelCharCount   = 0;
    this.fileData                  = null;
    this.uploadedFileName          = '';
    this.isFileUploaded            = false;

    // ── WFH: check for existing Pending / Approved request ───────────
    if (newLocation === 'Work from Home') {
        this.isCheckingWFHRequest = true;

        try {
            const today  = new Date().toISOString().split('T')[0];
            const result = await checkEmployeeWFHRequest({
                employeeId: this.employeeId,
                checkDate:  today
            });

            if (result.success && result.hasValidRequest) {
                // ✅ Valid WFH request found — allow check-in
                const statusLabel = result.status === 'Approved' ? '✅ Approved' : '🕐 Pending Approval';
                this.showToast(
                    'WFH Request Found',
                    `Your Work From Home request is ${statusLabel}. You may proceed with check-in.`,
                    'success'
                );
                console.log('✅ WFH request found — status:', result.status);

            } else {
                // ❌ No valid WFH request — block and redirect to WFH tab
                this.selectedWorkLocation = '';

                await LightningAlert.open({
                    label: 'WFH Request Required',
                    message:
                        'You do not have an active Work From Home request for today. ' +
                        'Please submit a WFH request first. Redirecting you to the WFH Request page now.',
                    theme: 'warning'
                });

                // Close the check-in modal first
                this.showCheckInModal = false;

                // Fire event up to dashboard to navigate to WFH tab
                const navigateEvent = new CustomEvent('navigatetowfh', {
                    bubbles: true,
                    composed: true
                });
                this.dispatchEvent(navigateEvent);
            }

        } catch (error) {
            console.error('❌ Error checking WFH request:', error);
            this.selectedWorkLocation = '';
            this.showToast(
                'Error',
                'Unable to verify WFH request. Please try again.',
                'error'
            );
        } finally {
            this.isCheckingWFHRequest = false;
        }
        return; // always exit early for WFH branch
    }

    // ── All other work locations ──────────────────────────────────────
    if (newLocation === 'Work from Office') {
        this.showBranchDropdown = true;

    } else if (newLocation === 'Client Place') {
        this.showClientPlaceDetails = true;

    } else if (newLocation === 'Field Work') {
        this.showFieldWorkDetails = true;

    } else if (newLocation === 'Business Travel') {
        this.showBusinessTravelSection = true;
    }
}
    async handleBranchChange(event) {
        this.selectedBranchId = event.detail.value;
        
        console.log('🏢 Branch selected - ID:', this.selectedBranchId);
        
        if (this.selectedBranchId) {
            try {
                const result = await getBranchDetails({ 
                    branchId: this.selectedBranchId 
                });
                
                if (result.success) {
                    this.selectedBranchName = result.branchName;
                    console.log('✅ Branch name retrieved:', this.selectedBranchName);
                } else {
                    console.error('❌ Failed to get branch details:', result.error);
                    this.showToast('Error', 
                        'Unable to retrieve branch details: ' + result.error, 
                        'error');
                }
            } catch (error) {
                console.error('❌ Error getting branch details:', error);
                this.showToast('Error', 
                    'Failed to get branch information: ' + (error.body?.message || error.message), 
                    'error');
            }
        } else {
            this.selectedBranchName = '';
        }
    }

    handleClientPlaceDetailsChange(event) {
        this.clientPlaceDetails = event.detail.value;
        this.clientPlaceCharCount = this.clientPlaceDetails ? this.clientPlaceDetails.length : 0;
    }

    handleFieldWorkDetailsChange(event) {
        this.fieldWorkDetails = event.detail.value;
        this.fieldWorkCharCount = this.fieldWorkDetails ? this.fieldWorkDetails.length : 0;
    }

    handleWFHReasonChange(event) {
        this.wfhReason = event.detail.value;
        this.wfhReasonCharCount = this.wfhReason ? this.wfhReason.length : 0;
    }

    handleBusinessTravelDetailsChange(event) {
        this.businessTravelDetails = event.detail.value;
        this.businessTravelCharCount = this.businessTravelDetails ? this.businessTravelDetails.length : 0;
    }

    handleBusinessTravelStartDateChange(event) {
        this.businessTravelStartDate = event.detail.value;
    }

    handleBusinessTravelEndDateChange(event) {
        this.businessTravelEndDate = event.detail.value;
    }

    // ===================================================================
    // BUSINESS TRAVEL FILE UPLOAD
    // ===================================================================

    handleBusinessTravelFileUpload(event) {
        const file = event.target.files[0];
        
        if (!file) return;
        
        console.log('✈️ File selected:', file.name, 'Size:', file.size);
        
        const maxSize = 5 * 1024 * 1024;
        if (file.size > maxSize) {
         LightningAlert.open({
        label: 'File Size Limit Exceeded',
        message: 'File size must be less than 5 MB.',
        theme: 'error'
    });
            event.target.value = '';
            return;
        }
        
        var reader = new FileReader();
        reader.onload = () => {
            var base64 = reader.result.split(',')[1];
            this.fileData = {
                'filename': file.name,
                'base64': base64,
                'recordId': null
            };
            this.uploadedFileName = file.name;
            this.isFileUploaded = true;
            
        console.log('✅ File processed:', this.fileData.filename);
        LightningAlert.open({
        label: 'Upload Ready',
        message: `File "${file.name}" is ready to upload.`,
        theme: 'success'
    });
        };
        
        reader.onerror = () => {
            this.showToast('Error', 'Failed to read file', 'error');
            this.fileData = null;
            this.uploadedFileName = '';
            this.isFileUploaded = false;
        };
        
        reader.readAsDataURL(file);
        event.target.value = '';
    }

    handleRemoveFile() {
        this.fileData = null;
        this.uploadedFileName = '';
        this.isFileUploaded = false;
     LightningAlert.open({
    label: 'Success',
    message: 'File removed successfully.',
    theme: 'success'
});

    }

    // ===================================================================
    // GPS LOCATION METHODS
    // ===================================================================

    getCurrentLocation() {
        console.log('📍 Getting current location...');
        this.isGettingLocation = true;
        this.locationErrorMessage = 'Requesting location permission...';
        this.hasValidLocation = false;
        
        if (!navigator.geolocation) {
            this.handleLocationError('Geolocation is not supported by this browser');
            return;
        }

        const options = {
            enableHighAccuracy: true,
            timeout: 30000,
            maximumAge: 0
        };

        navigator.geolocation.getCurrentPosition(
            (position) => {
                console.log('✅ Location success:', position);
                this.handleLocationSuccess(position);
            },
            (error) => {
                console.error('❌ Location error:', error);
                this.handleLocationError(this.getLocationErrorMessage(error));
                this.promptLocationSettings();
            },
            options
        );
    }

    async handleLocationSuccess(position) {
        this.latitude = position.coords.latitude.toFixed(6);
        this.longitude = position.coords.longitude.toFixed(6);
        this.locationAccuracy = Math.round(position.coords.accuracy);
        
        console.log('📍 Location captured:', {
            lat: this.latitude,
            lng: this.longitude,
            accuracy: this.locationAccuracy
        });
        
        await this.reverseGeocode(this.latitude, this.longitude);
    }

    async reverseGeocode(lat, lng) {
        try {
            console.log('🌍 Getting location details for coordinates:', lat, lng);
            
            const result = await getReverseGeocode({ 
                latitude: parseFloat(lat), 
                longitude: parseFloat(lng) 
            });
            
            if (result.success) {
                this.locationArea = result.mainAreaName || result.areaName || 'Unknown Area';
                this.locationCity = result.cityName || 'Unknown Location';
                this.locationState = result.stateName || 'Unknown State';
                this.locationCountry = result.countryName || 'Unknown Country';
                
                this.locationName = result.displayName || `${lat}, ${lng}`;
                this.displayLocationName = this.locationName;
                this.fullLocationAddress = result.fullAddress || `Coordinates: ${lat}, ${lng}`;
                
            } else {
                this.setFallbackLocation(lat, lng);
            }
            
        } catch (error) {
            console.error('❌ Reverse geocoding error:', error);
            this.setFallbackLocation(lat, lng);
        } finally {
            this.hasValidLocation = true;
            this.isGettingLocation = false;
            this.locationErrorMessage = '';
            await LightningAlert.open({
    label: 'Location Captured',
    message: `Location captured: ${this.displayLocationName}`,
    theme: 'success'
});

        }
    }

    setFallbackLocation(lat, lng) {
        this.locationArea = 'Unknown Area';
        this.locationName = `Location: ${lat}, ${lng}`;
        this.locationState = 'Unknown';
        this.locationCountry = 'Unknown';
        this.locationCity = 'Unknown';
        this.displayLocationName = `Coordinates: ${lat}, ${lng}`;
        this.fullLocationAddress = `Coordinates: ${lat}, ${lng}`;
    }

    handleLocationError(message) {
        this.hasValidLocation = false;
        this.isGettingLocation = false;
        this.locationErrorMessage = message;
        this.latitude = '';
        this.longitude = '';
        this.locationAccuracy = '';
        this.locationName = '';
        this.locationState = '';
        this.locationCountry = '';
        this.locationCity = '';
        this.locationArea = '';
        this.displayLocationName = '';
        this.fullLocationAddress = '';
        
     
    LightningAlert.open({
    label: 'Warning',
    message: message,
    theme: 'warning'
});

    }

    getLocationErrorMessage(error) {
        switch (error.code) {
            case error.PERMISSION_DENIED:
                return "Location access denied. Please enable location in your browser settings.";
            case error.POSITION_UNAVAILABLE:
                return "Location information is unavailable. Please check your GPS settings.";
            case error.TIMEOUT:
                return "Location request timed out. Please try again.";
            default:
                return "Unable to get location. Please enable location services.";
        }
    }

    promptLocationSettings() {
        const message = `To use attendance tracking, please:
        1. Click the location icon in your browser's address bar
        2. Allow location access for this site
        3. Refresh the page and try again`;

         LightningAlert.open({
    label: 'Location Permission Required',
    message: message,
    theme: 'info'
});

    }

    // ===================================================================
    // CAMERA METHODS
    // ===================================================================

    async captureCheckInPhoto() {
        this.currentPhotoType = 'checkin';
        await this.openCamera();
    }

    async captureCheckOutPhoto() {
        this.currentPhotoType = 'checkout';
        await this.openCamera();
    }

    async openCamera() {
        console.log('📸 Opening camera for:', this.currentPhotoType);
        
        try {
            this.isCapturingPhoto = true;
            
            if (!navigator.mediaDevices || !navigator.mediaDevices.getUserMedia) {
                throw new Error('Camera not supported on this device');
            }

            const stream = await navigator.mediaDevices.getUserMedia({
                video: { 
                    facingMode: 'environment',
                    width: { ideal: 1280 },
                    height: { ideal: 720 }
                }
            });

            this.capturePhotoFromStream(stream);

        } catch (error) {
            console.error('❌ Camera error:', error);
            this.isCapturingPhoto = false;
            
            if (error.name === 'NotAllowedError') {
          LightningAlert.open({
        message: 'Please allow camera access in your browser settings.',
        theme: 'warning',
        label: 'Camera Permission Required'
    });
            } else if (error.name === 'NotFoundError') {
        LightningAlert.open({
        message: 'No camera device found on this device.',
        theme: 'error',
        label: 'No Camera Found'
    });
            } else {
                this.openFileInput();
            }
        }
    }

    capturePhotoFromStream(stream) {
        const video = document.createElement('video');
        video.srcObject = stream;
        video.autoplay = true;
        video.playsInline = true;
        
        video.addEventListener('loadedmetadata', () => {
            video.play();
            
            setTimeout(() => {
                const canvas = document.createElement('canvas');
                const context = canvas.getContext('2d');
                
                canvas.width = video.videoWidth;
                canvas.height = video.videoHeight;
                
                context.drawImage(video, 0, 0, canvas.width, canvas.height);
                
                const base64 = canvas.toDataURL('image/jpeg', 0.8).split(',')[1];
                const fileName = `${this.currentPhotoType}_${new Date().getTime()}.jpg`;
                
                if (this.currentPhotoType === 'checkin') {
                    this.checkInPhotoPreview = canvas.toDataURL('image/jpeg', 0.8);
                    this.checkInPhotoB64 = base64;
                    this.checkInPhotoName = fileName;
                } else if (this.currentPhotoType === 'checkout') {
                    this.checkOutPhotoPreview = canvas.toDataURL('image/jpeg', 0.8);
                    this.checkOutPhotoB64 = base64;
                    this.checkOutPhotoName = fileName;
                }
                
                stream.getTracks().forEach(track => track.stop());
                
                this.isCapturingPhoto = false;
                //this.showToast('Success', 'Photo captured successfully!', 'success');
                 LightningAlert.open({
    label: 'Success',
    message: 'Photo captured successfully!',
    theme: 'success'
});

                
            }, 1000);
        });
    }

    openFileInput() {
        const fileInput = this.template.querySelector('.camera-input');
        if (fileInput) {
            fileInput.dataset.fieldName = this.currentPhotoType;
            fileInput.accept = 'image/*';
            fileInput.capture = 'environment';
            fileInput.click();
        } else {
            console.error('❌ Camera input not found');
            this.showToast('Error', 'Camera not available', 'error');
        }
    }

    handleFileSelect(event) {
        const file = event.target.files[0];
        const fieldName = event.target.dataset.fieldName;
        
        if (!file) {
            this.isCapturingPhoto = false;
            return;
        }

        if (!file.type.startsWith('image/')) {
            this.showToast('Error', 'Please select a valid image file', 'error');
            this.isCapturingPhoto = false;
            return;
        }

        const maxSize = 5 * 1024 * 1024;
        if (file.size > maxSize) {
            this.showToast('Error', 'Image size should be less than 5MB', 'error');
            this.isCapturingPhoto = false;
            return;
        }

        this.isCapturingPhoto = true;
        this.processPhotoFile(file, fieldName);
    }

    processPhotoFile(file, fieldName) {
        const reader = new FileReader();
        
        reader.onload = () => {
            try {
                const base64 = reader.result.split(',')[1];
                const fileName = `${fieldName}_${new Date().getTime()}.${file.type.split('/')[1]}`;
                
                if (fieldName === 'checkin') {
                    this.checkInPhotoPreview = reader.result;
                    this.checkInPhotoB64 = base64;
                    this.checkInPhotoName = fileName;
                } else if (fieldName === 'checkout') {
                    this.checkOutPhotoPreview = reader.result;
                    this.checkOutPhotoB64 = base64;
                    this.checkOutPhotoName = fileName;
                }
                
                this.isCapturingPhoto = false;
                //this.showToast('Success', 'Photo captured successfully!', 'success');
                 LightningAlert.open({
    label: 'Success',
    message: 'Photo captured successfully!',
    theme: 'success'
});

                
            } catch (error) {
                console.error('❌ Error processing photo:', error);
                this.isCapturingPhoto = false;
                //this.showToast('Error', 'Failed to process photo. Please try again.', 'error');
                 LightningAlert.open({
    label: 'Error',
    message: 'Failed to process photo. Please try again.',
    theme: 'error'
});

            }
        };
        
        reader.onerror = () => {
            this.isCapturingPhoto = false;
            //this.showToast('Error', 'Failed to read photo file', 'error');
             LightningAlert.open({
    label: 'Error',
    message: 'Failed to read photo file',
    theme: 'error'
});

        };
        
        reader.readAsDataURL(file);
        event.target.value = '';
    }

    // ===================================================================
    // ✅ UPDATED: CHECK ACTION HANDLER WITH MULTIPLE SESSIONS
    // ===================================================================

    handleCheckAction() {
        if (!this.currentUserName) {
            this.showToast('Error', 'User information not loaded. Please refresh the page.', 'error');
            LightningAlert.open({
        label: 'Error',
        message: 'User information not loaded. Please refresh the page.',
        theme: 'error'
    });


            return;
        }

        console.log('📌 Current states - CheckedIn:', this.isCheckedIn, 'CheckedOut:', this.isCheckedOut);
        console.log('📌 Session Number:', this.todaySessionNumber, 'Can Start New:', this.canStartNewSession);

        // ✅ NEW: Check if user can start a new session
        if (this.canStartNewSession) {
           // this.showToast('New Session', `Starting session ${this.todaySessionNumber + 1}. Previous sessions completed.`,  'info'  );
            LightningAlert.open({
    label: 'New Session',
    message: `Starting session ${this.todaySessionNumber + 1}. Previous sessions completed.`,
    theme: 'info'
});

            
            // Reset for new session
            this.isCheckedIn = false;
            this.isCheckedOut = false;
            this.todayAttendanceId = null;
            this.currentSessionId = null;
            
            this.openCheckInModal();
            
        } else if (!this.isCheckedIn && !this.isCheckedOut) {
            this.openCheckInModal();
            
        } else if (this.isCheckedIn && !this.isCheckedOut) {
            this.showCheckOutModal = true;
            
            setTimeout(() => {
                this.getCurrentLocation();
            }, 1000);
            
        } else {
            console.log('ℹ️ Session completed. Click again to start new session.');
            //this.showToast('Session Completed', 'Click "Start New Session" to begin another session today.', 'info');
     LightningAlert.open({
        label: 'Session Completed',
        message: 'Click "Start New Session" to begin another session today.',
        theme: 'info'
    });


        }
    }

    openCheckInModal() {
        this.showCheckInModal = true;
        this.selectedWorkLocation = '';
        this.showBranchDropdown = false;
        this.showWFHReasonSection = false;
        this.showClientPlaceDetails = false;
        this.showFieldWorkDetails = false;
        this.showBusinessTravelSection = false;
        this.requiresApproval = false;
        this.selectedBranchId = '';
        this.selectedBranchName = '';
        this.wfhReason = '';
        this.wfhReasonCharCount = 0;
        this.clientPlaceDetails = '';
        this.clientPlaceCharCount = 0;
        this.fieldWorkDetails = '';
        this.fieldWorkCharCount = 0;
        
        setTimeout(() => {
            this.getCurrentLocation();
        }, 1000);
    }

    closeModal() {
        this.showCheckInModal = false;
        this.showCheckOutModal = false;
        this.resetModalData();
    }

    resetModalData() {
        this.selectedBranchId = '';
        this.selectedBranchName = '';
        
        this.checkInPhotoPreview = '';
        this.checkOutPhotoPreview = '';
        this.checkInPhotoB64 = '';
        this.checkOutPhotoB64 = '';
        this.checkInPhotoName = '';
        this.checkOutPhotoName = '';
        this.checkInNotes = '';
        this.checkOutNotes = '';
        this.selectedWorkLocation = '';
        this.showBranchDropdown = false;
        this.showWFHReasonSection = false;
        this.showClientPlaceDetails = false;
        this.showFieldWorkDetails = false;
        this.requiresApproval = false;
        this.wfhReason = '';
        this.wfhReasonCharCount = 0;
        this.clientPlaceDetails = '';
        this.clientPlaceCharCount = 0;
        this.fieldWorkDetails = '';
        this.fieldWorkCharCount = 0;
        this.hasValidLocation = false;
        this.latitude = '';
        this.longitude = '';
        this.locationAccuracy = '';
        this.locationName = '';
        this.locationState = '';
        this.locationCountry = '';
        this.locationCity = '';
        this.locationArea = '';
        this.displayLocationName = '';
        this.fullLocationAddress = '';
        this.isGettingLocation = false;
        this.isCapturingPhoto = false;
        this.locationErrorMessage = 'Location not captured yet';
        
        if (this.cameraStream) {
            this.stopCameraStream();
        }
    }

    stopCameraStream() {
        if (this.cameraStream) {
            this.cameraStream.getTracks().forEach(track => track.stop());
            this.cameraStream = null;
        }
    }

    handleNotesChange(event) {
        const fieldName = event.target.name;
        if (fieldName === 'checkInNotes') {
            this.checkInNotes = event.target.value;
        } else if (fieldName === 'checkOutNotes') {
            this.checkOutNotes = event.target.value;
        }
    }

    // ===================================================================
    // ✅ UPDATED: CHECK-IN CONFIRMATION WITH SESSION NUMBER
    // ===================================================================


    async confirmCheckIn() {
        
        if (!this.selectedWorkLocation) {
          //  this.showToast('Error', 'Please select a work location', 'error');
            LightningAlert.open({
                message: result.error || 'Please select a work location',
                theme: 'error',
                label: 'Error'
            });
            return;
        }

        // Validate branch if Work from Office
        if (this.selectedWorkLocation === 'Work from Office') {
            if (!this.selectedBranchId || !this.selectedBranchName) {
              //  this.showToast('Error',   'Please select your branch office from the dropdown', 'error');
                LightningAlert.open({
                message: result.error || 'Please select your branch office from the dropdown',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
        }

        // Validate WFH reason if required
        if (this.requiresApproval && (!this.wfhReason || this.wfhReason.trim().length < 10)) {
            //this.showToast('Error', 'Please provide a detailed reason for working from home (minimum 10 characters)', 'error');
            this.errorMessage = 'Please provide a detailed reason for working from home (minimum 10 characters)';
            return;
        }

        // Validate Client Place details
        if (this.selectedWorkLocation === 'Client Place' && (!this.clientPlaceDetails || this.clientPlaceDetails.trim().length < 5)) {
           // this.showToast('Error', 'Please provide client place details (minimum 5 characters)', 'error');

                LightningAlert.open({
                message: result.error || 'Please provide client place details (minimum 5 characters)',
                theme: 'error',
                label: 'Error'
            });
            return;
        }

        // Validate Field Work details
        if (this.selectedWorkLocation === 'Field Work' && (!this.fieldWorkDetails || this.fieldWorkDetails.trim().length < 5)) {
           // this.showToast('Error', 'Please provide field work details (minimum 5 characters)', 'error');
            
               LightningAlert.open({
                message: result.error || 'Please provide field work details (minimum 5 characters)',
                theme: 'error',
                label: 'Error'
            });

            return;
        }

        // Validate Business Travel
        if (this.selectedWorkLocation === 'Business Travel') {
            if (!this.businessTravelDetails || this.businessTravelDetails.trim().length < 10) {
               // this.showToast('Error', 'Please provide business travel details (minimum 10 characters)', 'error');
                 LightningAlert.open({
                message: result.error || 'Please provide business travel details (minimum 10 characters)',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
            
            if (!this.businessTravelStartDate) {
               // this.showToast('Error', 'Please select travel start date', 'error');
                 LightningAlert.open({
                message: result.error || 'Please select travel start date',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
            
            if (!this.businessTravelEndDate) {
               // this.showToast('Error', 'Please select travel end date', 'error');
                 LightningAlert.open({
                message: result.error || 'Please select travel end date',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
            
            const startDate = new Date(this.businessTravelStartDate);
            const endDate = new Date(this.businessTravelEndDate);
            
            if (endDate < startDate) {
               // this.showToast('Error', 'End date cannot be before start date', 'error');
                 LightningAlert.open({
                message: result.error || 'End date cannot be before start date',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
            
            if (!this.fileData || !this.isFileUploaded) {
               // this.showToast('Error', 'Please upload at least one travel document', 'error');
                LightningAlert.open({
                message: result.error || 'Please upload at least one travel document',
                theme: 'error',
                label: 'Error'
            });
                return;
            }
        }

        if (!this.hasValidLocation) {
            //this.showToast('Error', 'Valid GPS location is required for check-in', 'error');

            LightningAlert.open({
                message: result.error || 'Valid GPS location is required for check-in',
                theme: 'error',
                 label: 'Error'
            });
            return;
        }

        if (!this.checkInPhotoB64) {
           // this.showToast('Error', 'Photo is required for check-in verification', 'error');

            LightningAlert.open({
                message: result.error || 'Photo is required for check-in verification',
                theme: 'error',
                 label: 'Error'
            });
            return;
        }

        this.isLoading = true;

        try {
            const now = new Date();
            const currentHour = now.getHours();
            const currentMinute = now.getMinutes();
            const isLate = currentHour > 9 || (currentHour === 9 && currentMinute > 15);
            
            const checkInDateTime = now.getFullYear() + '-' +
                String(now.getMonth() + 1).padStart(2, '0') + '-' +
                String(now.getDate()).padStart(2, '0') + ' ' +
                String(now.getHours()).padStart(2, '0') + ':' +
                String(now.getMinutes()).padStart(2, '0') + ':' +
                String(now.getSeconds()).padStart(2, '0');
            
            // ✅ NEW: Calculate session number
            const sessionNumber = this.todaySessionNumber + 1;
            
            // ✅ Build payload with SESSION NUMBER
            const payload = {
                Employee_Name__c: this.employeeId,
                Date__c: now.toISOString().split('T')[0],
                Check_In_Time__c: checkInDateTime,
                Work_Location__c: this.selectedWorkLocation,
                Check_In_Location__latitude__s: parseFloat(this.latitude),
                Check_In_Location__longitude__s: parseFloat(this.longitude),
                Check_In_Location_Name__c: this.displayLocationName,
                Check_In_State__c: this.locationState,
                Status__c: isLate ? 'Late' : 'Present',
                
                // ✅ NEW: Session tracking
                Session_Number__c: sessionNumber,
                Is_Multiple_Session__c: sessionNumber > 1,
                
                Notes__c: this.checkInNotes || 
                    `Session ${sessionNumber} check-in by ${this.currentUserName} via mobile app from ${this.displayLocationName}`,
                Check_In_Photo_B64: this.checkInPhotoB64,
                Check_In_Photo_Name: this.checkInPhotoName,
                
                'WFH_Reason__c': (this.requiresApproval || this.selectedWorkLocation === 'Work from Home') ? this.wfhReason : null,
                'Submitted_For_Approval__c': this.requiresApproval,
                'WFH_Approval_Status__c': (this.requiresApproval) ? 'Pending' : (this.autoApproveWFH ? 'Approved' : null),
                'Hybrid_Work_Schedule__c': (this.hasActiveHybridSchedule && this.selectedWorkLocation === 'Work from Home') ? this.hybridScheduleId : null,
                
                Client_Place_Details__c: this.selectedWorkLocation === 'Client Place' ? this.clientPlaceDetails : null,
                Field_Work_Details__c: this.selectedWorkLocation === 'Field Work' ? this.fieldWorkDetails : null,
                
                Business_Travel_Details__c: this.selectedWorkLocation === 'Business Travel' ? this.businessTravelDetails : null,
                Business_Travel_Start_Date__c: this.selectedWorkLocation === 'Business Travel' ? this.businessTravelStartDate : null,
                Business_Travel_End_Date__c: this.selectedWorkLocation === 'Business Travel' ? this.businessTravelEndDate : null
            };

            if (this.selectedWorkLocation === 'Work from Office' && this.selectedBranchId) {
                payload.Branch_Name__c = this.selectedBranchId;
            }

            console.log('✅ Check-in payload with session:', JSON.stringify(payload, null, 2));

            const result = await createAttendance({ payload: payload });

            if (result.success) {
                console.log('✅ Check-in successful - Session ' + sessionNumber + ', record ID:', result.recordId);
                
                this.isCheckedIn = true;
                this.scheduleAutoCheckout(); // ← ADD THIS LINE
                this.isCheckedOut = false;
                this.todayAttendanceId = result.recordId;
                this.currentSessionId = result.recordId;
                this.todaySessionNumber = sessionNumber;
                this.workLocation = this.selectedWorkLocation;
                this.todayCheckInTime = this.currentTime;
                this.canStartNewSession = false;
                
                this.showCheckInModal = false;

                // Upload file if Business Travel
                if (this.selectedWorkLocation === 'Business Travel' && this.fileData) {
                    console.log('✈️ Uploading travel document...');
                    
                    try {
                        const uploadResult = await uploadFile({
                            base64: this.fileData.base64,
                            filename: this.fileData.filename,
                            recordId: result.recordId
                        });
                        
                        if (uploadResult) {
                            console.log('✅ File uploaded successfully');
                           // this.showToast('Success',  `Session ${sessionNumber} started! Travel document uploaded.`,  'success'  );
                      LightningAlert.open({
                      message: result.message || `Session ${sessionNumber} started! Travel document uploaded.`,
                      theme: 'success',
                       label: 'Success'
                         });
                        } else {
                            this.showToast('Warning', 
                                'Check-in successful but file upload failed. Please upload manually.', 
                                'warning'
                            );
                        }
                    } catch (uploadError) {
                        console.error('❌ File upload error:', uploadError);
                        this.showToast('Warning',  'Check-in successful but file upload failed: ' + (uploadError.body?.message || uploadError.message), 'warning'
   );
                    }
                } else {
                    // ✅ UPDATED success message with session number
                    let successMessage = `Session ${sessionNumber} started! Checked in at ${this.displayLocationName}`;
                    
                    if (this.selectedWorkLocation === 'Work from Office' && this.selectedBranchName) {
                        successMessage += ` at ${this.selectedBranchName} branch`;
                    } else if (this.requiresApproval) {
                        successMessage += '. Your Work From Home request has been sent to ' + this.currentUserManagerName + ' for approval.';
                    } else if (this.autoApproveWFH && this.isScheduledWFH) {
                        successMessage += '. Working from home as per your approved hybrid schedule.';
                    } else if (this.selectedWorkLocation === 'Client Place') {
                        successMessage += `. Client visit recorded`;
                    } else if (this.selectedWorkLocation === 'Field Work') {
                        successMessage += `. Field work recorded`;
                    }
                    
                   // this.showToast('Success', successMessage, 'success');
                     LightningAlert.open({
    label: 'Success',
    message: successMessage,
    theme: 'success'
});

                }
                
                // Submit WFH approval if required
                if (this.requiresApproval && !this.autoApproveWFH) {
                    try {
                        console.log('📧 Submitting WFH approval for record:', result.recordId);
                        
                        const approvalResult = await submitWFHApproval({
                            attendanceRecordId: result.recordId,
                            employeeId: this.employeeId,
                            managerId: USER_ID,
                            reason: this.wfhReason
                        });
                        
                        if (approvalResult.success) {
                            this.showToast('Approval Submitted', 
                                `WFH approval request sent to ${this.currentUserManagerName}`, 
                                'success'
                            );
                        }
                    } catch (approvalError) {
                        console.error('❌ WFH Approval submission error:', approvalError);
                    }
                }

                this.resetModalData();
                
                // Refresh data
                await Promise.allSettled([
                    this.loadTodayAttendance(),
                    this.loadMonthlySummary().catch(e => console.log('Could not refresh summary')),
                    this.loadExistingAttendanceRecords().catch(e => console.log('Could not refresh records'))
                ]);

            } else {
                throw new Error(result.error || 'Unknown error occurred');
            }

        } catch (error) {
            console.error('❌ Check-in error:', error);
            this.showToast('Error', `Failed to check in: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    // ===================================================================
    // ✅ UPDATED: CHECK-OUT CONFIRMATION WITH SESSION NUMBER
    // ===================================================================

    async confirmCheckOut() {
        if (!this.hasValidLocation) {
            this.showToast('Error', 'Valid GPS location is required for check-out', 'error');
            return;
        }

        if (!this.checkOutPhotoB64) {
            this.showToast('Error', 'Photo is required for check-out verification', 'error');
            return;
        }

        if (!this.todayAttendanceId) {
            this.showToast('Error', 'No check-in record found for today. Please check in first.', 'error');
            return;
        }

        this.isLoading = true;

        try {
            const now = new Date();
            
            const checkOutDateTime = now.getFullYear() + '-' +
                String(now.getMonth() + 1).padStart(2, '0') + '-' +
                String(now.getDate()).padStart(2, '0') + ' ' +
                String(now.getHours()).padStart(2, '0') + ':' +
                String(now.getMinutes()).padStart(2, '0') + ':' +
                String(now.getSeconds()).padStart(2, '0');
            
            // ✅ UPDATED: Notes with session number
            const sessionNotes = this.checkOutNotes || 
                `Session ${this.todaySessionNumber} check-out by ${this.currentUserName} via mobile app from ${this.displayLocationName}`;
            
            const changes = {
                Check_Out_Time__c: checkOutDateTime,
                Check_Out_Location__latitude__s: parseFloat(this.latitude),
                Check_Out_Location__longitude__s: parseFloat(this.longitude),
                Check_Out_Location_Name__c: this.displayLocationName,
                Check_Out_State__c: this.locationState,
                Notes__c: sessionNotes,
                Check_Out_Photo_B64: this.checkOutPhotoB64,
                Check_Out_Photo_Name: this.checkOutPhotoName
            };

            console.log('🚪 Check-out changes for session ' + this.todaySessionNumber + ':', changes);

            const result = await updateAttendance({ 
                recordId: this.todayAttendanceId, 
                changes: changes 
            });
            
            if (result.success) {
                console.log('✅ Check-out successful for session ' + this.todaySessionNumber);
                
                this.isCheckedOut = true;
                this.canStartNewSession = true; // ✅ Allow new session
                this.lastSessionCheckOut = checkOutDateTime;
                
                this.showCheckOutModal = false;

                // ✅ Reload to get updated session data
                await this.loadTodayAttendance();

                this.showToast('Success', 
                    `Session ${this.todaySessionNumber} completed! Total hours today: ${this.actualHoursWorked}h. You can start a new session anytime.`, 
                    'success');

                this.resetModalData();
                
                // Refresh data
                await Promise.allSettled([
                    this.loadMonthlySummary().catch(e => console.log('Could not refresh summary')),
                    this.loadExistingAttendanceRecords().catch(e => console.log('Could not refresh records'))
                ]);

            } else {
                throw new Error(result.error || 'Unknown error occurred');
            }

        } catch (error) {
            console.error('❌ Check-out error:', error);
            this.showToast('Error', `Failed to check out: ${error.body?.message || error.message}`, 'error');
        } finally {
            this.isLoading = false;
        }
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable',
            duration: variant === 'error' ? 10000 : 5000
        });
        this.dispatchEvent(event);
    }

    // ===================================================================
    // ✅ UPDATED: BUTTON LABELS WITH SESSION SUPPORT
    // ===================================================================

    get isCheckDisabled() {
        if (this.hasLeaveToday) {
            return true;
        }
        
        if (this.isLoading || !this.currentUserName) {
            return true;
        }

        return false;
    }

    get isCheckInDisabled() {
        const baseValidation = !this.hasValidLocation || 
                              !this.selectedWorkLocation || 
                              !this.checkInPhotoB64 || 
                              this.isLoading || 
                              this.isGettingLocation ||
                              this.isCapturingPhoto ||
                              !this.currentUserName;
        
        if (baseValidation) {
            return true;
        }

        if (this.selectedWorkLocation === 'Work from Office') {
            return !this.selectedBranchId || !this.selectedBranchName;
        }
        
        if (this.selectedWorkLocation === 'Client Place') {
            return !this.clientPlaceDetails || this.clientPlaceDetails.trim().length < 5;
        }
        
        if (this.selectedWorkLocation === 'Field Work') {
            return !this.fieldWorkDetails || this.fieldWorkDetails.trim().length < 5;
        }
        
        if (this.selectedWorkLocation === 'Business Travel') {
            return !this.businessTravelDetails || 
                   this.businessTravelDetails.trim().length < 10 ||
                   !this.businessTravelStartDate ||
                   !this.businessTravelEndDate ||
                   !this.isFileUploaded;
        }
        
        if (this.requiresApproval) {
            return !this.wfhReason || this.wfhReason.trim().length < 10;
        }
        
        return false;
    }

    get isCheckOutDisabled() {
        return !this.hasValidLocation || 
               !this.checkOutPhotoB64 || 
               this.isLoading || 
               this.isGettingLocation ||
               this.isCapturingPhoto ||
               !this.currentUserName ||
               !this.todayAttendanceId;
    }

    get locationButtonLabel() {
        if (this.isGettingLocation) {
            return 'Getting Location...';
        }
        return this.hasValidLocation ? 'Update Location' : 'Get Current Location';
    }

    // ✅ UPDATED: Button labels with session support
    get checkButtonLabel() {
        if (this.hasLeaveToday) {
            return `On Leave Today - ${this.todayLeaveInfo.leaveCode || 'Leave'}`;
        }
        
        if (this.canStartNewSession) {
            return `Start Session ${this.todaySessionNumber + 1}`;
        }
        
        if (this.isCheckedIn && !this.isCheckedOut) {
            return `Check Out (Session ${this.todaySessionNumber})`;
        }

        if (this.todaySessionNumber > 0 && this.isCheckedOut) {
            return `Start Session ${this.todaySessionNumber + 1}`;
        }

        return 'Check In';
    }

    get leaveInfoForDisplay() {
        if (!this.hasLeaveToday || !this.todayLeaveInfo.leaveType) {
            return '';
        }
        
        let info = `${this.todayLeaveInfo.leaveType}`;
        
        if (this.todayLeaveInfo.isHalfDay && this.todayLeaveInfo.halfDayType) {
            info += ` (${this.todayLeaveInfo.halfDayType})`;
        }
        
        if (this.todayLeaveInfo.status) {
            info += ` - ${this.todayLeaveInfo.status}`;
        }
        
        return info;
    }

    get showLeaveInfoCard() {
        return this.hasLeaveToday && this.todayLeaveInfo.leaveType;
    }

    get checkInButtonLabel() {
        let baseLabel = '';
        if (this.requiresApproval) {
            baseLabel = 'Submit for Approval & Check In';
        } else if (this.selectedWorkLocation === 'Business Travel') {
            baseLabel = 'Upload Document & Check In';
        } else {
            baseLabel = 'Confirm Check In';
        }
        return baseLabel;
    }

    get locationText() {
        if (this.displayLocationName && this.displayLocationName !== '') {
            return this.displayLocationName;
        }
        return this.hasValidLocation ? `Location: ${this.latitude}, ${this.longitude}` : 'Location not set';
    }

    // ✅ UPDATED: Status with session info
    get checkStatus() {
        if (this.canStartNewSession) {
            return `${this.todaySessionNumber} session(s) completed today`;
        }
        if (this.isCheckedOut) return `Session ${this.todaySessionNumber} Completed`;
        if (this.isCheckedIn) return `Session ${this.todaySessionNumber} Active`;
        return 'Ready to Check In';
    }

    get shiftStart() {
        return this.todayCheckInTime || '9:30 AM';
    }

    get shiftEnd() {
        return this.isCheckedOut ? this.currentTime : '6:30 PM';
    }

    get lateStatusText() {
        if (this.isCheckedIn) {
            const now = new Date();
            const currentHour = now.getHours();
            const currentMinute = now.getMinutes();
            
            if (currentHour > 9 || (currentHour === 9 && currentMinute > 15)) {
                return 'Late';
            }
        }
        return 'On Time';
    }

    get lateBadgeClass() {
        const status = this.lateStatusText;
        return status === 'Late' ? 'late-badge' : 'on-time-badge';
    }

    get startRecord() {
        if (this.totalRecords === 0) return 0;
        return ((this.currentPage - 1) * this.pageSize) + 1;
    }

    get endRecord() {
        if (this.totalRecords === 0) return 0;
        const calculated = this.currentPage * this.pageSize;
        return calculated > this.totalRecords ? this.totalRecords : calculated;
    }

    get isFirstPage() {
        return this.currentPage === 1;
    }

    get isLastPage() {
        return this.currentPage === this.totalPages || this.totalPages === 0;
    }

    get showPreviousButton() {
        return !this.isFirstPage && this.showPagination;
    }

    get showNextButton() {
        return !this.isLastPage && this.showPagination;
    }

    get paginationInfo() {
        if (this.totalRecords === 0) {
            return 'No records found';
        }
        return `Showing ${this.startRecord} to ${this.endRecord} of ${this.totalRecords} records`;
    }

    get pageInfo() {
        if (this.totalPages === 0) return 'Page 0 of 0';
        return `Page ${this.currentPage} of ${this.totalPages}`;
    }

    get noRecordsFound() {
        return this.allAttendanceRecords.length === 0;
    }

    get presentDays() { return this.summaryData.presentDays; }
    get lateDays() { return this.summaryData.lateDays; }
    get absentDays() { return this.summaryData.absentDays; }
    get approvedLeaveDays() { return this.summaryData.approvedLeaveDays; }
    get lopDays() { return this.summaryData.lopDays; }
    get totalHours() { return this.summaryData.totalHours; }
    get avgHours() { return this.summaryData.avgHours; }
    get attendanceRate() { return this.summaryData.attendanceRate; }
    
    get summaryTitle() {
        if (this.isLoadingSummary) {
            return 'Loading Summary...';
        }
        if (this.summaryError) {
            return 'Summary Restricted';
        }
        return `${this.monthName}'s Summary`;
    }

    get summarySubtitle() {
        if (this.isLoadingSummary) {
            return 'Calculating attendance metrics';
        }
        if (this.summaryError) {
            return 'Field access restricted for summary data';
        }
        return `${this.recordsFound} records • ${this.totalWorkingDays} expected working days`;
    }

    get checkButtonClass() {
        let classes = ['check-button'];
        
        if (this.hasCompletedBothToday || (this.isCheckedIn && this.isCheckedOut)) {
            classes.push('completed-state');
        } else if (this.isCheckedIn && !this.isCheckedOut) {
            classes.push('checkout-ready-state');
        } else if (!this.isCheckedIn && !this.isCheckDisabled) {
            classes.push('ready-state');
        }
        
        return classes.join(' ');
    }

    // ===================================================================
    // HYBRID SCHEDULE MODAL METHODS (keeping existing code)
    // ===================================================================

    get minMonth() {
        const today = new Date();
        const year = today.getFullYear();
        const month = String(today.getMonth() + 1).padStart(2, '0');
        return `${year}-${month}`;
    }

    get hybridScheduleTypeOptions() {
        return [
            { label: 'Fixed Days (Same every week)', value: 'Fixed Days' },
            { label: 'Flexible', value: 'Flexible' },
            { label: 'Custom Pattern', value: 'Custom Pattern' }
        ];
    }

    get selectedHybridWFHDaysText() {
        const selected = this.hybridDaysOfWeek.filter(day => day.isWFH).map(day => day.label);
        return selected.length > 0 ? selected.join(', ') : 'None';
    }

    get selectedHybridOfficeDaysText() {
        const selected = this.hybridDaysOfWeek.filter(day => day.isOffice).map(day => day.label);
        return selected.length > 0 ? selected.join(', ') : 'None';
    }

    get hybridReasonCharCount() {
        return this.hybridScheduleReason ? this.hybridScheduleReason.length : 0;
    }

    get isHybridReasonTooShort() {
        return this.hybridReasonCharCount > 0 && this.hybridReasonCharCount < 20;
    }

    get showHybridSummary() {
        return this.hybridScheduleMonth && 
               (this.getSelectedHybridWFHDays().length > 0 || this.getSelectedHybridOfficeDays().length > 0);
    }

    get hybridScheduleMonthDisplay() {
        if (!this.hybridScheduleMonth) return '';
        const date = new Date(this.hybridScheduleMonth + '-01');
        return date.toLocaleDateString('en-US', { month: 'long', year: 'numeric' });
    }

    get totalHybridWFHDays() {
        return this.getSelectedHybridWFHDays().length;
    }

    get totalHybridOfficeDays() {
        return this.getSelectedHybridOfficeDays().length;
    }

    get isHybridSubmitDisabled() {
        return !this.hybridScheduleMonth || 
               (this.getSelectedHybridWFHDays().length === 0 && this.getSelectedHybridOfficeDays().length === 0) ||
               !this.hybridScheduleReason || 
               this.hybridScheduleReason.length < 20 ||
               this.isLoading;
    }

    openHybridScheduleModal() {
        console.log('Opening Hybrid Schedule Modal');
        this.showHybridScheduleModal = true;
        this.resetHybridScheduleForm();
    }

    closeHybridScheduleModal() {
        this.showHybridScheduleModal = false;
        this.resetHybridScheduleForm();
    }

    resetHybridScheduleForm() {
        this.hybridScheduleMonth = '';
        this.hybridScheduleType = 'Fixed Days';
        this.hybridScheduleReason = '';
        this.hybridDaysOfWeek = this.hybridDaysOfWeek.map(day => ({
            ...day,
            isWFH: false,
            isOffice: false
        }));
        this.hybridValidationError = false;
        this.hybridValidationErrorMessage = '';
    }

    handleHybridMonthChange(event) {
        this.hybridScheduleMonth = event.target.value;
        this.validateHybridForm();
    }

    handleHybridScheduleTypeChange(event) {
        this.hybridScheduleType = event.detail.value;
    }

    handleHybridWFHDayChange(event) {
        const dayValue = event.target.dataset.day;
        const isChecked = event.target.checked;

        this.hybridDaysOfWeek = this.hybridDaysOfWeek.map(day => {
            if (day.value === dayValue) {
                return { ...day, isWFH: isChecked };
            }
            return day;
        });

        this.validateHybridForm();
    }

    handleHybridOfficeDayChange(event) {
        const dayValue = event.target.dataset.day;
        const isChecked = event.target.checked;

        this.hybridDaysOfWeek = this.hybridDaysOfWeek.map(day => {
            if (day.value === dayValue) {
                return { ...day, isOffice: isChecked };
            }
            return day;
        });

        this.validateHybridForm();
    }

    handleHybridReasonChange(event) {
        this.hybridScheduleReason = event.target.value;
        this.validateHybridForm();
    }

    getSelectedHybridWFHDays() {
        return this.hybridDaysOfWeek.filter(day => day.isWFH).map(day => day.value);
    }

    getSelectedHybridOfficeDays() {
        return this.hybridDaysOfWeek.filter(day => day.isOffice).map(day => day.value);
    }

    validateHybridForm() {
        this.hybridValidationError = false;
        this.hybridValidationErrorMessage = '';

        if (this.getSelectedHybridWFHDays().length === 0 && this.getSelectedHybridOfficeDays().length === 0) {
            this.hybridValidationError = true;
            this.hybridValidationErrorMessage = 'Please select at least one WFH day or Office day';
            return false;
        }

        const wfhDays = this.getSelectedHybridWFHDays();
        const officeDays = this.getSelectedHybridOfficeDays();
        const overlap = wfhDays.filter(day => officeDays.includes(day));

        if (overlap.length > 0) {
            this.hybridValidationError = true;
            this.hybridValidationErrorMessage = `Cannot select same day for both WFH and Office: ${overlap.join(', ')}`;
            return false;
        }

        return true;
    }

      submitHybridSchedule() {
            if (!this.validateHybridForm()) {
                return;
            }

            this.isLoading = true;

            try {
                const wfhDays = this.getSelectedHybridWFHDays().join(';');
                const officeDays = this.getSelectedHybridOfficeDays().join(';');
                const scheduleMonth = this.hybridScheduleMonth + '-01';

                const result = submitHybridScheduleRequest({
                    employeeId: this.employeeId,
                    scheduleMonth: scheduleMonth,
                    wfhDays: wfhDays,
                    officeDays: officeDays,
                    scheduleType: this.hybridScheduleType,
                    reason: this.hybridScheduleReason
                     
                });
                return submitHybridSchedule
        if (result.success) {
                LightningAlert.open({
                    message: result.message || 'Your hybrid work schedule request has been submitted for approval',
                    theme: 'success',
                    label: 'Success'
                });

                    this.closeHybridScheduleModal();
                    this.checkHybridSchedule();
                } else {
                LightningAlert.open({
                    message: result.error || 'You already have a pending schedule. Please contact your Admin.',
                    theme: 'info',
                    label: 'Alert'
                });
                }

            } catch (error) {
            LightningAlert.open({
                message: 'Unexpected error occurred while submitting your request',
                theme: 'error',
                label: 'Error'
            });
            } finally {
                this.isLoading = false;
            }
        }
}