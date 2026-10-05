public with sharing class ClinicalServiceRequestController {
    @AuraEnabled
    public static void createRequest(
        string clinicalEncounterId,
        String patientName,
        String requestedById,
        String requestedTest,
        String status,
        String priority,
        String requestedCompletionDate,
        String completedOn,
        String referralEmail,
        String notes 
    ) {
        if (clinicalEncounterId == null) {
            throw new AuraHandledException('Clinical Encounter ID is required.');
        }

        // Query ClinicalEncounter to get Contact__c (Patient) and Prescribing_Doctor__c (Requested By)
        ClinicalEncounter encounter = [
            SELECT Id, Contact__c, Prescribing_Doctor__c,PatientId
            FROM ClinicalEncounter
            WHERE Id = :clinicalEncounterId
            LIMIT 1
        ];

        // if (encounter.Contact__c == null || encounter.Prescribing_Doctor__c == null) {
        //     throw new AuraHandledException('Clinical Encounter must have a Patient and a Prescribing Doctor.');
        // }

        ClinicalServiceRequest request = new ClinicalServiceRequest();
        request.EncounterId = clinicalEncounterId;
        request.PatientId = encounter.PatientId;
        request.Requested_By__c = encounter.Prescribing_Doctor__c;
        request.Requested_Test__c = requestedTest;
        request.Status = status;
        // request.Priority = priority;
        if(requestedCompletionDate != '' && requestedCompletionDate != null){
             request.Requested_Completion_Date__c = Date.valueOf(requestedCompletionDate);
        }

        if(completedOn != '' && completedOn != null){
             request.Completed_On__c = Date.valueOf(completedOn);
        }

        if (notes != null) {
         request.Notes__c = notes; // 👈 Assuming 'Notes__c' is a custom field on the object
            }

        request.Referral_Email__c = referralEmail;

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
}