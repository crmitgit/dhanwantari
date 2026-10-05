public with sharing class MedicationRequestController {

    @AuraEnabled
    public static void createMedicationRequest(
        String encounterId,
        String patientId,
        String medicationId,
        String instructions,
        String durationDays,
        String startFrom,
        Boolean morning,
        Boolean afternoon,
        Boolean night,
        String beforeAfterFood,
        String dosage
    ) {
        // Basic validations
        if (encounterId == null || patientId == null || medicationId == null) {
            throw new AuraHandledException('Encounter, Patient, and Medication are required.');
        }

        // Create and populate MedicationRequest
        MedicationRequest medRequest = new MedicationRequest();
        medRequest.ClinicalEncounterId = encounterId;
        medRequest.PatientId = patientId;
        medRequest.MedicationId = medicationId;
        medRequest.Instructions__c = instructions;
        if(durationDays != '' && durationDays != null){
            medRequest.Duration_Days__c = decimal.valueOf(durationDays);
        }
        if(startFrom != '' && startFrom != null){
            medRequest.Prescription_Start_Date__c = Date.valueOf(startFrom);
        }
        medRequest.To_be_taken_in_morning__c = morning;
        medRequest.To_be_taken_in_afternoon__c = afternoon;
        medRequest.To_be_taken_in_night__c = night;
        medRequest.BF_AF__c = beforeAfterFood;
        medRequest.Dosage_Strength__c = dosage;

        insert medRequest;
    }



    @AuraEnabled(cacheable=true)
    public static Map<String, String> getEncounterDetails(Id encounterId) {
        ClinicalEncounter encounter = [
            SELECT Id, Name, Contact__r.Name, Contact__c, PatientId, Patient.Name, Status
            FROM ClinicalEncounter
            WHERE Id = :encounterId
            LIMIT 1
        ];

        return new Map<String, String>{
            'EncounterName' => encounter.Name,
            'PatientId' => (encounter.PatientId != null ? String.valueOf(encounter.PatientId) : ''),
            'PatientName' => (encounter.PatientId != null ? encounter.Patient.Name : ''),
            'Status' => (encounter.Status != null ? encounter.Status : '')
        };
    }
    @AuraEnabled(cacheable=true)
    public static String getAISummary(Id clinicalEncounterId) {
        Encounter_Summary__c summary = [
            SELECT AI_Summary__c 
            FROM Encounter_Summary__c 
            WHERE Clinical_Encounter__c = :clinicalEncounterId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return summary.AI_Summary__c;
    }

}