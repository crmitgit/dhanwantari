/**
* @description       : 
* @author            : Karishma
* @group             : 
* @last modified on  : 22-09-2025
* @last modified by  : Karishma
**/
public class PrescriptionApprovalController 
{
    @AuraEnabled
    Public static resultWrapper sendEmail(string cinicalEncounterId)
    {
        resultWrapper resultWrap = new resultWrapper();
        try{
            
            ClinicalEncounter sendApprovalRec = [SELECT Id, Name, Patient.Name,Prescribing_Doctor__r.name, Prescribing_Doctor__r.PersonEmail,Requested_Physician_Assistant__c,Status from ClinicalEncounter where id =: cinicalEncounterId];
            String notificationFormattedDate = '';
            Date today = System.today();
            String formattedDate = today.format();            
            Group ownerGroup = [Select id,Name,DeveloperName from Group Where DeveloperName = 'MBBS_Doctors' and type = 'Queue'];
            ClinicalEncounter clinicalEncounterObj = new ClinicalEncounter();
            clinicalEncounterObj.Id = cinicalEncounterId;
            clinicalEncounterObj.OwnerId = ownerGroup.Id;
           // clinicalEncounterObj.Queue_Owner__c = ownerGroup.Id;
            update clinicalEncounterObj;
            
            String dynamicUrl = '/lightning/r/ClinicalEncounter/' + cinicalEncounterId+'/view?c__isOpenPopup=true';
            
            
            
            Messaging.CustomNotification notification = new Messaging.CustomNotification(); 
            notification.setTitle('New Consultation is assigned'); 
            notification.setBody('New Consultation is assigned for '+sendApprovalRec.Name +' on '+formattedDate); 
            notification.setSenderId(UserInfo.getUserId()); // sender user id
            
            CustomNotificationType customNotify = [SELECT Id,DeveloperName FROM CustomNotificationType Where DeveloperName = 'New_Consultation_Request'];
            notification.setNotificationTypeId(customNotify.id); 
            notification.setTargetId(cinicalEncounterId);
            //notification.setTargetPageRef('{"type":"standard__webPage","attributes":{"url":"' + dynamicUrl + '"}}'); // target object id 
            notification.send(new Set<String> { ownerGroup.Id });

            
            sendApprovalRec.Requested_Physician_Assistant__c = UserInfo.getName();
            sendApprovalRec.Status = 'Approval Pending';
            update sendApprovalRec;

            resultWrap.status = 'Success';
            resultWrap.message = 'Approval Sent';
      
            // // Get base domain (like https://your-org.lightning.force.com)
            String baseUrl = System.Url.getOrgDomainUrl().toExternalForm();
            
            String loginRedirectUrl = baseUrl +'/lightning/r/ClinicalEncounter/' + cinicalEncounterId+'/view?c__isOpenPopup=true';
            // // Use this in the email
            String emailBody = 'Hi <b>' + sendApprovalRec.Prescribing_Doctor__r.name+',</b><br/>';
            emailBody += '<br/> Please review and provide your approval for the medications listed in the attached patient consultation summary. Your final confirmation is required to proceed.';
            emailBody += '<br/><a href="' + loginRedirectUrl + '" target="_blank">Open Consultation Summary</a><br/>';
            emailBody += '<br/><b> Best regards,</b><br/>';
             emailBody += 'Physician Assistant,<br/>';
            emailBody += 'PHWC Chamoli.';
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setHtmlBody(emailBody);
            // // String[] toAddresses = new String[] { sendApprovalRec.Prescribing_Doctor__r.PersonEmail };
            // // mail.setToAddresses(toAddresses);
            mail.setToAddresses(new String[] { sendApprovalRec.Prescribing_Doctor__r.PersonEmail });
            mail.setSubject('Approval Request for Medication – Patient Consultation Summary');
            mail.setSaveAsActivity(false);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail});
            if (results[0].success) 
            {
                 resultWrap.status = 'Success';
                 resultWrap.message = 'Approval request has been sent to the doctor, and they have been notified.';
                 ClinicalEncounter updateApprovalDetails = new ClinicalEncounter();
                updateApprovalDetails.Id = cinicalEncounterId;
                updateApprovalDetails.Requested_Physician_Assistant__c = UserInfo.getName();
                update updateApprovalDetails;
            //     //return('The email was sent successfully.');
                return resultWrap;
         } 
             else
             {
                 resultWrap.status = 'Error';
                 resultWrap.message = results[0].errors[0].message;
                 return resultWrap;
             }
        }
        catch(exception ex){
            system.debug('Exception in PrescriptionApprovalController::'+ ex.getMessage());
            system.debug('Exception in PrescriptionApprovalController at line number ::'+ ex.getLineNumber());
            resultWrap.status = 'Error';
            resultWrap.message = ex.getMessage();
            return resultWrap;        
        }
    }
    
    @AuraEnabled
    public static resultWrapper sendEmailToPatient(String cinicalEncounterId,String doctorComment,Date followUpDate)
    {
        resultWrapper resultpatientWrap = new resultWrapper();
        ClinicalEncounter sendPrescriptionEmail = [SELECT Id, Patient.Name, Prescribing_Doctor__r.name, Patient.PersonEmail, Patient.Attendent_Email__c, StartDate from ClinicalEncounter where id =: cinicalEncounterId];
        user currentUser = [SELECT Id, Name, Registration_Number__c FROM User where Id = :UserInfo.getUserId()];
        String formattedDate = '';
        if(sendPrescriptionEmail.StartDate != null){
            Integer day = sendPrescriptionEmail.StartDate.day();
            String monthName = DateTime.newInstance(sendPrescriptionEmail.StartDate.year(), sendPrescriptionEmail.StartDate.month(), sendPrescriptionEmail.StartDate.day()).format('MMMM');
            Integer year = sendPrescriptionEmail.StartDate.year(); 
            
            formattedDate = day + ' ' + monthName + ' ' + year;
        }
        String loginRedirectUrl = 'https://cr1769668480593.my.site.com/Janaushadhi'+'?encounterId=' + cinicalEncounterId; 
        String emailBody = 'Dear <b>' + sendPrescriptionEmail.Patient.Name+',</b><br/>';
        emailBody += '<br/> Following your consultation dated <b>' + formattedDate + '</b>, you can now collect your prescribed medicines from Jan Aushadhi Kendra.';
        emailBody += '<br/> Please click the link below to find and select your nearest Jan Aushadhi Kendra - a government-authorised pharmacy offering quality medicines at subsidised prices.';
        emailBody += '<br/><a href="' + loginRedirectUrl + '" target="_blank">Click Here</a><br/>';
        emailBody += '<br/><b> Best regards,</b><br/>';
        emailBody += 'PHWC Chamoli.';
        Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
        mail.setHtmlBody(emailBody);
        mail.setToAddresses(new String[] {sendPrescriptionEmail.Patient.PersonEmail});
        if(sendPrescriptionEmail.Patient.Attendent_Email__c != null){
            String[] ccAddresses = new String[] { sendPrescriptionEmail.Patient.Attendent_Email__c };
            mail.setCcAddresses(ccAddresses);
         }
        // mail.setCcAddresses(ccAddresses);
        mail.setSubject('Collect Your Medicines from a Nearby Jan Aushadhi Kendra at Affordable Prices');
        mail.setSaveAsActivity(false);
       /* OrgWideEmailAddress[] owea = [
            SELECT Id FROM OrgWideEmailAddress 
            WHERE Address = 'shaik.karishma@crmit.com' 
            LIMIT 1
        ];
        
        List<OrgWideEmailAddress> owea =   [SELECT Id, Address FROM OrgWideEmailAddress LIMIT 1];

        if(!owea.isEmpty()){
            mail.setOrgWideEmailAddressId(owea[0].Id);
        }*/
        mail.setOrgWideEmailAddressId('0D2KY000000PBA90AO');

        // 1. Record the doctor's approval first – it must not depend on the patient email
        ClinicalEncounter updateApprovalDetails = new ClinicalEncounter();
        updateApprovalDetails.Id = cinicalEncounterId;
        updateApprovalDetails.Status = 'Diagnosis Approved';
        updateApprovalDetails.Approved_Date__c = System.today();
        updateApprovalDetails.Doctor_Name__c = sendPrescriptionEmail.Prescribing_Doctor__r.name;
        updateApprovalDetails.Registration_Number__c = currentUser.Registration_Number__c;
        updateApprovalDetails.Comments_Remarks__c = doctorComment;
        updateApprovalDetails.Follow_up_Date__c = followUpDate;
        try {
            update updateApprovalDetails;
        } catch (Exception ex) {
            resultpatientWrap.status = 'Error';
            resultpatientWrap.message = 'Could not save the approval: ' + ex.getMessage();
            return resultpatientWrap;
        }

        // 2. Then notify the patient; a failure here only produces a warning
        resultpatientWrap.status = 'Success';
        if (String.isBlank(sendPrescriptionEmail.Patient.PersonEmail)) {
            resultpatientWrap.message = 'Consultation approved. No email was sent because ' + sendPrescriptionEmail.Patient.Name + ' has no email address on file.';
            return resultpatientWrap;
        }
        try {
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[] {mail}, false);
            if (results[0].success) {
                resultpatientWrap.message = 'Consultation approved and the email was sent successfully to ' + sendPrescriptionEmail.Patient.Name;
                resultpatientWrap.email = mail.getToAddresses();
            } else {
                resultpatientWrap.message = 'Consultation approved, but the patient email could not be sent: ' + results[0].errors[0].message;
            }
        } catch (Exception ex) {
            resultpatientWrap.message = 'Consultation approved, but the patient email could not be sent: ' + ex.getMessage();
        }
        return resultpatientWrap;
    }
    
    public class resultWrapper
    {
        @AuraEnabled 
        public String status { get; set; }
        @AuraEnabled 
        public String message { get; set; }
        @AuraEnabled
        public List<String> email { get; set; }
        @AuraEnabled
        public String error { get; set; }
    }
    
    @AuraEnabled
    public static EncounterSummary getEncounterDetails(String encounterName) {
        // Query the Clinical Encounter and related records
        ClinicalEncounter encounter = [
            SELECT Name, StartDate, EndDate, Status,PatientId,
            Height_in_cm__c, Weight_in_Kg__c, Pulse_Rate_in_BPM__c,
            Blood_Pressure__c, Body_Temperature__c, SpO2__c,
            Clinical_Findings__c, Symptoms__c, Medical_History__c,
            Care_Instructions__c, Follow_up_Date__c,
            Contact__r.Name, Contact__r.Phone, Contact__r.Email,
            Contact__r.Account.Gender__c, Contact__r.Account.Age__c,
            Contact__r.Account.Patient_ID__c, Patient.Name, Patient.Phone, Patient.Patient_ID__c,
            Patient.Gender__c, Patient.Age__c,
            Prescribing_Doctor__r.Id, Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone,
            Facility.Name, FacilityId, Facility.Location__c,
            Facility.Location__Street__s, Facility.Location__City__s, Facility.Location__PostalCode__s, 
            (SELECT Clinical_Diagnosis__c, Diagnosis_Type__c FROM Diagnoses__r),
            (SELECT Id, MedicationId, Medication.Name, Duration_Days__c, Prescription_Start_Date__c, Dosage_Strength__c, To_be_taken_in_night__c, To_be_taken_in_afternoon__c, To_be_taken_in_morning__c,
             Morning__c, Afternoon__c, Night__c, BF_AF__c FROM MedicationRequest_ClinicalEncounter),
            (SELECT Id, Requested_Test__c, Requested_Completion_Date__c, Status FROM Encounters)
            FROM ClinicalEncounter
            WHERE Id = :encounterName
            LIMIT 1
        ];
        
        EncounterSummary output = new EncounterSummary();
        
        // Basic Details
        output.patientName = encounter.Patient.Name;
        output.doctorName = encounter.Prescribing_Doctor__r?.Name;
        output.patientId = encounter.PatientId;
        // Dates
        output.startDate = (encounter.StartDate != null)
            ? DateTime.newInstance(encounter.StartDate.year(), encounter.StartDate.month(), encounter.StartDate.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';
        output.endDate = (encounter.StartDate != null)
            ? DateTime.newInstance(encounter.StartDate.year(), encounter.StartDate.month(), encounter.StartDate.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';
        
        // Contact & Doctor Info
        output.phone = String.valueOf(encounter.Patient.Phone);
        output.email = String.valueOf(encounter.Contact__r.Email);
        output.doctorPhone = String.valueOf(encounter.Prescribing_Doctor__r.Phone);
        output.prescribingDoctorId = encounter.Prescribing_Doctor__r.Id;
        
        // Vitals and Clinical Details
        output.status = encounter.Status;
        output.facilityName = String.isNotBlank(encounter.Facility.Name) ? encounter.Facility.Name : 'N/A';
        output.height = encounter.Height_in_cm__c != null ? encounter.Height_in_cm__c + ' cm' : 'N/A';
        output.weight = encounter.Weight_in_Kg__c != null ? encounter.Weight_in_Kg__c + ' kg' : 'N/A';
        output.pulse = encounter.Pulse_Rate_in_BPM__c != null ? encounter.Pulse_Rate_in_BPM__c + ' BPM' : 'N/A';
        output.bloodPressure = String.isNotBlank(encounter.Blood_Pressure__c) ? encounter.Blood_Pressure__c : 'N/A';
        output.temperature = encounter.Body_Temperature__c != null ? encounter.Body_Temperature__c + ' °F' : 'N/A';
        output.spo2 = encounter.SpO2__c != null ? encounter.SpO2__c + '%' : 'N/A';
        
        // Demographics
        output.gender = String.isNotBlank(encounter.Patient.Gender__c) ? encounter.Patient.Gender__c : 'N/A';
        output.age = encounter.Patient.Age__c != null ? String.valueOf(encounter.Patient.Age__c) : 'N/A';
        output.pid = encounter.Patient.Patient_ID__c != null ? String.valueOf(encounter.Patient.Patient_ID__c) : 'Patient ID: N/A';
        
        // Clinical Notes
        output.clinicalFindings = String.isNotBlank(encounter.Clinical_Findings__c) ? encounter.Clinical_Findings__c : 'None Found';
        output.symptoms = String.isNotBlank(encounter.Symptoms__c) ? encounter.Symptoms__c : 'None reported';
        output.medicalHistory = String.isNotBlank(encounter.Medical_History__c) ? encounter.Medical_History__c : 'None reported';
        output.careInstructions = String.isNotBlank(encounter.Care_Instructions__c) ? encounter.Care_Instructions__c : 'Not provided';
        
       /* output.followUpDate = (encounter.Follow_up_Date__c != null)
            ? DateTime.newInstance(encounter.Follow_up_Date__c.year(), encounter.Follow_up_Date__c.month(), encounter.Follow_up_Date__c.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';*/
        output.followUpDate = encounter.Follow_up_Date__c;
        
        // Location Formatting
        List<String> locParts = new List<String>();
        if (String.isNotBlank(encounter.Facility.Location__Street__s)) locParts.add(encounter.Facility.Location__Street__s);
        if (String.isNotBlank(encounter.Facility.Location__City__s)) locParts.add(encounter.Facility.Location__City__s);
        if (String.isNotBlank(encounter.Facility.Location__PostalCode__s)) locParts.add(encounter.Facility.Location__PostalCode__s);
        output.location = locParts.isEmpty() ? 'Not Available' : String.join(locParts, ', ');
        
        // Diagnoses
        output.diagnoses = new List<Map<String, String>>();
        for (Diagnosis__c d : encounter.Diagnoses__r) {
            Map<String, String> diagMap = new Map<String, String>();
            diagMap.put('id', d.Id);
            diagMap.put('text', String.isNotBlank(d.Clinical_Diagnosis__c) ? d.Clinical_Diagnosis__c : 'N/A');
            diagMap.put('type', String.isNotBlank(d.Diagnosis_Type__c) ? d.Diagnosis_Type__c : 'Unknown');
            output.diagnoses.add(diagMap);
        }
        
        // Medications
        output.medications = new List<Map<String, Object>>();
        for (MedicationRequest m : encounter.MedicationRequest_ClinicalEncounter) {
            Map<String, Object> medMap = new Map<String, Object>();
            medMap.put('id', m.Id);
            medMap.put('medicationId',m.MedicationId);
            medMap.put('name', m.Medication.Name);
            medMap.put('duration', m.Duration_Days__c != null ? String.valueOf(m.Duration_Days__c) : 'N/A');
            medMap.put('startDate', m.Prescription_Start_Date__c != null
                       ? DateTime.newInstance(m.Prescription_Start_Date__c.year(), m.Prescription_Start_Date__c.month(), m.Prescription_Start_Date__c.day(), 0, 0, 0).format('dd-MMM-yyyy')
                       : 'N/A');
            medMap.put('toBeTakenInMorning', m.To_be_taken_in_morning__c);
            medMap.put('toBeTakenInAfternoon', m.To_be_taken_in_afternoon__c);
            medMap.put('toBeTakenInNight', m.To_be_taken_in_night__c);
            medMap.put('food', m.BF_AF__c);
            medMap.put('dosage', m.Dosage_Strength__c);
            output.medications.add(medMap);
        }
        
        // Clinical Service Requests (Lab/Diagnostic Tests)
        output.csrs = new List<Map<String, String>>();
        for (ClinicalServiceRequest s : encounter.Encounters) {
            if (String.isNotBlank(s.Requested_Test__c)) {
                Map<String, String> csrMap = new Map<String, String>();
                csrMap.put('id', s.Id);
                csrMap.put('RequestedTest', s.Requested_Test__c);
                csrMap.put('RequestedCompletionDate', s.Requested_Completion_Date__c != null
                           ? DateTime.newInstance(s.Requested_Completion_Date__c, Time.newInstance(0, 0, 0, 0)).format('dd-MMM-yyyy')
                           : 'N/A');
                csrMap.put('medStatus', s.Status);
                output.csrs.add(csrMap);
            }
        }
        
        return output;
    }
    
    // Data Transfer Object (DTO) class for Lightning components
    public class EncounterSummary {
        @AuraEnabled public String patientName;
        @AuraEnabled public String doctorName;
        @AuraEnabled public String startDate;
        @AuraEnabled public String endDate;
        @AuraEnabled public String status;
        @AuraEnabled public String height;
        @AuraEnabled public String weight;
        @AuraEnabled public String pulse;
        @AuraEnabled public String facilityName;
        @AuraEnabled public String bloodPressure;
        @AuraEnabled public String temperature;
        @AuraEnabled public String spo2;
        @AuraEnabled public String clinicalFindings;
        @AuraEnabled public String symptoms;
        @AuraEnabled public String medicalHistory;
        @AuraEnabled public String careInstructions;
       // @AuraEnabled public String followUpDate;
        @AuraEnabled public Date followUpDate;
        @AuraEnabled public String diagnosisText;
        @AuraEnabled public String location;
        @AuraEnabled public String phone;
        @AuraEnabled public String gender;
        @AuraEnabled public String age;
        @AuraEnabled public String pid;
        @AuraEnabled public String email;
        @AuraEnabled public String doctorPhone;
        @AuraEnabled public Id prescribingDoctorId;
        @AuraEnabled public List<Map<String, Object>> medications;
        @AuraEnabled public List<Map<String, String>> csrs;
        @AuraEnabled public List<Map<String, String>> diagnoses;
        @AuraEnabled public String patientId;
    }
    
    @AuraEnabled
    public static String deleteRecord(String recordId)
    {
        String Status;
        try
        {
            if(recordId !=null && recordId !='')
            {
                database.delete(recordId,false);  
            }           
            Status='Success'; 
        }
        catch(Exception e)
        {
            System.debug('Exception in PrescriptionApprovalController :'+e);
            System.debug('Exception in PrescriptionApprovalController line :'+e.getLineNumber());
            Status=String.valueOf(e);
            return Status;
        }  
        return Status;
    }

    @AuraEnabled
    public static imageWrapper getDoctoreImage()
    {
        imageWrapper imgWrap = new imageWrapper();
        User usr = [Select id,Name,Doctor_Signature__c,Consultation_Logo__c  from User Where Id=: '005KY000003ABfAYAW'];
        if(String.isNotBlank(usr.Doctor_Signature__c))
        {
            imgWrap.signatureImage = getImageURL(usr.Doctor_Signature__c);
            System.debug('Signature Image URL: ' + imgWrap.signatureImage);
        }
        if(String.isNotBlank(usr.Consultation_Logo__c)){
            imgWrap.consultationImage = getImageURL(usr.Consultation_Logo__c);
            System.debug('Consultation Image URL: ' + imgWrap.consultationImage);
        }
        return imgWrap;
    }

    public class imageWrapper
    {
        @AuraEnabled 
        public String consultationImage { get; set; }
        @AuraEnabled 
        public String signatureImage { get; set; }

    }

    public static string getImageURL(string signatureImage)
    {
        String imageURL='';
        Matcher imgMatcher = Pattern.compile( '<img(.+?)>' ).matcher(signatureImage);           
        while (imgMatcher.find()) {                
            String imageTag = imgMatcher.group();
            System.debug('imageTag^^'+imageTag );              
            
            imageURL= imageTag.substringBetween(' src="', '"' );
            System.debug('imageURL^^' + imageURL );
        }        
        return imageURL.unescapeHtml4();       
    }

@AuraEnabled
public static resultWrapper updateDiagnosis(List<Diagnosis__c> diagnosisList) {

    resultWrapper resultWrap = new resultWrapper();

    try {

        if(diagnosisList == null || diagnosisList.isEmpty()){
            resultWrap.status = 'Error';
            resultWrap.message = 'No diagnosis records received';
            return resultWrap;
        }
		System.debug('diagnosisList'+diagnosisList);
        update diagnosisList;

        resultWrap.status = 'Success';
        resultWrap.message = 'Diagnosis updated successfully';
        return resultWrap;

    }catch(Exception ex){
        System.debug('Exception :: '+ex.getMessage());

        resultWrap.status = 'Error';
        resultWrap.message = ex.getMessage();
        return resultWrap;
    }
}
    
}