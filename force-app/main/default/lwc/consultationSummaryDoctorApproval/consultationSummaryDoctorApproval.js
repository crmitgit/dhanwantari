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
import updateDiagnosis from '@salesforce/apex/PrescriptionApprovalController.updateDiagnosis';
import { CloseActionScreenEvent } from 'lightning/actions';

export default class ConsultationSummaryDoctorApporval extends LightningElement {
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
    showInvestigationEditModal = false;

    @wire(CurrentPageReference)
    getStateParameters(currentPageReference) {
        if (currentPageReference) {
            console.log('currentPageReference', JSON.stringify(currentPageReference));
            this.encounterName = currentPageReference.state?.recordId;
            console.log('encounterName', this.encounterName);
            if (this.encounterName) {
                this.isShowPopup = true;
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
                console.log('Patient Id::' + this.summary.patientId);
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
                        let parts = [];
                        if (this.summary.medications[i].morning && this.summary.medications[i].morning !== "N/A") parts.push(`Morning ${this.summary.medications[i].morning}`);
                        if (this.summary.medications[i].afternoon && this.summary.medications[i].afternoon !== "N/A") parts.push(`Afternoon ${this.summary.medications[i].afternoon}`);
                        if (this.summary.medications[i].night && this.summary.medications[i].night !== "N/A") parts.push(`Night ${this.summary.medications[i].night}`);

                        // Join dosage parts with ', ', then append food only if there's dosage
                        let dosageStr = parts.length ? parts.join(', ') : '';
                        if (this.summary.medications[i].food && this.summary.medications[i].food !== "N/A") {
                            dosageStr += dosageStr ? ` (${this.summary.medications[i].food})` : `(${this.summary.medications[i].food})`;
                        }

                        medicationData.dosage = dosageStr;
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
                text: diag.text || 'N/A',
                type: diag.type || 'Unknown',
                id: diag.id || '' 
            };
        });
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
    investigationHeading;
    handleEditRow(event) {
        this.selectedMedicationRowId = event.currentTarget.dataset.name;
        this.medicationHeading = 'Edit Medication';
        this.spinnerStatus = true;
        this.showEditModal = true;
        this.isShowPopup = false;

    }
    
    selectedInvestigationRowId;
    handleInvestigationEditRow(event){
        this.selectedInvestigationRowId = event.currentTarget.dataset.name;
        this.investigationHeading = 'Edit Investigation';
        this.showInvestigationEditModal = true;
        this.isShowPopup = false;
        this.spinnerStatus = true;
    }

    dataInvestigationLoaded(){
        this.spinnerStatus = false;
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
        const today = new Date();
        const tomorrow = new Date(today);
        tomorrow.setDate(today.getDate() + 1);
        // Format as YYYY-MM-DD
        this.addMedicationStartDate = tomorrow.toISOString().split('T')[0];
        this.showEditModal = true;
        this.spinnerStatus = true;
        this.isShowPopup = false;
        this.selectedMedicationRowId = null; // Reset the selected row ID for new entry
    }

    isAddInvestigation = false;
    investigationStatus;
    addInvestigationRow(){
        this.investigationHeading = 'Add Investigation';
        this.investigationStatus = 'Ordered';
        this.isAddInvestigation = true;
        this.showInvestigationEditModal = true;
        this.spinnerStatus = true;
        this.isShowPopup = false;
        this.selectedInvestigationRowId = null; // Reset the selected row ID for new entry
    }

    clodeDeleteModal() {
        this.showDeleteModal = false;
        this.isShowPopup = true;
        this.isAddMedication = false;
        this.isAddInvestigation = false;
    }

    handleSubmit(event) {
        event.preventDefault(); // Prevent default form submit

        // Get medication name from form fields
        const fields = event.detail.fields;
        const newMedicationName = fields.MedicationId; // Adjust if your field API name is different

        // Check for duplicate (ignore case, ignore current row if editing)
        const isDuplicate = this.medicationList.some(med =>
            med.medicationId &&
            med.medicationId.toLowerCase() === newMedicationName.toLowerCase() &&
            (!this.selectedMedicationRowId || med.id !== this.selectedMedicationRowId)
        );

        if (isDuplicate) {
            this.showInfoToast('Error', 'This medication is already present.', 'error');
            this.showSpinner = false;
            return;
        }

        // If no duplicate, proceed with save
        this.showSpinner = true;
        this.template.querySelector('lightning-record-edit-form').submit(fields);
    }

    handleInvestigationSubmit(event){
        console.log('handleInvestigationSubmit called');
    }

    handleError(event) {
        this.showSpinner = false;
    }

    handleSaveSuccess(event) {
        this.showSpinner = false;
        if (event && event.detail && event.detail.id) {
            this.fetchEncounterDetails();
            this.showInfoToast('Success', 'Medication saved!', 'success');
            this.showEditModal = false;
            this.isShowPopup = true;
            this.isAddMedication = false;
            this.isAddInvestigation = false;
        }
    }

    handleInvestigationSaveSuccess(event){
        this.showSpinner = false;
        if(event && event.detail && event.detail.id){
            this.fetchEncounterDetails();
            this.showInfoToast('Success', 'Investigation saved!', 'success');
            this.showInvestigationEditModal = false;
            this.isShowPopup = true;
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
        this.showInvestigationEditModal = false;
    }

    dataLoaded() {
        this.spinnerStatus = false;
    }

    diagnosisId;
    isDiagnosisEdit = false;
    handleDiagnosisEditRow(){
        this.isDiagnosisEdit = true;
    }

    handleDiagnosisCancel(){
        this.isDiagnosisEdit = false;
    }

    daignosisText;
    handleDiagnosisChange(event){
        this.daignosisText = event.target.value;
        this.diagnosisId = event.target.dataset.id;
        console.log('Diagnosis ID:', this.diagnosisId);
        console.log('Diagnosis Text:', this.daignosisText);
    }

    handleDiagnosisSave(){
        this.spinnerStatus = true;
        updateDiagnosis({
            diagnosisId: this.diagnosisId,
            diagnosisText: this.daignosisText
        })
        .then(result => {
            this.spinnerStatus = false;
            if (result.status === 'Success') {
                this.showInfoToast('Success', 'Diagnosis updated successfully!', 'success');
                this.fetchEncounterDetails();
                this.isDiagnosisEdit = false;
            } else {
                this.showInfoToast('Error', result.message, 'error');
            }
        })
        .catch(error => {
            this.spinnerStatus = false;
            console.log('Error updating diagnosis:', error);
        })
    }



  
    handleSendForApproval() {
        if(this.summary && this.summary.status === 'Diagnosis Approved'){
            this.showInfoToast('Info', 'This consultation summary is already approved.', 'info');
            return;
        }
        this.isSending = true;
        sendEmailToPatient({
            cinicalEncounterId: this.encounterName

        })
            .then((result) => {
                this.isSending = false;
                if (result.status == 'Success') {
                    this.showInfoToast('Success', result.message, 'success');
                    this.isShowPopup = false; // Close the popup after sending email
                    this.handleClose();
                    this.closeQuickAction();
                } else if (result.status == 'Error') {
                    this.showInfoToast('Error', result.message, 'error');
                    this.isShowPopup = false;
                    this.handleClose();
                    this.closeQuickAction();
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
        this.closeQuickAction();
    }

    // Below method is used to close the quick action button
    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
    }
}