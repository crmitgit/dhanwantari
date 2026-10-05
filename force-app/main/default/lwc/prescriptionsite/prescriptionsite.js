import { LightningElement, track, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getEncounterDetails from '@salesforce/apex/PrescriptionController.getEncounterDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class Prescriptionsite extends LightningElement {
    @track summary;
    @track isLoading = true;
    @track error;
    encounterId;
    token;

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference) {
        if (currentPageReference && currentPageReference.state) {
            this.encounterId = currentPageReference.state.id;
            this.token = currentPageReference.state.token;
            
            if (this.encounterId) {
                this.loadEncounterDetails();
            }
        }
    }

    loadEncounterDetails() {
        this.isLoading = true;
        getEncounterDetails({ encounterName: this.encounterId })
            .then(result => {
                this.summary = result;
                this.isLoading = false;
                this.error = null;
            })
            .catch(error => {
                this.error = error;
                this.isLoading = false;
                this.showToast('Error', 'Failed to load prescription details', 'error');
                console.error('Error loading encounter details:', error);
            });
    }

    get formattedMedications() {
        if (!this.summary || !this.summary.medications) return [];
        return this.summary.medications.map((med) => {
            let parts = [];
            if (med.morning && med.morning !== "N/A") parts.push(`Morning ${med.morning}`);
            if (med.afternoon && med.afternoon !== "N/A") parts.push(`Afternoon ${med.afternoon}`);
            if (med.night && med.night !== "N/A") parts.push(`Night ${med.night}`);
            
            // Join dosage parts with ', ', then append food only if there's dosage
            let dosageStr = parts.length ? parts.join(', ') : '';
            if (med.food && med.food !== "N/A") {
                dosageStr += dosageStr ? ` (${med.food})` : `(${med.food})`;
            }
            return {
                ...med,
                dosage: dosageStr
            };
        });
    }

    get isMedicationEmpty() {
        return !this.formattedMedications || this.formattedMedications.length === 0;
    }

    get currentDate() {
        return new Date().toLocaleDateString('en-IN', {
            day: '2-digit',
            month: 'short',
            year: 'numeric'
        });
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
        });
        this.dispatchEvent(evt);
    }

    handlePrint() {
        window.print();
    }
}