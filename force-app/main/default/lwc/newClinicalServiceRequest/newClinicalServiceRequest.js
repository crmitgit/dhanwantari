import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createRequest from '@salesforce/apex/ClinicalServiceRequestController.createRequest';
import getEncounterDetails from '@salesforce/apex/ClinicalServiceRequestController.getEncounterDetails';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';

export default class ClinicalServiceRequestModal extends LightningElement {
    @api clinicalEncounterId;
    @track isModalOpen = true;
    @api recordId;
    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;
    patientId;
    encounterName;
    patientName;
    patientUrl;
    requestedById;
    requestedTest = '';
    status = 'Ordered';
    priority = '';
    requestedCompletionDate = '';
    completedOn = '';
    isSaveDisabled = false;
    dateValue = '';
    notes = '';

    handleNotesChange(event) {
        this.notes = event.target.value;
    }

    // Computed label
    get completionLabel() {
        return this.status === 'Completed'
            ? 'Completion Date / पूर्ण तिथि'
            : 'Complete By / अनुरोधित पूर्णता तिथि';
    }

    get isDateRequired() {
        return this.status === 'Completed' || this.status === 'Ordered';
    }

    get minDate() {
        const today = new Date();
        return today.toISOString().split('T')[0];
    }

    get isStatusOrdered() {
        return this.status === 'Ordered';
    }

    get isStatusCompleted() {
        return this.status === 'Completed';
    }

    statusOptions = [
        { label: 'Ordered / अनुसूचित', value: 'Ordered' },
        { label: 'Completed / पूर्ण', value: 'Completed' }
    ];

    @wire(getEncounterDetails, { encounterId: '$recordId' })
    wiredEncounter({ error, data }) {
        if (data) {
            this.encounterName = data.EncounterName;
            this.patientId = data.PatientId;
            this.patientName = data.PatientName;
            this.patientUrl = `/lightning/r/Contact/${this.patientId}/view`;
            if (data.Status === 'Completed') {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Action Not Allowed/ कार्य अनुमति नहीं है',
                        message: 'This Clinical Encounter is already marked as Completed. You cannot add a new request/ यह अपॉइंटमेंट पहले ही पूर्ण के रूप में चिह्नित है। आप नया अनुरोध नहीं जोड़ सकते।',
                        variant: 'warning'
                    })
                );
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

    handleRequestedTestChange(event) {
        this.requestedTest = event.target.value;
    }

    handleLookupChange(event) {
        const fieldName = event.target.fieldName;
        const value = event.detail.value;
        if (fieldName === 'Requested_By__c') {
            this.requestedById = value;
        }
    }

    // handleStatusChange(event) {
    //     this.status = event.detail.value;
    // }

    handleRequestedDateChange(event) {
        this.requestedCompletionDate = event.target.value;
    }

    // handleRequestedDateChangeCompleted(event) {
    //     this.completedOn = event.target.value;
    // }

    handleDateChange(event) {
        this.dateValue = event.target.value;
    }


    closeModal() {
        this.isModalOpen = false;
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
    }

    submitRequest() {
        if (!this.requestedTest || this.requestedTest.trim() === '') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing Required Field',
                    message: 'Please enter the Requested Test\n/ कृपया अनुरोधित परीक्षण दर्ज करें।',
                    variant: 'error'
                })
            );
            return;
        }

        // if (this.status === 'Ordered' && !this.requestedCompletionDate) {
        //     this.dispatchEvent(
        //         new ShowToastEvent({
        //             title: 'Missing Date',
        //             message: 'Please select a Requested Completion Date\n/ कृपया अनुरोधित पूर्णता तिथि चुनें।',
        //             variant: 'error'
        //         })
        //     );
        //     return;
        // }

        // if (this.status === 'Completed' && !this.completedOn) {
        //     this.dispatchEvent(
        //         new ShowToastEvent({
        //             title: 'Missing Date',
        //             message: 'Please select the Completion Date\n/ कृपया पूर्ण तिथि चुनें।',
        //             variant: 'error'
        //         })
        //     );
        //     return;
        // }
        
        if (this.isDateRequired && !this.dateValue) {
            this.dispatchEvent(new ShowToastEvent({
                title: 'Missing Date',
                message: 'Please select the Completion date\n/ कृपया तिथि चुनें।',
                variant: 'error'
            }));
            return;
        }

        const today = new Date();
        const selectedDate = new Date(this.dateValue);
        today.setHours(0, 0, 0, 0);
        selectedDate.setHours(0, 0, 0, 0);

        console.log('selectedDate < today++',selectedDate < today);
        console.log('Status+++',this.status);
        console.log('this.status === Ordered',this.status === 'Ordered');

        if (this.status === 'Ordered' && selectedDate < today) {
            console.log('ordered');
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invalid Date',
                    message: 'Requested Completion Date must be today or a future date.\n/ अनुरोधित पूर्णता तिथि आज या उसके बाद की होनी चाहिए।',
                    variant: 'error'
                })
            );
            return;
        }
        createRequest({
            clinicalEncounterId: this.recordId,
            patientName: this.patientId,
            requestedById: this.requestedById,
            requestedTest: this.requestedTest,
            status: this.status,
            priority: this.priority,
            requestedCompletionDate: this.status === 'Ordered' ? this.dateValue : null,
            completedOn: this.status === 'Completed' ? this.dateValue : null,
            referralEmail: null, // ✅ REQUIRED
            notes: this.notes
        })
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Clinical Service Request created successfully!\n/ चिकित्सीय सेवा अनुरोध सफलतापूर्वक बनाया गया है!',
                    variant: 'success'
                })
            );
            // location.reload();
            this.closeModal();
        })
        .catch(error => {
            console.error('Error creating request:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to create Clinical Service Request\n/ चिकित्सीय सेवा अनुरोध बनाने में विफल।',
                    variant: 'error'
                })
            );
        });
    }
}