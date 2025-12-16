import { LightningElement, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { refreshApex } from '@salesforce/apex';
import getOnboardingRecords from '@salesforce/apex/OnboardingController.getOnboardingRecords';
import convertToContact from '@salesforce/apex/OnboardingController.convertToContact';

export default class OnboardingManager extends NavigationMixin(LightningElement) {
    @track onboardingRecords = [];
    @track selectedStatus = 'All';
    @track isLoading = false;
    @track showModal = false;
    @track selectedRecord = null;
    
    wiredRecordsResult;

    statusOptions = [
        { label: 'All', value: 'All' },
        { label: 'Submitted', value: 'Submitted' },
        { label: 'Under Review', value: 'Under Review' },
        { label: 'Approved', value: 'Approved' },
        { label: 'Converted', value: 'Converted' }
    ];

    @wire(getOnboardingRecords, { status: '$selectedStatus' })
    wiredRecords(result) {
        this.wiredRecordsResult = result;
        if (result.data) {
            this.onboardingRecords = result.data.map(record => {
                return {
                    ...record,
                    statusClass: this.getStatusClass(record.Status__c)
                };
            });
        } else if (result.error) {
            this.showToast('Error', 'Failed to load records', 'error');
        }
    }

    getStatusClass(status) {
        const classMap = {
            'Submitted': 'slds-badge slds-badge_lightest',
            'Under Review': 'slds-badge',
            'Approved': 'slds-badge slds-theme_success',
            'Converted': 'slds-badge slds-theme_info'
        };
        return classMap[status] || 'slds-badge';
    }

    handleStatusChange(event) {
        this.selectedStatus = event.target.value;
    }

    handleRefresh() {
        this.isLoading = true;
        return refreshApex(this.wiredRecordsResult)
            .then(() => {
                this.isLoading = false;
                this.showToast('Success', 'Records refreshed', 'success');
            })
            .catch(() => {
                this.isLoading = false;
            });
    }

    handleViewDetails(event) {
        const recordId = event.target.dataset.id;
        this.selectedRecord = this.onboardingRecords.find(r => r.Id === recordId);
        this.showModal = true;
    }

    handleCloseModal() {
        this.showModal = false;
        this.selectedRecord = null;
    }

    handleConvert(event) {
        const recordId = event.target.dataset.id;
        
        if (confirm('Are you sure you want to convert this onboarding record to a Contact?')) {
            this.isLoading = true;
            convertToContact({ onboardingId: recordId })
                .then(() => {
                    this.showToast('Success', 'Successfully converted to Contact', 'success');
                    return refreshApex(this.wiredRecordsResult);
                })
                .then(() => {
                    this.isLoading = false;
                })
                .catch(error => {
                    this.isLoading = false;
                    this.showToast('Error', error.body.message, 'error');
                });
        }
    }

    handleOpenContact(event) {
        const contactId = event.target.dataset.id;
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: contactId,
                objectApiName: 'Contact',
                actionName: 'view'
            }
        });
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get hasRecords() {
        return this.onboardingRecords && this.onboardingRecords.length > 0;
    }
}