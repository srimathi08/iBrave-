import { LightningElement, api, wire, track } from 'lwc';
import getProfilePhotoUrl from '@salesforce/apex/HR_ProfilePhotoService.getProfilePhotoUrl';
import markContactProfilePhoto from '@salesforce/apex/HR_ProfilePhotoService.markContactProfilePhoto';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class HrContactProfilePhoto extends LightningElement {
    @api recordId; // Contact Id
    @track currentPhotoUrl;

    @wire(getProfilePhotoUrl, { contactId: '$recordId' })
    wiredPhoto({ data, error }) {
        if (data) {
            this.currentPhotoUrl = data;
        } else if (error) {
            // optional: toast / log
        }
    }

    async handleUploadFinished(event) {
        const uploadedFiles = event.detail.files;
        if (!uploadedFiles || uploadedFiles.length === 0) return;

        const docId = uploadedFiles[0].documentId;

        try {
            await markContactProfilePhoto({ contactId: this.recordId, contentDocumentId: docId });

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Profile photo saved and synced to User.',
                    variant: 'success'
                })
            );

            // refresh preview
            this.currentPhotoUrl = null;
            // simple reload of wire
            getProfilePhotoUrl({ contactId: this.recordId }).then(url => {
                this.currentPhotoUrl = url;
            });

        } catch (e) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: e.body ? e.body.message : e.message,
                    variant: 'error'
                })
            );
        }
    }
}