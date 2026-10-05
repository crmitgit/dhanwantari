import { LightningElement, api, track } from 'lwc';

export default class MedicationFlowPhi3 extends LightningElement {
    @api recordId;

    @track showActiveModal = true;
    @track showAiModal = false;

    handleNext() {
        this.showActiveModal = false;
        this.showAiModal = true;
    }

    handleClose() {
        this.dispatchEvent(new CustomEvent('close'));
    }
    handleBack() {
        this.showAiModal = false;
        this.showActiveModal = true;
    }

}