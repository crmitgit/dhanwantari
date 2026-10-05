trigger ClinicalEncounterTrigger on ClinicalEncounter (after update) {
    
    List<Id> approvedEncounters = new List<Id>();
    
    for (ClinicalEncounter encounter : Trigger.new) {
        ClinicalEncounter oldEncounter = Trigger.oldMap.get(encounter.Id);
        
        
        if (encounter.Status == 'Approved' && 
            oldEncounter.Status != 'Approved') {
            
            approvedEncounters.add(encounter.Id);
        }
    }
    
    
    //if (!approvedEncounters.isEmpty()) {
       // QRCodeService.generateQRFromFlow(approvedEncounters);
    //}
}