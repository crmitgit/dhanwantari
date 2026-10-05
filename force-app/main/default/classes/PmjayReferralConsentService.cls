public without sharing class PmjayReferralConsentService {

    // Get patient details and files for consent
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getConsentDetails(String referralId) {

        System.debug('=== getConsentDetails START ===');
        System.debug('Input referralId: ' + referralId);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);

        if (String.isBlank(referralId)) {
            System.debug('Referral ID is blank');
            result.put('message', 'Referral ID cannot be blank.');
            return result;
        }

        try {
            System.debug('Querying Referral__c by Name');

            List<Referral__c> referrals = [
                SELECT Id,
                       Name,
                       Encounter__c,
                       Patient__c,
                       Patient__r.Name,
                       Patient__r.Phone,
                       Patient__r.Age__c,
                       Patient__r.Gender__c,
                       Referred_By__r.Name,
                       Referred_To__c,
                       Referred_To__r.Name,
                       Patient__r.Registered_At__r.Name,
                       Consent_Status__c,
                       Consented_File_IDs__c,
                       Consent_Timestamp__c,
                       CreatedDate
                FROM Referral__c
                WHERE Name = :referralId
                LIMIT 1
            ];

           

            System.debug('Referral query result size: ' + referrals.size());

            if (!referrals.isEmpty()) {
                Referral__c referral = referrals[0];

DateTime startTime = referral.Consent_Timestamp__c != null ? 
                     referral.Consent_Timestamp__c : 
                     referral.CreatedDate;

DateTime expiryDate = startTime.addDays(28);

if (System.now() > expiryDate) {
    result.put('success', false);
    result.put('expired', true);
    result.put(
        'message',
        'This consent link has expired. For assistance, please contact PHWC Chamoli or call our helpline at 1800-543-XXXX. / यह सहमति लिंक समाप्त हो गया है। सहायता के लिए, कृपया अपने PHWC केंद्र से संपर्क करें या हमारी हेल्पलाइन 1800-543-XXXX पर कॉल करें।'
    );
    result.put('expiryDate', expiryDate.format('dd/MM/yyyy'));
    return result;
}

            //      DateTime linkCreated = referral.Consent_Timestamp__c;
            //      DateTime expiryDate = linkCreated.addDays(28);
            //      System.debug('ExpiryDate: ' + expiryDate);

            // if (DateTime.now() > expiryDate) {
            //     result.put('success', false);
            //     result.put('expired', true);
            //     result.put('message', 'This consent link has expired. Please contact your healthcare provider.');
            //     result.put('expiryDate', expiryDate.format('dd/MM/yyyy'));
            //     return result;
            // }

                Account patientAccount = referral.Patient__r;

                System.debug('Referral Record Id: ' + referral.Id);
                System.debug('Patient Account: ' + patientAccount);

                if (patientAccount != null) {

                    result.put('success', true);
                    result.put('referralRecordId', referral.Id);
                    result.put('patientFullName', patientAccount.Name);
                    result.put('patientAge', String.valueOf(patientAccount.Age__c));
                    result.put('patientGender', patientAccount.Gender__c);
                    result.put('patientPhone', patientAccount.Phone);
                    result.put(
                        'referredBy',
                        referral.Referred_By__r != null ? referral.Referred_By__r.Name : ''
                    );

                    result.put('consentedFileIds', referral.Consented_File_IDs__c );

                    result.put(
                        'referredTo',
                        referral.Referred_To__r != null ? referral.Referred_To__r.Name : ''
                    );

                    result.put(
                        'phwcName',
                        patientAccount.Registered_At__r != null
                            ? patientAccount.Registered_At__r.Name
                            : ''
                    );

                    result.put('consentStatus', referral.Consent_Status__c);

                    /* ---------------- FILE COLLECTION ---------------- */
                    List<Map<String, String>> summaryFiles = new List<Map<String, String>>();
                    List<Map<String, String>> diagnosticFiles = new List<Map<String, String>>();
                    Set<Id> processedDocIds = new Set<Id>();

                    /* -------- CATEGORY 1: SUMMARY FILES -------- */

                    System.debug('Fetching Attachments on Referral');

                    for (Attachment att : [
                        SELECT Id, Name FROM Attachment WHERE ParentId = :referral.Id
                    ]) {
                        String ext = att.Name.contains('.') ? att.Name.substringAfterLast('.') : 'unknown';
                        summaryFiles.add(new Map<String, String>{
                            'Id' => att.Id,
                            'Title' => att.Name,
                            'Type' => 'Attachment',
                            'Extension' => ext.toLowerCase()
                        });
                        System.debug('Attachment added: ' + att.Name);
                    }

                    System.debug('Fetching ContentDocumentLinks on Referral');

                    Set<Id> referralDocIds = new Set<Id>();
                    // for (ContentDocumentLink cdl : [
                    //     SELECT ContentDocumentId
                    //     FROM ContentDocumentLink
                    //     WHERE LinkedEntityId = :referral.Id
                    // ]) {
                    //     referralDocIds.add(cdl.ContentDocumentId);
                    // }

                    System.debug('Referral ContentDocumentIds: ' + referralDocIds);

                    if (!referralDocIds.isEmpty()) {
                        for (ContentVersion cv : [
                            SELECT Id, Title, ContentDocumentId, FileExtension
                            FROM ContentVersion
                            WHERE ContentDocumentId IN :referralDocIds AND IsLatest = true
                        ]) {
                            summaryFiles.add(new Map<String, String>{
                                'Id' => cv.Id,
                                'Title' => cv.Title + '.' + cv.FileExtension,
                                'Type' => 'File',
                                'Extension' => cv.FileExtension.toLowerCase()
                            });
                            processedDocIds.add(cv.ContentDocumentId);
                            System.debug('Summary File added: ' + cv.Title);
                        }
                    }

                    /* -------- CATEGORY 2: DIAGNOSTIC REPORTS -------- */

                    if (String.isNotBlank(referral.Encounter__c)) {
                        System.debug('Processing Encounter__c: ' + referral.Encounter__c);

                        List<String> encounterNames = referral.Encounter__c.split(',');

                        Map<Id, ClinicalServiceRequest> csrMap =
                            new Map<Id, ClinicalServiceRequest>([
                                SELECT Id
                                FROM ClinicalServiceRequest
                                WHERE Encounter.Name IN :encounterNames
                            ]);

                        System.debug('ClinicalServiceRequest count: ' + csrMap.size());

                        if (!csrMap.isEmpty()) {

                            Map<Id, DiagnosticSummary> dsMap =
                                new Map<Id, DiagnosticSummary>([
                                    SELECT Id
                                    FROM DiagnosticSummary
                                    WHERE Clinical_Service_Request__c IN :csrMap.keySet()
                                ]);

                            System.debug('DiagnosticSummary count: ' + dsMap.size());

                            if (!dsMap.isEmpty()) {

                                Set<Id> diagDocIds = new Set<Id>();
                                for (ContentDocumentLink cdl : [
                                    SELECT ContentDocumentId
                                    FROM ContentDocumentLink
                                    WHERE LinkedEntityId IN :dsMap.keySet()
                                ]) {
                                    if (!processedDocIds.contains(cdl.ContentDocumentId)) {
                                        diagDocIds.add(cdl.ContentDocumentId);
                                    }
                                }

                                System.debug('Diagnostic ContentDocumentIds: ' + diagDocIds);

                                if (!diagDocIds.isEmpty()) {
                                    for (ContentVersion cv : [
                                        SELECT Id, Title, FileExtension, ContentDocumentId
                                        FROM ContentVersion
                                        WHERE ContentDocumentId IN :diagDocIds AND IsLatest = true
                                    ]) {
                                        diagnosticFiles.add(new Map<String, String>{
                                            'Id' => cv.Id,
                                            'Title' => cv.Title + '.' + cv.FileExtension,
                                            'Type' => 'Diagnostic',
                                            'Extension' => cv.FileExtension.toLowerCase()
                                        });
                                        System.debug('Diagnostic File added: ' + cv.Title);
                                    }
                                }
                            }
                        }
                    }

                    result.put('summaryFiles', summaryFiles);
                    result.put('diagnosticFiles', diagnosticFiles);
                    result.put('message', 'Details fetched successfully.');
                } else {
                    System.debug('Patient account is null');
                    result.put('message', 'No patient account associated with this referral ID.');
                }
            } else {
                System.debug('No referral found for given referralId');
                result.put('message', 'Referral ID not found.');
            }
        } catch (Exception e) {
            System.debug('Exception in getConsentDetails: ' + e);
            result.put('message', 'An error occurred: ' + e.getMessage());
        }

        System.debug('=== getConsentDetails END ===');
        return result;
    }

    // Save consent decision
    @AuraEnabled
    public static Map<String, Object> saveConsent(String referralRecordId, String consentStatus, List<String> selectedFileIds) {

        System.debug('=== saveConsent START ===');
        System.debug('ReferralRecordId: ' + referralRecordId);
        System.debug('ConsentStatus: ' + consentStatus);
        System.debug('SelectedFileIds: ' + selectedFileIds);

        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);

        try {
            Referral__c referral =
                [SELECT Id,Consent_Status__c, Referral_Status__c, Consent_Mode__c FROM Referral__c WHERE Id = :referralRecordId LIMIT 1];

            referral.Consent_Status__c = consentStatus;

            if (consentStatus == 'Granted' &&
                selectedFileIds != null &&
                !selectedFileIds.isEmpty()) {
                referral.Consent_Granted_Date__c = System.now();
                referral.Referral_Status__c = 'Referral Summarized';
                referral.Consented_File_IDs__c = String.join(selectedFileIds, ',');
                update referral;

                ReferralTriggerHelper.sendReferralEmail(new List<Id>{ referral.Id });
                System.debug('Consented_File_IDs__c set to: ' + referral.Consented_File_IDs__c);
            } else {
                referral.Consented_File_IDs__c = null;
                referral.Consent_Revoked__c = System.now();
                update referral;

                System.debug('Consented_File_IDs__c cleared');
            }


            result.put('success', true);
            result.put('message', 'Consent ' + consentStatus.toLowerCase() + ' successfully.');
        } catch (Exception e) {
            System.debug('Exception in saveConsent: ' + e);
            result.put('message', 'Error saving consent: ' + e.getMessage());
        }

        System.debug('=== saveConsent END ===');
        return result;
    }

   @AuraEnabled
    public static void grantManualConsent(Id referralId, String reason) {
        if (String.isBlank(reason)) {
            throw new AuraHandledException('Reason for manual consent is required.');
        }

        Referral__c ref = [
            SELECT Id, Consent_Status__c
            FROM Referral__c
            WHERE Id = :referralId
            FOR UPDATE
        ];

        if (ref.Consent_Status__c == 'Granted') {
            throw new AuraHandledException('Consent is already granted.');
        }

        ref.Consent_Status__c = 'Granted';
        ref.Consent_Mode__c = 'Manual';
        ref.Reason_for_Manual_Consent__c = reason;
        ref.Consent_Granted_Date__c = System.now();
        ref.Consent_Granted_By__c = UserInfo.getUserId();

        update ref;
    }
}