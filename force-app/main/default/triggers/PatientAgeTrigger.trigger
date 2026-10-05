trigger PatientAgeTrigger on Account (before insert, before update) {
    for (Account acc : Trigger.new) {
        if (acc.IsPersonAccount) {
            Date dob = acc.Birth_Date__c;
            if (dob != null) {
                Integer age = dob.daysBetween(Date.today()) / 365;
                acc.Age__c = age;
            } else {
                acc.Age__c = null;
            }
        }
    }
}