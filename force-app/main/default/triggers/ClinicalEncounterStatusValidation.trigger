/**
* @description       : 
* @author            : Nitheesh
* @group             : 
* @last modified on  : 06-10-2025
* @last modified by  : Nitheesh
**/

trigger ClinicalEncounterStatusValidation on ClinicalEncounter (before update) {
    Set<Id> encountersToValidate = new Set<Id>();

    // Collect records whose status is changing to 'Complete'
    for (ClinicalEncounter ce : Trigger.new) {
        ClinicalEncounter oldCE = Trigger.oldMap.get(ce.Id);
        if (ce.Status == 'Completed' && oldCE.Status != 'Completed') {
            encountersToValidate.add(ce.Id);
        }
    }

    if (encountersToValidate.isEmpty()) {
        return; // Nothing to validate
    }

    // Query counts of related Diagnosis per ClinicalEncounter
    Map<Id, Integer> diagnosisCountMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT Clinical_Encounter__c Id, COUNT(Id) cnt
        FROM Diagnosis__c
        WHERE Clinical_Encounter__c IN :encountersToValidate
        GROUP BY Clinical_Encounter__c
    ]) {
        diagnosisCountMap.put((Id)ar.get('Id'), (Integer)ar.get('cnt'));
    }

    // Query counts of related MedicationRequest per ClinicalEncounter
    Map<Id, Integer> medicationRequestCountMap = new Map<Id, Integer>();
    for (AggregateResult ar : [
        SELECT ClinicalEncounterId Id, COUNT(Id) cnt
        FROM MedicationRequest
        WHERE ClinicalEncounterId IN :encountersToValidate
        GROUP BY ClinicalEncounterId
    ]) {
        medicationRequestCountMap.put((Id)ar.get('Id'), (Integer)ar.get('cnt'));
    }

    // For each ClinicalEncounter being validated, check counts and block if needed
    for (ClinicalEncounter ce : Trigger.new) {
        if (encountersToValidate.contains(ce.Id)) {
            Integer diagCount = diagnosisCountMap.containsKey(ce.Id) ? diagnosisCountMap.get(ce.Id) : 0;
            Integer medReqCount = medicationRequestCountMap.containsKey(ce.Id) ? medicationRequestCountMap.get(ce.Id) : 0;
 

            if (diagCount == 0 || medReqCount == 0) {
                ce.Status.addError(
                    'Status cannot be changed to Completed unless at least a related Diagnosis and Medication Request are present'
                );
            }
        }
    }
}