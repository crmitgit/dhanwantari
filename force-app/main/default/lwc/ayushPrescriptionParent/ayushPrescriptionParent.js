import { LightningElement, api, track } from 'lwc';
import leafIcon from '@salesforce/resourceUrl/AyushLeafIcon';

export default class MedicationFlow extends LightningElement {
    @api recordId;

    @track showDisclaimer = true;     // 👈 START HERE
    @track showActiveModal = false;
    @track showAiModal = false;
    leafIcon = leafIcon;
    //isLoading = false;
    isLoading = false;

    handleProceed() {
        this.showDisclaimer = false;
        // this.isLoading = true;   
        this.showActiveModal = true;
    }

    handleNext() {
        this.isLoading = true;
        this.showActiveModal = false;
        this.showAiModal = true;
    }
    handleBack() {
        this.showAiModal = false;
        this.showActiveModal = true;
    }

    handleChildReady() {
        this.isLoading = false;   
    }

    // Close everything
    handleClose() {
        this.showDisclaimer = false;
        this.showActiveModal = false;
        this.showAiModal = false;
        this.dispatchEvent(new CustomEvent('close'));
    }
}