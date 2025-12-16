import { LightningElement, api } from 'lwc';

export default class OfferLetterPreview extends LightningElement {
    @api recordId;

    get previewUrl() {
        // Dynamically build the VF page URL
        // Replace the domain with your org domain if needed
        return '/apex/OfferLetterPDF?id=' + this.recordId;
    }
}