import { LightningElement, api, track, wire } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import createMedicationRequest from '@salesforce/apex/MedicationRequestController.createMedicationRequest';
import getEncounterDetails from '@salesforce/apex/MedicationRequestController.getEncounterDetails';
import getAISummary from '@salesforce/apex/MedicationRequestController.getAISummary';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import governmentLogo from '@salesforce/resourceUrl/Government_logo';
import { loadStyle } from 'lightning/platformResourceLoader';
import hideHelpText from '@salesforce/resourceUrl/hideHelpText';
import validateMedicationType from '@salesforce/apex/MedicationController.validateMedicationType';

export default class NewPrescription extends LightningElement {
    @api recordId;
    @track isModalOpen = true;
    pmjayLogo = pmjayLogo;
    governmentLogo = governmentLogo;
    patientId;
    encounterName;
    patientName;
    patientUrl;
    aiSummary = ''; // This should be HTML-formatted string
    isPatientCareTransitionPortal = false;
    medicationVariant = '';
    
    // @api isTransitionPortal = false;
    @api
    set isTransitionPortal(value){
        console.log('value::'+value);
        if(value){
            this.isPatientCareTransitionPortal = true;
            this.medicationVariant = 'label-hidden';
        }
    }
    get isTransitionPortal(){
        return this.isPatientCareTransitionPortal;
    }


    @track isGuideModalOpen = false;

    // renderedCallback() {
    //      if (this.isGuideModalOpen) {
    //          const formatted = this.aiSummary.replace(/\*\*(.*?)\*\*/g, '<strong>$1</strong>');
    //          const modalText = this.template.querySelector('#modalText');
    //          if (modalText) {
    //              modalText.innerHTML = formatted.replace(/\n/g, '<br>');
    //          }
    //      }
    // }

        // Method to open guide modal
        openGuideModal() {
            this.isGuideModalOpen = true;
        }

        // Method to close guide modal
        closeGuideModal() {
            this.isGuideModalOpen = false;
        }

        decodeHtmlEntities(str) {
            if (!str) return '';

            // Decode HTML entities
            const doc = new DOMParser().parseFromString(str, 'text/html');
            let decoded = doc.documentElement.textContent || '';
            console.log('decodedValue',decoded);
            // Bold formatting: **bold**
            decoded = decoded.replace(/\*\*(.*?)\*\*/g, '<b>$1</b>');

            // Add spacing before numbered lists (only if not at line start)
            decoded = decoded.replace(/(?:^|\n)(\d+\.\s)/g, '<br>$1');
    // Replace dash-style bullets with indented lines + ensure line break after last bullet
    decoded = decoded.replace(/-\s(.*?)(?=\n|$)/g, (match, content) => {
        return `<br>&nbsp;&nbsp;&nbsp;- ${content}` + (content.trim().endsWith('.') ? '<br>' : '');
    });

            // Add <br> only at sentence ends, not for numbered lists
            decoded = decoded.replace(/(?<!\d)\. /g, '.<br>');

            // Ensure line break after period followed by newline and capital letter
            decoded = decoded.replace(/\.([\r\n]+)([A-Z])/g, '.<br><br>$2');

            return decoded;
        }


    // Decoded (or formatted) fields
        get decodedAiSummary() {
            return this.decodeHtmlEntities(this.aiSummary);
        }

    fetchAISummary() {
        getAISummary({ clinicalEncounterId: this.recordId })
            .then(result => {
                this.aiSummary = result;
            })
            .catch(error => {
                console.error('Error fetching AI Summary:', error);
            });
    }

    getTomorrowDate() {
        const tomorrow = new Date();
        tomorrow.setDate(tomorrow.getDate() + 1);
        return tomorrow.toISOString().split('T')[0];
    }

    @track medicationSections = [
        {
            id: Date.now(),
            medicationId: '',
            instructions: '',
            durationDays: '',
            startFrom: '',
            morning: false,
            afternoon: false,
            night: false,
            showDosageInput: false,
            dosage: '',
            beforeAfterFood: ''
        }
    ];

    connectedCallback() {
        this.medicationSections[0].startFrom = this.getTodayDate();
        this.fetchAISummary();
        console.log('this.isPatientCareTransitionPortal:::'+this.isPatientCareTransitionPortal);
        //  if(this.isPatientCareTransitionPortal){
            loadStyle(this, hideHelpText);
        //  }
    }

    @wire(getEncounterDetails, { encounterId: '$recordId' })
    wiredDetails({ error, data }) {
        if (data) {
            this.encounterName = data.EncounterName;
            this.patientName = data.PatientName;
            this.patientId = data.PatientId;
            this.patientUrl = `/lightning/r/Contact/${this.patientId}/view`;

            if (data.Status === 'Completed') {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Action Not Allowed/ कार्य अनुमति नहीं है',
                    message: 'This Clinical Encounter is already marked as Completed. You cannot add a new medication/ यह अपॉइंटमेंट पहले ही पूर्ण के रूप में चिह्नित है। आप नई दवा नहीं जोड़ सकते।',
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
            console.error('Error fetching encounter details:', error);
        }
    }

    getTodayDate() {
    return new Date().toISOString().split('T')[0];
    }

    handleCheckboxChange(event) {
    const field = event.target.dataset.field;
    const id = parseInt(event.target.dataset.id, 10);

    const section = this.medicationSections.find(med => med.id === id);

    if (section) {
                section[field] = event.target.checked;

                section.showDosageInput =
                    section.morning || section.afternoon || section.night;
            }
    }

    handleInputChange(event) {
        const field = event.target.dataset.field;
        const id = parseInt(event.target.dataset.id, 10);
        const section = this.medicationSections.find(med => med.id === id);
        if (section) {
            section[field] = event.target.value;
        }
    }

    handleMedicationLookupChange(event) {
        const id = parseInt(event.target.dataset.id, 10);
        const selected = event.detail.value;
        const section = this.medicationSections.find(med => med.id === id);
        if (section) section.medicationId = Array.isArray(selected) ? selected[0] : selected;
    }

    handleStartDateChange(event) {
        const id = parseInt(event.target.dataset.id, 10);
        const section = this.medicationSections.find(med => med.id === id);
        if (section) section.startFrom = event.target.value;
    }

    addMedicationSection() {
        this.medicationSections = [
            ...this.medicationSections,
            {
                id: Date.now(),
                medicationId: '',
                instructions: '',
                durationDays: '',
                startFrom: this.getTodayDate(),
                morningDosage: '',
                afternoonDosage: '',
                eveningDosage: '',
                beforeAfterFood: ''
            }
        ];
    }

    removeSection(event) {
    const idToRemove = parseInt(event.target.dataset.id, 10);
    const card = this.template.querySelector(`[data-container-id="${idToRemove}"]`);

    if (card) {
        card.classList.add('fade-out');

        // Wait for the transition to finish
        setTimeout(() => {
            if (this.medicationSections.length > 1) {
                this.medicationSections = this.medicationSections.filter(m => m.id !== idToRemove);
            }
        }, 300); // Duration matches CSS transition
    }
}


    get showDeleteButtons() {
    return this.medicationSections.length > 1;
}


    closeModal() {
        console.log('closeModal called. Current isModalOpen:', this.isModalOpen); // Debug log
        this.isModalOpen = false;
        console.log('isModalOpen after setting to false:', this.isModalOpen); // Debug log
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
        document.body.classList.remove('modal-open');
    }

    openModal() {
        this.isModalOpen = true;
        document.body.classList.add('modal-open');
    }

@api
getPrescriptionsData() {
    const meds = [];
    this.template.querySelectorAll('.prescriptionsData').forEach(input => {
        meds.push({
            value: input.value,
            field: input.dataset.field || '',
            id: input.dataset.id
        });
    });
   // return meds;
   return this.medicationSections;
}

    async submitPrescription() {
    const today = new Date().toISOString().split('T')[0];

    // ✅ Check for duplicate medications
    const seen = new Set();
    for (const med of this.medicationSections) {
        if (!med.medicationId) continue;
        if (seen.has(med.medicationId)) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Duplicate Medication',
                    message: 'Each medication can only be added once\n/ हर दवा को केवल एक बार ही जोड़ा जा सकता है।',
                    variant: 'error'
                })
            );
            return;
        }
        seen.add(med.medicationId);
    }

    for (const med of this.medicationSections) {
        // ✅ Medication must be selected
        if (!med.medicationId) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing Medication',
                    message: 'Please select a medication\n/ कृपया एक दवा चुनें।',
                    variant: 'error'
                })
            );
            return;
        }

        // ✅ Duration must be a valid positive number
        const duration = parseInt(med.durationDays, 10);
        if (isNaN(duration) || duration <= 0) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invalid Duration',
                    message: 'Duration (Days) must be a positive number\n/ अवधि (दिनों में) एक सकारात्मक संख्या होनी चाहिए।',
                    variant: 'error'
                })
            );
            return;
        }

        // ✅ Start date must be present and not in the past
        if (!med.startFrom) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Missing Start Date',
                    message: 'Please select a start date for the medication\n/ कृपया दवा के लिए प्रारंभ तिथि चुनें।',
                    variant: 'error'
                })
            );
            return;
        }

        if (med.startFrom < today) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Invalid Start Date',
                    message: 'Start date cannot be in the past\n/ प्रारंभ तिथि पिछली तिथि नहीं हो सकती है।',
                    variant: 'error'
                })
            );
            return;
        }

        // ✅ At least one dosage must be filled
        // const isMorningEmpty = !med.morningDosage || med.morningDosage.trim() === '';
        // const isAfternoonEmpty = !med.afternoonDosage || med.afternoonDosage.trim() === '';
        // const isEveningEmpty = !med.eveningDosage || med.eveningDosage.trim() === '';
        // if (isMorningEmpty && isAfternoonEmpty && isEveningEmpty) {
        //     this.dispatchEvent(
        //         new ShowToastEvent({
        //             title: 'Missing Dosage Information',
        //             message: 'At least one of Morning, Afternoon, or Evening Dosage must be filled for each medication\n/ हर दवा के लिए सुबह, दोपहर या शाम में से कम से कम एक खुराक जरूर दर्ज की जानी चाहिए।',
        //             variant: 'error'
        //         })
        //     );
        //     return;
        // }
    }

    console.log('medicationSections',this.medicationSections);
        console.log('recordId',this.recordId);

        //changes by krati- begin

        // ===== MEDICATION TYPE VALIDATION =====

        const medicationIds = this.medicationSections
            .filter(m => m.medicationId)
            .map(m => m.medicationId);

        console.log('Calling validation with:', medicationIds);

        try {

            const result = await validateMedicationType({
                clinicalEncounterId: this.recordId,
                selectedMedicationIds: medicationIds
            });

            console.log('Validation Result:', result);

            if (result !== 'VALID') {

                const message =
                    result === 'Ayurvedic'
                        ? 'Only Ayurvedic medicines allowed for this consultation.'
                        : 'Only Allopathy medicines allowed for this consultation.';

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Invalid Medication Type',
                        message: message,
                        variant: 'error'
                    })
                );

                return;
            }

        } catch(error){
            console.error('Validation error', error);
            return;
        }

        //changes by krati- end

        if(this.isPatientCareTransitionPortal){
            const medicationData = new CustomEvent("medicationlist",{
                detail : this.medicationSections
            });
            this.dispatchEvent(medicationData);
            this.closeModal(); // Added: Close modal even if just dispatching data
            return;
        }



        // //krati changes begin

        // // ===== MEDICATION TYPE VALIDATION =====

        // const medicationIds = this.medicationSections
        //     .filter(m => m.medicationId)
        //     .map(m => m.medicationId);

        // try {

        //     const result = await validateMedicationType({
        //         clinicalEncounterId: this.recordId,
        //         selectedMedicationIds: medicationIds
        //     });

        //     if (result !== 'VALID') {

        //         const message =
        //             result === 'Ayurvedic'
        //                 ? 'Only Ayurvedic medicines allowed for this consultation.'
        //                 : 'Only Allopathy medicines allowed for this consultation.';

        //         this.dispatchEvent(
        //             new ShowToastEvent({
        //                 title: 'Invalid Medication Type',
        //                 message: message,
        //                 variant: 'error'
        //             })
        //         );

        //         return; // 🚫 STOP SAVE
        //     }

        // } catch(error){
        //     console.error('Validation error', error);
        //     return;
        // }

        // //changes by krati end


    // ✅ All validations passed, proceed to save
    const promises = this.medicationSections.map(med =>
        createMedicationRequest({
            encounterId: this.recordId,
            patientId: this.patientId,
            medicationId: med.medicationId,
            instructions: med.instructions,
            durationDays: med.durationDays,
            startFrom: med.startFrom,
            morning: med.morning,
            afternoon: med.afternoon,
            night: med.night,
            beforeAfterFood: med.beforeAfterFood,
            dosage: med.dosage
        })
    );

    Promise.all(promises)
        .then(() => {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Success',
                    message: 'Medication Requests created successfully!\n/ दवा अनुरोध सफलतापूर्वक बनाया गया है।',
                    variant: 'success'
                })
            );
            // Dispatch the medication list to the parent AFTER successful save
            const medicationDataEvent = new CustomEvent("medicationlist",{
                detail : this.medicationSections
            });
            this.dispatchEvent(medicationDataEvent);
            location.reload();
            this.closeModal(); // This line is already here, keep it.
             // Still keep this commented out as per previous discussion
        })
        .catch(error => {
            console.error('Error creating medication requests:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Failed to create one or more Medication Requests\n/ एक या अधिक दवा अनुरोध बनाने में विफल।',
                    variant: 'error'
                })
            );
        });
}

  // NewPrescription.js
// ... (rest of your code)

handleMedication(event){
    console.log('Event Detail:', event.detail); // Log the entire detail for debugging
    const sectionId = parseInt(event.detail.sectionId, 10); // Get the section ID from the event detail
    const medicationLookupId = event.detail.lookupId; // This is the Salesforce ID of the Medication
    const medicationLookupName = event.detail.lookupValue; // Get the display name

    // Find the correct medication section using its unique 'id'
    const section = this.medicationSections.find(med => med.id === sectionId);
    if (section) {
        section.medicationId = medicationLookupId; // Assign the actual Salesforce Medication ID
        section.selectedName = medicationLookupName; // Store the display name
        console.log(`Updated medicationId for section ${sectionId} to: ${section.medicationId}`);
        console.log(`Updated selectedName for section ${sectionId} to: ${section.selectedName}`);
    } else {
        console.error(`Could not find medication section with ID: ${sectionId}`);
    }
}

    get dosageOptions() {
        return [
            { label: '0', value: '0' },
            { label: '1', value: '1' },
            { label: '2', value: '2' },
            { label: '3', value: '3' },
            { label: '15 ml / 15 मि.ली.', value: '15 ml' },
            { label: '30 ml / 30 मि.ली.', value: '30 ml' },
            { label: '60 ml / 60 मि.ली.', value: '60 ml' }
        ];
    }

    get beforeAfterOptions() {
        return [
            { label: 'Before Food / खाने से पहले', value: 'Before Food' },
            { label: 'After Food / खाने के बाद', value: 'After Food' }
        ];
    }
}