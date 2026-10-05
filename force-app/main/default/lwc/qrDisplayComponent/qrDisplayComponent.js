import { LightningElement, track } from 'lwc';
import { NavigationMixin } from 'lightning/navigation';

export default class QrDisplayComponent extends NavigationMixin(LightningElement) {
    @track qrUrl = '';
    @track encounterDetails = {};
    @track kendraDetails = {};
    @track token = '';
    @track isLoading = true;

    connectedCallback() {
        this.loadQRDetails();
    }

    loadQRDetails() {
        try {
            // Get parameters from URL
            const urlParams = new URLSearchParams(window.location.search);
            
            const encounterId = urlParams.get('encounterId');
            this.qrUrl = decodeURIComponent(urlParams.get('qrUrl') || '');
            this.token = urlParams.get('token');
            
            const kendraDetailsStr = urlParams.get('kendraDetails');
            if (kendraDetailsStr) {
                this.kendraDetails = JSON.parse(decodeURIComponent(kendraDetailsStr));
            }

           const encounterDetailsStr = urlParams.get('encounterDetails');
        if (encounterDetailsStr) {
            this.encounterDetails = JSON.parse(decodeURIComponent(encounterDetailsStr));
        } else {
            // Fallback if encounter details not passed
            this.encounterDetails = {
                id: encounterId
            };
        }

            this.isLoading = false;
        } catch (error) {
            console.error('Error loading QR details:', error);
            this.isLoading = false;
        }
    }

    handleDownloadQR() {
        if (this.qrUrl) {
            // Create a temporary anchor element to download the QR code
            const link = document.createElement('a');
            link.href = this.qrUrl;
            link.download = `prescription-qr-${this.encounterDetails.id}.png`;
            document.body.appendChild(link);
            link.click();
            document.body.removeChild(link);
        }
    }

    get googleMapsLink() {
    if (this.kendraDetails?.Street && this.kendraDetails?.PostalCode) {
        const address = encodeURIComponent(`${this.kendraDetails.Street}, ${this.kendraDetails.PostalCode}`);
        return `https://www.google.com/maps/search/?api=1&query=${address}`;
    }
    return '#';
}

    handlePrintQR() {
        const printWindow = window.open('', '_blank');
        // const printContent = `
        //     <html>
        //         <head>
        //             <title>Prescription QR Code</title>
        //             <style>
        //                 body { font-family: Arial, sans-serif; text-align: center; padding: 20px; }
        //                 .qr-container { margin: 20px auto; padding: 20px; border: 2px dashed #333; display: inline-block; }
        //                 .details { margin: 20px 0; text-align: left; }
        //             </style>
        //         </head>
        //         <body>
        //             <h1>Prescription QR Code</h1>
        //             <div class="details">
        //                 <p><strong>Selected Kendra:</strong> ${this.kendraDetails.KendraCode || ''}</p>
        //                 <p><strong>Owner:</strong> ${this.kendraDetails.OwnerName || ''}</p>
        //                 <p><strong>Contact:</strong> ${this.kendraDetails.ContactNumber || ''}</p>
        //                 <p><strong>Address:</strong> ${this.kendraDetails.Street || ''}, ${this.kendraDetails.City || ''} - ${this.kendraDetails.PostalCode || ''}</p>
        //             </div>
        //             <div class="qr-container">
        //                 <img src="${this.qrUrl}" alt="Prescription QR Code" style="width: 200px; height: 200px;">
        //             </div>
        //             <p>Present this QR code at the selected Jan Aushadhi Kendra</p>
        //         </body>
        //     </html>
        // `;
        //printWindow.document.write(printContent);
        printWindow.document.close();
        printWindow.print();
    }

    handleBackToSearch() {
        // Navigate back to the Janaushadhi search page
        window.location.href = `/Janaushadhi/?encounterId=${encounterId}`;
    }
}