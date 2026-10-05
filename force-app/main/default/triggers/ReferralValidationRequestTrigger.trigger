trigger ReferralValidationRequestTrigger on Referral_Validation_Request__e (after insert) {
    Set<Id> referralIds = new Set<Id>();
    for (Referral_Validation_Request__e evt : Trigger.new) {
        try {
            referralIds.add((Id) evt.Referral_Id__c);
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'ReferralValidationRequestTrigger: bad referral id ' + evt.Referral_Id__c);
        }
    }
    for (Id referralId : referralIds) {
        System.enqueueJob(new ReferralValidationJob(referralId));
    }
}