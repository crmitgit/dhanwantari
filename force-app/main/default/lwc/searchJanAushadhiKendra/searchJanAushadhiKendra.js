import { LightningElement, wire, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';
import getJanaushadhiDetails from '@salesforce/apex/SearchJanAushadhiKendraController.getJanaushadhiDetails';
import getCities from '@salesforce/apex/SearchJanAushadhiKendraController.getCities';
import generateQRAndSendEmail from '@salesforce/apex/QRCodeService.generateQRAndSendEmail';
import ToastContainer from 'lightning/toastContainer';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class SearchJanAushadhiKendra extends NavigationMixin(LightningElement) {
    @track janaushadhiDetailsList = [];
    @track pinCode = '';
    @track selectedCity = '';
    @track cityOptions = [];
    @track isLoading = false;

    get filteredList() {
        return this.janaushadhiDetailsList.filter(kendra => {
            const cityMatch = this.selectedCity ? (kendra.City === this.selectedCity) : true;
            const pinMatch = this.pinCode ? (kendra.PostalCode || '').toLowerCase().includes(this.pinCode.toLowerCase()) : true;
            return cityMatch && pinMatch;
        });
    }

    connectedCallback(){
        const toastContainer = ToastContainer.instance();
        toastContainer.maxToasts = 5;
        toastContainer.toastPosition = 'top-center';
    }

    @wire(getJanaushadhiDetails)
    janaushadhiDetails({data,error}){
        if(data){
            this.janaushadhiDetailsList = data;
        }else if(error){
            console.log('Error fetching Janaushadhi details:'+error);
        }
    }

    @wire(getCities)
    wiredCities({data, error}) {
        if(data) {
            this.cityOptions = data.map(city => ({ label: city, value: city }));
        } else if(error) {
            console.log('Error fetching cities:', error);
        }
    }

    handleCityChange(event) {
        this.selectedCity = event.detail.value;
    }

    handlePinCodeChange(event) {
        this.pinCode = event.target.value;
    }

    handleSelect(event) {
        const selectedId = event.target.dataset.id;
        this.janaushadhiDetailsList = this.janaushadhiDetailsList.map(kendra => ({
            ...kendra,
            isSelected: kendra.janaushadhiId === selectedId
        }));
    }

    async handleSubmit() {
        const selectedRecord = this.janaushadhiDetailsList.find(kendra => kendra.isSelected);
        
        if(!selectedRecord) {
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: 'Please select a Jan Aushadhi Kendra before proceeding.',
                    variant: 'error'
                })
            );
            return;
        }

        this.isLoading = true;

        try {
           
            const urlParams = new URLSearchParams(window.location.search);
            const encounterId = urlParams.get('encounterId') || urlParams.get('id');
            
            if(!encounterId) {
                throw new Error('Encounter ID not found');
            }

            
            const result = await generateQRAndSendEmail({ 
                encounterId: encounterId,
                selectedKendraId: selectedRecord.janaushadhiId 
            });
            
            if(result.success) {

                 const encounterDetails = result.encounterDetails;
              
                this[NavigationMixin.Navigate]({
                 type: 'standard__webPage',
                  attributes: {
                  url: `/qr-display?encounterId=${encounterId}&qrUrl=${encodeURIComponent(result.qrUrl)}&token=${result.token}&kendraDetails=${encodeURIComponent(JSON.stringify(selectedRecord))}&encounterDetails=${encodeURIComponent(JSON.stringify(encounterDetails))}`
                 }
    });

                this.dispatchEvent(
                    new ShowToastEvent({
                        title: 'Success',
                        message: 'QR Code generated and email sent successfully!',
                        variant: 'success'
                    })
                );
            } else {
                throw new Error(result.message || 'Failed to generate QR code');
            }

        } catch (error) {
            console.error('Error generating QR code:', error);
            this.dispatchEvent(
                new ShowToastEvent({
                    title: 'Error',
                    message: error.message || 'Failed to generate QR code. Please try again.',
                    variant: 'error'
                })
            );
        } finally {
            this.isLoading = false;
        }
    }
}