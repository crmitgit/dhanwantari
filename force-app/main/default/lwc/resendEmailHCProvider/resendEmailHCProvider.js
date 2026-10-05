import { LightningElement,api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import getEmailBody from '@salesforce/apex/resendEmailHCProviderController.getEmailBody';
import sendReferralEmail from '@salesforce/apex/resendEmailHCProviderController.sendReferralEmail';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { CloseActionScreenEvent } from 'lightning/actions';
import pmjayLogo from '@salesforce/resourceUrl/pmjayLogoNew';
import Government_logo from '@salesforce/resourceUrl/Government_logo';
import { loadStyle } from 'lightning/platformResourceLoader';
import reduceCustomModalSize from "@salesforce/resourceUrl/reduceCustomModalSize";

export default class ResendEmailHCProvider extends LightningElement {
    @api recordId;
    emailBodyResult;
    leftCornerImageUrl = pmjayLogo;
    rightCornerImageUrl = Government_logo;
    isShowPreviewBody = false;
    isShowConfirmation = true;
    spinnerStatus = true;

    connectedCallback(){
        loadStyle(this, reduceCustomModalSize); // This line is used to decrease width of the quick action button
    }

    @wire(CurrentPageReference)
    getPageReferenceParameters(currentPageReference){
        if(currentPageReference){
            this.spinnerStatus = false;
            console.log('currentPageReference::'+JSON.stringify(currentPageReference));
            this.recordId = currentPageReference.state.recordId;
            console.log('recordId::'+this.recordId);
            if(this.recordId){
                this.fetchEmailBody();
            }
        }
    }
    
    fetchEmailBody(){
        getEmailBody({
            referralId : this.recordId
        })
        .then(result =>{
            console.log(result);
            if(result.status == 'warning'){
                this.showInfoToast('Warning', result.body, result.status);
                this.closeQuickAction();
            }else if(result.status == 'success'){
                this.emailBodyResult = result.body;
                this.isShowPreviewBody = true;
            }
        })
        .catch(error =>{
            console.log('Error in GetEmailBody data ' + JSON.stringify(error));
        })
    }

    confirmSendEmail(){
        this.spinnerStatus = true;
        sendReferralEmail({
            referralId : this.recordId
        })
        .then(result =>{
            this.spinnerStatus = false;
            console.log(result);
            if(result.status == 'Success'){
                this.showInfoToast('Success', result.body, 'success');
                this.closeQuickAction();
            }else if(result.status == 'Error'){
                this.showInfoToast('Error', result.body, 'error');
                this.closeQuickAction();
            }
        })
        .catch(error =>{
            this.spinnerStatus = false;
            console.log('Error in sendReferralEmail data ' + JSON.stringify(error));
        })
    }

    sendEmail(){
        this.isShowConfirmation = true;
        this.isShowPreviewBody = false;
    }

    handleCloseClick(){
        this.isShowConfirmation = false;
        this.closeQuickAction();
    }

    // Below method is used to close the quick action button
    closeQuickAction() {
        this.dispatchEvent(new CloseActionScreenEvent());
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
}