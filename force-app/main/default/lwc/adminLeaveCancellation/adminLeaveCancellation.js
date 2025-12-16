import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import Id from '@salesforce/user/Id';
import getCancellableLeaveRequests from '@salesforce/apex/LeaveRequestController.getCancellableLeaveRequests';
import cancelLeaveRequest from '@salesforce/apex/LeaveRequestController.cancelLeaveRequest';

export default class AdminLeaveCancellation extends LightningElement {
    @track employeeId = '';
    currentUserId = Id;
    
    @track cancellableLeaves = [];
    @track isLoading = false;
    @track searchPerformed = false;
    
    // Filter to show only active users
    userFilter = {
        criteria: [
            {
                fieldPath: 'IsActive',
                operator: 'eq',
                value: true
            }
        ]
    };
    
    /**
     * Handle employee selection from lookup
     */
    handleEmployeeSelect(event) {
        this.employeeId = event.detail.recordId;
        
        if (this.employeeId) {
            this.loadCancellableLeaves();
        }
    }
    
    /**
     * Load cancellable leave requests
     */
    loadCancellableLeaves() {
        this.isLoading = true;
        this.searchPerformed = true;
        
        getCancellableLeaveRequests({ employeeId: this.employeeId })
            .then(result => {
                console.log('Leave requests found:', result.length);
                this.cancellableLeaves = result.map(leave => ({
                    ...leave,
                    formattedStartDate: this.formatDate(leave.Start_Date__c),
                    formattedEndDate: this.formatDate(leave.End_Date__c)
                }));
                
                if (this.cancellableLeaves.length === 0) {
                    this.showToast('Info', 'No active leave requests found for this employee', 'info');
                }
            })
            .catch(error => {
                console.error('Error loading leave requests:', error);
                this.showToast('Error', 'Failed to load leave requests: ' + this.getErrorMessage(error), 'error');
                this.cancellableLeaves = [];
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    /**
     * Handle Cancel Leave button click
     */
    handleCancelClick(event) {
        const leaveId = event.target.dataset.id;
        const leaveName = event.target.dataset.name;
        const employeeName = event.target.dataset.employee;
        
        const confirmMessage = `Are you sure you want to cancel leave request "${leaveName}" for ${employeeName}?\n\nThis will:\n✅ Restore the leave balance\n✅ Enable attendance check-in\n✅ Send notification email to employee`;
        
        if (confirm(confirmMessage)) {
            this.cancelLeave(leaveId);
        }
    }
    
    /**
     * Cancel leave request
     */
    cancelLeave(leaveId) {
        this.isLoading = true;
        const cancellationReason = 'Cancelled by Admin to enable attendance check-in';
        
        cancelLeaveRequest({
            leaveRequestId: leaveId,
            cancelledBy: this.currentUserId,
            cancellationReason: cancellationReason
        })
            .then(result => {
                if (result.success) {
                    this.showToast('Success', result.message, 'success');
                    this.loadCancellableLeaves();
                } else {
                    this.showToast('Error', result.message, 'error');
                }
            })
            .catch(error => {
                console.error('Error cancelling leave:', error);
                this.showToast('Error', 'Failed to cancel leave request: ' + this.getErrorMessage(error), 'error');
            })
            .finally(() => {
                this.isLoading = false;
            });
    }
    
    formatDate(dateString) {
        if (!dateString) return '';
        try {
            const date = new Date(dateString);
            return date.toLocaleDateString('en-US', { 
                year: 'numeric', 
                month: 'short', 
                day: '2-digit' 
            });
        } catch (e) {
            return dateString;
        }
    }
    
    getErrorMessage(error) {
        if (!error) return 'Unknown error';
        if (error.body?.message) return error.body.message;
        if (error.message) return error.message;
        return JSON.stringify(error);
    }
    
    get hasCancellableLeaves() {
        return this.cancellableLeaves && this.cancellableLeaves.length > 0;
    }
    
    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ 
            title, 
            message, 
            variant,
            mode: 'dismissable'
        }));
    }
}