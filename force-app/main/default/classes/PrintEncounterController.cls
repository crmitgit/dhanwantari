public class PrintEncounterController {
    public Id encounterId { get; set; }
    public ClinicalEncounter encounter { get; private set; }
    public String signatureImageUrl { get; private set; }
    public String formattedAddress { get; private set; }
    public String formattedStartDate { get; private set; }
    public String formattedEndDate { get; private set; }
    public String formattedFollowUpDate { get; private set; }
    public List<MedicationWrapper> medicationWrappers { get; private set; }
    public List<Diagnosis__c> diagnoses { get; private set; }
    public List<ClinicalServiceRequest> clinicalServices { get; private set; }

    public PrintEncounterController() {
        encounterId = ApexPages.currentPage().getParameters().get('id');

        if (encounterId != null) {
            // Query Encounter & related fields
            encounter = [
                SELECT Name, StartDate, EndDate, Height_in_cm__c, Weight_in_Kg__c,
                       Pulse_Rate_in_BPM__c, Blood_Pressure__c, Body_Temperature__c,
                       SpO2__c, Symptoms__c, Clinical_Findings__c,
                       Medical_History__c, Contact__r.Name, Contact__r.Phone,Contact__r.Account.Patient_ID__c,
                       Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone,
                       Facility.Name, Facility.Location__Street__s,Contact__r.Account.Gender__c, Contact__r.Account.Age__c,
                       Facility.Location__City__s, Facility.Location__PostalCode__s, Patient.Name,
                       Follow_up_Date__c, Care_Instructions__c, Patient.Phone, Patient.Patient_ID__c, Patient.Age__c, Patient.Gender__c
                FROM ClinicalEncounter
                WHERE Id = :encounterId
                LIMIT 1
            ];

            // Build formatted address
            List<String> parts = new List<String>();
            if (encounter.Facility.Location__Street__s != null)
                parts.add(encounter.Facility.Location__Street__s);
            if (encounter.Facility.Location__City__s != null)
                parts.add(encounter.Facility.Location__City__s);
            if (encounter.Facility.Location__PostalCode__s != null)
                parts.add(encounter.Facility.Location__PostalCode__s);
            formattedAddress = String.join(parts, ', ');

    if (encounter.StartDate != null)
        formattedStartDate = encounter.StartDate.format('dd-MMM-yyyy');
    if (encounter.StartDate != null)
        formattedEndDate = encounter.StartDate.format('dd-MMM-yyyy');
    if (encounter.Follow_up_Date__c != null)
    formattedFollowUpDate = formatDate(encounter.Follow_up_Date__c); // Add this line

            // Load signature image if available
            loadSignatureImage();

            // Medications
            List<MedicationRequest> meds = [
                SELECT Duration_Days__c, Prescription_Start_Date__c,
                       Medication.Name, Morning__c, Afternoon__c,
                       Night__c, BF_AF__c
                FROM MedicationRequest
                WHERE ClinicalEncounterId = :encounterId
            ];
            medicationWrappers = new List<MedicationWrapper>();
            for (MedicationRequest m : meds)
                medicationWrappers.add(new MedicationWrapper(m));

            // Diagnoses
            diagnoses = [
                SELECT Clinical_Diagnosis__c, Diagnosis_Type__c
                FROM Diagnosis__c
                WHERE Clinical_Encounter__c = :encounterId
            ];

            // Clinical services
            clinicalServices = [
                SELECT Requested_Test__c, Requested_Completion_Date__c,Status
                FROM ClinicalServiceRequest
                WHERE EncounterId = :encounterId
            ];
        }
    }

    // Helper to format date or return blank
    private String formatDate(Date dt) {
    if (dt == null) return '';
    // Convert Date to DateTime (midnight) for formatting
    DateTime dtTime = DateTime.newInstance(dt.year(), dt.month(), dt.day(), 0, 0, 0);
    return dtTime.format('dd-MMM-yyyy'); // e.g., 22-Jun-2025
}

    // Load signature from Attachment or Files
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

    // Wrappers and getters
    public String getPatientName() {
        return encounter?.Patient.Name;
    }
    public String getDoctorName() {
        return encounter?.Prescribing_Doctor__r?.Name;
    }
    public List<String> getCareInstructionsList() {
        if (String.isBlank(encounter.Care_Instructions__c)) return new List<String>();
        List<String> lines = encounter.Care_Instructions__c.split('\n');
        List<String> results = new List<String>();
        for (String line : lines) {
            line = line.trim();
            if (line != '') results.add('- ' + line);
        }
        return results;
    }

    // Medication wrapper class
    public class MedicationWrapper {
        public MedicationRequest med { get; set; }
        public String dosage { get; set; }
        public MedicationWrapper(MedicationRequest m) {
            this.med = m;
            List<String> doses = new List<String>();
            if (!String.isBlank(m.Morning__c)) doses.add('Morning: ' + m.Morning__c);
            if (!String.isBlank(m.Afternoon__c)) doses.add('Afternoon: ' + m.Afternoon__c);
            if (!String.isBlank(m.Night__c)) doses.add('Night: ' + m.Night__c);
            String d = String.join(doses, ', ');
            if (!String.isBlank(m.BF_AF__c)) d += ' (' + m.BF_AF__c + ')';
            dosage = d;
        }
    }
}