trigger DiagnosisTrigger on Diagnosis__c (after insert) {
    if (Trigger.isAfter && Trigger.isInsert) {
        DiagnosisController.updateEncounterStatusOnDiagnosis(Trigger.new);
    }
}