public with sharing class PortalConfigController {

	@AuraEnabled(cacheable = true)
	public static Integer getInactivityTime(){
        try {
            List<Portal_Config__mdt> configs = [
                SELECT Inactivity_Time_Minutes__c
                FROM Portal_Config__mdt
                LIMIT 1
            ];

            if (!configs.isEmpty() && configs[0].Inactivity_Time_Minutes__c != null) {
                return Integer.valueOf(configs[0].Inactivity_Time_Minutes__c);
            }

            return 10;
        } catch (Exception e) {
            System.debug('Error: ' + e.getMessage());
            return 10;
        }
    }
}