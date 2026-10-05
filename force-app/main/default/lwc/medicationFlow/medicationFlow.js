import { LightningElement, api, track } from 'lwc';
import getMedicationType from '@salesforce/apex/MedicationController.getMedicationType';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class MedicationFlow extends LightningElement {
    @api recordId;

    // @track showActiveModal = true;
    // @track showAiModal = false;
    isLoading = true;
    showActiveModal = false;
    showAiModal = false;
    isReady = false;
    hasChecked = false; // IMPORTANT

    connectedCallback() {
        this.validateMedication();
    }
    async validateMedication() {

        try {

            const result = await getMedicationType({
                consultationId: this.recordId
            });

            // ❌ AYURVEDIC CASE
            if (result === 'Ayurvedic') {
                this.handleClose();
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Not Allowed',
                        message:
                            'AI Medication Assistant cannot be used for Ayurvedic medications.',
                        variant: 'error'
                    })
                );
                return;
            }

            // ✅ ALLOWED → NOW SHOW REAL UI
            this.isLoading = false;
            this.showActiveModal = true;

        } catch (error) {

            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Unable to validate medication.',
                    variant: 'error'
                })
            );

            this.dispatchEvent(new CloseActionScreenEvent());
        }
    }
    

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