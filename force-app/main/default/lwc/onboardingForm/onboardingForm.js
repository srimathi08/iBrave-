import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import getCandidateData from '@salesforce/apex/OnboardingFormController.getCandidateData';
import getPicklistValues from '@salesforce/apex/OnboardingFormController.getPicklistValues';
import saveCandidateData from '@salesforce/apex/OnboardingFormController.saveCandidateData';
import checkFileUploadPermissions from '@salesforce/apex/OnboardingFormController.checkFileUploadPermissions';
import markOnboardingCompleted from '@salesforce/apex/OnboardingFormController.markOnboardingCompleted';
import uploadFile from '@salesforce/apex/OnboardingFormController.uploadFile';

export default class OnboardingForm extends LightningElement {
    @api recordId;
    
    @track candidateData = {};
    @track educationRecords = [];
    @track familyRecords = [];
    @track workRecords = [];
    @track bankRecords = [];
    
    @track currentStep = 'personal';
    @track isLoading = true;
    @track showSuccess = false;
    @track declarationAccepted = false;
    @track sameAsCommAddress = false;
    
    @track isAdvertisement = false;
    @track isConsultancy = false;
    @track isReferred = false;
    @track isCampus = false;
    // File upload tracking
    @track aadharUploaded = false;
    @track panUploaded = false;
    @track uanUploaded = false;
    @track dlUploaded = false;

    // Selected filenames for inline display
    @track aadharFileName;
    @track panFileName;
    @track uanFileName;
    @track dlFileName;
    
    // Picklist options
    salutationOptions = [];
    genderOptions = [];
    bloodGroupOptions = [];
    sourceOfApplicantOptions = [];
    maritalStatusOptions = [];
    educationTypeOptions = [];
    modeOfStudyOptions = [];
    relationshipOptions = [];
    employmentTypeOptions = [];
    accountTypeOptions = [];
    bankStatusOptions = [];

    connectedCallback() {
        console.log('=== Component Connected ===');
        console.log('Initial recordId from @api:', this.recordId);
        
        if (!this.recordId) {
            this.recordId = this.getUrlParameter('recordId');
            console.log('RecordId from URL (recordId):', this.recordId);
        }
        
        if (!this.recordId) {
            this.recordId = this.getUrlParameter('c__recordId');
            console.log('RecordId from URL (c__recordId):', this.recordId);
        }
        
        if (!this.recordId) {
            this.recordId = this.getUrlParameter('id');
            console.log('RecordId from URL (id):', this.recordId);
        }
        
        if (!this.recordId) {
            const hash = window.location.hash;
            if (hash.includes('recordId=')) {
                this.recordId = hash.split('recordId=')[1].split('&')[0];
                console.log('RecordId from hash:', this.recordId);
            }
        }
        
        console.log('Final recordId:', this.recordId);
        console.log('Full URL:', window.location.href);
        console.log('User Agent:', navigator.userAgent);
        
        this.loadPicklistValues();
        
        if (this.recordId) {
            if (this.recordId.length === 18 || this.recordId.length === 15) {
                this.checkUploadPermissions();
                this.loadData();
            } else {
                console.error('Invalid recordId format:', this.recordId);
                this.isLoading = false;
                this.showToast('Error', 'Invalid Candidate ID format in URL', 'error');
            }
        } else {
            this.isLoading = false;
            this.showToast('Error', 'Candidate ID is missing from URL. Please use the link provided in your email.', 'error');
            console.error('ERROR: No Candidate ID found in URL');
        }
    }

    checkUploadPermissions() {
        console.log('=== Checking File Upload Permissions ===');
        checkFileUploadPermissions({ recordId: this.recordId })
            .then(result => {
                console.log('Upload Permissions:', result);
                if (!result.canUpload) {
                    console.warn('WARNING: User does not have permission to upload files');
                    this.showToast('Warning', 'You may not have permission to upload files. Please contact your administrator.', 'warning');
                }
                if (!result.recordExists) {
                    console.error('ERROR: Candidate record does not exist');
                    this.showToast('Error', 'Candidate record not found', 'error');
                }
            })
            .catch(error => {
                console.error('Error checking permissions:', error);
                console.error('Error details:', JSON.stringify(error));
            });
    }

    getUrlParameter(param) {
        const urlParams = new URLSearchParams(window.location.search);
        let value = urlParams.get(param);
        
        if (value) {
            console.log(`Found ${param} in search params:`, value);
            return value;
        }
        
        const hash = window.location.hash;
        if (hash) {
            const hashParams = new URLSearchParams(hash.substring(hash.indexOf('?')));
            value = hashParams.get(param);
            if (value) {
                console.log(`Found ${param} in hash params:`, value);
                return value;
            }
        }
        
        return null;
    }

    loadPicklistValues() {
        getPicklistValues()
            .then(result => {
                console.log('Picklist values loaded');
                this.salutationOptions = this.mapPicklistOptions(result.salutation);
                this.genderOptions = this.mapPicklistOptions(result.gender);
                this.bloodGroupOptions = this.mapPicklistOptions(result.bloodGroup);
                this.sourceOfApplicantOptions = this.mapPicklistOptions(result.sourceOfApplicant);
                this.maritalStatusOptions = this.mapPicklistOptions(result.maritalStatus);
                this.educationTypeOptions = this.mapPicklistOptions(result.educationType);
                this.modeOfStudyOptions = this.mapPicklistOptions(result.modeOfStudy);
                this.relationshipOptions = this.mapPicklistOptions(result.relationship);
                this.employmentTypeOptions = this.mapPicklistOptions(result.employmentType);
                this.accountTypeOptions = this.mapPicklistOptions(result.accountType);
                this.bankStatusOptions = this.mapPicklistOptions(result.bankStatus);
            })
            .catch(error => {
                console.error('Error loading picklist values:', error);
                this.showToast('Error', 'Failed to load form options: ' + this.getErrorMessage(error), 'error');
            });
    }

    loadData() {
        if (!this.recordId) {
            console.error('Cannot load data: recordId is null');
            this.isLoading = false;
            return;
        }

        console.log('Loading data for Candidate ID:', this.recordId);
        this.isLoading = true;

        getCandidateData({ candidateId: this.recordId })
            .then(result => {
                console.log('Candidate data loaded successfully');
                
                this.candidateData = { 
                    ...result.candidate,
                    Id: this.recordId
                };
                
                console.log('candidateData.Id:', this.candidateData.Id);
                
                this.educationRecords = (result.educationRecords || []).map((edu, index) => ({
                    ...edu,
                    uniqueId: edu.Id || `temp-edu-${Date.now()}-${index}`,
                    displayIndex: index + 1,
                    uploadedFiles: []
                }));
                
                this.familyRecords = (result.familyRecords || []).map((fam, index) => ({
                    ...fam,
                    uniqueId: fam.Id || `temp-fam-${Date.now()}-${index}`,
                    displayIndex: index + 1
                }));
                
                this.workRecords = (result.workRecords || []).map((work, index) => ({
                    ...work,
                    uniqueId: work.Id || `temp-work-${Date.now()}-${index}`,
                    displayIndex: index + 1,
                    uploadedFiles: []
                }));
                
                this.bankRecords = (result.bankRecords || []).map((bank, index) => ({
                    ...bank,
                    uniqueId: bank.Id || `temp-bank-${Date.now()}-${index}`,
                    displayIndex: index + 1,
                    uploadedFiles: []
                }));
                
                this.isLoading = false;
            })
            .catch(error => {
                console.error('Error loading candidate data:', error);
                this.isLoading = false;
                this.showToast('Error', 'Failed to load candidate data: ' + this.getErrorMessage(error), 'error');
            });
    }

    mapPicklistOptions(picklistArray) {
        if (!picklistArray || !Array.isArray(picklistArray)) return [];
        return picklistArray.map(item => ({
            label: item.label,
            value: item.value
        }));
    }

    handleCandidateChange(event) {
        const field = event.target.name;
        const value = event.detail.value;
        
        this.candidateData = {
            ...this.candidateData,
            [field]: value,
            Id: this.recordId
        };
        
        console.log(`Updated ${field}:`, value);
    }
/*handleSourceChange(event) {
    this.handleCandidateChange(event); // update main data object

    const selectedValue = event.detail.value;
    this.isAdvertisement = selectedValue === 'Advertisement';
    this.isConsultancy = selectedValue === 'Consultancy';
    this.isReferred = selectedValue === 'Referred';
    this.isCampus = selectedValue === 'Campus';
}*/
handleSourceChange(event) {
    // Always update the main data object first
    this.handleCandidateChange(event);

    const selectedValue = event.detail.value;

    // Compute all flags in a single place to keep them mutually exclusive and predictable
    const isAdvertisement = selectedValue === 'Advertisement';
    const isConsultancy = selectedValue === 'Consultancy';
    const isReferred = selectedValue === 'Referred';
    const isCampus = selectedValue === 'Campus';

    // If the source changed to a different type, clear values of fields that will be hidden
    // to avoid stale data being submitted
    if (!isAdvertisement) {
        this.candidateData.Mode_Of_Advertising__c = '';
    }
    if (!isConsultancy) {
        this.candidateData.Consultancy_Name__c = '';
    }
    if (!isReferred) {
        this.candidateData.Referred_Person_Name__c = '';
    }
    if (!isCampus) {
        this.candidateData.Campus_Name__c = '';
        this.candidateData.Campus_City__c = '';
    }

    // Assign booleans last so UI reactivity happens after data cleanup
    this.isAdvertisement = isAdvertisement;
    this.isConsultancy = isConsultancy;
    this.isReferred = isReferred;
    this.isCampus = isCampus;
}
   handleEducationFileUpload(event) {
    const index = parseInt(event.target.dataset.index);
    const file = event.target.files[0];
    if (!file) return;

    const edu = this.educationRecords[index];
    const recordId = edu.Id; // Only works after record is created

    if (recordId) {
        this.uploadFileToRecord(file, recordId, `Education #${index + 1}`, 'Education_Detail__c');
        // Optionally store uploaded file info in LWC state
        edu.uploadedFiles = edu.uploadedFiles || [];
        edu.uploadedFiles.push({ fileName: file.name });
    } else {
        this.showToast('Info', 'Please save Education record before uploading.', 'info');
    }
}

    removeEducationFile(event) {
        console.log('=== Remove Education File ===');
        const index = parseInt(event.target.dataset.index);
        const fileId = event.target.dataset.fileId;
        console.log('Removing file:', fileId, 'from index:', index);
        
        this.educationRecords = this.educationRecords.map((edu, i) => {
            if (i === index) {
                return {
                    ...edu,
                    uploadedFiles: (edu.uploadedFiles || []).filter(file => file.documentId !== fileId)
                };
            }
            return edu;
        });
        
        this.showToast('Success', 'File removed', 'success');
    }

   
handleWorkFileUpload(event) {
    const index = parseInt(event.target.dataset.index);
    const file = event.target.files[0];
    if (!file) return;

    const work = this.workRecords[index];
    const recordId = work.Id;

    if (recordId) {
        this.uploadFileToRecord(file, recordId, `Work Experience #${index + 1}`, 'Work_Experience__c');
        work.uploadedFiles = work.uploadedFiles || [];
        work.uploadedFiles.push({ fileName: file.name });
    } else {
        this.showToast('Info', 'Please save Work Experience record before uploading.', 'info');
    }
}
    removeWorkFile(event) {
        const index = parseInt(event.target.dataset.index);
        const fileId = event.target.dataset.fileId;
        
        this.workRecords = this.workRecords.map((work, i) => {
            if (i === index) {
                return {
                    ...work,
                    uploadedFiles: (work.uploadedFiles || []).filter(file => file.documentId !== fileId)
                };
            }
            return work;
        });
        
        this.showToast('Success', 'File removed', 'success');
    }

    // Bank File Upload Handler with Debug Logging
   handleBankFileChange(event) {
    const index = parseInt(event.target.dataset.index);
    const file = event.target.files[0];
    if (!file) {
        this.showToast('Error', 'No file selected for Bank Proof upload.', 'error');
        return;
    }

    // Upload file to Candidate record
    this.uploadFileToRecord(file, this.recordId, `Bank Proof #${index + 1}`, 'Candidate__c');

    // Store temporarily for UI display
    this.bankRecords = this.bankRecords.map((bank, i) => {
        if (i === index) {
            return {
                ...bank,
                uploadedFiles: [{ fileName: file.name }]
            };
        }
        return bank;
    });

    this.showToast('Success', `Bank proof "${file.name}" selected and uploaded successfully`, 'success');
}


    removeBankFile(event) {
        const index = parseInt(event.target.dataset.index);
        const fileId = event.target.dataset.fileId;
        
        this.bankRecords = this.bankRecords.map((bank, i) => {
            if (i === index) {
                return {
                    ...bank,
                    uploadedFiles: (bank.uploadedFiles || []).filter(file => file.documentId !== fileId)
                };
            }
            return bank;
        });
        
        this.showToast('Success', 'File removed', 'success');
    }

    handleEducationChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        
        this.educationRecords = this.educationRecords.map((edu, i) => {
            if (i === index) {
                return { ...edu, [field]: value };
            }
            return edu;
        });
    }

    handleAddEducation() {
        const newEducation = {
            uniqueId: `temp-edu-${Date.now()}`,
            displayIndex: this.educationRecords.length + 1,
            Education_Type__c: '',
            Institution_Name__c: '',
            Board_University__c: '',
            Course_Stream__c: '',
            Mode_of_Study__c: '',
            Year_of_Completion__c: null,
            Percentage__c: null,
            Certificate_Attached__c: false,
            uploadedFiles: []
        };
        this.educationRecords = [...this.educationRecords, newEducation];
    }

    handleDeleteEducation(event) {
        const index = parseInt(event.target.dataset.index);
        this.educationRecords = this.educationRecords.filter((_, i) => i !== index);
        this.educationRecords = this.educationRecords.map((edu, i) => ({
            ...edu,
            displayIndex: i + 1
        }));
    }

    handleFamilyChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.detail.value;
        
        this.familyRecords = this.familyRecords.map((fam, i) => {
            if (i === index) {
                return { ...fam, [field]: value };
            }
            return fam;
        });
    }

    handleAddFamily() {
        const newFamily = {
            uniqueId: `temp-fam-${Date.now()}`,
            displayIndex: this.familyRecords.length + 1,
            Name__c: '',
            Relationship__c: '',
            Date_Of_Birth__c: null,
            Age__c: null,
            Contact_No__c: '',
            Occupation__c: ''
        };
        this.familyRecords = [...this.familyRecords, newFamily];
    }

    handleDeleteFamily(event) {
        const index = parseInt(event.target.dataset.index);
        this.familyRecords = this.familyRecords.filter((_, i) => i !== index);
        this.familyRecords = this.familyRecords.map((fam, i) => ({
            ...fam,
            displayIndex: i + 1
        }));
    }

    handleWorkChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        
        this.workRecords = this.workRecords.map((work, i) => {
            if (i === index) {
                return { ...work, [field]: value };
            }
            return work;
        });
    }

    handleAddWork() {
        const newWork = {
            uniqueId: `temp-work-${Date.now()}`,
            displayIndex: this.workRecords.length + 1,
            Company_Name__c: '',
            Designation__c: '',
            Employment_Type__c: '',
            Start_Date__c: null,
            End_Date__c: null,
            Currently_Working__c: false,
            Experience_Years__c: null,
            Skills_Technologies_Used__c: '',
            uploadedFiles: []
        };
        this.workRecords = [...this.workRecords, newWork];
    }

    handleDeleteWork(event) {
        const index = parseInt(event.target.dataset.index);
        this.workRecords = this.workRecords.filter((_, i) => i !== index);
        this.workRecords = this.workRecords.map((work, i) => ({
            ...work,
            displayIndex: i + 1
        }));
    }

    handleBankChange(event) {
        const index = parseInt(event.target.dataset.index);
        const field = event.target.name;
        const value = event.target.type === 'checkbox' ? event.target.checked : event.detail.value;
        
        this.bankRecords = this.bankRecords.map((bank, i) => {
            if (i === index) {
                return { ...bank, [field]: value };
            }
            return bank;
        });
    }

    handleAddBank() {
        const newBank = {
            uniqueId: `temp-bank-${Date.now()}`,
            displayIndex: this.bankRecords.length + 1,
            Bank_Name__c: '',
            Branch_Name__c: '',
            Account_Holder_Name__c: '',
            Account_Number__c: '',
            IFSC_Code__c: '',
            Account_Type__c: '',
            Primary_Account__c: false,
            Status__c: '',
            Remarks__c: '',
            uploadedFiles: []
        };
        this.bankRecords = [...this.bankRecords, newBank];
    }

    handleDeleteBank(event) {
        const index = parseInt(event.target.dataset.index);
        this.bankRecords = this.bankRecords.filter((_, i) => i !== index);
        this.bankRecords = this.bankRecords.map((bank, i) => ({
            ...bank,
            displayIndex: i + 1
        }));
    }

    handleSameAddressChange(event) {
        this.sameAsCommAddress = event.target.checked;
        if (this.sameAsCommAddress) {
            this.candidateData = {
                ...this.candidateData,
                Permanent_Address__Street__s: this.candidateData.Communication_Address__Street__s,
                Permanent_Address__City__s: this.candidateData.Communication_Address__City__s,
                Permanent_Address__StateCode__s: this.candidateData.Communication_Address__StateCode__s,
                Permanent_Address__CountryCode__s: this.candidateData.Communication_Address__CountryCode__s,
                Permanent_Address__PostalCode__s: this.candidateData.Communication_Address__PostalCode__s
            };
        }
    }

    handleDeclarationChange(event) {
        this.declarationAccepted = event.target.checked;
    }

    handleNext() {
        const steps = ['personal', 'address', 'education', 'family', 'work', 'bank', 'review'];
        const currentIndex = steps.indexOf(this.currentStep);
        
        // Validation before moving to next step
        if (this.currentStep === 'personal') {
            if (!this.aadharUploaded || !this.panUploaded) {
                this.showToast('Warning', 'Please upload Aadhar and PAN documents before proceeding', 'warning');
                console.warn('Validation failed: Aadhar uploaded:', this.aadharUploaded, 'PAN uploaded:', this.panUploaded);
                return;
            }
        }
        
        if (currentIndex < steps.length - 1) {
            this.currentStep = steps[currentIndex + 1];
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    handlePrevious() {
        const steps = ['personal', 'address', 'education', 'family', 'work', 'bank', 'review'];
        const currentIndex = steps.indexOf(this.currentStep);
        if (currentIndex > 0) {
            this.currentStep = steps[currentIndex - 1];
            window.scrollTo({ top: 0, behavior: 'smooth' });
        }
    }

    handleSubmit() {
        if (!this.declarationAccepted) {
            this.showToast('Error', 'Please accept the declaration before submitting', 'error');
            return;
        }
        
        if (!this.recordId || !this.candidateData.Id) {
            this.showToast('Error', 'Cannot submit: Candidate ID is missing', 'error');
            console.error('recordId or candidateData.Id is missing');
            return;
        }
        
        console.log('=== Submitting Form ===');
        console.log('Candidate ID:', this.candidateData.Id);
        
        this.isLoading = true;
        
        const cleanedData = this.prepareDataForSave();
        
        saveCandidateData({
            candidateData: JSON.stringify(this.candidateData),
            educationData: JSON.stringify(cleanedData.education),
            familyData: JSON.stringify(cleanedData.family),
            workData: JSON.stringify(cleanedData.work),
            bankData: JSON.stringify(cleanedData.bank)
        })
        /*.then(result => {
            if (result === 'SUCCESS') {
                this.showSuccess = true;
                this.showToast('Success', 'Your onboarding form has been submitted successfully!', 'success');
            }
        })*/
         .then(result => {
        if (result === 'SUCCESS') {
            console.log('✅ Candidate data saved successfully');

            // 1️⃣ Call onboarding completion update
            return markOnboardingCompleted({ candidateId: this.candidateData.Id });
        } else {
            throw new Error('Unexpected result from saveCandidateData: ' + result);
        }
    })
     .then(updateResult => {
        if (updateResult === 'SUCCESS') {
            this.showSuccess = true;
            this.showToast('Success', 'Your onboarding form has been submitted successfully!', 'success');

            // Optionally redirect or show completion screen
            // Example: window.location.href = '/thankyou';
        } else {
            console.warn('⚠️ Onboarding completion update returned:', updateResult);
        }
    })
            .catch(error => {
            console.error('Submit error:', error);
            this.showToast('Error', 'Failed to submit form: ' + this.getErrorMessage(error), 'error');
        })
        .finally(() => {
            this.isLoading = false;
        });
    }

    prepareDataForSave() {
        const cleanRecord = (record) => {
            const clean = { ...record };
            if (clean.Id && (clean.Id.startsWith('temp-') || clean.Id.length !== 18)) {
                delete clean.Id;
            }
            delete clean.uniqueId;
            delete clean.displayIndex;
            delete clean.uploadedFiles;
            return clean;
        };

        return {
            education: this.educationRecords.map(cleanRecord),
            family: this.familyRecords.map(cleanRecord),
            work: this.workRecords.map(cleanRecord),
            bank: this.bankRecords.map(cleanRecord)
        };
    }

    get isPersonalStep() { return this.currentStep === 'personal'; }
    get isAddressStep() { return this.currentStep === 'address'; }
    get isEducationStep() { return this.currentStep === 'education'; }
    get isFamilyStep() { return this.currentStep === 'family'; }
    get isWorkStep() { return this.currentStep === 'work'; }
    get isBankStep() { return this.currentStep === 'bank'; }
    get isReviewStep() { return this.currentStep === 'review'; }
    
    get isFirstStep() { return this.currentStep === 'personal'; }
    get isLastStep() { return this.currentStep === 'review'; }
    get submitDisabled() { return !this.declarationAccepted; }
    
    get hasEducationRecords() { return this.educationRecords.length > 0; }
    get hasFamilyRecords() { return this.familyRecords.length > 0; }
    get hasWorkRecords() { return this.workRecords.length > 0; }
    get hasBankRecords() { return this.bankRecords.length > 0; }
    
    get isMarried() {
        return this.candidateData.Marital_Status__c === 'Married';
    }

    getErrorMessage(error) {
        console.error('Full error object:', error);
        if (error.body) {
            if (error.body.message) return error.body.message;
            if (error.body.pageErrors && error.body.pageErrors.length > 0) {
                return error.body.pageErrors[0].message;
            }
            if (error.body.fieldErrors) {
                const fieldErrors = Object.values(error.body.fieldErrors).flat();
                if (fieldErrors.length > 0) {
                    return fieldErrors[0].message;
                }
            }
        }
        return error.message || 'Unknown error occurred';
    }

    showToast(title, message, variant) {
        const event = new ShowToastEvent({ title, message, variant, mode: 'sticky' });
        this.dispatchEvent(event);
        
        // Also log to console for debugging
        console.log(`Toast [${variant}]: ${title} - ${message}`);
    }
    handleFileChangeAadhar(event) {
        const file = event.target.files[0];
        if (!file) {
            this.showToast('Error', 'No file selected for Aadhar upload.', 'error');
            return;
        }
        this.aadharFileName = file.name;
        this.uploadFileToRecord(file, this.recordId, 'Aadhar');
    }

handleFileChangePAN(event) {
    const file = event.target.files[0];
    if (!file) {
        this.showToast('Error', 'No file selected for PAN upload.', 'error');
        return;
    }
    this.panFileName = file.name;
    this.uploadFileToRecord(file, this.recordId, 'PAN');
}
handleFileChangeUAN(event) {
    const file = event.target.files[0];
    if (!file) return;
    this.uanFileName = file.name;
    this.uploadFileToRecord(file, this.recordId, 'UAN', 'Candidate__c');
}

handleFileChangeDL(event) {
    const file = event.target.files[0];
    if (!file) return;
    this.dlFileName = file.name;
    this.uploadFileToRecord(file, this.recordId, 'Driving License', 'Candidate__c');
}
// Generic uploader for reusability
uploadFileToRecord(file, recordId, labelName, targetObject) {
    if (!recordId) {
        this.showToast('Error', 'Record not initialized for upload.', 'error');
        return;
    }

    const reader = new FileReader();
    reader.onload = () => {
        const base64 = reader.result.split(',')[1];
        uploadFile({ recordId, fileName: file.name, base64Data: base64, contentType: file.type })
            .then((docId) => {
                this.showToast('Success', `${labelName} file uploaded successfully`, 'success');
                console.log(`${labelName} uploaded to ${targetObject}: ${docId}`);
                if (labelName === 'Aadhar') this.aadharUploaded = true;
                if (labelName === 'PAN') this.panUploaded = true;
                if (labelName === 'UAN') this.uanUploaded = true;
                if (labelName === 'Driving License') this.dlUploaded = true;
            })
            .catch((error) => {
                console.error('Upload error:', error);
                this.showToast('Error', 'Upload failed: ' + this.getErrorMessage(error), 'error');
            });
    };
    reader.readAsDataURL(file);
}
}