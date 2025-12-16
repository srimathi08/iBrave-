import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getUserDetails from '@salesforce/apex/EmployeeOverviewController.getUserDetails';
import updateUserDetails from '@salesforce/apex/EmployeeOverviewController.updateUserDetails';
import USER_ID from '@salesforce/user/Id';

export default class EmployeeOverview extends LightningElement {
    @track userDetails = {};
    @track originalUserDetails = {};
    @track isEditMode = false;
    @track isLoading = true;
    @track isSaving = false;

    userId = USER_ID;

    // Time Zone Options
    timeZoneOptions = [
        { label: 'Pacific Standard Time', value: 'America/Los_Angeles' },
        { label: 'Mountain Standard Time', value: 'America/Denver' },
        { label: 'Central Standard Time', value: 'America/Chicago' },
        { label: 'Eastern Standard Time', value: 'America/New_York' },
        { label: 'GMT', value: 'Europe/London' },
        { label: 'India Standard Time', value: 'Asia/Kolkata' }
    ];

    // Language Options
    languageOptions = [
        { label: 'English', value: 'en_US' },
        { label: 'Spanish', value: 'es' },
        { label: 'French', value: 'fr' },
        { label: 'German', value: 'de' },
        { label: 'Japanese', value: 'ja' }
    ];

    connectedCallback() {
        this.loadUserDetails();
    }

    loadUserDetails() {
        this.isLoading = true;
        getUserDetails({ userId: this.userId })
            .then(result => {
                this.userDetails = { ...result };
                this.originalUserDetails = { ...result };
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to load user details: ' + error.body.message, 'error');
                this.isLoading = false;
            });
    }

    handleEditToggle() {
        this.isEditMode = !this.isEditMode;
        if (!this.isEditMode) {
            // Reset to original values on cancel
            this.userDetails = { ...this.originalUserDetails };
        }
    }

    handleFieldChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.value;
        this.userDetails = { ...this.userDetails, [field]: value };
    }

    handleCancel() {
        this.userDetails = { ...this.originalUserDetails };
        this.isEditMode = false;
    }

    handleSave() {
        this.isSaving = true;
        updateUserDetails({ userId: this.userId, userDetails: this.userDetails })
            .then(() => {
                this.showToast('Success', 'Profile updated successfully', 'success');
                this.originalUserDetails = { ...this.userDetails };
                this.isEditMode = false;
                this.isSaving = false;
            })
            .catch(error => {
                this.showToast('Error', 'Failed to update profile: ' + error.body.message, 'error');
                this.isSaving = false;
            });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get editButtonLabel() {
        return this.isEditMode ? 'Cancel' : 'Edit Profile';
    }

    get editButtonIcon() {
        return this.isEditMode ? 'utility:close' : 'utility:edit';
    }

    get editButtonVariant() {
        return this.isEditMode ? 'neutral' : 'brand';
    }

    get statusBadgeClass() {
        return this.userDetails.IsActive ? 'badge active' : 'badge inactive';
    }

    get userStatus() {
        return this.userDetails.IsActive ? 'Active' : 'Inactive';
    }
}