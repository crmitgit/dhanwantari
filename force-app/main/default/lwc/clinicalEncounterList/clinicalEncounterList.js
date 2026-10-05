import { LightningElement, track, wire } from 'lwc';
import getConsultationsByStatus from '@salesforce/apex/ConsultationController.getConsultationsByStatus';
import updateClinicalEncounterOwner from '@salesforce/apex/ConsultationController.updateClinicalEncounterOwner';
import userId from '@salesforce/user/Id';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { refreshApex } from '@salesforce/apex';
import { NavigationMixin } from 'lightning/navigation';

import pmjayLogoNew from '@salesforce/resourceUrl/pmjayLogoNew';
import Government_logo from '@salesforce/resourceUrl/Government_logo';

export default class ClinicalEncounterList extends NavigationMixin(LightningElement) {
    @track consultations = [];
    @track error;
    @track isLoading = false;
    currentUserId = userId;
    wiredConsultationsResult;

    pmjayLogoUrl = pmjayLogoNew;
    pmlogo2Url = Government_logo;
    statusList = ['Approval Pending', 'Assigned to Doctor'];

    @wire(getConsultationsByStatus, { statuses: '$statusList' })
    wiredConsultations(result) {
        this.wiredConsultationsResult = result;
        const { error, data } = result;

        if (data) {
            console.log('consultation data: ', data);
            this.consultations = data.map((encounter, index) => {
                let clinicalDiagnosis = '';
                if (encounter.Diagnoses__r && encounter.Diagnoses__r.length > 0) {
                    clinicalDiagnosis = encounter.Diagnoses__r[0].Clinical_Diagnosis__c;
                }
                return {
                    ...encounter,
                    rowNumber: index + 1,
                    ClinicalDiagnosisFromRelated: clinicalDiagnosis
                };
            });
            this.error = undefined;
        } else if (error) {
            this.error = error.body.message;
            this.consultations = [];
            console.error('Error fetching clinical encounters:', this.error);
        }
    }

    handleAccept(event) {
        const consultationId = event.target.dataset.id;
        console.log('Accept clicked for Clinical Encounter ID:', consultationId);

        this.isLoading = true;

        updateClinicalEncounterOwner({ clinicalEncounterId: consultationId, newOwnerId: this.currentUserId })
            .then(result => {
                if (result === 'Success') {
                    console.log('Success from consultation controller');
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Success',
                            message: 'Clinical Encounter assigned and status updated. Navigating to record page...',
                            variant: 'success',
                            mode: 'dismissable'
                        })
                    );

                    return refreshApex(this.wiredConsultationsResult)
                    .then(() => {
                        this.isLoading = false;
                        this[NavigationMixin.GenerateUrl]({
                                type: 'standard__recordPage',
                                attributes: {
                                    recordId: consultationId,
                                    actionName: 'view'
                                },
                                state: {
                                    c__openQA: 'true',
                                    c__isOpenPopup: 'true'   // prevents caching
                                }
                            }).then(url => {
                                console.log('Generated URL:', url);
                                window.location.href = url;   // force navigation with state
                            });
                        });
                    } else {
                    this.isLoading = false;
                    this.dispatchEvent(
                        new ShowToastEvent({
                            title: 'Error',
                            message: 'Failed to update owner and status. Please try again.',
                            variant: 'error'
                        })
                    );
                }
            })
            .catch(error => {
                this.isLoading = false;
                this.error = error;
                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Error updating record',
                        message: error.body ? error.body.message : 'Unknown error',
                        variant: 'error'
                    })
                );
                console.error('Error updating Clinical Encounter owner and status:', JSON.stringify(error));
            });
    }
}