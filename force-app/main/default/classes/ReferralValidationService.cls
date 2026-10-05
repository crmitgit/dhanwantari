/**
 * Backs the "Referral Validation" card on the Empanelled Healthcare Portal.
 *
 * The portal runs as the site guest user, which cannot call Einstein. So the flow is:
 *   1. The portal calls getReferralValidation(). Everything factual (patient, visits, vitals,
 *      investigations, documents) is read straight from the records and returned immediately.
 *   2. If no AI verdict is stored yet, a Referral_Validation_Request__e is published.
 *   3. ReferralValidationRequestTrigger runs as an internal user (see
 *      ReferralValidationRequestConfig) and enqueues ReferralValidationJob, which builds the
 *      dossier, calls the Referral_Validation prompt template and stores the JSON on the referral.
 *   4. The portal polls getValidationStatus() until the verdict arrives.
 *
 * The record strength level (High / Medium / Low) is NOT decided by the model. It rates how well the
 * PHWC record supports the referral, not whether the hospital should accept the patient. CaseBundle.score() computes
 * it from weighted, countable data points (weights live in Referral_Validation_Rule__mdt). The model
 * only explains that score and adds unscored clinical notes. The stored explanation carries the score
 * fingerprint it was written against, so it is regenerated automatically when the record changes.
 */
public without sharing class ReferralValidationService {

    public static final String PROMPT_TEMPLATE = 'Referral_Validation';
    public static final String STATUS_PENDING = 'Pending';
    public static final String STATUS_COMPLETE = 'Complete';
    public static final String STATUS_FAILED = 'Failed';

    private static final Integer STALE_PENDING_MINUTES = 5;
    private static final String NOT_RECORDED = 'Not recorded';
    private static final Set<String> PLACEHOLDERS = new Set<String>{ 'n/a', 'na', 'n.a.', 'none', 'nil', '-', '--', 'null', 'not applicable' };
    private static final String TIMEZONE = 'Asia/Kolkata';

    @TestVisible
    private static String mockPromptResponse;

    // ------------------------------------------------------------------
    // Scoring rules. Defaults match the agreed weights; any
    // Referral_Validation_Rule__mdt record with the same DeveloperName overrides them.
    // ------------------------------------------------------------------

    private static final Map<String, Decimal> RULE_DEFAULTS = new Map<String, Decimal>{
        // Record depth (20)
        'Depth_0_Visits' => 0, 'Depth_1_Visit' => 8, 'Depth_2_Visits' => 14, 'Depth_3_Plus_Visits' => 20,
        // Vitals on the referral visit (15)
        'Vital_Recorded_Each' => 2, 'Vitals_Plausible' => 5,
        // Clinical documentation (15)
        'Documentation_Each' => 3,
        // Investigations and evidence (20)
        'Tests_Ordered' => 5, 'Test_Results_Recorded' => 10, 'Documents_Shared' => 5,
        // Identity and consent (10)
        'PMJAY_Verified' => 6, 'PMJAY_Id_On_File' => 2, 'Consent_Granted' => 2,
        // Duplication (10)
        'No_Duplicate_Tests' => 5, 'No_Other_Open_Referral' => 5,
        // Urgency alignment (10)
        'Urgency_Match' => 10, 'Urgency_Mismatch' => 3,
        // Bands (percent of available points)
        'Band_High_Min' => 75, 'Band_Medium_Min' => 50,
        // Realistic ranges
        'SpO2_Min' => 70, 'SpO2_Max' => 100, 'Temp_F_Min' => 93, 'Temp_F_Max' => 108,
        'Pulse_Min' => 30, 'Pulse_Max' => 220, 'Systolic_Min' => 60, 'Systolic_Max' => 260,
        'Diastolic_Min' => 30, 'Diastolic_Max' => 160, 'Weight_Kg_Min' => 1, 'Weight_Kg_Max' => 250,
        // Red-flag vitals used for urgency
        'Red_Flag_SpO2_Below' => 92, 'Red_Flag_Systolic_Above' => 180, 'Red_Flag_Systolic_Below' => 90,
        'Red_Flag_Pulse_Above' => 120, 'Red_Flag_Temp_F_At_Least' => 103,
        // Windows (days)
        'Duplicate_Test_Window_Days' => 30, 'Other_Referral_Window_Days' => 30, 'Cap_Other_Referral_Days' => 7,
        // Integrity flags (not scored)
        'Utilisation_Window_Days' => 90, 'Patient_Referrals_Amber' => 3, 'Patient_Referrals_Red' => 5,
        'Family_Referrals_Amber' => 4, 'Backdated_Gap_Days' => 7, 'Not_Received_Grace_Days' => 7
    };

    private static Map<String, Decimal> ruleValues;

    @TestVisible
    private static Decimal rule(String key) {
        if (ruleValues == null) {
            ruleValues = RULE_DEFAULTS.clone();
            try {
                for (Referral_Validation_Rule__mdt m : Referral_Validation_Rule__mdt.getAll().values()) {
                    if (m.Value__c != null) {
                        ruleValues.put(m.DeveloperName, m.Value__c);
                    }
                }
            } catch (Exception e) {
                System.debug(LoggingLevel.WARN, 'ReferralValidationService: using default rules. ' + e.getMessage());
            }
        }
        return ruleValues.containsKey(key) ? ruleValues.get(key) : 0;
    }

    // ------------------------------------------------------------------
    // Portal entry points
    // ------------------------------------------------------------------

    @AuraEnabled
    public static Map<String, Object> getReferralValidation(String referralName, String hospitalName) {
        Referral__c ref = loadAuthorisedReferral(referralName, hospitalName);
        CaseBundle bundle = new CaseBundle(ref);
        Map<String, Object> result = bundle.toFacts();
        if (needsRun(ref) || explanationOutOfDate(ref, bundle.scoreKey())) {
            requestRun(ref);
        }
        result.put('validation', validationState(ref));
        return result;
    }

    @AuraEnabled
    public static Map<String, Object> getValidationStatus(String referralName, String hospitalName) {
        Referral__c ref = loadAuthorisedReferral(referralName, hospitalName);
        if (needsRun(ref)) {
            requestRun(ref);
        }
        return validationState(ref);
    }

    @AuraEnabled
    public static Map<String, Object> rerunValidation(String referralName, String hospitalName) {
        Referral__c ref = loadAuthorisedReferral(referralName, hospitalName);
        if (ref.Validation_Status__c != STATUS_PENDING || isStale(ref)) {
            requestRun(ref);
        }
        return validationState(ref);
    }

    // ------------------------------------------------------------------
    // Called by ReferralValidationJob (internal user context)
    // ------------------------------------------------------------------

    public static void runValidation(Id referralId) {
        Referral__c upd = new Referral__c(Id = referralId);
        try {
            Referral__c ref = queryReferral(referralId, null);
            CaseBundle bundle = new CaseBundle(ref);
            Object parsed = JSON.deserializeUntyped(extractJson(callPrompt(bundle.toDossier())));
            if (!(parsed instanceof Map<String, Object>)
                    || !((Map<String, Object>) parsed).containsKey('summary')) {
                throw new ValidationException('The model response was not in the expected shape.');
            }
            Map<String, Object> explanation = (Map<String, Object>) parsed;
            // The level always comes from the weighted score, never from the model.
            explanation.remove('confidence');
            explanation.put('scoreKey', bundle.scoreKey());
            upd.Validation_Result__c = JSON.serialize(explanation);
            upd.Validation_Status__c = STATUS_COMPLETE;
            upd.Validation_Error__c = null;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'ReferralValidationService: ' + e.getMessage() + '\n' + e.getStackTraceString());
            upd.Validation_Status__c = STATUS_FAILED;
            upd.Validation_Error__c = e.getMessage().left(255);
        }
        upd.Validation_Run_At__c = System.now();
        update upd;
    }

    /** Flags for one referral without authorisation or a model run. Internal use only (not @AuraEnabled). */
    public static List<Map<String, Object>> integrityFlagsFor(Id referralId) {
        Referral__c ref = queryReferral(referralId, null);
        return ref == null ? new List<Map<String, Object>>() : new CaseBundle(ref).integrityFlags();
    }

    @TestVisible
    private static String callPrompt(String dossier) {
        if (Test.isRunningTest()) {
            return mockPromptResponse;
        }
        ConnectApi.WrappedValue dossierValue = new ConnectApi.WrappedValue();
        dossierValue.value = dossier;

        ConnectApi.EinsteinPromptTemplateGenerationsInput input = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        input.inputParams = new Map<String, ConnectApi.WrappedValue>{ 'Input:Referral_Dossier' => dossierValue };
        input.isPreview = false;
        input.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();

        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation output =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate(PROMPT_TEMPLATE, input);
        if (output == null || output.generations == null || output.generations.isEmpty()) {
            throw new ValidationException('No response from the Referral_Validation prompt template.');
        }
        return output.generations[0].text;
    }

    /** Strips code fences or stray prose around the JSON object the model returns. */
    @TestVisible
    private static String extractJson(String raw) {
        if (String.isBlank(raw)) {
            throw new ValidationException('Empty response from the model.');
        }
        Integer startIdx = raw.indexOf('{');
        Integer endIdx = raw.lastIndexOf('}');
        if (startIdx < 0 || endIdx <= startIdx) {
            throw new ValidationException('The model did not return JSON.');
        }
        return raw.substring(startIdx, endIdx + 1);
    }

    // ------------------------------------------------------------------
    // Access and run state
    // ------------------------------------------------------------------

    private static Referral__c loadAuthorisedReferral(String referralName, String hospitalName) {
        if (String.isBlank(referralName)) {
            throw auraError('Please enter a Referral ID. / à¤•à¥ƒà¤ªà¤¯à¤¾ à¤à¤• à¤°à¥‡à¤«à¤°à¤² à¤†à¤ˆà¤¡à¥€ à¤¦à¤°à¥à¤œ à¤•à¤°à¥‡à¤‚à¥¤');
        }
        if (String.isBlank(hospitalName)) {
            throw auraError('Your session has expired. Please log in again. / à¤•à¥ƒà¤ªà¤¯à¤¾ à¤«à¤¿à¤° à¤¸à¥‡ à¤²à¥‰à¤—à¤¿à¤¨ à¤•à¤°à¥‡à¤‚à¥¤');
        }
        Referral__c ref = queryReferral(null, referralName.trim());
        if (ref == null) {
            throw auraError('Referral ID not found. / à¤°à¥‡à¤«à¤°à¤² à¤†à¤ˆà¤¡à¥€ à¤¨à¤¹à¥€à¤‚ à¤®à¤¿à¤²à¥€à¥¤');
        }
        if (ref.Consent_Status__c != 'Granted') {
            throw auraError('Patient consent is pending or not granted. Empanelled hospitals are not authorized to view patient details. / à¤°à¥‹à¤—à¥€ à¤•à¥€ à¤¸à¤¹à¤®à¤¤à¤¿ à¤²à¤‚à¤¬à¤¿à¤¤ à¤¹à¥ˆà¥¤');
        }
        if (ref.Referred_To__c == null || !hospitalName.trim().equalsIgnoreCase(ref.Referred_To__r.Name)) {
            throw auraError('This referral was not sent to your hospital. / à¤¯à¤¹ à¤°à¥‡à¤«à¤°à¤² à¤†à¤ªà¤•à¥‡ à¤…à¤¸à¥à¤ªà¤¤à¤¾à¤² à¤•à¥‹ à¤¨à¤¹à¥€à¤‚ à¤­à¥‡à¤œà¤¾ à¤—à¤¯à¤¾ à¤¹à¥ˆà¥¤');
        }
        return ref;
    }

    private static Boolean needsRun(Referral__c ref) {
        return ref.Validation_Status__c == null || isStale(ref);
    }

    /** True when a completed explanation was written against a different score than the record gives now. */
    private static Boolean explanationOutOfDate(Referral__c ref, String currentKey) {
        if (ref.Validation_Status__c != STATUS_COMPLETE || String.isBlank(ref.Validation_Result__c)) {
            return false;
        }
        try {
            Map<String, Object> stored = (Map<String, Object>) JSON.deserializeUntyped(ref.Validation_Result__c);
            return stored.get('scoreKey') != currentKey;
        } catch (Exception e) {
            return true;
        }
    }

    private static Boolean isStale(Referral__c ref) {
        return ref.Validation_Status__c == STATUS_PENDING
            && (ref.Validation_Run_At__c == null
                || ref.Validation_Run_At__c < System.now().addMinutes(-STALE_PENDING_MINUTES));
    }

    private static void requestRun(Referral__c ref) {
        ref.Validation_Status__c = STATUS_PENDING;
        ref.Validation_Run_At__c = System.now();
        ref.Validation_Error__c = null;
        update new Referral__c(
            Id = ref.Id,
            Validation_Status__c = ref.Validation_Status__c,
            Validation_Run_At__c = ref.Validation_Run_At__c,
            Validation_Error__c = null
        );
        EventBus.publish(new Referral_Validation_Request__e(Referral_Id__c = ref.Id));
    }

    private static Map<String, Object> validationState(Referral__c ref) {
        Map<String, Object> state = new Map<String, Object>{
            'status' => ref.Validation_Status__c,
            'runAt' => ref.Validation_Run_At__c == null ? null : ref.Validation_Run_At__c.format('HH:mm, d MMMM', TIMEZONE),
            'error' => ref.Validation_Error__c,
            'ai' => null
        };
        if (ref.Validation_Status__c == STATUS_COMPLETE && String.isNotBlank(ref.Validation_Result__c)) {
            try {
                state.put('ai', JSON.deserializeUntyped(ref.Validation_Result__c));
            } catch (Exception e) {
                state.put('status', STATUS_FAILED);
                state.put('error', 'Stored validation result could not be read.');
            }
        }
        return state;
    }

    @TestVisible
    private static Referral__c queryReferral(Id referralId, String referralName) {
        List<Referral__c> refs = [
            SELECT Id, Name, Patient__c, Referral_Date__c, Referral_Priority__c, Referral_Status__c,
                   Recommended_Visit_By__c, Chief_Complaints_and_Presenting_Symptoms__c,
                   Preliminary_Diagnosis__c, Referral_Summary__c, Referral_Summary2__c,
                   Reason_for_Referral_to_Another_Provider__c, PrimarySpecialty__c, Primary_Specialty__r.Name,
                   SecondarySpecialty__c, Secondary_Specialty__r.Name,
                   Referred_By__r.Name, Account_Referred_By__r.Name,
                   Referred_To__c, Referred_To__r.Name,
                   Clinical_Encounter__c, Encounter__c, Clinical_Service_Request__c,
                   Consent_Status__c, Consent_Mode__c, Consent_Granted_Date__c, Consented_File_IDs__c,
                   Patient_Received_Date__c, CreatedDate,
                   Validation_Result__c, Validation_Status__c, Validation_Run_At__c, Validation_Error__c,
                   Patient__r.Name, Patient__r.Age__c, Patient__r.Gender__c, Patient__r.Birth_Date__c,
                   Patient__r.Blood_Group__c, Patient__r.Known_Allergies__c, Patient__r.PMJAY_Scheme_Verified__c,
                   Patient__r.PM_JAY_ID__c, Patient__r.PMJAY_Family_ID__c, Patient__r.Phone, Patient__r.Registered_At__r.Name
            FROM Referral__c
            WHERE (Id = :referralId OR Name = :referralName)
            LIMIT 1
        ];
        return refs.isEmpty() ? null : refs[0];
    }

    // ------------------------------------------------------------------
    // Everything known about the case, read once, rendered two ways
    // ------------------------------------------------------------------

    public class CaseBundle {
        Referral__c ref;
        Date referralDate;
        Set<Id> referralEncounterIds = new Set<Id>();
        List<ClinicalEncounter> visits = new List<ClinicalEncounter>();
        List<ClinicalServiceRequest> requests = new List<ClinicalServiceRequest>();
        List<DiagnosticSummary> diagnostics = new List<DiagnosticSummary>();
        List<MedicationRequest> medications = new List<MedicationRequest>();
        List<HealthCondition> conditions = new List<HealthCondition>();
        List<AllergyIntolerance> allergies = new List<AllergyIntolerance>();
        List<Referral__c> otherReferrals = new List<Referral__c>();
        List<Map<String, Object>> documents = new List<Map<String, Object>>();
        Map<Id, String> duplicateNotes = new Map<Id, String>();
        Set<Id> entitiesWithDocuments = new Set<Id>();
        Map<Id, Integer> documentCountByEntity = new Map<Id, Integer>();
        Map<String, Object> scoreCache;
        Map<String, Object> fitCache;
        List<Map<String, Object>> flagsCache;

        public CaseBundle(Referral__c ref) {
            this.ref = ref;
            this.referralDate = ref.Referral_Date__c != null ? ref.Referral_Date__c : ref.CreatedDate.date();
            Id pid = ref.Patient__c;
            Datetime cutoff = Datetime.newInstanceGmt(referralDate.addDays(2), Time.newInstance(0, 0, 0, 0));

            if (ref.Clinical_Encounter__c != null) {
                referralEncounterIds.add(ref.Clinical_Encounter__c);
            }
            Set<String> referralEncounterNames = new Set<String>();
            if (String.isNotBlank(ref.Encounter__c)) {
                for (String n : ref.Encounter__c.split(',')) {
                    referralEncounterNames.add(n.trim());
                }
            }

            List<ClinicalEncounter> recent = [
                SELECT Id, Name, StartDate, Status, Patient_Type__c, Symptoms__c, Clinical_Findings__c,
                       Medical_History__c, Blood_Pressure__c, Pulse_Rate_in_BPM__c, SpO2__c,
                       Body_Temperature__c, Weight_in_Kg__c, Height_in_cm__c, Care_Instructions__c,
                       Follow_up_Date__c, Required_before_follow_up__c, Additional_Information__c,
                       Comments_Remarks__c, Doctor_Name__c, Prescribing_Doctor__r.Name, Facility.Name
                FROM ClinicalEncounter
                WHERE PatientId = :pid AND StartDate <= :cutoff
                ORDER BY StartDate DESC
                LIMIT 15
            ];
            for (Integer i = recent.size() - 1; i >= 0; i--) {
                visits.add(recent[i]);
                if (referralEncounterNames.contains(recent[i].Name)) {
                    referralEncounterIds.add(recent[i].Id);
                }
            }

            requests = [
                SELECT Id, Name, Requested_Test__c, Status, Priority, Type, Notes__c, Completed_On__c,
                       Requested_Completion_Date__c, CreatedDate, EncounterId, Encounter.Name
                FROM ClinicalServiceRequest
                WHERE PatientId = :pid AND CreatedDate <= :cutoff
                ORDER BY CreatedDate ASC
                LIMIT 30
            ];

            diagnostics = [
                SELECT Id, Name, Summary, Status, Sample_Type__c, Sample_Drawn_Date__c, IssuedDateTime,
                       EffectiveStartDateTime, CreatedDate, ImageComments1,
                       Clinical_Service_Request__c, Clinical_Service_Request__r.Name, Clinical_Service_Request__r.Requested_Test__c
                FROM DiagnosticSummary
                WHERE PatientId = :pid AND CreatedDate <= :cutoff
                ORDER BY CreatedDate ASC
                LIMIT 30
            ];

            medications = [
                SELECT Id, Medication.Name, Medication_Name__c, Dosage_Strength__c, Dosage_Frequency__c,
                       Dosage_Timing__c, Duration_Days__c, Instructions__c, Status,
                       Prescription_Start_Date__c, ClinicalEncounterId
                FROM MedicationRequest
                WHERE PatientId = :pid AND CreatedDate <= :cutoff
                ORDER BY Prescription_Start_Date__c DESC NULLS LAST
                LIMIT 40
            ];

            conditions = [
                SELECT Id, ProblemName, ProblemDescription, ConditionStatus, Severity, OnsetStartDateTime
                FROM HealthCondition
                WHERE PatientId = :pid
                LIMIT 20
            ];

            allergies = [
                SELECT Id, Name, Status, Severity, Type
                FROM AllergyIntolerance
                WHERE PatientId = :pid
                LIMIT 20
            ];

            otherReferrals = [
                SELECT Id, Name, Referral_Date__c, Referred_To__c, Referred_To__r.Name, Referral_Status__c,
                       Referral_Priority__c, Preliminary_Diagnosis__c, Patient_Received_Date__c, Consent_Status__c
                FROM Referral__c
                WHERE Patient__c = :pid AND Id != :ref.Id
                ORDER BY Referral_Date__c DESC NULLS LAST
                LIMIT 10
            ];

            loadDocuments();
            findDuplicateRequests();
        }

        /** Document titles only, never contents, filtered by the same consent rules as PmjayReferralService. */
        private void loadDocuments() {
            Boolean enforceConsent = ref.Consent_Mode__c != 'Manual';
            Set<Id> consentedIds = new Set<Id>();
            if (enforceConsent && String.isNotBlank(ref.Consented_File_IDs__c)) {
                for (String idStr : ref.Consented_File_IDs__c.split(',')) {
                    try {
                        consentedIds.add((Id) idStr.trim());
                    } catch (Exception e) {
                        // ignore malformed ids, as the existing service does
                    }
                }
                for (ContentVersion cv : [SELECT ContentDocumentId FROM ContentVersion WHERE Id IN :consentedIds]) {
                    consentedIds.add(cv.ContentDocumentId);
                }
            }

            for (Attachment att : [SELECT Id, Name, CreatedDate FROM Attachment WHERE ParentId = :ref.Id ORDER BY CreatedDate]) {
                if (!enforceConsent || consentedIds.contains(att.Id)) {
                    documents.add(new Map<String, Object>{
                        'title' => att.Name, 'source' => 'Attached to referral ' + ref.Name,
                        'dateLabel' => fmt(att.CreatedDate)
                    });
                }
            }

            Map<Id, String> sourceByEntity = new Map<Id, String>{ ref.Id => 'Attached to referral ' + ref.Name };
            for (DiagnosticSummary ds : diagnostics) {
                sourceByEntity.put(ds.Id, 'Diagnostic result ' + ds.Name);
            }
            Map<Id, String> sourceByDoc = new Map<Id, String>();
            for (ContentDocumentLink cdl : [
                SELECT ContentDocumentId, LinkedEntityId
                FROM ContentDocumentLink
                WHERE LinkedEntityId IN :sourceByEntity.keySet()
            ]) {
                if ((!enforceConsent || consentedIds.contains(cdl.ContentDocumentId))
                        && !sourceByDoc.containsKey(cdl.ContentDocumentId)) {
                    sourceByDoc.put(cdl.ContentDocumentId, sourceByEntity.get(cdl.LinkedEntityId));
                    entitiesWithDocuments.add(cdl.LinkedEntityId);
                    Integer seen = documentCountByEntity.get(cdl.LinkedEntityId);
                    documentCountByEntity.put(cdl.LinkedEntityId, seen == null ? 1 : seen + 1);
                }
            }
            if (!sourceByDoc.isEmpty()) {
                for (ContentVersion cv : [
                    SELECT ContentDocumentId, Title, FileExtension, CreatedDate
                    FROM ContentVersion
                    WHERE ContentDocumentId IN :sourceByDoc.keySet() AND IsLatest = true
                    ORDER BY CreatedDate
                ]) {
                    documents.add(new Map<String, Object>{
                        'title' => cv.Title + (String.isBlank(cv.FileExtension) ? '' : '.' + cv.FileExtension),
                        'source' => sourceByDoc.get(cv.ContentDocumentId),
                        'dateLabel' => fmt(cv.CreatedDate)
                    });
                }
            }
        }

        /** Flags a request that repeats a test ordered in the previous 30 days. */
        private void findDuplicateRequests() {
            for (Integer i = 0; i < requests.size(); i++) {
                Set<String> tests = testNames(requests[i].Requested_Test__c);
                if (tests.isEmpty()) {
                    continue;
                }
                for (Integer j = 0; j < i; j++) {
                    ClinicalServiceRequest earlier = requests[j];
                    Integer gap = earlier.CreatedDate.date().daysBetween(requests[i].CreatedDate.date());
                    if (gap > rule('Duplicate_Test_Window_Days')) {
                        continue;
                    }
                    Set<String> overlap = testNames(earlier.Requested_Test__c);
                    overlap.retainAll(tests);
                    if (!overlap.isEmpty()) {
                        duplicateNotes.put(requests[i].Id,
                            String.join(new List<String>(overlap), ', ') + ' already ordered in ' + earlier.Name
                            + ' on ' + fmt(earlier.CreatedDate) + ' (' + gap + ' days earlier'
                            + (earlier.Completed_On__c != null ? ', completed ' + fmt(earlier.Completed_On__c) : '') + ')');
                        break;
                    }
                }
            }
        }

        // ---------------- refs shared by facts and dossier ----------------

        private Boolean hasConsultRequest() {
            return String.isNotBlank(specialty());
        }

        private String specialty() {
            List<String> parts = new List<String>();
            String primary = ref.Primary_Specialty__r != null ? ref.Primary_Specialty__r.Name : ref.PrimarySpecialty__c;
            String secondary = ref.Secondary_Specialty__r != null ? ref.Secondary_Specialty__r.Name : ref.SecondarySpecialty__c;
            for (String value : new List<String>{ primary, secondary }) {
                if (String.isBlank(value)) continue;
                for (String part : value.split(',')) {
                    String p = part.trim();
                    // PHWC staff type N/A or similar into the secondary specialty; it is not a specialty.
                    if (String.isNotBlank(p) && !PLACEHOLDERS.contains(p.toLowerCase()) && !parts.contains(p)) parts.add(p);
                }
            }
            return String.join(parts, ', ');
        }

        private String referringDoctor() {
            if (ref.Referred_By__r != null) return ref.Referred_By__r.Name;
            if (ref.Account_Referred_By__r != null) return ref.Account_Referred_By__r.Name;
            return null;
        }

        private String referringFacility() {
            if (ref.Patient__r != null && ref.Patient__r.Registered_At__r != null) {
                return ref.Patient__r.Registered_At__r.Name;
            }
            for (Integer i = visits.size() - 1; i >= 0; i--) {
                if (visits[i].Facility != null) return visits[i].Facility.Name;
            }
            return null;
        }

        private String reason() {
            List<String> parts = new List<String>();
            for (String s : new List<String>{ ref.Referral_Summary__c, ref.Referral_Summary2__c, ref.Reason_for_Referral_to_Another_Provider__c }) {
                if (String.isNotBlank(s) && !parts.contains(s.trim())) parts.add(s.trim());
            }
            return String.join(parts, ' ');
        }

        private String medsForVisit(Id encounterId) {
            List<String> names = new List<String>();
            for (MedicationRequest m : medications) {
                if (m.ClinicalEncounterId == encounterId) names.add(medLabel(m));
            }
            return String.join(names, '; ');
        }

        private String currentMeds() {
            List<String> names = new List<String>();
            for (MedicationRequest m : medications) {
                if (m.Status == 'Active' && names.size() < 12) names.add(medLabel(m));
            }
            return String.join(names, '; ');
        }

        private String medLabel(MedicationRequest m) {
            String name = m.Medication != null ? m.Medication.Name : m.Medication_Name__c;
            List<String> bits = new List<String>{ String.isBlank(name) ? 'Unnamed medicine' : name };
            if (String.isNotBlank(m.Dosage_Strength__c)) bits.add(m.Dosage_Strength__c);
            if (String.isNotBlank(m.Dosage_Frequency__c)) bits.add(m.Dosage_Frequency__c.replace(';', ', '));
            if (m.Duration_Days__c != null) bits.add(m.Duration_Days__c.intValue() + ' days');
            return String.join(bits, ', ');
        }

        private List<String> systemChecks() {
            List<String> lines = new List<String>();
            lines.add('Consent: ' + ref.Consent_Status__c
                + (ref.Consent_Granted_Date__c != null ? ' on ' + fmt(ref.Consent_Granted_Date__c) : '')
                + (ref.Consent_Mode__c != null ? ' (' + ref.Consent_Mode__c + ')' : ''));
            lines.add('PM-JAY beneficiary verification on the patient record: '
                + (ref.Patient__r != null && ref.Patient__r.PMJAY_Scheme_Verified__c == true ? 'Verified' : 'Not verified')
                + '. PM-JAY ID ' + (ref.Patient__r != null && String.isNotBlank(ref.Patient__r.PM_JAY_ID__c) ? 'on file.' : 'missing.'));
            if (visits.isEmpty()) {
                lines.add('Consultations recorded before the referral: none.');
            } else {
                Date first = visitDate(visits[0]);
                lines.add('Consultations recorded up to the referral: ' + visits.size()
                    + (first != null ? ', first on ' + fmt(first) + ', ' + first.daysBetween(referralDate) + ' days before the referral.' : '.'));
            }
            lines.add('Referral priority: ' + orNr(ref.Referral_Priority__c)
                + '. Recommended visit by: ' + (ref.Recommended_Visit_By__c != null ? fmt(ref.Recommended_Visit_By__c) : NOT_RECORDED) + '.');
            lines.add('Patient received at hospital: '
                + (ref.Patient_Received_Date__c != null ? fmt(ref.Patient_Received_Date__c) : 'not yet') + '.');
            if (duplicateNotes.isEmpty()) {
                lines.add('Duplicate investigations within ' + rule('Duplicate_Test_Window_Days').intValue() + ' days: none found.');
            } else {
                for (ClinicalServiceRequest r : requests) {
                    if (duplicateNotes.containsKey(r.Id)) {
                        lines.add('Duplicate investigation: ' + r.Name + ' repeats ' + duplicateNotes.get(r.Id) + '.');
                    }
                }
            }
            lines.add('Other referrals sent for this patient to a different hospital within '
                + rule('Other_Referral_Window_Days').intValue() + ' days and not received: ' + openElsewhere().size() + '.');
            lines.add('Documents shared under consent: ' + documents.size() + '.');
            return lines;
        }

        /**
         * Referrals for the same patient that were actually sent (consent granted, not a draft or failed
         * referral) to a different hospital within the window, and not yet received there.
         */
        private List<Referral__c> openElsewhere() {
            List<Referral__c> result = new List<Referral__c>();
            for (Referral__c o : otherReferrals) {
                if (o.Patient_Received_Date__c != null || o.Referral_Date__c == null || o.Referred_To__c == null
                        || o.Referred_To__c == ref.Referred_To__c || o.Consent_Status__c != 'Granted'
                        || o.Referral_Status__c == 'Draft' || o.Referral_Status__c == 'Referral Failed') {
                    continue;
                }
                if (Math.abs(o.Referral_Date__c.daysBetween(referralDate)) <= rule('Other_Referral_Window_Days')) {
                    result.add(o);
                }
            }
            return result;
        }

        // ---------------- integrity flags (facts only, not scored, never accusations) ----------------

        /**
         * Referral-level checks modelled on the NHA PM-JAY anti-fraud triggers. Each one is a prompt to verify,
         * computed from records. Aadhaar and ABHA are stored masked in this org, so they are never compared;
         * only the full PM-JAY ID is used for the shared-identity check. Provider-pattern checks (referral
         * steering, copied notes across patients) deliberately do not appear here, because the hospital
         * viewing the portal may be the subject of them.
         */
        public List<Map<String, Object>> integrityFlags() {
            if (flagsCache != null) return flagsCache;
            List<Map<String, Object>> flags = new List<Map<String, Object>>();
            Id pid = ref.Patient__c;
            Account p = ref.Patient__r;
            Date windowStart = referralDate.addDays(-rule('Utilisation_Window_Days').intValue());
            Integer windowDays = rule('Utilisation_Window_Days').intValue();

            // Same beneficiary referred to more than one hospital at the same time
            List<Referral__c> elsewhere = openElsewhere();
            if (!elsewhere.isEmpty()) {
                Boolean close = false;
                List<String> named = new List<String>();
                for (Referral__c o : elsewhere) {
                    Integer gap = Math.abs(o.Referral_Date__c.daysBetween(referralDate));
                    if (gap <= rule('Cap_Other_Referral_Days')) close = true;
                    if (named.size() < 4) {
                        named.add(o.Name + ' to ' + (o.Referred_To__r == null ? 'another hospital' : o.Referred_To__r.Name) + ' (' + fmt(o.Referral_Date__c) + ')');
                    }
                }
                Integer more = elsewhere.size() - named.size();
                flags.add(flag(close ? 'red' : 'amber',
                    elsewhere.size() == 1 ? 'Open referral to another hospital' : elsewhere.size() + ' open referrals to other hospitals',
                    'Sent with consent and not received: ' + String.join(named, '; ') + (more > 0 ? '; and ' + more + ' more' : '') + '.',
                    'NHA trigger: same beneficiary in more than one place at the same time'));
            }

            // Heavy use by the patient or the family unit
            Integer patientCount = [SELECT COUNT() FROM Referral__c WHERE Patient__c = :pid AND Referral_Date__c >= :windowStart AND Referral_Date__c <= :referralDate];
            if (patientCount >= rule('Patient_Referrals_Amber')) {
                flags.add(flag(patientCount >= rule('Patient_Referrals_Red') ? 'red' : 'amber',
                    'Frequent referrals for this patient',
                    patientCount + ' referrals for this patient in the ' + windowDays + ' days up to this one.',
                    'NHA trigger: excessive utilisation by a member of the family unit'));
            }
            String familyId = p == null ? null : p.PMJAY_Family_ID__c;
            if (String.isNotBlank(familyId)) {
                Integer familyCount = [SELECT COUNT() FROM Referral__c WHERE Patient__r.PMJAY_Family_ID__c = :familyId AND Referral_Date__c >= :windowStart AND Referral_Date__c <= :referralDate];
                if (familyCount >= rule('Family_Referrals_Amber') && familyCount > patientCount) {
                    flags.add(flag('amber', 'Frequent referrals across the family',
                        familyCount + ' referrals for members of this PM-JAY family in the ' + windowDays + ' days up to this one.',
                        'NHA trigger: excessive utilisation by a member of the family unit'));
                }
            }

            // Same PM-JAY ID on another patient record
            String pmjayId = p == null ? null : p.PM_JAY_ID__c;
            if (String.isNotBlank(pmjayId)) {
                Integer shared = [SELECT COUNT() FROM Account WHERE PM_JAY_ID__c = :pmjayId AND Id != :pid];
                if (shared > 0) {
                    flags.add(flag('red', 'PM-JAY ID also on another patient record',
                        'The same PM-JAY ID is on ' + shared + ' other patient record' + (shared == 1 ? '' : 's')
                            + '. It may be a data-entry duplicate; confirm identity on arrival.',
                        'Identity check'));
                }
            }

            // Thin history
            ClinicalEncounter rv = referralVisit();
            Boolean noComplaints = String.isBlank(ref.Chief_Complaints_and_Presenting_Symptoms__c) && (rv == null || String.isBlank(rv.Symptoms__c));
            Boolean noFindingsOrHistory = rv == null || (String.isBlank(rv.Clinical_Findings__c) && String.isBlank(rv.Medical_History__c));
            if (noComplaints || noFindingsOrHistory) {
                flags.add(flag('amber', 'Thin clinical history',
                    (noComplaints ? 'No presenting complaints are recorded. ' : '')
                        + (noFindingsOrHistory ? 'No clinical findings or medical history are recorded for the referral visit.' : ''),
                    'NHA trigger: complaints or presenting symptoms not mentioned, documentation vague or insufficient'));
            }

            // Timeline
            AggregateResult firstEver = [SELECT MIN(StartDate) firstVisit FROM ClinicalEncounter WHERE PatientId = :pid];
            Datetime firstVisit = (Datetime) firstEver.get('firstVisit');
            if (firstVisit == null) {
                flags.add(flag('amber', 'No consultation on record',
                    'There is no consultation for this patient at all, before or after the referral.', 'Record consistency check'));
            } else if (firstVisit.date() > referralDate) {
                flags.add(flag('amber', 'Referral dated before the first consultation',
                    'The referral is dated ' + fmt(referralDate) + ' but the first consultation is ' + fmt(firstVisit) + '.',
                    'Record consistency check'));
            }
            if (ref.Referral_Date__c != null) {
                Integer entryGap = ref.Referral_Date__c.daysBetween(ref.CreatedDate.date());
                if (entryGap > rule('Backdated_Gap_Days')) {
                    flags.add(flag('amber', 'Referral entered well after its date',
                        'Dated ' + fmt(ref.Referral_Date__c) + ' but entered on ' + fmt(ref.CreatedDate) + ' (' + entryGap + ' days later).',
                        'Record consistency check'));
                }
            }

            // Recommended visit date passed without the patient arriving
            if (ref.Patient_Received_Date__c == null && ref.Recommended_Visit_By__c != null) {
                Integer overdue = ref.Recommended_Visit_By__c.daysBetween(Date.today());
                if (overdue > rule('Not_Received_Grace_Days')) {
                    flags.add(flag('amber', 'Patient not received',
                        // No running day count here: it would change the fingerprint daily and re-run the model.
                        'The recommended visit date was ' + fmt(ref.Recommended_Visit_By__c) + ' and the patient has not been received.',
                        'Record consistency check'));
                }
            }

            flagsCache = flags;
            return flags;
        }

        private Map<String, Object> flag(String severity, String title, String detail, String basis) {
            return new Map<String, Object>{ 'severity' => severity, 'title' => title, 'detail' => detail, 'basis' => basis };
        }

        private String flagsDossier() {
            List<String> d = new List<String>{ 'ITEMS TO VERIFY (record checks, not scored; prompts to verify, never accusations)' };
            List<Map<String, Object>> flags = integrityFlags();
            if (flags.isEmpty()) d.add('- None found.');
            for (Map<String, Object> f : flags) {
                d.add('- [' + f.get('severity') + '] ' + f.get('title') + ': ' + f.get('detail') + ' (' + f.get('basis') + ')');
            }
            return String.join(d, '\n');
        }

        // ---------------- fit for this hospital (facts only, not scored) ----------------

        public Map<String, Object> fit() {
            if (fitCache != null) return fitCache;
            String hospital = ref.Referred_To__r == null ? 'this hospital' : ref.Referred_To__r.Name;

            // IsActive is never set on HealthcareProviderSpecialty in this org, so it is ignored;
            // a link counts as offered unless its EffectiveTo date has passed.
            Map<String, String> offered = new Map<String, String>();
            if (ref.Referred_To__c != null) {
                for (HealthcareProviderSpecialty hps : [
                    SELECT Specialty.Name
                    FROM HealthcareProviderSpecialty
                    WHERE Healthcare_Provider__c = :ref.Referred_To__c
                      AND SpecialtyId != null
                      AND (EffectiveTo = null OR EffectiveTo >= TODAY)
                ]) {
                    for (String part : hps.Specialty.Name.split(',')) {
                        if (String.isNotBlank(part)) offered.put(part.trim().toLowerCase(), part.trim());
                    }
                }
            }

            List<String> requested = new List<String>();
            for (String part : specialty().split(',')) {
                if (String.isNotBlank(part) && !requested.contains(part.trim())) requested.add(part.trim());
            }

            List<Map<String, Object>> rows = new List<Map<String, Object>>();
            for (String s : requested) {
                String status = offered.isEmpty() ? 'unknown' : offered.containsKey(s.toLowerCase()) ? 'offered' : 'not_offered';
                rows.add(new Map<String, Object>{
                    'label' => s,
                    'status' => status,
                    'detail' => status == 'offered' ? 'Offered by ' + hospital
                        : status == 'not_offered' ? 'Not in the specialties recorded for ' + hospital
                        : 'No specialties are recorded for ' + hospital
                });
            }

            List<String> previous = new List<String>();
            for (Referral__c o : otherReferrals) {
                if (o.Referred_To__c == ref.Referred_To__c && o.Patient_Received_Date__c != null) {
                    previous.add(o.Name + ', received ' + fmt(o.Patient_Received_Date__c));
                }
            }

            List<String> offeredNames = offered.values();
            offeredNames.sort();
            fitCache = new Map<String, Object>{
                'hospital' => hospital,
                'specialties' => rows,
                'hasSpecialtyRequest' => !rows.isEmpty(),
                'offeredList' => offeredNames.isEmpty() ? NOT_RECORDED : String.join(offeredNames, ', '),
                'previouslyReceived' => !previous.isEmpty(),
                'previousDetail' => previous.isEmpty() ? 'No earlier referral for this patient was received here' : String.join(previous, '; ')
            };
            return fitCache;
        }

        private String fitDossier() {
            Map<String, Object> f = fit();
            List<String> d = new List<String>{ 'HOSPITAL FIT (facts from the records, not scored)' };
            for (Object o : (List<Object>) f.get('specialties')) {
                Map<String, Object> row = (Map<String, Object>) o;
                d.add('- Specialty requested ' + row.get('label') + ': ' + row.get('detail'));
            }
            if (!(Boolean) f.get('hasSpecialtyRequest')) d.add('- No specialty recorded on the referral');
            d.add('- Specialties recorded for ' + f.get('hospital') + ': ' + f.get('offeredList'));
            d.add('- Patient previously received here: ' + f.get('previousDetail'));
            return String.join(d, '\n');
        }

        // ---------------- weighted score ----------------

        /** The consultation the referral was raised from, or the latest one. */
        private ClinicalEncounter referralVisit() {
            for (Integer i = visits.size() - 1; i >= 0; i--) {
                if (referralEncounterIds.contains(visits[i].Id)) return visits[i];
            }
            return visits.isEmpty() ? null : visits[visits.size() - 1];
        }

        /** Stable fingerprint of the score, stored with the explanation to detect record changes. */
        public String scoreKey() {
            String basis = JSON.serialize(score()) + JSON.serialize(integrityFlags());
            return EncodingUtil.convertToHex(Crypto.generateDigest('MD5', Blob.valueOf(basis)));
        }

        public Map<String, Object> score() {
            if (scoreCache != null) return scoreCache;

            List<ScoreArea> areas = new List<ScoreArea>();
            List<String> caps = new List<String>();
            List<String> redFlags = new List<String>();
            List<String> implausible = new List<String>();
            ClinicalEncounter rv = referralVisit();

            // 1. Record depth
            ScoreArea depth = new ScoreArea('record_depth', 'Record depth');
            Integer n = visits.size();
            Decimal depthPts = n >= 3 ? rule('Depth_3_Plus_Visits') : n == 2 ? rule('Depth_2_Visits') : n == 1 ? rule('Depth_1_Visit') : rule('Depth_0_Visits');
            List<String> visitNames = new List<String>();
            for (ClinicalEncounter v : visits) visitNames.add(v.Name + (v.StartDate != null ? ' (' + fmt(v.StartDate) + ')' : ''));
            depth.add('Consultations before the referral', depthPts, rule('Depth_3_Plus_Visits'),
                n == 0 ? 'None recorded' : n + ' recorded: ' + String.join(visitNames, ', '));
            areas.add(depth);
            if (n == 0) caps.add('Low|No consultation is recorded before the referral');

            // 2. Vitals on the referral visit
            ScoreArea vit = new ScoreArea('vitals', 'Vitals on the referral visit');
            Decimal each = rule('Vital_Recorded_Each');
            Decimal sys;
            Decimal dia;
            Boolean bpUnreadable = false;
            if (rv != null && String.isNotBlank(rv.Blood_Pressure__c)) {
                List<String> bp = rv.Blood_Pressure__c.replaceAll('[^0-9/]', '').split('/');
                try {
                    sys = Decimal.valueOf(bp[0]);
                    dia = Decimal.valueOf(bp[1]);
                } catch (Exception e) {
                    bpUnreadable = true;
                }
            }
            Decimal pulse = rv == null ? null : rv.Pulse_Rate_in_BPM__c;
            Decimal spo2 = rv == null ? null : rv.SpO2__c;
            Decimal temp = rv == null ? null : rv.Body_Temperature__c;
            Decimal weight = rv == null ? null : rv.Weight_in_Kg__c;
            String visitLabel = rv == null ? '' : ' (' + rv.Name + ')';

            vit.add('Blood pressure recorded', rv != null && String.isNotBlank(rv.Blood_Pressure__c) ? each : 0, each,
                rv != null && String.isNotBlank(rv.Blood_Pressure__c) ? rv.Blood_Pressure__c + ' mm Hg' + visitLabel : NOT_RECORDED);
            vit.add('Pulse recorded', pulse != null ? each : 0, each, pulse != null ? num(pulse) + ' bpm' : NOT_RECORDED);
            vit.add('SpO₂ recorded', spo2 != null ? each : 0, each, spo2 != null ? num(spo2) + '%' : NOT_RECORDED);
            vit.add('Temperature recorded', temp != null ? each : 0, each, temp != null ? num(temp) + ' °F' : NOT_RECORDED);
            vit.add('Weight recorded', weight != null ? each : 0, each, weight != null ? num(weight) + ' kg' : NOT_RECORDED);

            if (bpUnreadable) implausible.add('blood pressure "' + rv.Blood_Pressure__c + '" could not be read');
            checkRange(implausible, 'systolic BP', sys, 'Systolic_Min', 'Systolic_Max');
            checkRange(implausible, 'diastolic BP', dia, 'Diastolic_Min', 'Diastolic_Max');
            checkRange(implausible, 'pulse', pulse, 'Pulse_Min', 'Pulse_Max');
            checkRange(implausible, 'SpO₂', spo2, 'SpO2_Min', 'SpO2_Max');
            checkRange(implausible, 'temperature', temp, 'Temp_F_Min', 'Temp_F_Max');
            checkRange(implausible, 'weight', weight, 'Weight_Kg_Min', 'Weight_Kg_Max');
            Boolean anyVital = sys != null || pulse != null || spo2 != null || temp != null || weight != null;
            vit.add('Recorded values within realistic ranges',
                anyVital && implausible.isEmpty() ? rule('Vitals_Plausible') : 0, rule('Vitals_Plausible'),
                !anyVital ? 'No vitals to check' : implausible.isEmpty() ? 'All within range' : 'Out of range: ' + String.join(implausible, '; '));
            areas.add(vit);
            if (!implausible.isEmpty()) caps.add('Medium|A recorded vital sign is outside the realistic range');

            if (spo2 != null && spo2 < rule('Red_Flag_SpO2_Below')) redFlags.add('SpO₂ ' + num(spo2) + '%');
            if (sys != null && sys > rule('Red_Flag_Systolic_Above')) redFlags.add('systolic BP ' + num(sys));
            if (sys != null && sys < rule('Red_Flag_Systolic_Below')) redFlags.add('systolic BP ' + num(sys));
            if (pulse != null && pulse > rule('Red_Flag_Pulse_Above')) redFlags.add('pulse ' + num(pulse));
            if (temp != null && temp >= rule('Red_Flag_Temp_F_At_Least')) redFlags.add('temperature ' + num(temp) + ' °F');

            // 3. Clinical documentation
            ScoreArea docs = new ScoreArea('documentation', 'Clinical documentation');
            Decimal dEach = rule('Documentation_Each');
            String complaints = String.isNotBlank(ref.Chief_Complaints_and_Presenting_Symptoms__c)
                ? ref.Chief_Complaints_and_Presenting_Symptoms__c : (rv == null ? null : rv.Symptoms__c);
            docs.addPresence('Chief complaints', complaints, dEach);
            docs.addPresence('Preliminary diagnosis', ref.Preliminary_Diagnosis__c, dEach);
            docs.addPresence('Reason for referral', reason(), dEach);
            docs.addPresence('Clinical findings', rv == null ? null : rv.Clinical_Findings__c, dEach);
            docs.addPresence('Medical history', rv == null ? null : rv.Medical_History__c, dEach);
            areas.add(docs);

            // 4. Investigations and evidence
            ScoreArea inv = new ScoreArea('investigations', 'Investigations and evidence');
            Set<Id> requestsWithResult = new Set<Id>();
            for (DiagnosticSummary ds : diagnostics) {
                Boolean hasResult = String.isNotBlank(ds.Summary) || String.isNotBlank(ds.ImageComments1)
                    || entitiesWithDocuments.contains(ds.Id);
                if (hasResult && ds.Clinical_Service_Request__c != null) requestsWithResult.add(ds.Clinical_Service_Request__c);
            }
            Integer withResult = 0;
            for (ClinicalServiceRequest r : requests) {
                if (r.Completed_On__c != null || requestsWithResult.contains(r.Id)) withResult++;
            }
            Integer ordered = requests.size();
            inv.add('Investigations ordered', ordered > 0 ? rule('Tests_Ordered') : 0, rule('Tests_Ordered'),
                ordered == 0 ? 'None ordered' : ordered + ' ordered');
            inv.add('Results recorded for ordered tests',
                ordered == 0 ? 0 : (rule('Test_Results_Recorded') * withResult / ordered).setScale(1),
                rule('Test_Results_Recorded'),
                ordered == 0 ? 'Nothing ordered' : withResult + ' of ' + ordered + ' have a result or completion date');
            inv.add('Documents shared under consent', documents.isEmpty() ? 0 : rule('Documents_Shared'), rule('Documents_Shared'),
                documents.isEmpty() ? 'None shared' : documents.size() + ' shared');
            areas.add(inv);
            if (ordered > 0 && withResult == 0) caps.add('Medium|Tests were ordered but no results are recorded');

            // 5. Identity and consent
            ScoreArea idc = new ScoreArea('identity', 'Identity and consent');
            Boolean verified = ref.Patient__r != null && ref.Patient__r.PMJAY_Scheme_Verified__c == true;
            Boolean hasPmjayId = ref.Patient__r != null && String.isNotBlank(ref.Patient__r.PM_JAY_ID__c);
            idc.add('PM-JAY beneficiary verified', verified ? rule('PMJAY_Verified') : 0, rule('PMJAY_Verified'), verified ? 'Verified' : 'Not verified');
            idc.add('PM-JAY ID on file', hasPmjayId ? rule('PMJAY_Id_On_File') : 0, rule('PMJAY_Id_On_File'), hasPmjayId ? 'On file' : 'Missing');
            idc.add('Consent granted', ref.Consent_Status__c == 'Granted' ? rule('Consent_Granted') : 0, rule('Consent_Granted'),
                ref.Consent_Status__c + (ref.Consent_Granted_Date__c != null ? ', ' + fmt(ref.Consent_Granted_Date__c) : ''));
            areas.add(idc);
            if (!verified) caps.add('Medium|The patient is not PM-JAY verified');

            // 6. Duplication
            ScoreArea dup = new ScoreArea('duplication', 'Duplication');
            dup.add('No test repeated within ' + rule('Duplicate_Test_Window_Days').intValue() + ' days',
                duplicateNotes.isEmpty() ? rule('No_Duplicate_Tests') : 0, rule('No_Duplicate_Tests'),
                duplicateNotes.isEmpty() ? 'None repeated' : duplicateNotes.size() + ' repeated: ' + String.join(duplicateNotes.values(), '; '));
            List<String> openElsewhere = new List<String>();
            Boolean capOther = false;
            for (Referral__c o : openElsewhere()) {
                openElsewhere.add(o.Name + ' to ' + (o.Referred_To__r == null ? 'another hospital' : o.Referred_To__r.Name) + ', ' + fmt(o.Referral_Date__c));
                if (Math.abs(o.Referral_Date__c.daysBetween(referralDate)) <= rule('Cap_Other_Referral_Days')) capOther = true;
            }
            dup.add('No other open referral to a different hospital', openElsewhere.isEmpty() ? rule('No_Other_Open_Referral') : 0,
                rule('No_Other_Open_Referral'), openElsewhere.isEmpty() ? 'None found' : String.join(openElsewhere, '; '));
            areas.add(dup);
            if (capOther) caps.add('Medium|Another referral to a different hospital is open within ' + rule('Cap_Other_Referral_Days').intValue() + ' days');

            // 7. Urgency alignment
            ScoreArea urg = new ScoreArea('urgency', 'Urgency alignment');
            String priority = ref.Referral_Priority__c;
            Boolean matched;
            String why;
            String flagText = redFlags.isEmpty() ? 'no red-flag vitals' : 'red-flag vitals: ' + String.join(redFlags, ', ');
            if (priority == 'Emergency') {
                matched = !redFlags.isEmpty();
                why = matched ? 'Emergency, supported by ' + flagText : 'Emergency, but ' + flagText + ' (overstated)';
            } else if (priority == 'Routine') {
                matched = redFlags.isEmpty();
                why = matched ? 'Routine, with ' + flagText : 'Routine, but ' + flagText + ' (understated)';
            } else if (priority == 'Urgent') {
                matched = true;
                why = 'Urgent, with ' + flagText;
            } else {
                matched = false;
                why = 'Priority not recorded';
            }
            urg.add('Priority matches the recorded vitals', matched ? rule('Urgency_Match') : rule('Urgency_Mismatch'), rule('Urgency_Match'), why);
            areas.add(urg);

            // Total, band and caps
            Decimal points = 0;
            Decimal maxPoints = 0;
            List<Object> areaMaps = new List<Object>();
            for (ScoreArea a : areas) {
                points += a.points;
                maxPoints += a.maxPoints;
                areaMaps.add(a.toMap());
            }
            Integer percent = maxPoints == 0 ? 0 : (points * 100 / maxPoints).round(System.RoundingMode.HALF_UP).intValue();
            String rawBand = percent >= rule('Band_High_Min') ? 'High' : percent >= rule('Band_Medium_Min') ? 'Medium' : 'Low';
            String band = rawBand;
            List<String> appliedCaps = new List<String>();
            for (String cap : caps) {
                String ceiling = cap.substringBefore('|');
                appliedCaps.add(cap.substringAfter('|') + ' (at most ' + ceiling + ')');
                if (bandRank(ceiling) < bandRank(band)) band = ceiling;
            }

            scoreCache = new Map<String, Object>{
                'score' => percent,
                'points' => points.setScale(1),
                'maxPoints' => maxPoints.setScale(1),
                'rawBand' => rawBand,
                'band' => band,
                'capped' => band != rawBand,
                'caps' => appliedCaps,
                'redFlags' => redFlags,
                'areas' => areaMaps,
                'bandHighMin' => rule('Band_High_Min').intValue(),
                'bandMediumMin' => rule('Band_Medium_Min').intValue()
            };
            return scoreCache;
        }

        private void checkRange(List<String> out, String label, Decimal value, String minKey, String maxKey) {
            if (value != null && (value < rule(minKey) || value > rule(maxKey))) {
                out.add(label + ' ' + num(value) + ' (expected ' + num(rule(minKey)) + '–' + num(rule(maxKey)) + ')');
            }
        }

        private String scoreDossier() {
            Map<String, Object> s = score();
            List<String> d = new List<String>();
            d.add('RECORD STRENGTH SCORE (computed from the records; final, do not re-score. It rates how well the record supports the referral, not whether to accept the patient)');
            d.add('Level: ' + s.get('band') + ' | Score: ' + s.get('score') + ' out of 100 (' + s.get('points') + ' of ' + s.get('maxPoints') + ' points)'
                + ' | Bands: High ' + s.get('bandHighMin') + '+, Medium ' + s.get('bandMediumMin') + '+, Low below');
            List<String> capList = (List<String>) s.get('caps');
            if (capList.isEmpty()) d.add('Caps applied: none. Do not mention caps.');
            for (String cap : capList) {
                d.add('Cap applied: ' + cap);
            }
            for (Object o : (List<Object>) s.get('areas')) {
                Map<String, Object> a = (Map<String, Object>) o;
                d.add(a.get('label') + ': ' + a.get('points') + ' of ' + a.get('maxPoints'));
                for (Object io : (List<Object>) a.get('items')) {
                    Map<String, Object> it = (Map<String, Object>) io;
                    d.add('  - ' + it.get('label') + ': ' + it.get('points') + ' of ' + it.get('maxPoints') + ' | ' + it.get('detail'));
                }
            }
            return String.join(d, '\n');
        }

        // ---------------- facts for the portal ----------------

        public Map<String, Object> toFacts() {
            Account p = ref.Patient__r;
            Map<String, Object> facts = new Map<String, Object>();

            facts.put('referral', new Map<String, Object>{
                'name' => ref.Name,
                'dateLabel' => fmt(referralDate),
                'priority' => ref.Referral_Priority__c,
                'status' => ref.Referral_Status__c,
                'recommendedVisitBy' => ref.Recommended_Visit_By__c == null ? null : fmt(ref.Recommended_Visit_By__c),
                'receivedDate' => ref.Patient_Received_Date__c == null ? null : fmt(ref.Patient_Received_Date__c),
                'complaints' => ref.Chief_Complaints_and_Presenting_Symptoms__c,
                'diagnosis' => ref.Preliminary_Diagnosis__c,
                'reason' => reason(),
                'specialty' => specialty(),
                'doctor' => referringDoctor(),
                'facility' => referringFacility(),
                'referredTo' => ref.Referred_To__r == null ? null : ref.Referred_To__r.Name,
                'consent' => ref.Consent_Status__c,
                'consentDate' => ref.Consent_Granted_Date__c == null ? null : fmt(ref.Consent_Granted_Date__c),
                'underCareSince' => visits.isEmpty() || visitDate(visits[0]) == null ? null : fmt(visitDate(visits[0]))
            });

            facts.put('patient', new Map<String, Object>{
                'name' => p.Name,
                'age' => p.Age__c == null ? null : String.valueOf(p.Age__c.intValue()),
                'gender' => p.Gender__c,
                'birthDate' => p.Birth_Date__c == null ? null : fmt(p.Birth_Date__c),
                'bloodGroup' => p.Blood_Group__c,
                'allergies' => allergyText(),
                'pmjayVerified' => p.PMJAY_Scheme_Verified__c == true,
                'pmjayId' => mask(p.PM_JAY_ID__c),
                'phone' => mask(p.Phone),
                'registeredAt' => p.Registered_At__r == null ? null : p.Registered_At__r.Name,
                'conditions' => conditionText()
            });

            List<Map<String, Object>> visitRows = new List<Map<String, Object>>();
            for (Integer i = 0; i < visits.size(); i++) {
                ClinicalEncounter v = visits[i];
                visitRows.add(new Map<String, Object>{
                    'ref' => 'V' + (i + 1),
                    'name' => v.Name,
                    'dateLabel' => visitDate(v) == null ? NOT_RECORDED : fmt(v.StartDate),
                    'shortDate' => v.StartDate == null ? '' : v.StartDate.format('d MMM', TIMEZONE),
                    'type' => v.Patient_Type__c,
                    'facility' => v.Facility == null ? null : v.Facility.Name,
                    'doctor' => v.Prescribing_Doctor__r != null ? v.Prescribing_Doctor__r.Name : v.Doctor_Name__c,
                    'complaints' => v.Symptoms__c,
                    'findings' => v.Clinical_Findings__c,
                    'history' => v.Medical_History__c,
                    'bp' => v.Blood_Pressure__c,
                    'pulse' => num(v.Pulse_Rate_in_BPM__c),
                    'spo2' => v.SpO2__c == null ? null : num(v.SpO2__c) + '%',
                    'temp' => v.Body_Temperature__c == null ? null : num(v.Body_Temperature__c) + ' Â°F',
                    'weight' => v.Weight_in_Kg__c == null ? null : num(v.Weight_in_Kg__c) + ' kg',
                    'plan' => planText(v),
                    'medications' => medsForVisit(v.Id),
                    'isReferralVisit' => referralEncounterIds.contains(v.Id)
                });
            }
            facts.put('visits', visitRows);

            List<Map<String, Object>> requestRows = new List<Map<String, Object>>();
            if (hasConsultRequest()) {
                requestRows.add(new Map<String, Object>{
                    'ref' => 'C1', 'title' => specialty() + ' consultation',
                    'meta' => orNr(ref.Referral_Priority__c) + ' priority',
                    'detail' => ref.Preliminary_Diagnosis__c
                });
            }
            for (Integer i = 0; i < requests.size(); i++) {
                ClinicalServiceRequest r = requests[i];
                List<String> meta = new List<String>{ 'Ordered ' + fmt(r.CreatedDate) };
                if (r.Status != null) meta.add(r.Status);
                if (r.Completed_On__c != null) meta.add('completed ' + fmt(r.Completed_On__c));
                requestRows.add(new Map<String, Object>{
                    'ref' => 'R' + (i + 1),
                    'title' => String.isBlank(r.Requested_Test__c) ? r.Name : r.Requested_Test__c,
                    'meta' => String.join(meta, ', '),
                    'detail' => duplicateNotes.containsKey(r.Id) ? 'Repeats ' + duplicateNotes.get(r.Id) + '.' : r.Notes__c
                });
            }
            facts.put('requests', requestRows);

            List<Map<String, Object>> diagRows = new List<Map<String, Object>>();
            for (Integer i = 0; i < diagnostics.size(); i++) {
                DiagnosticSummary d = diagnostics[i];
                diagRows.add(new Map<String, Object>{
                    'ref' => 'D' + (i + 1),
                    'title' => diagnosticTitle(d),
                    'dateLabel' => diagnosticDate(d),
                    'status' => d.Status,
                    'result' => String.isNotBlank(d.Summary) ? d.Summary : d.ImageComments1
                });
            }
            facts.put('diagnostics', diagRows);

            List<Map<String, Object>> docRows = new List<Map<String, Object>>();
            for (Integer i = 0; i < documents.size(); i++) {
                Map<String, Object> doc = documents[i].clone();
                doc.put('ref', 'E' + (i + 1));
                docRows.add(doc);
            }
            facts.put('documents', docRows);

            List<Map<String, Object>> otherRows = new List<Map<String, Object>>();
            for (Referral__c o : otherReferrals) {
                otherRows.add(new Map<String, Object>{
                    'name' => o.Name,
                    'dateLabel' => o.Referral_Date__c == null ? NOT_RECORDED : fmt(o.Referral_Date__c),
                    'referredTo' => o.Referred_To__r == null ? null : o.Referred_To__r.Name,
                    'priority' => o.Referral_Priority__c,
                    'received' => o.Patient_Received_Date__c != null
                });
            }
            facts.put('otherReferrals', otherRows);
            facts.put('currentMedications', currentMeds());
            facts.put('score', score());
            facts.put('fit', fit());
            facts.put('flags', integrityFlags());
            return facts;
        }

        // ---------------- dossier for the prompt ----------------

        public String toDossier() {
            Account p = ref.Patient__r;
            List<String> d = new List<String>();

            d.add('REFERRAL');
            d.add('Referral ID: ' + ref.Name);
            d.add('Referral date: ' + fmt(referralDate));
            d.add('Priority: ' + orNr(ref.Referral_Priority__c));
            d.add('Status: ' + orNr(ref.Referral_Status__c));
            d.add('Referred by: ' + orNr(referringDoctor()) + ', ' + orNr(referringFacility()));
            d.add('Referred to: ' + orNr(ref.Referred_To__r == null ? null : ref.Referred_To__r.Name));
            d.add('Specialty requested: ' + orNr(specialty()));
            d.add('Recommended visit by: ' + (ref.Recommended_Visit_By__c == null ? NOT_RECORDED : fmt(ref.Recommended_Visit_By__c)));
            d.add('Chief complaints: ' + orNr(ref.Chief_Complaints_and_Presenting_Symptoms__c));
            d.add('Preliminary diagnosis: ' + orNr(ref.Preliminary_Diagnosis__c));
            d.add('Reason for referral: ' + orNr(reason()));

            d.add('');
            d.add('PATIENT');
            d.add('Age and sex: ' + (p.Age__c == null ? 'age not recorded' : p.Age__c.intValue() + ' years') + ', ' + orNr(p.Gender__c));
            d.add('Blood group: ' + orNr(p.Blood_Group__c));
            d.add('Known allergies: ' + orNr(allergyText()));
            d.add('Recorded conditions: ' + orNr(conditionText()));
            d.add('Registered at: ' + orNr(p.Registered_At__r == null ? null : p.Registered_At__r.Name));

            d.add('');
            d.add('CONSULTATIONS (oldest first)');
            if (visits.isEmpty()) d.add('None recorded.');
            for (Integer i = 0; i < visits.size(); i++) {
                ClinicalEncounter v = visits[i];
                d.add('[V' + (i + 1) + '] ' + v.Name + ' | ' + (v.StartDate == null ? 'date not recorded' : fmt(v.StartDate))
                    + ' | ' + orNr(v.Patient_Type__c) + ' consultation'
                    + (v.Facility != null ? ' | ' + v.Facility.Name : '')
                    + (referralEncounterIds.contains(v.Id) ? ' | referral raised at this visit' : ''));
                d.add('  Complaints: ' + orNr(v.Symptoms__c));
                d.add('  Findings: ' + orNr(v.Clinical_Findings__c));
                d.add('  History: ' + orNr(v.Medical_History__c));
                d.add('  Vitals: BP ' + orNr(v.Blood_Pressure__c) + ', pulse ' + orNr(num(v.Pulse_Rate_in_BPM__c))
                    + ', SpO2 ' + orNr(num(v.SpO2__c)) + '%, temperature ' + orNr(num(v.Body_Temperature__c))
                    + ' Â°F, weight ' + orNr(num(v.Weight_in_Kg__c)) + ' kg, height ' + orNr(num(v.Height_in_cm__c)) + ' cm');
                d.add('  Plan: ' + orNr(planText(v)));
                d.add('  Medicines prescribed: ' + orNr(medsForVisit(v.Id)));
            }

            d.add('');
            d.add('SERVICES REQUESTED');
            if (hasConsultRequest()) {
                d.add('[C1] Specialist consultation: ' + specialty() + ', ' + orNr(ref.Referral_Priority__c) + ' priority');
            }
            if (requests.isEmpty()) d.add('No investigations ordered.');
            for (Integer i = 0; i < requests.size(); i++) {
                ClinicalServiceRequest r = requests[i];
                d.add('[R' + (i + 1) + '] ' + r.Name + ' | ' + orNr(r.Requested_Test__c) + ' | ordered ' + fmt(r.CreatedDate)
                    + ' | status ' + orNr(r.Status) + ' | priority ' + orNr(r.Priority)
                    + ' | completed ' + (r.Completed_On__c == null ? 'no' : fmt(r.Completed_On__c))
                    + (r.Encounter != null ? ' | from ' + r.Encounter.Name : '')
                    + (String.isNotBlank(r.Notes__c) ? ' | notes: ' + r.Notes__c : ''));
            }

            d.add('');
            d.add('DIAGNOSTIC RESULTS');
            if (diagnostics.isEmpty()) d.add('None recorded.');
            for (Integer i = 0; i < diagnostics.size(); i++) {
                DiagnosticSummary x = diagnostics[i];
                d.add('[D' + (i + 1) + '] ' + x.Name + ' | ' + diagnosticTitle(x) + ' | ' + diagnosticDate(x)
                    + ' | status ' + orNr(x.Status)
                    + ' | result text: ' + orNr(String.isNotBlank(x.Summary) ? x.Summary : x.ImageComments1)
                    + ' | report files attached: ' + (documentCountByEntity.containsKey(x.Id) ? String.valueOf(documentCountByEntity.get(x.Id)) + ' (the result is in the attached report)' : 'none'));
            }

            d.add('');
            d.add('CURRENT MEDICINES');
            d.add(orNr(currentMeds()));

            d.add('');
            d.add('DOCUMENTS ATTACHED');
            if (documents.isEmpty()) d.add('None shared.');
            for (Integer i = 0; i < documents.size(); i++) {
                Map<String, Object> doc = documents[i];
                d.add('[E' + (i + 1) + '] ' + doc.get('title') + ' | ' + doc.get('source') + ' | uploaded ' + doc.get('dateLabel'));
            }

            d.add('');
            d.add('OTHER REFERRALS FOR THIS PATIENT');
            if (otherReferrals.isEmpty()) d.add('None.');
            for (Referral__c o : otherReferrals) {
                d.add(o.Name + ' | ' + (o.Referral_Date__c == null ? NOT_RECORDED : fmt(o.Referral_Date__c))
                    + ' | to ' + orNr(o.Referred_To__r == null ? null : o.Referred_To__r.Name)
                    + ' | ' + orNr(o.Referral_Priority__c) + ' | ' + orNr(o.Preliminary_Diagnosis__c)
                    + ' | ' + (o.Patient_Received_Date__c == null ? 'not received' : 'received ' + fmt(o.Patient_Received_Date__c)));
            }

            d.add('');
            d.add('SYSTEM CHECKS');
            for (String line : systemChecks()) d.add('- ' + line);

            d.add('');
            d.add(scoreDossier());

            d.add('');
            d.add(fitDossier());

            d.add('');
            d.add(flagsDossier());

            return String.join(d, '\n');
        }

        // ---------------- small helpers ----------------

        private Date visitDate(ClinicalEncounter v) {
            return v.StartDate == null ? null : v.StartDate.date();
        }

        private String planText(ClinicalEncounter v) {
            List<String> parts = new List<String>();
            if (String.isNotBlank(v.Care_Instructions__c)) parts.add(v.Care_Instructions__c.trim());
            if (String.isNotBlank(v.Required_before_follow_up__c)) parts.add('Tests before follow-up: ' + v.Required_before_follow_up__c.trim());
            if (v.Follow_up_Date__c != null) parts.add('Follow-up ' + fmt(v.Follow_up_Date__c) + '.');
            if (String.isNotBlank(v.Comments_Remarks__c)) parts.add(v.Comments_Remarks__c.trim());
            return String.join(parts, ' ');
        }

        private String diagnosticTitle(DiagnosticSummary x) {
            if (String.isNotBlank(x.Sample_Type__c)) return x.Sample_Type__c;
            if (x.Clinical_Service_Request__r != null && String.isNotBlank(x.Clinical_Service_Request__r.Requested_Test__c)) {
                return x.Clinical_Service_Request__r.Requested_Test__c;
            }
            return x.Name;
        }

        private String diagnosticDate(DiagnosticSummary x) {
            if (x.Sample_Drawn_Date__c != null) return 'sample ' + fmt(x.Sample_Drawn_Date__c);
            if (x.IssuedDateTime != null) return 'issued ' + fmt(x.IssuedDateTime);
            if (x.EffectiveStartDateTime != null) return fmt(x.EffectiveStartDateTime);
            return 'recorded ' + fmt(x.CreatedDate);
        }

        private String allergyText() {
            List<String> parts = new List<String>();
            if (ref.Patient__r != null && String.isNotBlank(ref.Patient__r.Known_Allergies__c)) {
                parts.add(ref.Patient__r.Known_Allergies__c.trim());
            }
            for (AllergyIntolerance a : allergies) {
                parts.add(a.Name + (a.Severity != null ? ' (' + a.Severity + ')' : ''));
            }
            return String.join(parts, '; ');
        }

        private String conditionText() {
            List<String> parts = new List<String>();
            for (HealthCondition c : conditions) {
                String name = String.isNotBlank(c.ProblemName) ? c.ProblemName : c.ProblemDescription;
                if (String.isNotBlank(name)) {
                    parts.add(name + (c.ConditionStatus != null ? ' (' + c.ConditionStatus + ')' : ''));
                }
            }
            return String.join(parts, '; ');
        }
    }

    // ------------------------------------------------------------------
    // Formatting
    // ------------------------------------------------------------------

    private static String fmt(Date d) {
        return d == null ? NOT_RECORDED : Datetime.newInstanceGmt(d, Time.newInstance(12, 0, 0, 0)).formatGmt('d MMMM yyyy');
    }

    private static String fmt(Datetime dt) {
        return dt == null ? NOT_RECORDED : dt.format('d MMMM yyyy', TIMEZONE);
    }

    private static String num(Decimal n) {
        return n == null ? null : n.stripTrailingZeros().toPlainString();
    }

    private static String orNr(String s) {
        return String.isBlank(s) ? NOT_RECORDED : s.trim();
    }

    private static String mask(String s) {
        if (String.isBlank(s)) return null;
        String t = s.deleteWhitespace();
        if (t.length() <= 4) return 'â€¢â€¢â€¢â€¢';
        return t.left(2) + 'â€¢'.repeat(t.length() - 4) + t.right(2);
    }

    private static Set<String> testNames(String requested) {
        Set<String> names = new Set<String>();
        if (String.isBlank(requested)) return names;
        for (String part : requested.split('[,;\\n]')) {
            String n = part.trim().toLowerCase();
            if (n.length() > 1) names.add(n);
        }
        return names;
    }

    private static AuraHandledException auraError(String message) {
        AuraHandledException e = new AuraHandledException(message);
        e.setMessage(message);
        return e;
    }

    private static Integer bandRank(String band) {
        return band == 'High' ? 3 : band == 'Medium' ? 2 : 1;
    }

    /** One weighted area of the score and the data points that earned or lost its points. */
    public class ScoreArea {
        String key;
        String label;
        Decimal points = 0;
        Decimal maxPoints = 0;
        List<Map<String, Object>> items = new List<Map<String, Object>>();

        ScoreArea(String key, String label) {
            this.key = key;
            this.label = label;
        }

        void add(String itemLabel, Decimal earned, Decimal available, String detail) {
            items.add(new Map<String, Object>{
                'label' => itemLabel,
                'points' => earned.setScale(1),
                'maxPoints' => available.setScale(1),
                'met' => available > 0 && earned >= available,
                'detail' => detail
            });
            points += earned;
            maxPoints += available;
        }

        void addPresence(String itemLabel, String value, Decimal available) {
            Boolean present = String.isNotBlank(value);
            add(itemLabel, present ? available : 0, available, present ? value.trim().abbreviate(160) : NOT_RECORDED);
        }

        Map<String, Object> toMap() {
            Decimal ratio = maxPoints == 0 ? 0 : points / maxPoints;
            return new Map<String, Object>{
                'key' => key,
                'label' => label,
                'points' => points.setScale(1),
                'maxPoints' => maxPoints.setScale(1),
                'status' => ratio >= 0.8 ? 'green' : ratio >= 0.5 ? 'amber' : 'red',
                'items' => items
            };
        }
    }

    public class ValidationException extends Exception {}
}