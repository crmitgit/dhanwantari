import { LightningElement, api, wire, track } from 'lwc';
import getEncounterDetails from '@salesforce/apex/PrescriptionApprovalController.getEncounterDetails';
import sendEncounterEmail from '@salesforce/apex/EncounterSummaryController.sendEncounterEmail';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import doctorlogo from '@salesforce/resourceUrl/DoctorLogo';
import doctorLogoNew from '@salesforce/resourceUrl/DoctorLogoNew';
import getDoctorSignature from '@salesforce/apex/EncounterSummaryController.getDoctorSignature';
import { CurrentPageReference } from 'lightning/navigation';
import sendEmailToPatient from '@salesforce/apex/PrescriptionApprovalController.sendEmailToPatient';
import deleteRecord from "@salesforce/apex/PrescriptionApprovalController.deleteRecord";
// new changes
import { updateRecord } from 'lightning/uiRecordApi';
import updateDiagnosis from '@salesforce/apex/PrescriptionApprovalController.updateDiagnosis';


export default class EncounterSummary extends LightningElement {
    @api encounterName;
    recordId;
    summary = {};
    hospitalLogo = pmjayLogo;
    consultationLogo = doctorlogo;
    doctorLogoNew = doctorLogoNew;
    signature;
    @track isSending = false;
    showConfirmModal = false;
    isShowPopup = false;
    @track medicationList = [];
    showEditModal = false;
    showDeleteConfirm = false;
    spinnerStatus = false;
    showDeleteModal = false;
    morning = false;
    afternoon = false;
    night = false;

    // new changes 
    @track isClinicalEdit = false;
    editedClinicalFindings;
    // Diagnosis Edit Mode
    @track isDiagnosisEdit = false;
    @track editedDiagnosis;
    //Care Instructions 
    @track isCareEdit = false;
    @track editedCareInstructions;
    @track doctorComment = '';
    isFollowUpEdit = false;
    followUpDate;


    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            console.log('currentPageReference', JSON.stringify(currentPageReference));
            const isOpenPopup = currentPageReference.state.c__isOpenPopup;
            console.log('isOpenPopup', isOpenPopup);
            this.encounterName = currentPageReference.attributes?.recordId;
            console.log('encounterName', this.encounterName);
            if (isOpenPopup === 'true') {
                this.isShowPopup = true;
                console.log('this.isShowPopup',this.isShowPopup);
                this.fetchEncounterDetails();
            }
            else {
                this.isShowPopup = false;
            }
        }
    }


    fetchEncounterDetails() {
        this.spinnerStatus = true;
        getEncounterDetails({ encounterName: this.encounterName })
            .then(result => {
                this.summary = result;
                console.log('this.summary::' + JSON.stringify(result));
                console.log('Patient Id::' + this.summary.patientId);
               // this.followUpDate = this.formatDateForInput(this.summary.followUpDate);
                this.followUpDate = this.summary.followUpDate;
                console.log('this.followUpDate::' + this.summary.followUpDate);
                console.log('LINE 76::');
                this.spinnerStatus = false;
                if (this.summary || this.summary.medications.length > 0) {
                    this.medicationList = [];
                    for (let i = 0; i < this.summary.medications.length; i++) {
                        console.log('medication', JSON.stringify(this.summary.medications[i]));
                        let medicationData = {};
                        medicationData.index = i + 1;
                        medicationData.id = this.summary.medications[i].id;
                        medicationData.isEdit = false;
                        medicationData.medicationId = this.summary.medications[i].medicationId;
                        medicationData.medicationName = this.summary.medications[i].name;
                        medicationData.duration = this.summary.medications[i].duration;
                        medicationData.startDate = this.summary.medications[i].startDate;
                        medicationData.beforeAfterFood = this.summary.medications[i].food;
                        const med = this.summary.medications[i];
                        
                        let timingLines = [];

                        if (med.toBeTakenInMorning) {
                            timingLines.push({ label: 'Morning', dose: med.dosage, food: med.food });
                        }
                        if (med.toBeTakenInAfternoon) {
                            timingLines.push({ label: 'Afternoon', dose: med.dosage, food: med.food });
                        }
                        if (med.toBeTakenInNight) {
                            timingLines.push({ label: 'Night', dose: med.dosage, food: med.food });
                        }

                        medicationData.timingList = timingLines;
                        this.medicationList.push(medicationData);
                    }
                }
                getDoctorSignature({ doctorId: result.prescribingDoctorId })
                    .then(sig => { this.signature = sig; })
                    .catch(err => { console.error('Sig error', err); });
            })
            .catch(error => {
                this.spinnerStatus = false;
                console.log('Error fetching encounter details:', error);
            });
    }


    // new changes -Krati
    handleEditClinical() {
    this.isClinicalEdit = true;
    this.editedClinicalFindings = this.summary.clinicalFindings;
    }
    handleClinicalChange(event) {
    this.editedClinicalFindings = event.target.value;
    }
    handleSaveClinicalFindings() {

        const fields = {};
        fields['Id'] = this.encounterName;
        fields['Clinical_Findings__c'] = this.editedClinicalFindings;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {

                this.showInfoToast(
                    'Success',
                    'Clinical Findings updated successfully',
                    'success'
                );

                this.isClinicalEdit = false;
                this.fetchEncounterDetails(); // refresh data
            })
            .catch(error => {
                console.error(error);

                this.showInfoToast(
                    'Error',
                    'Failed to update Clinical Findings',
                    'error'
                );
            });
    }
    handleCancelClinical() {
    this.isClinicalEdit = false;
    }

    // 

    // new changes -Krati
    handleEditCare() {
    this.isCareEdit = true;
    this.editedCareInstructions = this.summary.careInstructions;
    
    }

    handleCareChange(event) {
    this.editedCareInstructions = event.target.value;
    }
    
    handleSaveCareInstructions() {

        const fields = {};
        fields['Id'] = this.encounterName;
        fields['Care_Instructions__c'] = this.editedCareInstructions;

        const recordInput = { fields };

        updateRecord(recordInput)
            .then(() => {

                this.showInfoToast(
                    'Success',
                    'Care Findings updated successfully',
                    'success'
                );

                this.isCareEdit = false;
                this.fetchEncounterDetails(); // refresh data
            })
            .catch(error => {
                console.error(error);

                this.showInfoToast(
                    'Error',
                    'Failed to update Care Findings',
                    'error'
                );
            });
    }
    handleCancelCare() {
        this.isCareEdit = false;
    }

    handleCommentChange(event) {
        this.doctorComment = event.target.value;
    }

    handleFollowUpChange(event) {
        this.followUpDate = event.target.value;
    }

    // formatDateForInput(dateValue) {

    //     if (!dateValue) return null;

    //     const date = new Date(dateValue);

    //     return date.toISOString().split('T')[0];
    // }

    formatDateForInput(dateValue) {

        console.log('Incoming date value:', dateValue);

        if (!dateValue) {
            return null;
        }

        const date = new Date(dateValue);

        // ✅ THE REAL FIX
        if (isNaN(date.getTime())) {
            console.warn('Invalid date received:', dateValue);
            return null;
        }

        return date.toISOString().split('T')[0];
    }



// handleEditDiagnosis() {
//     this.isDiagnosisEdit = true;
//     this.editedDiagnosis = this.summary.diagnosis;
// }

handleEditDiagnosis() {
    this.isDiagnosisEdit = true;

    this.editedDiagnosis =
        this.summary.diagnoses
            ?.map(d => `${d.type}: ${d.text}`)
            .join('\n') || '';
}

handleCancelDiagnosis() {
    this.isDiagnosisEdit = false;
}

handleDiagnosisChange(event) {
    this.editedDiagnosis = event.target.value;
}

    handleSaveDiagnosis() {

        // Convert textarea back to array
        const updatedDiagnosisList = this.editedDiagnosis
            .split('\n')
            .map(line => {

                const parts = line.split(':');

                return {
                    type: parts[0]?.trim(),
                    text: parts[1]?.trim()
                };
            });

        // Merge with original ids
        const recordsToUpdate =
            this.summary.diagnoses.map((diag, index) => ({
                Id: diag.id,
                Clinical_Diagnosis__c: updatedDiagnosisList[index]?.text
            }));

        console.log('recordstoUpdate',recordsToUpdate);
        console.log('stringifiedrecordstoUpdate',JSON.stringify(recordsToUpdate));


        updateDiagnosis({ diagnosisList: recordsToUpdate })
            .then(() => {

                this.showInfoToast(
                    'Success',
                    'Diagnosis updated successfully',
                    'success'
                );

                this.isDiagnosisEdit = false;
                this.fetchEncounterDetails();
            })
            .catch(error => {
                console.error(error);

                this.showInfoToast(
                    'Error',
                    'Failed to update diagnosis',
                    'error'
                );
            });
    }


    

    // new changes ended - Krati

    get isMedicationEmpty() {
        return !this.summary.medications || this.summary.medications.length === 0;
    }

    get isCsrEmpty() {
        return !this.summary.csrs || this.summary.csrs.length === 0;
    }

    get formattedCareInstructions() {
        if (!this.summary?.careInstructions) return '';
        return this.summary.careInstructions
            .split('\n')
           .map(line => `- ${line}`)
            .join('\n');
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


    handlePrint() {
        const container = this.template.querySelector('.encounter-summary-container');
        const recommendationText = this.template.querySelector('.recommendation-box')?.value || '';

        if (!container) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Encounter summary not found.',
                    variant: 'error'
                })
            );
            return;
        }

        const encodedRecommendation = encodeURIComponent(recommendationText);
        const vfUrl = `/apex/PrintEncounterSummary?id=${this.encounterName}&rec=${encodedRecommendation}`;
        window.open(vfUrl, '_blank');
    }

    handleClose() {
        const closeEvent = new CustomEvent('close');
        this.dispatchEvent(closeEvent);
        // this.dispatchEvent(new CloseActionScreenEvent()); // Optional: use if this is in a quick action modal
    }
    get formattedDiagnosisList() {
        if (!this.summary?.diagnoses) return [];

        return this.summary.diagnoses.map(diag => {
            return {
                id: diag.id,     // ⭐ IMPORTANT
                text: diag.text || 'N/A',
                type: diag.type || 'Unknown'
            };
        });
    }

    get hasDiagnosis() {
        return this.formattedDiagnosisList?.length > 0;
    }

    promptEmailConfirmation() {
        this.showConfirmModal = true;
    }

    cancelEmail() {
        this.showConfirmModal = false;
    }

    handleEmail() {
        const email = this.summary?.email;
        const encounterId = this.encounterName;
        const patientName = this.summary?.patientName || 'Patient';
        const facilityName = this.summary?.facilityName || 'PHWC';
        const doctorName = this.summary?.doctorName || 'Your Doctor';
        const endDate = this.summary?.endDate || '';

        this.showConfirmModal = false;

        if (!email) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Patient email not available.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isSending = true;

        sendEncounterEmail({
            encounterId: encounterId,
            patientEmail: email,
            patientName: patientName,
            facilityName: facilityName,
            endDate: endDate,
            doctorName: doctorName
        })
            .then(() => {
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'Email sent successfully!',
                        variant: 'success'
                    })
                );
            })
            .catch(error => {
                console.error('Email send error:', error);
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error',
                        message: 'Failed to send email.',
                        variant: 'error'
                    })
                );
            })
            .finally(() => {
                this.isSending = false;
            });
    }

    selectedMedicationRowId;
    medicationHeading;
    deleteMedicationName;
    deleteMedicationId;
    handleEditRow(event) {
        this.selectedMedicationRowId = event.currentTarget.dataset.name;
        this.medicationHeading = 'Edit Medication';
        this.spinnerStatus = true;
        this.showEditModal = true;
        this.isShowPopup = false;

    }

    removeRow(event) {
        this.deleteMedicationName = event.target.name;
        this.deleteMedicationId = event.currentTarget.dataset.name;
        this.showDeleteModal = true;
    }

    isAddMedication = false;
    addMedicationStartDate;
    addMedicationRow() {
        this.isAddMedication = true;
        this.medicationHeading = 'Add Medication';
        this.morning = false;
        this.afternoon = false;
        this.night = false;
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);
        // Format as YYYY-MM-DD
        this.addMedicationStartDate = today.toISOString().split('T')[0];
        this.showEditModal = true;
        this.spinnerStatus = true;
        this.isShowPopup = false;
        this.selectedMedicationRowId = null; // Reset the selected row ID for new entry
    }

    clodeDeleteModal() {
        this.showDeleteModal = false;
        this.isShowPopup = true;
        this.isAddMedication = false;
    }

    handleSubmit(event) {
        event.preventDefault(); // Prevent default form submit

        // Get medication name from form fields
        const fields = event.detail.fields;

        if (!this.morning && !this.afternoon && !this.night) {
            this.showInfoToast('Error', 'Please select at least one dosage timing', 'Error');
            return;
        }


         fields.To_be_taken_in_morning__c = this.morning;
         fields.To_be_taken_in_afternoon__c = this.afternoon;
         fields.To_be_taken_in_night__c = this.night;
        const newMedicationName = fields.MedicationId; // Adjust if your field API name is different

        // Check for duplicate (ignore case, ignore current row if editing)
        const isDuplicate = this.medicationList.some(med =>
            med.medicationId &&
            med.medicationId.toLowerCase() === newMedicationName.toLowerCase() &&
            (!this.selectedMedicationRowId || med.id !== this.selectedMedicationRowId)
        );

        const selectedDate = fields.Prescription_Start_Date__c;
        const today = new Date().toISOString().split('T')[0];

        if (selectedDate < today) {
            this.showInfoToast('Error', 'Start date cannot be in the past.', 'error');
            return;
        }

        if (isDuplicate) {
            this.showInfoToast('Error', 'This medication is already present.', 'error');
            this.showSpinner = false;
            return;
        }

        // If no duplicate, proceed with save
        this.showSpinner = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleError(event) {
        this.showSpinner = false;
    }

    handleSaveSuccess(event) {
        this.showSpinner = false;
        if (event && event.detail && event.detail.id) {
            this.fetchEncounterDetails();
            this.showInfoToast('Success', 'Medication saved!', 'success');
            this.morning = false;
            this.afternoon = false;
            this.night = false;
            this.showEditModal = false;
            this.isShowPopup = true;
            this.isAddMedication = false;
        }
    }

    handleDelete() {
        this.deleteRecordFromBackend(this.deleteMedicationId);
    }

    deleteRecordFromBackend(recordId) {
        this.showSpinner = true;
        deleteRecord({
            recordId: recordId
        })
            .then(result => {
                this.showSpinner = false;
                if (result != 'Success') {
                    this.showInfoToast('Error', result, 'error');
                } else if (result == 'Success') {
                    this.showInfoToast('Success', 'Medication deleted!', 'success');
                    this.fetchEncounterDetails();
                    this.showDeleteModal = false;
                }
            })
            .catch(error => {
                this.showSpinner = false;
                console.log("error", JSON.stringify(this.error));
                this.showInfoToast('Error', error.body.message, 'error');
            })
    }

    closeModals() {
        this.showEditModal = false;
        this.isShowPopup = true;
    }

    dataLoaded(event) {
        if (!this.selectedMedicationRowId) {
            this.spinnerStatus = false;
            return;
        }

        const record = event.detail.records[this.selectedMedicationRowId];

        if (record) {
            this.morning = !!record.fields.To_be_taken_in_morning__c.value;
            this.afternoon = !!record.fields.To_be_taken_in_afternoon__c.value;
            this.night = !!record.fields.To_be_taken_in_night__c.value;
        }

        this.spinnerStatus = false;
    }

    // Below method added by Karishma on 22nd July 2025
    handleSendForApproval() {
        console.log('approce sclicked');
        this.isSending = true;
        sendEmailToPatient({
            cinicalEncounterId: this.encounterName,
            doctorComment: this.doctorComment,
            followUpDate: this.followUpDate
        })
            .then((result) => {
                this.isSending = false;
                if (result.status == 'Success') {
                    console.log('email sent to ',result.email);
                    this.showInfoToast('Success', result.message, 'success');
                    this.isShowPopup = false; // Close the popup after sending email
                    this.handleClose();
                } else if (result.status == 'Error') {
                    this.showInfoToast('Error', result.message, 'error');
                    this.isShowPopup = false;
                    this.handleClose();
                }
            })
            .catch(error => {
                this.isSending = false;
                console.log('Error sending email for approval:', error);
            });
    }

    showInfoToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }

    hideModalBox() {
        this.isShowPopup = false;
    }

    handleCheckboxChange(event) {
        const field = event.target.dataset.field;
        const value = event.target.checked;

        if (field === 'To_be_taken_in_morning__c') {
            this.morning = value;
        } else if (field === 'To_be_taken_in_afternoon__c') {
            this.afternoon = value;
        } else if (field === 'To_be_taken_in_night__c') {
            this.night = value;
        }
    }
}