import { LightningElement, api } from 'lwc';

export default class AppointmentletterPreview extends LightningElement {
    @api recordId;
    @api docType; // 'Appointment' or 'NDA'

    /*get appointmentUrl() {
    return '/apex/AppointmentLetterVF?id=' + this.recordId;
}

get ndaUrl() {
    return '/apex/NDADocumentVF?id=' + this.recordId;
}*/
get previewUrl() {
    let url;
    if (this.docType === 'NDA') {
        url = '/apex/NDADocumentVF?id=' + this.recordId;
    } else {
        url = '/apex/AppointmentLetterVF?id=' + this.recordId;
    }
    // debug
    // eslint-disable-next-line no-console
    console.log('docType in getter:', this.docType, 'url:', url);
    return url;
}

get title() {
    return this.docType === 'NDA'
        ? 'NDA Preview'
        : 'Appointment Letter Preview';
}



connectedCallback() {
// eslint-disable-next-line no-console
console.log('docType from Flow:', this.docType);
}
}