import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCurrentAttendanceStatus from '@salesforce/apex/AttendanceController.getCurrentAttendanceStatus';
import checkIn from '@salesforce/apex/AttendanceController.checkIn';
import checkOut from '@salesforce/apex/AttendanceController.checkOut';
import getAttendanceHistory from '@salesforce/apex/AttendanceController.getAttendanceHistory';

export default class Attendance extends LightningElement {
    @track isCheckedIn = false;
    @track isProcessing = false;
    @track processingMessage = '';
    @track currentTime = '';
    @track displayTime = '00:00:00';
    @track timerLabel = 'Ready to start';
    @track showCamera = false;
    @track showLocationInfo = false;
    @track currentAddress = '';
    @track attendanceRecord = {};
    @track attendanceHistory = [];
    
    // Timer variables
    timerInterval;
    startTime;
    elapsedSeconds = 0;
    
    // Location variables
    currentLatitude;
    currentLongitude;
    
    // Camera variables
    mediaStream;
    capturedImageId;

    connectedCallback() {
        this.startCurrentTimeUpdate();
        this.loadCurrentStatus();
        this.loadAttendanceHistory();
    }

    disconnectedCallback() {
        this.clearTimerInterval();
        this.stopCamera();
        this.stopCurrentTimeUpdate();
    }

    // Current time display
    startCurrentTimeUpdate() {
        this.updateCurrentTime();
        this.currentTimeInterval = setInterval(() => {
            this.updateCurrentTime();
        }, 1000);
    }

    stopCurrentTimeUpdate() {
        if (this.currentTimeInterval) {
            clearInterval(this.currentTimeInterval);
        }
    }

    updateCurrentTime() {
        const now = new Date();
        this.currentTime = now.toLocaleTimeString('en-US', { 
            hour12: false,
            hour: '2-digit',
            minute: '2-digit',
            second: '2-digit'
        });
    }

    // Load current attendance status
    async loadCurrentStatus() {
        try {
            const result = await getCurrentAttendanceStatus();
            
            if (result.hasActiveSession) {
                this.isCheckedIn = result.isCheckedIn;
                this.attendanceRecord = result.attendanceRecord;
                
                if (this.isCheckedIn && result.elapsedSeconds) {
                    this.elapsedSeconds = result.elapsedSeconds;
                    this.startTimer();
                }
            }
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Failed to load attendance status', 'error');
        }
    }

    // Timer functionality
    startTimer() {
        this.clearTimerInterval();
        this.timerLabel = 'Working Time';
        
        this.timerInterval = setInterval(() => {
            this.elapsedSeconds++;
            this.displayTime = this.formatTime(this.elapsedSeconds);
        }, 1000);
        
        this.displayTime = this.formatTime(this.elapsedSeconds);
    }

    stopTimer() {
        this.clearTimerInterval();
        this.timerLabel = 'Session Complete';
    }

    clearTimerInterval() {
        if (this.timerInterval) {
            clearInterval(this.timerInterval);
            this.timerInterval = null;
        }
    }

    formatTime(seconds) {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor((seconds % 3600) / 60);
        const secs = seconds % 60;
        
        return `${hours.toString().padStart(2, '0')}:${minutes.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }

    // Main check-in/out handler
    async handleCheckInOut() {
        if (this.isProcessing) return;
        
        this.isProcessing = true;
        this.processingMessage = 'Getting location...';
        
        try {
            // Get location first
            await this.getCurrentLocation();
            
            // Show camera for image capture
            this.processingMessage = 'Starting camera...';
            await this.startCamera();
            
        } catch (error) {
            this.isProcessing = false;
            this.showToast('Error', error.message || 'Failed to get location', 'error');
        }
    }

    // Location functionality
    getCurrentLocation() {
        return new Promise((resolve, reject) => {
            if (!navigator.geolocation) {
                reject(new Error('Geolocation is not supported'));
                return;
            }

            navigator.geolocation.getCurrentPosition(
                async (position) => {
                    this.currentLatitude = position.coords.latitude;
                    this.currentLongitude = position.coords.longitude;
                    
                    try {
                        this.currentAddress = await this.reverseGeocode(
                            this.currentLatitude, 
                            this.currentLongitude
                        );
                        this.showLocationInfo = true;
                        resolve();
                    } catch (error) {
                        this.currentAddress = `${this.currentLatitude}, ${this.currentLongitude}`;
                        this.showLocationInfo = true;
                        resolve();
                    }
                },
                (error) => {
                    reject(new Error('Failed to get location: ' + error.message));
                },
                {
                    enableHighAccuracy: true,
                    timeout: 10000,
                    maximumAge: 60000
                }
            );
        });
    }

    async reverseGeocode(lat, lng) {
        // Using a simple reverse geocoding service
        // In production, you might want to use Google Maps API or similar
        try {
            const response = await fetch(`https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=${lat}&longitude=${lng}&localityLanguage=en`);
            const data = await response.json();
            return data.display_name || `${lat}, ${lng}`;
        } catch (error) {
            return `${lat}, ${lng}`;
        }
    }

    // Camera functionality
    async startCamera() {
        try {
            this.showCamera = true;
            
            const stream = await navigator.mediaDevices.getUserMedia({ 
                video: { 
                    facingMode: 'user',
                    width: { ideal: 640 },
                    height: { ideal: 480 }
                } 
            });
            
            this.mediaStream = stream;
            
            // Wait for template to render
            await new Promise(resolve => setTimeout(resolve, 100));
            
            const videoElement = this.template.querySelector('[lwc\\:ref="videoElement"]');
            if (videoElement) {
                videoElement.srcObject = stream;
            }
            
            this.processingMessage = 'Please capture your photo';
            
        } catch (error) {
            this.showCamera = false;
            this.isProcessing = false;
            this.showToast('Error', 'Failed to access camera: ' + error.message, 'error');
        }
    }

    async captureImage() {
        try {
            const videoElement = this.template.querySelector('[lwc\\:ref="videoElement"]');
            const canvasElement = this.template.querySelector('[lwc\\:ref="canvasElement"]');
            
            if (!videoElement || !canvasElement) {
                throw new Error('Camera elements not found');
            }
            
            const context = canvasElement.getContext('2d');
            canvasElement.width = videoElement.videoWidth;
            canvasElement.height = videoElement.videoHeight;
            
            context.drawImage(videoElement, 0, 0);
            
            // Convert to blob
            const blob = await new Promise(resolve => canvasElement.toBlob(resolve, 'image/jpeg', 0.8));
            
            // Create file and upload
            const file = new File([blob], `attendance_${Date.now()}.jpg`, { type: 'image/jpeg' });
            this.capturedImageId = await this.uploadImage(file);
            
            this.stopCamera();
            this.processingMessage = 'Processing attendance...';
            
            // Proceed with check-in/out
            if (this.isCheckedIn) {
                await this.performCheckOut();
            } else {
                await this.performCheckIn();
            }
            
        } catch (error) {
            this.showToast('Error', 'Failed to capture image: ' + error.message, 'error');
            this.cancelCamera();
        }
    }

    async uploadImage(file) {
        // This is a placeholder for image upload functionality
        // In a real implementation, you would upload to Salesforce Files
        // and return the ContentDocument ID
        return 'placeholder_image_id_' + Date.now();
    }

    stopCamera() {
        if (this.mediaStream) {
            this.mediaStream.getTracks().forEach(track => track.stop());
            this.mediaStream = null;
        }
        this.showCamera = false;
    }

    cancelCamera() {
        this.stopCamera();
        this.isProcessing = false;
        this.processingMessage = '';
        this.showLocationInfo = false;
    }

    // Check-in/out operations
    async performCheckIn() {
        try {
            const result = await checkIn({
                latitude: this.currentLatitude,
                longitude: this.currentLongitude,
                address: this.currentAddress,
                imageId: this.capturedImageId
            });
            
            if (result.success) {
                this.isCheckedIn = true;
                this.attendanceRecord = result.attendanceRecord;
                this.elapsedSeconds = 0;
                this.startTimer();
                
                this.showToast('Success', 'Checked in successfully!', 'success');
                this.loadAttendanceHistory();
            }
            
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Check-in failed', 'error');
        } finally {
            this.isProcessing = false;
            this.processingMessage = '';
            this.showLocationInfo = false;
        }
    }

    async performCheckOut() {
        try {
            const result = await checkOut({
                latitude: this.currentLatitude,
                longitude: this.currentLongitude,
                address: this.currentAddress,
                imageId: this.capturedImageId
            });
            
            if (result.success) {
                this.isCheckedIn = false;
                this.attendanceRecord = result.attendanceRecord;
                this.stopTimer();
                
                this.showToast('Success', 'Checked out successfully!', 'success');
                this.loadAttendanceHistory();
            }
            
        } catch (error) {
            this.showToast('Error', error.body?.message || 'Check-out failed', 'error');
        } finally {
            this.isProcessing = false;
            this.processingMessage = '';
            this.showLocationInfo = false;
        }
    }

    // History functionality
    async loadAttendanceHistory() {
        try {
            const history = await getAttendanceHistory({ limitCount: 10 });
            this.attendanceHistory = history.map(record => ({
                ...record,
                FormattedDate: this.formatDate(record.Date),
                FormattedCheckIn: this.formatDateTime(record.CheckInTime),
                FormattedCheckOut: this.formatDateTime(record.CheckOutTime),
                FormattedHours: this.formatHours(record.TotalHours),
                StatusClass: this.getStatusClass(record.Status)
            }));
        } catch (error) {
            console.error('Error loading history:', error);
        }
    }

    refreshHistory() {
        this.loadAttendanceHistory();
    }

    // Utility methods
    formatDate(dateValue) {
        if (!dateValue) return '-';
        return new Date(dateValue).toLocaleDateString('en-US', {
            month: 'short',
            day: 'numeric',
            year: 'numeric'
        });
    }

    formatDateTime(dateTimeValue) {
        if (!dateTimeValue) return '-';
        return new Date(dateTimeValue).toLocaleTimeString('en-US', {
            hour: '2-digit',
            minute: '2-digit',
            hour12: true
        });
    }

    formatHours(hours) {
        if (!hours) return '-';
        const h = Math.floor(hours);
        const m = Math.round((hours - h) * 60);
        return `${h}h ${m}m`;
    }

    getStatusClass(status) {
        const baseClass = 'status-badge';
        return status === 'Checked In' ? 
            `${baseClass} status-active` : 
            `${baseClass} status-completed`;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    // Getters
    get checkInButtonClass() {
        const baseClass = 'slds-button checkin-button';
        return this.isCheckedIn ? 
            `${baseClass} slds-button_destructive checkout-btn` : 
            `${baseClass} slds-button_brand checkin-btn`;
    }

    get buttonLabel() {
        return this.isCheckedIn ? 'Check Out' : 'Check In';
    }

    get buttonIcon() {
        return this.isCheckedIn ? 'utility:logout' : 'utility:login';
    }

    get statusBadgeClass() {
        const baseClass = 'summary-value status-badge';
        return this.isCheckedIn ? 
            `${baseClass} status-active` : 
            `${baseClass} status-completed`;
    }

    get todayCheckIn() {
        return this.attendanceRecord.Check_In_Time__c ? 
            this.formatDateTime(this.attendanceRecord.Check_In_Time__c) : '-';
    }

    get todayCheckOut() {
        return this.attendanceRecord.Check_Out_Time__c ? 
            this.formatDateTime(this.attendanceRecord.Check_Out_Time__c) : '-';
    }

    get todayTotalHours() {
        return this.attendanceRecord.Total_Hours__c ? 
            this.formatHours(this.attendanceRecord.Total_Hours__c) : '-';
    }

    get todayStatus() {
        return this.attendanceRecord.Status__c || 'Not Started';
    }

    get hasHistory() {
        return this.attendanceHistory && this.attendanceHistory.length > 0;
    }
}