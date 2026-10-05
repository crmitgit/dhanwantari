public without sharing class ConsultationController {
    @AuraEnabled(cacheable=true)
    public static List<ClinicalEncounter> getConsultationsByStatus(List<String> statuses) {
        return [
            SELECT Id, Name, Patient.Name,
                (SELECT Id, Clinical_Diagnosis__c FROM Diagnoses__r)
            FROM ClinicalEncounter
            WHERE Status IN :statuses
            ORDER BY Name ASC
        ];
    }

    @AuraEnabled
    public static String updateClinicalEncounterOwner(Id clinicalEncounterId, Id newOwnerId) {
        try {
            // Accepting only assigns the doctor; the status stays 'Approval Pending'
            // until the doctor approves (then 'Diagnosis Approved').
            ClinicalEncounter ce = new ClinicalEncounter(
                Id = clinicalEncounterId,
                Owner__c = newOwnerId
            );
            update ce; // Perform the DML update
            return 'Success';
        } catch (DmlException e) {
            System.debug('Error updating Clinical Encounter owner: ' + e.getMessage());
            throw new AuraHandledException('Error updating record: ' + e.getMessage());
        }
    }
}