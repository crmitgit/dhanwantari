public with sharing class MedicationController {
    
    public class MedicationWrapper {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String dosage { get; set; }
        @AuraEnabled public String frequency { get; set; }
        @AuraEnabled public Date startDate { get; set; }
        @AuraEnabled public Date endDate { get; set; }
        @AuraEnabled public Boolean isActive { get; set; }

        @AuraEnabled public String formattedStartDate { get; set; }
        @AuraEnabled public String formattedEndDate { get; set; } 
        
        public MedicationWrapper(Id medicationId, String medicationName, String dosageStrength, 
                               String freq, Date prescriptionStartDate, Date calculatedEndDate, Boolean active) {
            this.id = medicationId;
            this.name = medicationName;
            this.dosage = dosageStrength;
            this.frequency = freq;
            this.startDate = prescriptionStartDate;
            this.endDate = calculatedEndDate;
            this.isActive = active;
            
            // Format dates using helper method
            this.formattedStartDate = formatDate(prescriptionStartDate);
            this.formattedEndDate = formatDate(calculatedEndDate);
        }
    }
    
    public class MedicationResponse {
        @AuraEnabled public List<MedicationWrapper> activeMedications { get; set; }
        @AuraEnabled public List<MedicationWrapper> pastMedications { get; set; }
        
        public MedicationResponse() {
            this.activeMedications = new List<MedicationWrapper>();
            this.pastMedications = new List<MedicationWrapper>();
        }
    }
    
    // Helper method to format Date to desired string
    private static String formatDate(Date dateValue) {
        if (dateValue == null) return '';
        
        // Convert Date to DateTime for formatting
        DateTime dt = DateTime.newInstance(dateValue, Time.newInstance(0, 0, 0, 0));
        return dt.format('dd-MMM-yyyy');
    }
    
    @AuraEnabled(cacheable=true)
    public static MedicationResponse getMedicationData(String patientId) {
        try {
            MedicationResponse response = new MedicationResponse();
            Date today = Date.today();
            
            
            List<SObject> medications = Database.query(
                'SELECT Id, Medication.Name, Dosage_Strength__c, Morning__c, Afternoon__c, Night__c, ' +
                'To_be_taken_in_morning__c, To_be_taken_in_afternoon__c, To_be_taken_in_night__c, ' +
                'Prescription_Start_Date__c, Duration_Days__c ' +
                'FROM MedicationRequest ' +
                'WHERE PatientId = :patientId ' +
                'ORDER BY Prescription_Start_Date__c DESC'
            );
            
            for (SObject med : medications) {
                // Extract field values
                String medicationName = '';
                if (med.getSObject('Medication') != null) {
                    medicationName = (String) med.getSObject('Medication').get('Name');
                }
                
                String dosageStrength = (String) med.get('Dosage_Strength__c');
                Date startDate = (Date) med.get('Prescription_Start_Date__c');
                Decimal durationDays = (Decimal) med.get('Duration_Days__c');
                String morning = (String) med.get('Morning__c');
                String afternoon = (String) med.get('Afternoon__c');
                String night = (String) med.get('Night__c');
                Boolean takeMorning = (Boolean) med.get('To_be_taken_in_morning__c');
                Boolean takeAfternoon = (Boolean) med.get('To_be_taken_in_afternoon__c');
                Boolean takeNight = (Boolean) med.get('To_be_taken_in_night__c');

                // Prescription form saves the To_be_taken_in_* checkboxes; older records use the
                // Morning/Afternoon/Night dosage picklists. Count a slot if either is set.
                String frequency = calculateFrequency(
                    isSlotSet(takeMorning, morning),
                    isSlotSet(takeAfternoon, afternoon),
                    isSlotSet(takeNight, night)
                );
                
                // Calculate end date
                Date endDate = null;
                Boolean isActive = false;
                
                if (startDate != null && durationDays != null) {
                    endDate = startDate.addDays(durationDays.intValue());
                    isActive = endDate >= today;
                }
                
                // Create medication wrapper
                MedicationWrapper medWrapper = new MedicationWrapper(
                    med.Id, 
                    medicationName, 
                    dosageStrength, 
                    frequency, 
                    startDate, 
                    endDate, 
                    isActive
                );
                
                // Add to appropriate list
                if (isActive) {
                    response.activeMedications.add(medWrapper);
                } else {
                    response.pastMedications.add(medWrapper);
                }
            }
            
            return response;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching medication data: ' + e.getMessage());
        }
    }
    
    private static Boolean isSlotSet(Boolean checkbox, String dosage) {
        return checkbox == true || (String.isNotBlank(dosage) && dosage != '0');
    }

    private static String calculateFrequency(Boolean morning, Boolean afternoon, Boolean night) {
        Integer count = 0;

        if (morning) count++;
        if (afternoon) count++;
        if (night) count++;
        
        switch on count {
            when 1 {
                return 'Once daily';
            }
            when 2 {
                return 'Twice daily';
            }
            when 3 {
                return 'Thrice daily';
            }
            when else {
                return 'As needed';
            }
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<TestReportWrapper> getTestReportsSummary(String patientId) {
        List<TestReportWrapper> testReports = new List<TestReportWrapper>();
        
        try {
            List<DiagnosticSummary> diagnosticSummaries = [
                SELECT Id, Sample_Type__c, Sample_Drawn_Date__c, Status, Summary
                FROM DiagnosticSummary 
                WHERE PatientId = :patientId
                ORDER BY Sample_Drawn_Date__c DESC
            ];
            
            for (DiagnosticSummary diagnostic : diagnosticSummaries) {
                TestReportWrapper wrapper = new TestReportWrapper();
                wrapper.id = diagnostic.Id;
                wrapper.testName = diagnostic.Sample_Type__c;
                // Fix: Use the same helper method for formatting dates
                wrapper.testDate = formatDate(diagnostic.Sample_Drawn_Date__c);
                wrapper.status = diagnostic.Status;
                wrapper.keyFindings = diagnostic.Summary;
                testReports.add(wrapper);
            }
            
        } catch (Exception e) {
            System.debug('Error fetching test reports: ' + e.getMessage());
            throw new AuraHandledException('Unable to fetch test reports: ' + e.getMessage());
        }
        
        return testReports;
    }
    
    //CHANGES BY KRATI
    
    @AuraEnabled(cacheable=true)
    public static String getMedicationType(Id consultationId){
        List<MedicationRequest> meds = [
            SELECT Medicine_Type__c
            FROM MedicationRequest
            WHERE ClinicalEncounterId = :consultationId
            LIMIT 1
        ];

        // No medications on the consultation yet → no type, don't block
        return meds.isEmpty() ? null : meds[0].Medicine_Type__c;
    }
    
    @AuraEnabled
    public static String validateMedicationType(
        Id clinicalEncounterId,
        List<Id> selectedMedicationIds
    ){
        
        System.debug('VALIDATION CALLED');
        System.debug('Encounter Id: ' + clinicalEncounterId);
        System.debug('Selected Meds: ' + selectedMedicationIds);
    
        // STEP 1 — Existing Medication Requests on this encounter
        List<MedicationRequest> existingRequests = [
            SELECT Medication.RecordType.DeveloperName
            FROM MedicationRequest
            WHERE ClinicalEncounterId = :clinicalEncounterId
            AND MedicationId != NULL
            LIMIT 1
        ];
    
        // ✅ First prescription → allow
        if(existingRequests.isEmpty()){
            return 'VALID';
        }
    
        String consultationType =
            existingRequests[0].Medication.RecordType.DeveloperName;
    
        // STEP 2 — Fetch selected Medication record types
        List<Medication> selectedMeds = [
            SELECT RecordType.DeveloperName
            FROM Medication
            WHERE Id IN :selectedMedicationIds
        ];
    
        // STEP 3 — Compare
        for(Medication med : selectedMeds){
            if(med.RecordType.DeveloperName != consultationType){
                return consultationType; // mismatch
            }
        }
    
        return 'VALID';
    }

    public class TestReportWrapper {
        @AuraEnabled
        public String id { get; set; }
        
        @AuraEnabled
        public String testName { get; set; }
        
        // Changed to String to hold formatted date
        @AuraEnabled
        public String testDate { get; set; }
        
        @AuraEnabled
        public String status { get; set; }
        
        @AuraEnabled
        public String keyFindings { get; set; }
    }
}