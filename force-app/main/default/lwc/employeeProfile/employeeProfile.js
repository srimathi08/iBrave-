import { LightningElement, track } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getEmployeeProfile from '@salesforce/apex/EmployeeProfileController.getEmployeeProfile';
import getEducationDetails from '@salesforce/apex/EmployeeProfileController.getEducationDetails';
import uploadCertificate from '@salesforce/apex/EmployeeProfileController.uploadCertificate';
import deleteFile from '@salesforce/apex/EmployeeProfileController.deleteFile';
import deleteEducationRecord from '@salesforce/apex/EmployeeProfileController.deleteEducationRecord';

export default class EmployeeProfile extends LightningElement {
    @track employeeData;
    @track educationList = [];
    @track isLoading = true;
    @track showCertificateUpload = false;
    @track isUploadingCertificate = false;

    @track certificateData = {
        name: '',
        type: '',
        institution: '',
        issueDate: '',
        certificateNumber: '',
        fileName: '',
        base64: ''
    };

    certificateTypeOptions = [
        { label: 'Degree Certificate', value: 'Degree Certificate' },
        { label: 'Experience Letter', value: 'Experience Letter' },
        { label: 'Identity Proof', value: 'Identity Proof' },
        { label: 'Professional Certification', value: 'Professional Certification' },
        { label: 'Training Certificate', value: 'Training Certificate' },
        { label: 'Other', value: 'Other' }
    ];

    connectedCallback() {
        this.loadEmployeeData();
        this.loadEducationData();
    }

    loadEmployeeData() {
        this.isLoading = true;
        getEmployeeProfile()
            .then(data => {
                this.employeeData = data;
                this.isLoading = false;
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
                this.isLoading = false;
            });
    }

    loadEducationData() {
        getEducationDetails()
            .then(data => {
                // Add isExpanded property for collapsible attachments
                this.educationList = data.map(edu => ({
                    ...edu,
                    isExpanded: false,
                    chevronIcon: 'utility:chevronright',
                    fileCount: edu.attachedFiles ? edu.attachedFiles.length : 0,
                    hasFiles: edu.attachedFiles && edu.attachedFiles.length > 0
                }));
            })
            .catch(error => {
                this.showToast('Error', this.getErrorMessage(error), 'error');
            });
    }

    get hasEducation() {
        return this.educationList && this.educationList.length > 0;
    }

    get displayPhotoUrl() {
        if (this.employeeData?.photoUrl) {
            const timestamp = new Date().getTime();
            let baseUrl = this.employeeData.photoUrl;
            baseUrl = baseUrl.replace(/[?&]t=\d+/g, '');
            const separator = baseUrl.includes('?') ? '&' : '?';
            return `${baseUrl}${separator}t=${timestamp}`;
        }
        return '/_slds/images/themes/oneSalesforce/theme-properties/profile_avatar_200.png';
    }

    get formattedAddress() {
        return this.employeeData?.address || 'Not provided';
    }

    get uploadCertificateButtonLabel() {
        return this.isUploadingCertificate ? 'Uploading...' : 'Upload Certificate';
    }

    get uploadCertificateIcon() {
        return this.isUploadingCertificate ? 'utility:spinner' : null;
    }

    get isCertificateUploadDisabled() {
        return this.isUploadingCertificate ||
            !this.certificateData.name ||
            !this.certificateData.type ||
            !this.certificateData.base64;
    }

    // Toggle attachment visibility for a certificate card
    toggleAttachments(event) {
        const certId = event.currentTarget.dataset.id;
        this.educationList = this.educationList.map(edu => {
            if (edu.id === certId) {
                const nowExpanded = !edu.isExpanded;
                return {
                    ...edu,
                    isExpanded: nowExpanded,
                    chevronIcon: nowExpanded ? 'utility:chevrondown' : 'utility:chevronright'
                };
            }
            return edu;
        });
    }

    handleAddCertificateClick() {
        this.resetCertificateForm();
        this.showCertificateUpload = true;
    }

    handleCertificateUploadCancel() {
        this.showCertificateUpload = false;
        this.resetCertificateForm();
    }

    handleCertificateFieldChange(event) {
        const field = event.target.dataset.field;
        this.certificateData[field] = event.target.value;
        this.certificateData = { ...this.certificateData };
    }

    handleCertificateFileChange(event) {
        const file = event.target.files[0];
        if (file) {
            const allowedTypes = [
                'application/pdf',
                'image/jpeg', 'image/jpg', 'image/png',
                'application/msword',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
            ];

            if (!allowedTypes.includes(file.type)) {
                this.showToast('Error', 'Please upload PDF, Image, or Word document only', 'error');
                event.target.value = '';
                return;
            }

            if (file.size > 10485760) {
                this.showToast('Error', 'File size should not exceed 10MB', 'error');
                event.target.value = '';
                return;
            }

            this.certificateData.fileName = file.name;

            const reader = new FileReader();
            reader.onload = () => {
                const base64 = reader.result.split(',')[1];
                this.certificateData.base64 = base64;
                this.certificateData = { ...this.certificateData };
            };
            reader.readAsDataURL(file);
        }
    }

    handleCertificateUpload() {
        if (!this.certificateData.name || !this.certificateData.type || !this.certificateData.base64) {
            this.showToast('Error', 'Please fill all required fields and upload a file', 'error');
            return;
        }

        this.isUploadingCertificate = true;

        uploadCertificate({
            certificateName: this.certificateData.name,
            certificateType: this.certificateData.type,
            institution: this.certificateData.institution,
            issueDate: this.certificateData.issueDate,
            certificateNumber: this.certificateData.certificateNumber,
            base64Data: this.certificateData.base64,
            fileName: this.certificateData.fileName
        })
            .then((result) => {
                console.log('Certificate uploaded successfully. ID:', result);
                this.showToast('Success', 'Certificate uploaded successfully', 'success');
                this.showCertificateUpload = false;
                this.resetCertificateForm();
                this.isUploadingCertificate = false;
                this.loadEducationData();
            })
            .catch(error => {
                console.error('Certificate upload error:', error);
                this.showToast('Error', this.getErrorMessage(error), 'error');
                this.isUploadingCertificate = false;
            });
    }

    resetCertificateForm() {
        this.certificateData = {
            name: '',
            type: '',
            institution: '',
            issueDate: '',
            certificateNumber: '',
            fileName: '',
            base64: ''
        };
        const fileInput = this.template.querySelector('.file-input');
        if (fileInput) {
            fileInput.value = '';
        }
    }

    handleFileDownload(event) {
        const downloadUrl = event.currentTarget.dataset.url;
        window.open(downloadUrl, '_blank');
    }

    handleFileDelete(event) {
        const contentDocumentId = event.currentTarget.dataset.fileid;

        if (confirm('Are you sure you want to delete this file?')) {
            deleteFile({ contentDocumentId })
                .then(() => {
                    this.showToast('Success', 'File deleted successfully', 'success');
                    this.loadEducationData();
                })
                .catch(error => {
                    this.showToast('Error', this.getErrorMessage(error), 'error');
                });
        }
    }

    handleEducationDelete(event) {
        const educationId = event.currentTarget.dataset.id;

        if (confirm('Are you sure you want to delete this certificate? All associated files will also be deleted.')) {
            deleteEducationRecord({ educationId })
                .then(() => {
                    this.showToast('Success', 'Certificate deleted successfully', 'success');
                    this.loadEducationData();
                })
                .catch(error => {
                    this.showToast('Error', this.getErrorMessage(error), 'error');
                });
        }
    }

    getErrorMessage(error) {
        if (error.body && error.body.message) {
            return error.body.message;
        } else if (error.message) {
            return error.message;
        }
        return 'An unknown error occurred';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({
            title,
            message,
            variant
        });
        this.dispatchEvent(event);
    }
}