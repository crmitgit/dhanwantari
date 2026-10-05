import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createRequest from '@salesforce/apex/DiagnosisController.createRequest';
import getEncounterDetails from '@salesforce/apex/DiagnosisController.getEncounterDetails';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';

export default class DiagnosisModal extends LightningElement {
    @api clinicalEncounterId;
    @track isModalOpen = true;
    @api recordId;
    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;
    patientId;
    encounterName;
    patientName;
    patientUrl;
    @track isLoading = false;

    clinicalDiagnosis = '';
    severity = '';
    diagnosisType = 'Provisional';

    severityOptions = [
        { label: 'Chronic / दीर्घकालिक ', value: 'Chronic' },
        { label: 'Acute / अचानक ', value: 'Acute' }
    ];

    typeOptions = [
        { label: 'Provisional / अस्थायी निदान', value: 'Provisional' },
        { label: 'Final / अंतिम निदान', value: 'Final' }
    ];

    @wire(getEncounterDetails, { encounterId: '$recordId' })
    wiredEncounter({ error, data }) {
        if (data) {
            this.encounterName = data.EncounterName;
            this.patientId = data.PatientId;
            this.patientName = data.PatientName;
            console.log('patient name is: ',this.patientName);
            this.patientUrl = `/lightning/r/Contact/${this.patientId}/view`;
            if (data.Status === 'Completed') {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Action Not Allowed/ कार्य अनुमति नहीं है',
                        message: 'This Clinical Encounter is already marked as Completed. You cannot add a new diagnosis/ यह अपॉइंटमेंट पहले ही पूर्ण के रूप में चिह्नित है। आप नया निदान नहीं जोड़ सकते।',
                        variant: 'warning'
                    })
                );

                // Close modal
                this.closeModal();
            }
            if (data.Status === 'Referred') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Action Not Allowed/ कार्य अनुमति नहीं है',
                    message: 'This Clinical Encounter is already marked as Referred. You cannot add a new medication./ यह अपॉइंटमेंट पहले ही रेफ़र के रूप में चिह्नित है। आप नई दवा नहीं जोड़ सकते।',
                    variant: 'warning'
                })
            );
            // Close modal
            this.closeModal();
        }
        } else if (error) {
            console.error('Error retrieving encounter details:', error);
        }
    }

    handleNewDiagnosis(event) {
        this.clinicalDiagnosis = event.target.value;
    }


    handleSeverityChange(event) {
        this.severity = event.detail.value;
    }

    handleTypeChange(event) {
        this.diagnosisType = event.detail.value;
    }

    closeModal() {
        this.isModalOpen = false;
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    submitRequest() {
        // Validations
        if (!this.clinicalDiagnosis || this.clinicalDiagnosis.trim().length < 10) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Validation Error',
                    message: 'Clinical Diagnosis must be at least 10 characters long\n/ नैदानिक निदान कम से कम 10 अक्षरों का होना चाहिए।',
                    variant: 'error'
                })
            );
            return;
        }

        if (!this.diagnosisType) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing Required Fields',
                    message: 'Please select a Diagnosis Type\n/ कृपया निदान प्रकार चुनें।',
                    variant: 'error'
                })
            );
            return;
        }

        this.isLoading = true; // 🔄 Show spinner

        createRequest({
            clinicalEncounterId: this.recordId,
            patientName: this.patientId,
            clinicalDiagnosis: this.clinicalDiagnosis,
            severity: this.severity,
            diagnosisType: this.diagnosisType
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'New Diagnosis created successfully!\n/ नया निदान सफलतापूर्वक बनाया गया है।',
                        variant: 'success'
                    })
                );
                this.isLoading = false; // ✅ Hide spinner
                location.reload();
                this.closeModal();
            })
            .catch(error => {
                console.error('Error creating request:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to create Diagnosis\n/ निदान बनाने में विफल।',
                        variant: 'error'
                    })
                );
                this.isLoading = false; // ✅ Hide spinner
            });
    }

}