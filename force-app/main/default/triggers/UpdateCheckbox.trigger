trigger UpdateCheckbox on HealthcareProvider (before insert, before update) {
    for (HealthcareProvider record : Trigger.new) {
        if (record.Open_All_Day__c == true) {
            record.Operating_Hours__c = 'Open All Day';
        }
    }
}