public with sharing class DiagnosisController {
    @AuraEnabled
    public static void createRequest(
        string clinicalEncounterId,
        String patientName,
        String clinicalDiagnosis,
        String severity,
        String diagnosisType
    ) {
        if (clinicalEncounterId == null) {
            throw new AuraHandledException('Clinical Encounter ID is required.');
        }

        // Query ClinicalEncounter to get Contact__c (Patient) and Prescribing_Doctor__c (Requested By)
        ClinicalEncounter encounter = [
            SELECT Id, Contact__c, Prescribing_Doctor__c,PatientId,Prescribing_Doctor__r.Name
            FROM ClinicalEncounter
            WHERE Id = :clinicalEncounterId
            LIMIT 1
        ];

        // if (encounter.Contact__c == null || encounter.Prescribing_Doctor__c == null) {
        //     throw new AuraHandledException('Clinical Encounter must have a Patient and a Prescribing Doctor.');
        // }

        Diagnosis__c request = new Diagnosis__c();
        request.Clinical_Encounter__c = clinicalEncounterId;
        request.Patient__c = encounter.PatientId;
        request.Clinical_Diagnosis__c = clinicalDiagnosis;
        request.Severity__c = severity;
        request.Diagnosis_Type__c = diagnosisType;
        
        insert request;
    }

    @AuraEnabled(cacheable=true)
	public static Map<String, String> getEncounterDetails(Id encounterId) {
    ClinicalEncounter encounter = [
        SELECT Id, Name, Contact__c, Contact__r.Name, Status, Patient.Name, Patient.Id
        FROM ClinicalEncounter
        WHERE Id = :encounterId
        LIMIT 1
    ];

    return new Map<String, String>{
        'EncounterName' => encounter.Name,
        'PatientId' => (encounter.Patient.Id != null ? String.valueOf(encounter.Patient.Id) : ''),
        'PatientName' => (encounter.Patient.Name != null ? encounter.Patient.Name : ''),
        'Status' => (encounter.Status != null ? encounter.Status : '')
    };
}
     public static void updateEncounterStatusOnDiagnosis(List<Diagnosis__c> newDiagnoses) {
        Set<Id> encounterIds = new Set<Id>();
        for (Diagnosis__c diag : newDiagnoses) {
            if (diag.Clinical_Encounter__c != null) {
                encounterIds.add(diag.Clinical_Encounter__c);
            }
        }

        if (encounterIds.isEmpty()) return;

        List<ClinicalEncounter> encountersToUpdate = [
            SELECT Id, Status
            FROM ClinicalEncounter
            WHERE Id IN :encounterIds AND Status = 'Started'
        ];

        for (ClinicalEncounter encounter : encountersToUpdate) {
            encounter.Status = 'Ongoing';
        }

        if (!encountersToUpdate.isEmpty()) {
            update encountersToUpdate;
        }
    }
}