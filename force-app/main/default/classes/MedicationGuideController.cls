public with sharing class MedicationGuideController {

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

        System.debug('🔥 getAISummary called');
        System.debug('➡️ clinicalEncounterId: ' + clinicalEncounterId);

        Encounter_Summary__c latestSummary = null;
        Prompt_Audit_Log__c latestAudit = null;

        // Latest Encounter Summary record
        List<Encounter_Summary__c> summaryList = [
            SELECT AI_Summary__c, Run_Id__c, CreatedDate,AI_Summary_Phi3__c
            FROM Encounter_Summary__c
            WHERE Clinical_Encounter__c = :clinicalEncounterId
            ORDER BY Run_Id__c DESC
            LIMIT 1
        ];

        System.debug('📌 Summary records found: ' + summaryList.size());

        if (!summaryList.isEmpty()) {
            latestSummary = summaryList[0];
            System.debug('✅ Latest Summary Found');
            System.debug('   Summary Id: ' + latestSummary.Id);
            System.debug('   Summary RunId: ' + latestSummary.Run_Id__c);
            System.debug('   Summary CreatedDate: ' + latestSummary.CreatedDate);
        }

        // Latest Audit Log record
        List<Prompt_Audit_Log__c> auditList = [
            SELECT Id, Run_Id__c, CreatedDate
            FROM Prompt_Audit_Log__c
            WHERE Consultation__c = :clinicalEncounterId
            ORDER BY Run_Id__c DESC
            LIMIT 1
        ];

        System.debug('📌 Audit records found: ' + auditList.size());

        if (!auditList.isEmpty()) {
            latestAudit = auditList[0];
            System.debug('✅ Latest Audit Found');
            System.debug('   Audit Id: ' + latestAudit.Id);
            System.debug('   Audit RunId: ' + latestAudit.Run_Id__c);
            System.debug('   Audit CreatedDate: ' + latestAudit.CreatedDate);
        }

        // If nothing exists
        if (latestSummary == null && latestAudit == null) {
            System.debug('⚠️ No Summary and No Audit records found. Returning null.');
            return null;
        }

        // If only audit exists
        if (latestSummary == null && latestAudit != null) {
            System.debug('⚠️ Only Audit exists. Returning escalation message.');
            return 'This patient requires specialist evaluation and management.';
        }

        // If only summary exists
        if (latestSummary != null && latestAudit == null) {
            System.debug('⚠️ Only Summary exists. Returning AI Summary.');
            return latestSummary.AI_Summary__c;
        }

        // Both exist -> compare RunId safely
        String summaryRunId = latestSummary.Run_Id__c;
        String auditRunId = latestAudit.Run_Id__c;

        System.debug('📌 Comparing RunIds...');
        System.debug('   Summary RunId: ' + summaryRunId);
        System.debug('   Audit RunId: ' + auditRunId);

        // Handle null/blank RunId scenarios
        if (String.isBlank(summaryRunId) && String.isBlank(auditRunId)) {
            System.debug('⚠️ Both RunIds are blank. Falling back to CreatedDate comparison.');

            if (latestAudit.CreatedDate > latestSummary.CreatedDate) {
                System.debug('❌ Latest is Audit (by CreatedDate). Returning escalation message.');
                return 'This patient requires specialist evaluation and management.';
            }

            System.debug('✅ Latest is Summary (by CreatedDate). Returning AI Summary.');
            return latestSummary.AI_Summary__c;
        }

        if (String.isBlank(summaryRunId) && !String.isBlank(auditRunId)) {
            System.debug('⚠️ Summary RunId is blank but Audit RunId exists. Returning escalation message.');
            return 'This patient requires specialist evaluation and management.';
        }

        if (!String.isBlank(summaryRunId) && String.isBlank(auditRunId)) {
            System.debug('⚠️ Audit RunId is blank but Summary RunId exists. Returning AI Summary.');
            return latestSummary.AI_Summary__c;
        }

        // Normal comparison (both non-blank)
        if (auditRunId > summaryRunId) {
            System.debug('❌ Audit RunId is greater. Returning escalation message.');
            return 'This patient requires specialist evaluation and management.';
        }

        System.debug('✅ Summary RunId is greater/equal. Returning AI Summary.');
        return latestSummary.AI_Summary__c;
    }

    @AuraEnabled(cacheable=true)
    public static String getAyushAISummary(Id clinicalEncounterId) {
        Ayush_AI_Summary__c summary = [
            SELECT AI_Summary__c
            FROM Ayush_AI_Summary__c 
            WHERE Consultation__c = :clinicalEncounterId 
            ORDER BY CreatedDate DESC 
            LIMIT 1
        ];
        return summary.AI_Summary__c;
    }
    @AuraEnabled(cacheable=true)
public static String getAISummaryPhi3(Id clinicalEncounterId) {

    System.debug('🔥 getAISummaryPhi3 called');
    System.debug('➡️ clinicalEncounterId: ' + clinicalEncounterId);

    List<Encounter_Summary__c> summaryList = [
        SELECT AI_Summary_Phi3__c, CreatedDate
        FROM Encounter_Summary__c
        WHERE Clinical_Encounter__c = :clinicalEncounterId
        ORDER BY CreatedDate DESC
        LIMIT 1
    ];

    System.debug('📌 Phi3 Summary records found: ' + summaryList.size());

    if(summaryList.isEmpty()){
        System.debug('⚠️ No Phi3 summary found.');
        return null;
    }

    System.debug('✅ Returning Phi3 AI Summary');
    return summaryList[0].AI_Summary_Phi3__c;
}
}