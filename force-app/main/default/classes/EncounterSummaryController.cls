// Apex controller for handling Encounter Summary retrieval and related actions
public with sharing class EncounterSummaryController {

    // ------------------------- GET ENCOUNTER DETAILS -------------------------

    @AuraEnabled(cacheable=true)
    public static EncounterSummary getEncounterDetails(String encounterName) {
        // Query the Clinical Encounter and related records
        ClinicalEncounter encounter = [
            SELECT Name, StartDate, EndDate, Status, Approved_Date__c,
                   Height_in_cm__c, Weight_in_Kg__c, Pulse_Rate_in_BPM__c,
                   Blood_Pressure__c, Body_Temperature__c, SpO2__c,
                   Clinical_Findings__c, Symptoms__c, Medical_History__c,
                   Care_Instructions__c, Follow_up_Date__c,
                   Contact__r.Name, Contact__r.Phone, Contact__r.Email,
                   Patient.Gender__c, Patient.Age__c,
                   Contact__r.Account.Patient_ID__c,Patient.Name, Patient.Phone, Patient.Patient_ID__c,
                   Prescribing_Doctor__r.Id, Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone,
                   Facility.Name, FacilityId, Facility.Location__c, Patient.PersonEmail,
                   Facility.Location__Street__s, Facility.Location__City__s, Facility.Location__PostalCode__s,
                   (SELECT Clinical_Diagnosis__c, Diagnosis_Type__c FROM Diagnoses__r),
                   (SELECT Id, MedicationId, Medication.Name, Duration_Days__c, Prescription_Start_Date__c,
                           Morning__c, Afternoon__c, Night__c, BF_AF__c FROM MedicationRequest_ClinicalEncounter),
                   (SELECT Id, Requested_Test__c, Requested_Completion_Date__c, Status FROM Encounters)
            FROM ClinicalEncounter
            WHERE Id = :encounterName
            LIMIT 1
        ];

        EncounterSummary output = new EncounterSummary();

        // Basic Details
        output.patientName = encounter.Patient?.Name;
        output.doctorName = encounter.Prescribing_Doctor__r?.Name;

        // Dates
        output.startDate = (encounter.StartDate != null)
            ? DateTime.newInstance(encounter.StartDate.year(), encounter.StartDate.month(), encounter.StartDate.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';
        output.endDate = (encounter.StartDate != null)
            ? DateTime.newInstance(encounter.StartDate.year(), encounter.StartDate.month(), encounter.StartDate.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';

        // Contact & Doctor Info
        output.phone = String.valueOf(encounter.Patient.Phone);
        output.email = String.valueOf(encounter.Patient.PersonEmail);
        output.doctorPhone = String.valueOf(encounter.Prescribing_Doctor__r.Phone);
        output.prescribingDoctorId = encounter.Prescribing_Doctor__r.Id;

        // Vitals and Clinical Details
        output.status = encounter.Status;
        // A doctor approval stamps Approved_Date__c (PrescriptionApprovalController.sendEmailToPatient)
        output.isDoctorApproved = encounter.Approved_Date__c != null || encounter.Status == 'Diagnosis Approved';
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

        output.followUpDate = (encounter.Follow_up_Date__c != null)
            ? DateTime.newInstance(encounter.Follow_up_Date__c.year(), encounter.Follow_up_Date__c.month(), encounter.Follow_up_Date__c.day(), 0, 0, 0).format('dd-MMM-yyyy')
            : 'N/A';

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
            diagMap.put('text', String.isNotBlank(d.Clinical_Diagnosis__c) ? d.Clinical_Diagnosis__c : 'N/A');
            diagMap.put('type', String.isNotBlank(d.Diagnosis_Type__c) ? d.Diagnosis_Type__c : 'Unknown');
            output.diagnoses.add(diagMap);
        }

        // Medications
        output.medications = new List<Map<String, String>>();
        for (MedicationRequest m : encounter.MedicationRequest_ClinicalEncounter) {
            Map<String, String> medMap = new Map<String, String>();
            medMap.put('id', m.Id);
            medMap.put('name', m.Medication.Name);
            medMap.put('duration', m.Duration_Days__c != null ? String.valueOf(m.Duration_Days__c) : 'N/A');
            medMap.put('startDate', m.Prescription_Start_Date__c != null
                ? DateTime.newInstance(m.Prescription_Start_Date__c.year(), m.Prescription_Start_Date__c.month(), m.Prescription_Start_Date__c.day(), 0, 0, 0).format('dd-MMM-yyyy')
                : 'N/A');
            medMap.put('morning', m.Morning__c != null && m.Morning__c != '0' ? m.Morning__c : 'N/A');
            medMap.put('afternoon', m.Afternoon__c != null && m.Afternoon__c != '0' ? m.Afternoon__c : 'N/A');
            medMap.put('night', m.Night__c != null && m.Night__c != '0' ? m.Night__c : 'N/A');
            medMap.put('food', m.BF_AF__c);
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
        @AuraEnabled public Boolean isDoctorApproved;
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
        @AuraEnabled public String followUpDate;
        @AuraEnabled public String diagnosisText;
        @AuraEnabled public String location;
        @AuraEnabled public String phone;
        @AuraEnabled public String gender;
        @AuraEnabled public String age;
        @AuraEnabled public String pid;
        @AuraEnabled public String email;
        @AuraEnabled public String doctorPhone;
        @AuraEnabled public Id prescribingDoctorId;
        @AuraEnabled public List<Map<String, String>> medications;
        @AuraEnabled public List<Map<String, String>> csrs;
        @AuraEnabled public List<Map<String, String>> diagnoses;
    }

    // ------------------------- SEND ENCOUNTER EMAIL -------------------------

    @AuraEnabled
    public static void sendEncounterEmail(String encounterId, String patientEmail, String patientName, String facilityName, String doctorName, String endDate) {
        if (String.isBlank(encounterId) || String.isBlank(patientEmail)) {
            throw new AuraHandledException('Missing required parameters.');
        }

        // Set default greeting
        String greetingName = String.isNotBlank(patientName) ? patientName.trim() : 'Patient';

        // Generate PDF of encounter summary
        PageReference pdfPage = Page.PrintEncounterSummary;
        pdfPage.getParameters().put('id', encounterId);
        Blob pdfBlob = pdfPage.getContentAsPDF();

        // Create PDF attachment
        String formattedFileName = 'Prescription' + '_' + patientName + '_' + endDate + '.pdf';
        Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
        attachment.setFileName(formattedFileName);
        attachment.setBody(pdfBlob);
        attachment.setContentType('application/pdf');

        // Create multilingual email body
        String plainBody =
            'Dear ' + greetingName + ',\n\n' +
            'Thank you for visiting ' + facilityName + ' on ' + endDate + '.\n' +
            'Your prescription (attached) has been shared with you for your reference.\n\n' +
            '---------------------------------------------------------------------------------\n\n' +
            'प्रिय ' + greetingName + ',\n\n' +
            'हमसे ' + endDate + ' को ' + facilityName + ' पर परामर्श करने के लिए धन्यवाद।\n' +
            'आपकी पर्ची (संलग्न) आपके संदर्भ के लिए साझा की गई है।\n\n' +
            'Kind regards,\n' + facilityName + '\n\n' +
            '—\nCONFIDENTIALITY NOTICE: This email and any attachments contain personal medical information intended solely for the addressee.\n' +
            'यह एक गोपनीय ईमेल है जिसमें केवल संबंधित व्यक्ति की व्यक्तिगत चिकित्सा जानकारी है।\n\n' +
            'This is a system‑generated message from a no‑reply email. Please do not respond to this email.\n' +
            'यह एक सिस्टम द्वारा जनरेट किया गया ईमेल है। कृपया इसका उत्तर न दें।';

        // Create and send email
        Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
        email.setToAddresses(new String[] { patientEmail });
        email.setSubject('Your Prescription from ' + doctorName + ' – ' + endDate + ' | आपकी पर्ची ' + doctorName + ' द्वारा – ' + endDate);
        email.setPlainTextBody(plainBody);
        email.setFileAttachments(new Messaging.EmailFileAttachment[] { attachment });
        Messaging.sendEmail(new Messaging.SingleEmailMessage[] { email });

        // Save PDF as ContentVersion if not already saved
        ClinicalEncounter encounterRecord = [
            SELECT Id, Contact__c, Status FROM ClinicalEncounter WHERE Id = :encounterId LIMIT 1
        ];

        List<ContentVersion> existingVersions = [
            SELECT Id, Title FROM ContentVersion WHERE Title = :formattedFileName
        ];

        if (existingVersions.isEmpty()) {
            ContentVersion cv = new ContentVersion();
            cv.Title = formattedFileName;
            cv.PathOnClient = formattedFileName;
            cv.VersionData = pdfBlob;
            cv.FirstPublishLocationId = encounterRecord.Contact__c;
            insert cv;
        }

        // Mark Encounter as completed
        //encounterRecord.Status = 'Completed';
        //update encounterRecord;
    }

    // ------------------------- GET DOCTOR SIGNATURE IMAGE -------------------------

    @AuraEnabled(cacheable=true)
    public static String getDoctorSignature(String doctorId) {
        // Try to get latest ContentDocument
        List<ContentDocumentLink> links = [
            SELECT ContentDocument.LatestPublishedVersionId, ContentDocument.LatestPublishedVersion.FileType
            FROM ContentDocumentLink
            WHERE LinkedEntityId = :doctorId
            ORDER BY ContentDocument.CreatedDate DESC
            LIMIT 1
        ];

        if (!links.isEmpty()) {
            Id verId = links[0].ContentDocument.LatestPublishedVersionId;
            ContentVersion cv = [
                SELECT VersionData, FileType FROM ContentVersion WHERE Id = :verId
            ];
            String mime = cv.FileType.toUpperCase().startsWith('JP') ? 'image/jpeg'
                       : cv.FileType.toUpperCase() == 'PNG' ? 'image/png'
                       : 'application/octet-stream';
            return 'data:' + mime + ';base64,' + EncodingUtil.base64Encode(cv.VersionData);
        }

        // Fallback to legacy Attachment
        List<Attachment> atts = [
            SELECT Body, ContentType FROM Attachment
            WHERE ParentId = :doctorId
            ORDER BY CreatedDate DESC
            LIMIT 1
        ];

        if (!atts.isEmpty()) {
            return 'data:' + atts[0].ContentType + ';base64,' + EncodingUtil.base64Encode(atts[0].Body);
        }

        return null; // No signature found
    }
}