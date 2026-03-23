// ========================================
// FILE 3: contactToUserConverter.js (Updated with Picklist-based UI)
// ========================================

import { LightningElement, api, wire, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { getRecord } from 'lightning/uiRecordApi';
import getContactDetails from '@salesforce/apex/ContactToUserController.getContactDetails';
import convertContactToUser from '@salesforce/apex/ContactToUserController.convertContactToUser';

const CONTACT_FIELDS = [
    'Contact.FirstName',
    'Contact.LastName',
    'Contact.Email',
    'Contact.Employee_Category__c',
    'Contact.Date_of_Joining__c',
    'Contact.Number_of_Children__c',
    'Contact.Marital_Status__c',
    'Contact.Employee_Id__c',
    'Contact.Manager__c',
    'Contact.Employment_Status__c',
    'Contact.Probation_End_Date__c',
    'Contact.Is_Probation__c',
    'Contact.Mode_of_Work__c',
    'Contact.GenderIdentity',
    'Contact.Employment_Type__c',
    'Contact.Date_Of_Birth__c',
    'Contact.Designation__c'
];

export default class ContactToUserConverter extends LightningElement {
    @api recordId;
    @track contactData;
    @track isLoading = false;
    @track showModal = false;
    @track modalTitle = '';
    @track modalMessage = '';
    @track modalVariant = 'info';
    @track isError = false;
    @track showFieldMapping = false;
    @track showLicenseInfo = true;

    // Wire to get contact details
    @wire(getContactDetails, { contactId: '$recordId' })
    wiredContactData({ error, data }) {
        if (data) {
            this.contactData = data;
            
            // Automatically show warning if user already exists
            if (data.hasExistingUser) {
                this.showUserExistsWarning();
            }
        } else if (error) {
            this.showToast('Error', 'Unable to load contact details', 'error');
            console.error('Error loading contact:', error);
        }
    }

    // Show warning if user already exists
    showUserExistsWarning() {
        const warningBox = this.template.querySelector('.existing-user-warning');
        if (warningBox) {
            warningBox.classList.remove('slds-hide');
        }
    }

    // Get display text for user type with license info
    get userTypeDisplay() {
        if (!this.contactData || !this.contactData.contactUserType) {
            return 'Not Selected';
        }
        return this.contactData.contactUserType;
    }

    // Get user license display
    get userLicenseDisplay() {
        if (!this.contactData || !this.contactData.expectedUserLicense) {
            return 'Not Determined';
        }
        return this.contactData.expectedUserLicense;
    }

    // Get profile display
    get profileDisplay() {
        if (!this.contactData || !this.contactData.expectedProfile) {
            return 'Not Determined';
        }
        return this.contactData.expectedProfile;
    }

    // Get license variant for styling
    get licenseVariant() {
        if (!this.contactData || !this.contactData.expectedUserLicense) {
            return 'warning';
        }
        
        const license = this.contactData.expectedUserLicense;
        if (license === 'Salesforce') {
            return 'success';
        } else if (license === 'Partner Community') {
            return 'info';
        } else if (license === 'Customer Community') {
            return 'default';
        }
        return 'warning';
    }

    // Get license icon
    get licenseIcon() {
        if (!this.contactData || !this.contactData.expectedUserLicense) {
            return 'utility:warning';
        }
        
        const license = this.contactData.expectedUserLicense;
        if (license === 'Salesforce') {
            return 'utility:salesforce1';
        } else if (license === 'Partner Community') {
            return 'utility:partner';
        } else if (license === 'Customer Community') {
            return 'utility:user';
        }
        return 'utility:info';
    }

    // Get CSS class for license badge
    get licenseBadgeClass() {
        const license = this.userLicenseDisplay;
        if (license === 'Salesforce') {
            return 'license-badge salesforce-license';
        } else if (license === 'Partner Community') {
            return 'license-badge partner-license';
        } else if (license === 'Customer Community') {
            return 'license-badge customer-license';
        }
        return 'license-badge default-license';
    }

    // Check if conversion is possible
    get canConvert() {
        if (!this.contactData) return false;
        
        return !this.contactData.hasExistingUser && 
               this.contactData.contactUserType !== null && 
               this.contactData.contactUserType !== undefined &&
               this.contactData.contactUserType !== '';
    }

    // Get license mapping info
    get licenseMappingInfo() {
        return [
            {
                userType: 'Management',
                license: 'Salesforce',
                profile: 'System Administrator',
                icon: 'utility:salesforce1',
                variant: 'success'
            },
            {
                userType: 'HR Manager',
                license: 'Salesforce',
                profile: 'System Administrator',
                icon: 'utility:salesforce1',
                variant: 'success'
            },
            {
                userType: 'HR Team',
                license: 'Partner Community',
                profile: 'Partner Community Login User',
                icon: 'utility:partner',
                variant: 'info'
            },
            {
                userType: 'On-Role(Manager)',
                license: 'Partner Community',
                profile: 'Partner Community Login User',
                icon: 'utility:partner',
                variant: 'info'
            },
            {
                userType: 'On-Role(Team Member)',
                license: 'Customer Community',
                profile: 'Customer Community Login User',
                icon: 'utility:user',
                variant: 'default'
            },
            {
                userType: 'Intern-Stipend',
                license: 'Customer Community',
                profile: 'Customer Community Login User',
                icon: 'utility:user',
                variant: 'default'
            },
            {
                userType: 'Unpaid Intern',
                license: 'Customer Community',
                profile: 'Customer Community Login User',
                icon: 'utility:user',
                variant: 'default'
            }
        ];
    }

    // Toggle field mapping section
    toggleFieldMapping() {
        this.showFieldMapping = !this.showFieldMapping;
    }

    // Toggle license info section
    toggleLicenseInfo() {
        this.showLicenseInfo = !this.showLicenseInfo;
    }

    // Get button label for field mapping toggle
    get fieldMappingButtonLabel() {
        return this.showFieldMapping ? 'Hide Field Mapping Details' : 'Show Field Mapping Details';
    }

    // Get button label for license info toggle
    get licenseInfoButtonLabel() {
        return this.showLicenseInfo ? 'Hide License Mapping Guide' : 'Show License Mapping Guide';
    }

    // Format date for display
    formatDate(dateValue) {
        if (!dateValue) return 'Not Set';
        return new Date(dateValue).toLocaleDateString();
    }

    // Get formatted field mappings
    get fieldMappings() {
        if (!this.contactData) return [];
        
        return [
            { label: 'Date of Joining', value: this.formatDate(this.contactData.dateOfJoining), icon: 'utility:date_input' },
            { label: 'Date of Birth', value: this.formatDate(this.contactData.dateOfBirth), icon: 'utility:cake' },
            { label: 'Employee ID', value: this.contactData.employeeId || 'Not Set', icon: 'utility:identity' },
            { label: 'Designation', value: this.contactData.designation || 'Not Set', icon: 'utility:cases' },
            { label: 'Employment Status', value: this.contactData.employmentStatus || 'Not Set', icon: 'utility:checkmark_circle' },
            { label: 'Employment Type', value: this.contactData.employmentType || 'Not Set', icon: 'utility:work_order_type' },
            { label: 'Gender', value: this.contactData.gender || 'Not Set', icon: 'utility:user' },
            { label: 'Marital Status', value: this.contactData.maritalStatus || 'Not Set', icon: 'utility:people' },
            { label: 'Number of Children', value: this.contactData.numberOfChildren !== null ? this.contactData.numberOfChildren : 'Not Set', icon: 'utility:groups' },
            { label: 'Mode of Work', value: this.contactData.modeOfWork || 'Not Set', icon: 'utility:home' },
            { label: 'Is Probation', value: this.contactData.isProbation ? 'Yes' : 'No', icon: 'utility:clock' },
            { label: 'Probation End Date', value: this.formatDate(this.contactData.probationEndDate), icon: 'utility:end_date' },
            { label: 'Manager', value: this.contactData.managerName || 'Not Set', icon: 'utility:hierarchy' }
        ];
    }

    // Handle convert button click
    handleConvert() {
        if (!this.canConvert) {
            if (this.contactData.hasExistingUser) {
                this.showUserExistsModal();
            } else {
                this.showToast('Warning', 'Please select an Employee Category before converting', 'warning');
            }
            return;
        }

        this.isLoading = true;

        convertContactToUser({ contactId: this.recordId })
            .then(result => {
                if (result.success) {
                    this.showSuccessModal(result);
                    this.refreshContactData();
                } else {
                    this.showErrorModal(result.message);
                }
            })
            .catch(error => {
                this.showErrorModal('Unexpected error: ' + this.reduceErrors(error));
                console.error('Error converting contact:', error);
            })
            .finally(() => {
                this.isLoading = false;
            });
    }

    // Show success modal
    showSuccessModal(result) {
        this.modalTitle = '✓ User Created Successfully';
        this.modalMessage = result.message;
        this.modalVariant = 'success';
        this.isError = false;
        this.showModal = true;
    }

    // Show error modal
    showErrorModal(message) {
        this.modalTitle = 'Error Creating User';
        this.modalMessage = message;
        this.modalVariant = 'error';
        this.isError = true;
        this.showModal = true;
    }

    // Show user exists modal
    showUserExistsModal() {
        this.modalTitle = 'User Already Exists';
        this.modalMessage = `A user with email ${this.contactData.email} already exists in the system.\n\nUsername: ${this.contactData.existingUsername}\n\nPlease check the existing user record before creating a new one.`;
        this.modalVariant = 'warning';
        this.isError = true;
        this.showModal = true;
    }

    // Close modal
    closeModal() {
        this.showModal = false;
    }

    // Refresh contact data after conversion
    refreshContactData() {
        getContactDetails({ contactId: this.recordId })
            .then(data => {
                this.contactData = data;
            })
            .catch(error => {
                console.error('Error refreshing contact data:', error);
            });
    }

    // Show toast notification
    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        });
        this.dispatchEvent(evt);
    }

    // Reduce errors to readable format
    reduceErrors(errors) {
        if (!Array.isArray(errors)) {
            errors = [errors];
        }

        return (
            errors
                .filter(error => !!error)
                .map(error => {
                    if (Array.isArray(error.body)) {
                        return error.body.map(e => e.message);
                    } else if (error.body && typeof error.body.message === 'string') {
                        return error.body.message;
                    } else if (typeof error.message === 'string') {
                        return error.message;
                    }
                    return error.statusText;
                })
                .reduce((prev, curr) => prev.concat(curr), [])
                .filter(message => !!message)
                .join(', ')
        );
    }

    // Get modal variant class
    get modalVariantClass() {
        return `slds-modal__header slds-theme_${this.modalVariant}`;
    }
}
