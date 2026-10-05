public without sharing class AayushGuideController {

    @AuraEnabled
    public static String validateEncounter(Id clinicalEncounterId) {
        // Get Clinical Encounter and its related data
        ClinicalEncounter encounter = [
            SELECT Id,
                (SELECT Clinical_Diagnosis__c FROM Diagnoses__r)
            FROM ClinicalEncounter
            WHERE Id = :clinicalEncounterId
            LIMIT 1
        ];
        
        List<String> missing = new List<String>();

        if (encounter.Diagnoses__r.isEmpty()) {
            missing.add('Clinical Diagnosis');
        }

        // Return validation result
        return missing.isEmpty() ? 'VALID' : 'Missing: ' + String.join(missing, ', ');
    }

    @AuraEnabled(cacheable=true)
    public static String getAISummary(Id clinicalEncounterId) {
        Ayush_AI_Summary__c summary = [
            SELECT AI_Summary__c
            FROM Ayush_AI_Summary__c 
            WHERE Consultation__c = :clinicalEncounterId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return summary.AI_Summary__c;
    }
}