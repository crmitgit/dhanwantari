public without sharing class ClinicalEncounterController2 {

    public ClinicalEncounter encounter { get; private set; }
    public String signatureImageUrl { get; private set; }
	private ReferralPDFData pdfDataCache;

    public ClinicalEncounterController2() {
		String patientId = ApexPages.currentPage().getParameters().get('patientId');
        encounter = [
            SELECT Id, Name, StartDate, Facility.Name,
                   Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone,
                   (SELECT Id, Clinical_Diagnosis__c, Diagnosis_Description__c
                    FROM Diagnoses__r)
            FROM ClinicalEncounter
            WHERE PatientId = :patientId
            ORDER BY StartDate DESC
            LIMIT 1
        ];

        loadSignatureImage();
    }


private void loadSignatureImage() {
        // Option A: Classic Attachment
        List<Attachment> atts = [
            SELECT Id FROM Attachment
            WHERE ParentId = :encounter.Prescribing_Doctor__c
            AND Name LIKE '%signature%'
            LIMIT 1
        ];
        if (!atts.isEmpty()) {
            signatureImageUrl = '/servlet/servlet.FileDownload?file=' + atts[0].Id;
            return;
        }

        // Option B: ContentVersion via Files
        List<ContentDocumentLink> links = [
            SELECT ContentDocumentId FROM ContentDocumentLink
            WHERE LinkedEntityId = :encounter.Prescribing_Doctor__c
            LIMIT 1
        ];
        if (!links.isEmpty()) {
            List<ContentVersion> versions = [
                SELECT Id FROM ContentVersion
                WHERE ContentDocumentId = :links[0].ContentDocumentId
                ORDER BY VersionNumber DESC
                LIMIT 1
            ];
            if (!versions.isEmpty()) {
                signatureImageUrl = '/sfc/servlet.shepherd/version/download/' + versions[0].Id;
            }
        }
    }


    private ReferralPDFData getPdfData() {
        if (pdfDataCache == null) {
            String referralId = ApexPages.currentPage().getParameters().get('referralId');
            String patientId = ApexPages.currentPage().getParameters().get('patientId');
            
            if (String.isNotBlank(referralId) && String.isNotBlank(patientId)) {
                pdfDataCache = getReferralPDFData(Id.valueOf(referralId), Id.valueOf(patientId));
            } else {
                pdfDataCache = new ReferralPDFData();
            }
        }
        return pdfDataCache;
    }

// Individual properties that VF can access
        public String refName {
            get { return getPdfData().refName; }
        }
        
        public String patientName {
            get { return getPdfData().patientName; }
        }
        
        public String mob {
            get { return getPdfData().mob; }
        }
        
        public Integer age {
            get { return getPdfData().age; }
        }
        
        public String gender {
            get { return getPdfData().gender; }
        }
        
        public String pmjayId {
            get { return getPdfData().pmjayId; }
        }
        
        public String aadharNumber {
            get { return getPdfData().aadharNumber; }
        }
        
        public String attendantName {
            get { return getPdfData().attendantName; }
        }
        
        public String attendantPhone {
            get { return getPdfData().attendantPhone; }
        }
        
        public String referringDoctor {
            get { return getPdfData().referringDoctor; }
        }
        
        public String referringPHWC {
            get { return getPdfData().referringPHWC; }
        }
        
        public String doctorsPhone {
            get { return getPdfData().doctorsPhone; }
        }
        
        public String referredPrimarySpecialty {
            get { return getPdfData().referredPrimarySpecialty; }
        }
        
        public String referredSecondarySpecialty {
            get { return getPdfData().referredSecondarySpecialty; }
        }
        
        public String referralPriority {
            get { return getPdfData().referralPriority; }
        }
        
        public String reasonForReferral {
            get { return getPdfData().reasonForReferral; }
        }
        
        public String careSummary {
            get { return getPdfData().careSummary; }
        }
        
        public String latestDiagnosis {
            get { return getPdfData().latestDiagnosis; }
        }
        
        public String recommendedVisitBy {
            get { return getPdfData().recommendedVisitBy; }
        }
        
        public String referralDate {
            get { return getPdfData().referralDate; }
        }

        public String referralSummary {
            get { return getPdfData().referralSummary; }
        }
        




    @AuraEnabled(cacheable=true)
    public static List<EncounterWrapper> getLatestEncountersWithDiagnosis(Id accountId) {
        List<ClinicalEncounter> encounters = [
            SELECT Id, Name, PatientId, Patient.Name, Patient.Age__c, 
                   Prescribing_Doctor__c, Prescribing_Doctor__r.Name,
                   StartDate
            FROM ClinicalEncounter
            WHERE PatientId = :accountId AND Status = 'Diagnosis Approved'
            ORDER BY CreatedDate DESC
            LIMIT 5
        ];

        Set<Id> encounterIds = new Set<Id>();
        for (ClinicalEncounter ce : encounters) {
            encounterIds.add(ce.Id);
        }

        if (encounterIds.isEmpty()) {
            return new List<EncounterWrapper>();
        }

        Map<Id, List<Diagnosis__c>> encounterIdToDiagnosesMap = new Map<Id, List<Diagnosis__c>>();
        List<Diagnosis__c> diagnoses = [
            SELECT Id, Name, Clinical_Diagnosis__c, Diagnosis_Description__c, Severity__c, Patient__c,
                   Clinical_Encounter__c
            FROM Diagnosis__c
            WHERE Clinical_Encounter__c IN :encounterIds
        ];

        for (Diagnosis__c diag : diagnoses) {
            if (diag.Clinical_Encounter__c != null) {
                if (!encounterIdToDiagnosesMap.containsKey(diag.Clinical_Encounter__c)) {
                    encounterIdToDiagnosesMap.put(diag.Clinical_Encounter__c, new List<Diagnosis__c>());
                }
                encounterIdToDiagnosesMap.get(diag.Clinical_Encounter__c).add(diag);
            }
        }

        List<EncounterWrapper> results = new List<EncounterWrapper>();
        for (ClinicalEncounter ce : encounters) {
            EncounterWrapper wrap = new EncounterWrapper();
            wrap.encounter = ce;
            wrap.diagnoses = encounterIdToDiagnosesMap.get(ce.Id) != null ? encounterIdToDiagnosesMap.get(ce.Id) : new List<Diagnosis__c>();
            wrap.patientName = ce.Patient != null ? ce.Patient.Name : null;
            wrap.patientAge = ce.Patient != null ? (Integer)ce.Patient.Age__c : null; // <--- Add patientAge here
            results.add(wrap);
        }

        return results;
    }
    
   @AuraEnabled
public static Id createReferral(
    String referralId,
    Id patientId,
    //Id referredById,
    Id referredToId,
    String referralSummary,
    String primarySpecialty,
    String secondarySpecialty,
    List<selectedEncounterWrapper> encounterWrap,
    String recommendedVisitBy,
    String referralPriority,
    String chiefComplaints,
    String preliminaryDiagnosis,
    String saveAsDraft, 
    String consentMode,
    String manualConsentReason,
    String referralSummaryByAI
) {
    Referral__c newReferral;
    try {
        // Check if updating existing referral or creating new
        if (String.isNotBlank(referralId)) {
            newReferral = [SELECT Id FROM Referral__c WHERE Id = :referralId LIMIT 1];
        } else {
            newReferral = new Referral__c();
            newReferral.Patient__c = patientId;
            newReferral.Referral_Date__c = Date.today();
            newReferral.Referral_Summary2__c = referralSummaryByAI;
            
            //chanhes
            //// 🔥 AUTO POPULATE CONTACT FROM LATEST ENCOUNTER DOCTOR
        if (encounterWrap != null && !encounterWrap.isEmpty()) {
        
            // First encounter = latest (already sorted from LWC)
            selectedEncounterWrapper latestEnc = encounterWrap[0];
        
            if (latestEnc.prescribingDoctorId != null) {
        
                Account doctorAcc = [
                    SELECT PersonContactId
                    FROM Account
                    WHERE Id = :latestEnc.prescribingDoctorId
                    LIMIT 1
                ];
        
                if (doctorAcc.PersonContactId != null) {
                    newReferral.Referred_By__c = doctorAcc.PersonContactId;
                }
            }
        }           
            
        }
        
        newReferral.Referred_To__c = referredToId;
        newReferral.Referral_Summary__c = referralSummary;
        
        if (String.isNotBlank(primarySpecialty)) {
            newReferral.PrimarySpecialty__c = primarySpecialty;
        }
        if (String.isNotBlank(secondarySpecialty)) {
            newReferral.SecondarySpecialty__c = secondarySpecialty;
        }
        if (String.isNotBlank(chiefComplaints)) {
            newReferral.Chief_Complaints_and_Presenting_Symptoms__c = chiefComplaints;
        }
        if (String.isNotBlank(preliminaryDiagnosis)) {
            newReferral.Preliminary_Diagnosis__c = preliminaryDiagnosis;
        }
        
        // Handle draft status
        if (saveAsDraft == 'true') {
            newReferral.Referral_Status__c = 'Draft';
            newReferral.Consent_Status__c = 'Not Requested';
        }
        
        // Only set encounter on new referrals
        if (String.isBlank(referralId)) {
            String clinicalEncounter = '';
            for (selectedEncounterWrapper eachEncounter : encounterWrap) {
                if (String.isNotBlank(clinicalEncounter)) {
                    clinicalEncounter += ',' + eachEncounter.encounterName;
                } else {
                    clinicalEncounter = eachEncounter.encounterName;
                }
            }
            newReferral.Encounter__c = clinicalEncounter;
        }
        
        if (String.isNotBlank(consentMode)) {
            if (consentMode == 'Manual') {
                newReferral.Consent_Mode__c = 'Manual';
                newReferral.Reason_for_Manual_Consent__c = manualConsentReason;
                newReferral.Consent_Status__c = 'Granted';
                newReferral.Referral_Status__c = 'Referral Summarized';
                newReferral.Consent_Granted_By__c = UserInfo.getUserId();

            } else if (consentMode == 'Digital') {  
                newReferral.Consent_Mode__c = 'Digital';
                newReferral.Referral_Status__c = 'Referral Summarized';  
                newReferral.Consent_Status__c = 'Pending';
            }
        }
        
        // newReferral.Referred_By__c = referredById;
        
        if (String.isNotBlank(recommendedVisitBy)) {
            try {
                newReferral.Recommended_Visit_By__c = Date.valueOf(recommendedVisitBy);
            } catch (Exception e) {
                System.debug('Error parsing date: ' + recommendedVisitBy + ' - ' + e.getMessage()+ + e.getLineNumber());
                throw new AuraHandledException('Invalid date format for Recommended Visit By: ' + recommendedVisitBy);
            }
        }
        
        if (String.isNotBlank(referralPriority)) {
            newReferral.Referral_Priority__c = referralPriority;
        }
        
        upsert newReferral;
        // 🔥 UPDATE CONSULTATION STATUS
if (encounterWrap != null && !encounterWrap.isEmpty()) {

    selectedEncounterWrapper latestEnc = encounterWrap[0];

    if (latestEnc.encounterId != null) {

        ClinicalEncounter cons = new ClinicalEncounter(
            Id = latestEnc.encounterId,
            Status = 'Referred'   
        );

        update cons;
    }
}

return newReferral.Id;
        //System.debug('new Referral created');
       //return newReferral.Id;
        
    } catch (Exception e) {
        System.debug('Error in createReferral: ' + e.getMessage() + ' at line: ' + e.getLineNumber());
        throw new AuraHandledException('Error creating/updating referral: ' + e.getMessage());
    }
    
}
    
    @AuraEnabled
public static String generateAndAttachPDF(
    Id referralId,
    Id patientId,
    String timelineDataJSON,
    String medicationsJSON,
    String testReportsJSON
) {
    try {
        // Fetch all required data from database
        ReferralPDFData pdfData = getReferralPDFData(referralId, patientId);
        
        String timelineDataHTML = generateTimelineHTML(timelineDataJSON);
        String activeMedicationsHTML = generateActiveMedicationsHTML(medicationsJSON);
        String pastMedicationsHTML = generatePastMedicationsHTML(medicationsJSON);
        String testReportsHTML = generateTestReportsHTML(testReportsJSON);
     
        PageReference pdfPage = Page.ReferralCaseFilePDF;
        pdfPage.getParameters().put('referralId', String.valueOf(referralId));
        pdfPage.getParameters().put('patientId', String.valueOf(patientId));
        pdfPage.getParameters().put('timelineDataHTML', timelineDataHTML);
        pdfPage.getParameters().put('activeMedicationsHTML', activeMedicationsHTML);
        pdfPage.getParameters().put('pastMedicationsHTML', pastMedicationsHTML);
        pdfPage.getParameters().put('testReportsHTML', testReportsHTML);

        Blob pdfBlob;
        if(Test.isRunningTest()) {
            pdfBlob = Blob.valueOf('Test PDF Content');
        } else {
            pdfBlob = pdfPage.getContentAsPDF();
        }

		Account patient = [
                SELECT Id, Name
                FROM Account 
                WHERE Id = :patientId 
                LIMIT 1
            ];

        Attachment pdfAttachment = new Attachment(
            ParentId = referralId,
            Name = 'Referral_Summary_' + patient.Name + '_' + System.now().format('dd-MMM-yyyy')  + '.pdf',
            Body = pdfBlob,
            ContentType = 'application/pdf'
        );
        insert pdfAttachment;

        String reasonText = '';
        if (String.isNotBlank(pdfData.reasonForReferral)) {
            System.debug('Reason for reefrral' + pdfData.reasonForReferral.length());
            reasonText = pdfData.reasonForReferral.length() > 100 ? 
                         pdfData.reasonForReferral.left(100) + '...' : 
                         pdfData.reasonForReferral;
        } else {
            reasonText = 'Not specified';
        }

        String noteContent = 'Referral created for ' + pdfData.patientName + '\n\n' +
                         'Reason: ' + reasonText + '\n\n' +
                         'PDF generated and attached';
        ContentNote note = new ContentNote(
            Title = 'Referral Note - ' + Datetime.now().format('MM/dd/yyyy'),
            Content = Blob.valueOf(noteContent)
        );
        insert note;

        ContentDocumentLink link = new ContentDocumentLink(
            ContentDocumentId = note.Id,
            LinkedEntityId = referralId,
            ShareType = 'V'
        );
        insert link;

      Referral__c referral = [
                    SELECT Id,
                           Name,
                           Consent_Status__c,
                           Consent_Mode__c,
                           Referral_Status__c,
                           Patient__r.PersonEmail,
                           Patient__r.Name
                    FROM Referral__c
                    WHERE Id = :referralId
                    LIMIT 1
                ];
                
                // CASE 1: Manual consent → send referral email immediately
                if (
                    referral.Consent_Mode__c == 'Manual' &&
                    referral.Consent_Status__c == 'Granted' &&
                    referral.Referral_Status__c == 'Referral Summarized'
                ) {
                    ReferralTriggerHelper.sendReferralEmail(
                        new List<Id>{ referral.Id }
                    );
                }

            // CASE 2: Digital consent initiated → send patient consent email
            if (
                referral.Consent_Mode__c == 'Digital' &&
                referral.Consent_Status__c == 'Pending' &&
                String.isNotBlank(referral.Patient__r.PersonEmail)
            ) {
                sendPatientConsentEmail(
                    referral.Patient__r.PersonEmail,
                    referral.Patient__r.Name,
                    referral.Name
                );
            }

			
        //sendReferralEmail(referralId);
        return 'Success';

    } catch (Exception e) {
        throw new AuraHandledException('PDF generation failed: ' + e.getMessage() +
                                       '\nJSON for timeline: "' + timelineDataJSON +
                                       '"\nJSON for medications: "' + medicationsJSON +
                                       '"\nJSON for test reports: "' + testReportsJSON + '"');
    }
}

    public static void sendPatientConsentEmail(
        String patientEmail,
        String patientName,
        String ReferralId
    ) {
        String referralName = referralId != null ? referralId.trim() : null;

        Referral__c ref = [SELECT Id FROM Referral__c WHERE Name = :referralName LIMIT 1];
        String consentLink =
            'https://cr1769668480593.my.site.com/PatientConsent/s/?referralId='
            + referralId;
    
        String subject = 'Consent required to share your medical records';
    
        DateTime expiryDateTime = System.now().addDays(28);
String formattedExpiryDate = expiryDateTime.format('dd-MMM-yyyy hh:mm a');

String body =
    'Dear ' + patientName + ',\n\n' +
    'You have been referred by PHWC Chamoli ' +
    'to a higher healthcare facility for further care.\n\n' +
    'To securely share your medical records with the receiving hospital, ' +
    'your consent is required.\n\n' +
    'Please click the link below to provide or deny consent:\n' +
    consentLink + '\n\n' +
    'This link will remain active until: ' + formattedExpiryDate + '\n' +
    'During this period, you may also withdraw your consent at any time ' +
    'using the same link.\n\n' +
    '---\n\n' +
    'प्रिय ' + patientName + ',\n\n' +
    'आपको आपके प्राथमिक स्वास्थ्य एवं कल्याण केंद्र द्वारा ' +
    'आगे के इलाज के लिए एक उच्च चिकित्सा संस्थान में रेफर किया गया है।\n\n' +
    'आपकी चिकित्सा जानकारी को सुरक्षित रूप से साझा करने के लिए ' +
    'आपकी सहमति आवश्यक है।\n\n' +
    'कृपया सहमति देने या अस्वीकार करने के लिए नीचे दिए गए लिंक पर क्लिक करें:\n' +
    consentLink + '\n\n' +
    'यह लिंक इस तिथि तक सक्रिय रहेगा: ' + formattedExpiryDate + '\n' +
    'इस अवधि के दौरान आप इसी लिंक का उपयोग करके ' +
    'कभी भी अपनी सहमति वापस ले सकते हैं।\n\n' +
    'यह एक सिस्टम-जनरेटेड संदेश है। कृपया इस ईमेल का उत्तर न दें।\n\n' +
    'Regards,\nPHWC Team';
    
        Messaging.SingleEmailMessage mail =
            new Messaging.SingleEmailMessage();
        mail.setToAddresses(new String[] { patientEmail });
        mail.setSubject(subject);
        mail.setPlainTextBody(body);
    
        Messaging.sendEmail(
            new Messaging.SingleEmailMessage[] { mail }
        );

        Referral__c refToUpdate = new Referral__c(
        Id = ref.Id,
        Consent_Timestamp__c = System.now()
    );
    update refToUpdate;
    }


// New method to fetch all PDF data
    @AuraEnabled(cacheable=true)
    public static ReferralPDFData getReferralPDFData(Id referralId, Id patientId) {
        try {
            ReferralPDFData pdfData = new ReferralPDFData();
            
            // Fetch Referral data
            Referral__c referral = [
                SELECT Id, Name, Referral_Summary__c, Referral_Summary2__c, Referral_Priority__c, Referral_Date__c,
                       Chief_Complaints_and_Presenting_Symptoms__c, Preliminary_diagnosis__c,
                       PrimarySpecialty__c, SecondarySpecialty__c, Recommended_Visit_By__c
                FROM Referral__c 
                WHERE Id = :referralId 
                LIMIT 1
            ];
            
            // Fetch Patient data
            Account patient = [
                SELECT Id, Name, Phone, Age__c, Gender__c, PM_JAY_ID__c,
                       Attendant_Phone__c, AADHAR_Number_Original__c, Attendant_Name__c
                FROM Account
                WHERE Id = :patientId
                LIMIT 1
            ];
            
            // Fetch latest Clinical Encounter data
            List<ClinicalEncounter> encounters = [
                SELECT Id, Name, StartDate, Facility.Name,
                       Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone,
                       (SELECT Id, Clinical_Diagnosis__c, Diagnosis_Description__c
                        FROM Diagnoses__r)
                FROM ClinicalEncounter
                WHERE PatientId = :patientId
                ORDER BY StartDate DESC
                LIMIT 1
            ];
            
            // Populate referral data
            pdfData.refName = referral.Name;
            pdfData.reasonForReferral = referral.Referral_Summary__c;
            pdfData.referralPriority = referral.Referral_Priority__c;
            pdfData.careSummary = referral.Chief_Complaints_and_Presenting_Symptoms__c;
            pdfData.latestDiagnosis = referral.Preliminary_diagnosis__c;
            pdfData.referredPrimarySpecialty = referral.PrimarySpecialty__c;
            pdfData.referredSecondarySpecialty = referral.SecondarySpecialty__c;
            pdfData.referralSummary = referral.Referral_Summary2__c;
            
            // Populate patient data
            pdfData.patientName = patient.Name;
            pdfData.mob = patient.Phone;
            pdfData.age = Integer.valueOf(patient.Age__c != null ? patient.Age__c : 0);
            pdfData.gender = patient.Gender__c;
            pdfData.pmjayId = patient.PM_JAY_ID__c;
            pdfData.attendantName = patient.Attendant_Name__c;
            pdfData.attendantPhone = patient.Attendant_Phone__c;
            pdfData.aadharNumber = formatAadharNumber(patient.AADHAR_Number_Original__c);
    
             String indianDateFormat = '';
            if (referral.Recommended_Visit_By__c != null) {
                DateTime dt = DateTime.newInstance(referral.Recommended_Visit_By__c, Time.newInstance(0, 0, 0, 0));
                indianDateFormat = dt.format('dd-MMM-yyyy'); 
            }
            pdfData.recommendedVisitBy = indianDateFormat; 
            
            String referDate = '';
            if (referral.Referral_Date__c != null) {
                DateTime dt = DateTime.newInstance(referral.Referral_Date__c, Time.newInstance(0, 0, 0, 0));
                referDate = dt.format('dd-MMM-yyyy'); 
            }
            pdfData.referralDate = referDate; 
      
            // Populate encounter data
            if (!encounters.isEmpty()) {
                ClinicalEncounter latestEncounter = encounters[0];
                pdfData.referringPHWC = latestEncounter.Facility.Name;
                pdfData.referringDoctor = latestEncounter.Prescribing_Doctor__r.Name;
                pdfData.doctorsPhone = latestEncounter.Prescribing_Doctor__r.Phone;
            }
            
            return pdfData;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching PDF data: ' + e.getMessage());
        }
    }

// Helper method for formatting Aadhar number
    private static String formatAadharNumber(String aadharNumber) {
        if (String.isBlank(aadharNumber)) {
            return 'N/A';
        }
        if (aadharNumber.length() >= 3) {
            System.debug('adharnumber' + aadharNumber.length() );
            return '*********' + aadharNumber.substring(aadharNumber.length() - 3);
        }
        return aadharNumber;
    }

// Wrapper class for PDF data
public class ReferralPDFData {
    @AuraEnabled public String refName;
    @AuraEnabled public String patientName;
    @AuraEnabled public String mob;
    @AuraEnabled public Integer age;
    @AuraEnabled public String gender;
    @AuraEnabled public String pmjayId;
    @AuraEnabled public String aadharNumber;
    @AuraEnabled public String attendantName;
    @AuraEnabled public String attendantPhone;
    @AuraEnabled public String referringDoctor;
    @AuraEnabled public String referringPHWC;
    @AuraEnabled public String doctorsPhone;
    @AuraEnabled public String referredPrimarySpecialty;
    @AuraEnabled public String referredSecondarySpecialty;
    @AuraEnabled public String referralPriority;
    @AuraEnabled public String reasonForReferral;
    @AuraEnabled public String careSummary;
    @AuraEnabled public String latestDiagnosis;
    @AuraEnabled public String recommendedVisitBy;
	@AuraEnabled public String referralDate;
    @AuraEnabled public String referralSummary;
}


    @future(callout=true)
    public static void sendReferralEmail(Id referralId)
    {
		Referral__c ref = [Select Id, Referred_To__c, Primary_Specialty__c, Secondary_Specialty__c, Referred_To__r.name, Primary_Specialty__r.name, Referred_By__r.name, Referred_By__r.Phone, Referred_By__r.Email, Referred_To__r.Nodal_Person_Email_Address__c, Patient__r.Name, Patient__r.Age__c, Patient__r.Gender__c, Patient__r.Phone // Updated to Patient__r and added Patient__r.Age__c
                               from Referral__c where Id =:referralId];

            Map<Id,referral__c> refferalMap = new Map<Id,referral__c>();
            refferalMap.put(referralId,ref);
            //ReferralTriggerHelper.sendEmail(refferalMap);
    }

    private static String generateTimelineHTML(String timelineDataJSON) {
        List<Map<String, Object>> timelineData = new List<Map<String, Object>>();
        if (String.isNotBlank(timelineDataJSON) && timelineDataJSON.trim().startsWith('[')) {
            List<Object> rawTimelineData = (List<Object>) JSON.deserializeUntyped(timelineDataJSON);
            for (Object obj : rawTimelineData) {
                if (obj instanceof Map<String, Object>) {
                    timelineData.add((Map<String, Object>) obj);
                }
            }
        }

        if (timelineData.isEmpty()) {
            return '<p>No timeline data available.</p>';
        }

        String html = '<table class="slds-table"><thead><tr><th>Date</th><th>Doctor/PHWC</th><th>Chief Complaints</th><th>Diagnosis</th></tr></thead><tbody>';
        for (Map<String, Object> row : timelineData) {
            html += '<tr>';
            html += '<td>' + (row.containsKey('date') && row.get('date') != null ? String.valueOf(row.get('date')) : '') + '</td>';
            html += '<td>' + (row.containsKey('doctorFacility') && row.get('doctorFacility') != null ? String.valueOf(row.get('doctorFacility')) : '') + '</td>';
            html += '<td>' + (row.containsKey('symptoms') && row.get('symptoms') != null ? String.valueOf(row.get('symptoms')) : '') + '</td>';
            html += '<td>' + (row.containsKey('diagnosis') && row.get('diagnosis') != null ? String.valueOf(row.get('diagnosis')) : '') + '</td>';
            html += '</tr>';
        }
        html += '</tbody></table>';
        return html;
    }

   private static String generateActiveMedicationsHTML(String medicationsJSON) {
    List<Map<String, Object>> activeMeds = new List<Map<String, Object>>();
    if (String.isNotBlank(medicationsJSON) && medicationsJSON.trim().startsWith('{')) {
        Object deserializedObject = JSON.deserializeUntyped(medicationsJSON);
        if (deserializedObject instanceof Map<String, Object>) {
            Map<String, Object> medications = (Map<String, Object>) deserializedObject;
            List<Object> rawActiveMeds = medications.containsKey('active') && medications.get('active') instanceof List<Object> ?
                                                 (List<Object>) medications.get('active') : new List<Object>();
            for (Object obj : rawActiveMeds) {
                if (obj instanceof Map<String, Object>) {
                    activeMeds.add((Map<String, Object>) obj);
                }
            }
        }
    }

    if (activeMeds.isEmpty()) {
        return '<p>No active medications available.</p>';
    }

    String html = '<table class="slds-table"><thead><tr><th>Medication</th><th>Frequency</th><th>Started On</th></tr></thead><tbody>';
    for (Map<String, Object> row : activeMeds) {
        html += '<tr>';
        html += '<td>' + (row.containsKey('name') && row.get('name') != null ? String.valueOf(row.get('name')) : '') + '</td>';
        html += '<td>' + (row.containsKey('frequency') && row.get('frequency') != null ? String.valueOf(row.get('frequency')) : '') + '</td>';
        html += '<td>' + (row.containsKey('formattedStartDate') && row.get('formattedStartDate') != null ? String.valueOf(row.get('formattedStartDate')) : '') + '</td>';
        html += '</tr>';
    }
    html += '</tbody></table>';
    return html;
}

private static String generatePastMedicationsHTML(String medicationsJSON) {
    List<Map<String, Object>> pastMeds = new List<Map<String, Object>>();
    if (String.isNotBlank(medicationsJSON) && medicationsJSON.trim().startsWith('{')) {
        Object deserializedObject = JSON.deserializeUntyped(medicationsJSON);
        if (deserializedObject instanceof Map<String, Object>) {
            Map<String, Object> medications = (Map<String, Object>) deserializedObject;
            List<Object> rawPastMeds = medications.containsKey('past') && medications.get('past') instanceof List<Object> ?
                                           (List<Object>) medications.get('past') : new List<Object>();
            for (Object obj : rawPastMeds) {
                if (obj instanceof Map<String, Object>) {
                    pastMeds.add((Map<String, Object>) obj);
                }
            }
        }
    }

    if (pastMeds.isEmpty()) {
        return '<p>No past medications available.</p>';
    }

    String html = '<table class="slds-table"><thead><tr><th>Medication</th><th>Frequency</th><th>Until</th></tr></thead><tbody>';
    for (Map<String, Object> row : pastMeds) {
        html += '<tr>';
        html += '<td>' + (row.containsKey('name') && row.get('name') != null ? String.valueOf(row.get('name')) : '') + '</td>';
        html += '<td>' + (row.containsKey('frequency') && row.get('frequency') != null ? String.valueOf(row.get('frequency')) : '') + '</td>';
        html += '<td>' + (row.containsKey('formattedEndDate') && row.get('formattedEndDate') != null ? String.valueOf(row.get('formattedEndDate')) : '') + '</td>';
        html += '</tr>';
    }
    html += '</tbody></table>';
    return html;
}

private static String generateTestReportsHTML(String testReportsJSON) {
    List<Map<String, Object>> testReports = new List<Map<String, Object>>();
    if (String.isNotBlank(testReportsJSON) && testReportsJSON.trim().startsWith('[')) {
        List<Object> rawTestReports = (List<Object>) JSON.deserializeUntyped(testReportsJSON);
        for (Object obj : rawTestReports) {
            if (obj instanceof Map<String, Object>) {
                testReports.add((Map<String, Object>) obj);
            }
        }
    }

    if (testReports.isEmpty()) {
        return '<p>No test reports available.</p>';
    }

    String html = '<table class="slds-table"><thead><tr><th>Test Name</th></tr></thead><tbody>';
    for (Map<String, Object> row : testReports) {
        html += '<tr>';
        html += '<td>' + (row.containsKey('testName') && row.get('testName') != null ? String.valueOf(row.get('testName')) : '') + 
                (row.containsKey('testDate') && row.get('testDate') != null ? ' (' + String.valueOf(row.get('testDate')) + ')' : '') + '</td>';
        html += '</tr>';
    }
    html += '</tbody></table>';
    return html;
}
    public class EncounterWrapper {
        @AuraEnabled public ClinicalEncounter encounter;
        @AuraEnabled public List<Diagnosis__c> diagnoses;
        @AuraEnabled public String patientName { get; set; }
        @AuraEnabled public Integer patientAge { get; set; } // <--- Add patientAge to wrapper
    }

    public class selectedEncounterWrapper
    {
        @AuraEnabled
        public string encounterId {get;set;}
        @AuraEnabled
        public string encounterName {get;set;}
        @AuraEnabled
        public string diagnosis {get;set;}
        @AuraEnabled
        public string prescribingDoctorId {get;set;}
        @AuraEnabled
        public string prescribingDoctor {get;set;}
        @AuraEnabled
        public string encounterDate {get;set;}
        @AuraEnabled
        public string selected {get;set;}
    }

    @AuraEnabled
    public static Account getPatientDetails(Id patientId) {
        return [
        SELECT Name, Height_in_cm__c, Weight_in_Kg__c
        FROM Account
        WHERE Id = :patientId
        ];
    }

    @AuraEnabled
    public static Id createConsultation(
            Id patientId,
            String consultationType,
            String status,
            String category,
            String startDate,
            String symptoms,
            String vikriti,
            String additionalInfo,
            Decimal height,
            Decimal weight,
            Decimal pulse,
            Decimal temperature,
            Decimal spo2,
            String bloodPressure
        ) {
            ClinicalEncounter ce = new ClinicalEncounter();

            ce.PatientId = patientId;
            ce.Patient_Type__c = consultationType;
            ce.Status = status;
            ce.Category = category;
            ce.StartDate = DateTime.valueOf(startDate);
            ce.Symptoms__c = symptoms;
            ce.Vikriti__c = vikriti;
            ce.Additional_Information__c = additionalInfo;

            ce.Height_in_cm__c = height;
            ce.Weight_in_Kg__c = weight;
            ce.Pulse_Rate_in_BPM__c = pulse;
            ce.Body_Temperature__c = temperature;
            ce.SpO2__c = spo2;
            ce.Blood_Pressure__c = bloodPressure;

            insert ce;
            return ce.Id;
        }
}