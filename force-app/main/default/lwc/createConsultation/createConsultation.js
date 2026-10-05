import { LightningElement, api, track } from 'lwc';
import createConsultation from '@salesforce/apex/ClinicalEncounterController2.createConsultation';
import getPatientDetails from '@salesforce/apex/ClinicalEncounterController2.getPatientDetails';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';

export default class CreateConsultation extends NavigationMixin(LightningElement) {

    @api recordId;

    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;

    @track isModalOpen = true;
    @track form = {};

    patientName;
    patientUrl;

    connectedCallback() {
        console.log('record id: ', this.recordId);
        this.form.Status = 'Started';
        this.form.StartDate = new Date().toISOString().split('T')[0];

        this.patientUrl = `/lightning/r/Contact/${this.recordId}/view`;

        getPatientDetails({ patientId: this.recordId })
            .then(res => {
                this.patientName = res.Name;
                this.form.Height_in_cm__c = res.Height_in_cm__c;
                this.form.Weight_in_Kg__c = res.Weight_in_Kg__c;
                console.log(this.form.Weight_in_Kg__c);
            });
    }

    handleChange(event) {
        const field = event.target.dataset.field;
        this.form[field] = event.target.value;

        if (field === 'StartDate') {
            this.validateStartDate();
        }
    }

    handleSave() {

        if (!this.form.Patient_Type__c || !this.form.Status || !this.form.StartDate || !this.form.Category || !this.form.Symptoms__c
        || !this.form.Height_in_cm__c || !this.form.Weight_in_Kg__c || !this.form.Pulse_Rate_in_BPM__c || !this.form.Body_Temperature__c
        || !this.form.SpO2__c || !this.form.Blood_Pressure__c) {
            this.showToast('Error', 'Please fill in all the required fields.', 'error');
            return;
        }

        const input = this.template.querySelector('[data-field="StartDate"]');
        if(input){
            const value = input.value;
            const today = new Date().toISOString().split('T')[0];
                if (value && value < today) {
                    this.showToast('Error', 'Start Date cannot be in the past', 'error');
                    return;
                }
        }

        let startDateTime = null;

        if (this.form.StartDate) {
            const date = new Date(this.form.StartDate);

            // force local midnight (NOT UTC)
            const year = date.getFullYear();
            const month = String(date.getMonth() + 1).padStart(2, '0');
            const day = String(date.getDate()).padStart(2, '0');

            startDateTime = `${year}-${month}-${day} 00:00:00`;
        }

        createConsultation({
            patientId: this.recordId,
            consultationType: this.form.Patient_Type__c,
            status: this.form.Status,
            category: this.form.Category,
            startDate: startDateTime,
            symptoms: this.form.Symptoms__c,
            vikriti: this.form.Vikriti__c,
            additionalInfo: this.form.Additional_Information__c,

            height: this.form.Height_in_cm__c,
            weight: this.form.Weight_in_Kg__c,
            pulse: this.form.Pulse_Rate_in_BPM__c,
            temperature: this.form.Body_Temperature__c,
            spo2: this.form.SpO2__c,
            bloodPressure: this.form.Blood_Pressure__c
        })
        .then((recordId) => {
            this.showToast('Success', 'Consultation created', 'success');

            this[NavigationMixin.Navigate]({
                type: 'standard__recordPage',
                attributes: {
                    recordId: recordId,
                    objectApiName: 'ClinicalEncounter',
                    actionName: 'view'
                }
            })
        })
        .catch(error => {
            console.error(error);
            this.showToast('Error', 'Failed to create', 'error');
        });
        console.log('start date: ', this.form.StartDate);
    }

    closeModal() {
        this.isModalOpen = false;
        this.dispatchEvent(new CustomEvent('close'));
    }

    showToast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }

    get consultationTypeOptions() {
        return [
            { label: 'New', value: 'New' },
            { label: 'Follow-up', value: 'Follow-up' }
        ];
    }

    get statusOptions() {
        return [
            { label: 'Started', value: 'Started' },
            { label: 'Ongoing', value: 'Ongoing' },
            { label: 'Approval Pending', value: 'Approval Pending' },
            { label: 'Diagnosis Approved', value: 'Diagnosis Approved' },
            { label: 'Referred', value: 'Referred' },
            { label: 'Completed', value: 'Completed' },
            { label: 'Cancelled', value: 'Cancelled' }
        ];
    }

    get categoryOptions() {
        return [
            { label: 'Ambulatory', value: 'Ambulatory' },
            { label: 'Emergency', value: 'Emergency' },
            { label: 'Home Health', value: 'Home Health' },
            { label: 'Inpatient Encounter', value: 'Inpatient Encounter' }
        ];
    }

    get vikritiOptions() {
        return [
            { label: 'High Vata', value: 'High Vata' },
            { label: 'High Pitta', value: 'High Pitta' },
            { label: 'High Kapha', value: 'High Kapha' }
        ];
    }

    get todayDate() {
        return new Date().toISOString().split('T')[0];
    }

    validateStartDate() {
        const input = this.template.querySelector('[data-field="StartDate"]');
        if (!input) return;

        const value = input.value;
        const today = new Date().toISOString().split('T')[0];

        if (value && value < today) {
            input.setCustomValidity('Start Date cannot be in the past');
        } else {
            input.setCustomValidity('');
        }
    }
}