public without sharing class QRCodeService {


    // Existing method for trigger-based calls
    public static void generateQRFromFlow(List<Id> encounterIds) {
        for (Id encounterId : encounterIds) {
            generateAndSendQR(encounterId);
        }
    }
    
    // New method for LWC component calls
    @AuraEnabled
    public static Map<String, Object> generateQRAndSendEmail(Id encounterId, Id selectedKendraId) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            ClinicalEncounter encounter = [SELECT PatientId, Patient.Name, Patient.PersonEmail, Contact__c, Contact__r.Email, Contact__r.Name, 
                                          Prescribing_Doctor__r.Name, Facility.Name, StartDate
                                          FROM ClinicalEncounter 
                                          WHERE Id = :encounterId];
            
            // Generate simple token
            String token = String.valueOf(encounterId) + String.valueOf(System.now().getTime());
            
            // Create QR URL
            String prescriptionUrl = 'https://cr1769668480593.my.site.com/janAushadiKendraMedicineCollection/s?id=' + 
                                   encounterId + '&token=' + token + '&kendra=' + selectedKendraId;
            String qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + 
                          EncodingUtil.urlEncode(prescriptionUrl, 'UTF-8');
            
            // Send email
            Boolean emailSent = sendQREmail(encounter.Patient.PersonEmail, encounter.Contact__r.Name, 
                                          qrUrl, encounter, selectedKendraId);
            System.debug('Email sent from generateQRAndSendEmail?'+ emailSent+encounter.Patient.PersonEmail);
            
            // Store QR details in custom object or update encounter (optional)
            // storeQRDetails(encounterId, token, qrUrl, selectedKendraId);
            
            result.put('success', true);
            result.put('qrUrl', qrUrl);
            result.put('token', token);
            result.put('message', 'QR Code generated and email sent successfully');

			result.put('encounterDetails', new Map<String, Object>{
                'patientName' => encounter.Contact__r.Name,
                'doctorName' => encounter.Prescribing_Doctor__r.Name,
                'facilityName' => encounter.Facility.Name,
                'appointmentDate' => encounter.StartDate.format('dd/MM/yyyy'),
                'patientEmail' => encounter.Contact__r.Email
            });
            
        } catch (Exception e) {
            result.put('success', false);
            result.put('message', 'Error generating QR code: ' + e.getMessage());
            System.debug('Error in generateQRAndSendEmail: ' + e.getMessage());
        }
        
        return result;
    }
    
    // Existing method - modified to work with both trigger and LWC calls
    public static void generateAndSendQR(Id encounterId) {
        try {
            ClinicalEncounter encounter = [SELECT PatientId, Patient.Name, Patient.PersonEmail, Contact__c, Contact__r.Email, Contact__r.Name, 
                                          Prescribing_Doctor__r.Name, Facility.Name, StartDate
                                          FROM ClinicalEncounter 
                                          WHERE Id = :encounterId];
            
            // Generate simple token
            String token = String.valueOf(encounterId) + String.valueOf(System.now().getTime());
            	
            // Create QR URL
            String prescriptionUrl = 'https://cr1769668480593.my.site.com/janAushadiKendraMedicineCollection/s?id=' + 
                                   encounterId + '&token=' + token;
            String qrUrl = 'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=' + 
                          EncodingUtil.urlEncode(prescriptionUrl, 'UTF-8');
            
            sendQREmail(encounter.Patient.PersonEmail, encounter.Contact__r.Name, qrUrl, encounter, null);
            System.debug('email sent from generateAndSendQR?'+ encounter.Patient.PersonEmail);
            
        } catch (Exception e) {
            System.debug('Error in generateAndSendQR: ' + e.getMessage());
        }
    }
    
    // Modified email method to handle selected kendra //generateAndSendQR //generateQRAndSendEmail
    private static Boolean sendQREmail(String email, String patientName, String qrUrl, 
                                     ClinicalEncounter encounter, Id selectedKendraId) {
        try {

             // Check if email is valid
        if (String.isBlank(email)) {
            System.debug('Email address is blank or null');
            return false;
        }
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            System.debug(email);
            // Set email details
            mail.setToAddresses(new String[]{email});
            mail.setSubject('Your Prescription QR Code - Jan Aushadhi Kendra');
            mail.setSaveAsActivity(false); // Important for guest user contexts
            mail.setUseSignature(false);
        
        // Optional: Set sender display name
            mail.setSenderDisplayName('PHWC Chamoli');
            
            // Format appointment date
            String appointmentDate = encounter.StartDate.format('dd/MM/yyyy');
            
            // Get selected kendra details if provided
            String kendraInfo = '';
            if (selectedKendraId != null) {
                try {
                    // Get Janaushadhi Pharmacy details
                    Janaushadhi_Pharmacy__c kendra = [SELECT Id, Name, Owner_Name__c, Contact_Number__c, 
                                                     Address__c, Address__StateCode__s, Address__City__s, 
                                                     Address__PostalCode__s, Address__Street__s 
                                                     FROM Janaushadhi_Pharmacy__c 
                                                     WHERE Id = :selectedKendraId LIMIT 1];
                    
                    kendraInfo ='<table cellpadding="0" cellspacing="0" border="0" style="background: white; border: 1px solid #e1e5e9; border-radius: 6px; padding: 12px; width: 100%; max-width: 500px; margin: 0 auto;">' +
                            '<tr>' +
                                '<td align="center" style="padding: 5px;">' +
                                    '<table cellpadding="0" cellspacing="0" border="0">' +
                                        '<tr>' +
                                            '<td align="center" style="padding: 0 10px;">' +
                                                '<table cellpadding="0" cellspacing="0" border="0">' +
                                                    '<tr>' +
                                                        '<td style="color: #737373; font-size: 14px; line-height: 14px; padding-right: 6px; vertical-align: middle;">👤</td>' +
                                                        '<td style="color: #000; font-size: 14px; line-height: 14px; vertical-align: middle;">' + (String.isNotBlank(kendra.Owner_Name__c) ? kendra.Owner_Name__c : 'N/A') + '</td>' +
                                                    '</tr>' +
                                                '</table>' +
                                            '</td>' +
                                            '<td align="center" style="padding: 0 10px;">' +
                                                '<table cellpadding="0" cellspacing="0" border="0">' +
                                                    '<tr>' +
                                                        '<td style="color: #737373; font-size: 14px; line-height: 14px; padding-right: 6px; vertical-align: middle;">📞</td>' +
                                                        '<td style="color: #000; font-size: 14px; line-height: 14px; vertical-align: middle;">' + (String.isNotBlank(kendra.Contact_Number__c) ? kendra.Contact_Number__c : 'N/A') + '</td>' +
                                                    '</tr>' +
                                                '</table>' +
                                            '</td>' +
                                        '</tr>' +
                                    '</table>' +
                                '</td>' +
                            '</tr>' +
                            '<tr>' +
                                '<td align="center" style="padding: 2px 0;">' +
                                    '<table cellpadding="0" cellspacing="0" border="0">' +
                                        '<tr>' +
                                            '<td style="color: #737373; font-size: 13px; line-height: 14px; padding-right: 3px; vertical-align: middle;">📍</td>' +
                                            '<td style="vertical-align: middle;">' +
                                                '<a href="https://maps.google.com/?q=' + EncodingUtil.urlEncode(String.isNotBlank(kendra.Address__Street__s) ? kendra.Address__Street__s : '', 'UTF-8') + '" target="_blank" style="color: #2196f3; text-decoration: none; font-weight: 500; font-size: 13px;">' +
                                                    (String.isNotBlank(kendra.Address__Street__s) ? kendra.Address__Street__s : 'Address not available') + ' 🔗' +
                                                '</a>' +
                                            '</td>' +
                                        '</tr>' +
                                    '</table>' +
                                '</td>' +
                            '</tr>' +
                        '</table>';
                    
                } catch (Exception e) {
                    System.debug('Error fetching kendra details: ' + e.getMessage());
                }
            }
            
            // Email body with QR code
            String emailBody = 
                '<html><body style="font-family: Arial, sans-serif; margin: 0; padding: 15px; background-color: #f5f5f5;">' +
                '<div style="max-width: 600px; margin: 0 auto; background-color: white; padding: 25px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);">' +
                
                //'<div style="text-align: center; margin-bottom: 20px;">' +
                //'<h1 style="color: #2c5aa0; margin: 0; font-size: 24px; font-weight: 600;">Prescription</h1>' +
                //'<p style="color: #666; margin: 1.5px 0 0 0; font-size: 13px;">PHWC Chamoli</p>' +
                //'</div>' +
                
                // Consultation Details Box
                //'<div style="background-color: #f8f9fa; padding: 15px; border-radius: 6px; margin-bottom: 15px; border: 1px solid #e9ecef;">' +
                //'<h3 style="color: #333; margin: 0 0 8px 0; font-size: 18px; font-weight: 500;">Consultation Details</h3>' +
                //'<p style="color: #000; margin: 2px 0; font-size: 13.5px; line-height: 24px;"><strong>Consultation Date:</strong> ' + appointmentDate + '</p>' +
                //'<p style="color: #000; margin: 2px 0; font-size: 13.5px; line-height: 24px;"><strong>Doctor:</strong> ' + encounter.Prescribing_Doctor__r.Name + '</p>' +
                //'<p style="color: #000; margin: 2px 0; font-size: 13.5px; line-height: 24px;"><strong>Facility:</strong> ' + encounter.Facility.Name + '</p>' +
                //'</div>' +
                
               
                
                '<div style="text-align: center;">' +
                '<h2 style="color: #333; margin-bottom: 10px; font-size: 20px; font-weight: 500;">Dear ' + patientName + ',</h2>' +
                
                '<p style="color: #555; font-size: 15px; line-height: 1.5; margin-bottom: 15px;">Buy Prescribed Medicines from Jan Aushadhi Kendra at Subsidized Rates</p>' +
                
                '<div style="background-color: #f8f9fa; padding: 15px; border-radius: 6px; margin: 15px 0;">' +
                '<p style="color: #333; font-size: 15px; font-weight: 500; margin-bottom: 3px;">Please present this QR code at the Jan Aushadhi Kendra:</p>' +

				 kendraInfo + // Selected kendra info (if available)				
                '<img src="' + qrUrl + '" alt="Prescription QR Code" style="width: 160px; height: 160px; margin: 20px auto; padding: 12px; border: 1px dashed #ddd; display: inline-block; background-color: #FFFFFF;">' +
                '</div>' +
                
                '<div style="background-color: #e3f2fd; padding: 15px; border-radius: 6px; margin: 20px 0; border-left: 3px solid #2196f3;">' +
                '<h3 style="color: #1976d2; margin: 0 0 10px 0; font-size: 16px; text-align: left;">Instructions:</h3>' +
                '<div style="text-align: left;">' +
                '<p style="color: #555; margin: 5px 0; font-size: 13px;">• Present this QR code at the Jan Aushadhi Kendra counter</p>' +
                '<p style="color: #555; margin: 5px 0; font-size: 13px;">• This code expires in 48 hours from now</p>' +
                '<p style="color: #555; margin: 5px 0; font-size: 13px;">• The QR code has been sent over WhatsApp as well</p>' +
                '</div>' +
                '</div>' +
                
                '<p style="color: #666; font-size: 13px; margin-top: 25px;">Thank you for choosing PHWC Chamoli for your healthcare needs.</p>' +
                
                '<div style="margin-top: 25px; padding-top: 15px; border-top: 1px solid #eee;">' +
               // '<p style="color: #333; font-size: 14px; font-weight: 500; margin: 0;">Best regards,</p>' +
                //s'<p style="color: #2c5aa0; font-size: 14px; font-weight: 600; margin: 3px 0 0 0;">PHWC Chamoli</p>' +
                '<p style="color: #666; font-size: 12px; margin-top: 2px;">Powered by Dhanwantri • © CRMIT Solutions</p>' +
                '</div>' +
                
                '</div>' +
                '</div>' +
                '</body></html>';
            
            mail.setHtmlBody(emailBody);

            
            // Send email
            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{mail});
            
            System.debug('QR email sent successfully to: ' + email);
            return true;
            
        } catch (Exception e) {
            System.debug('Error sending QR email: ' + e.getMessage());
            return false;
        }
    }

	
    
}