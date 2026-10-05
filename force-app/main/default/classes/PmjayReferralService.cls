public without sharing class PmjayReferralService {
    

    // Inner class ResultWrapper to return status, message, and record ID
    public class ResultWrapper {
        @AuraEnabled
        public string status {get;set;}
        @AuraEnabled
        public string message {get;set;}
        @AuraEnabled
        public Id recordId {get;set;} // Added to return the ID of created records
        @AuraEnabled
        public Id phwcDoctorId {get;set;} // Added to return PHWC Doctor ID from encounter
        @AuraEnabled
        public String phwcDoctorName {get;set;} // Optional: to display in LWC
    }

@AuraEnabled
public static String downloadZip(
    List<Id> contentVersionIds,
    List<Id> attachmentIds
) {
    Compression.ZipWriter zipWriter = new Compression.ZipWriter();

    // -------------------------
    // 1️⃣ ContentVersion (Files)
    // -------------------------
    if (contentVersionIds != null && !contentVersionIds.isEmpty()) {
        for (ContentVersion cv : [
            SELECT PathOnClient, Title, FileExtension, VersionData
            FROM ContentVersion
            WHERE Id IN :contentVersionIds
        ]) {
            String fileName;

            // PathOnClient kabhi null hota hai
            if (cv.PathOnClient != null) {
                fileName = cv.PathOnClient;
            } else {
                fileName = cv.Title + '.' + cv.FileExtension;
            }

            zipWriter.addEntry(fileName, cv.VersionData);
        }
    }

    // -------------------------
    // 2️⃣ Attachment (Legacy)
    // -------------------------
    if (attachmentIds != null && !attachmentIds.isEmpty()) {
        for (Attachment att : [
            SELECT Name, Body
            FROM Attachment
            WHERE Id IN :attachmentIds
        ]) {
            zipWriter.addEntry(att.Name, att.Body);
        }
    }

    // -------------------------
    // 3️⃣ Final ZIP
    // -------------------------
    Blob zipBlob = zipWriter.getArchive();
    return EncodingUtil.base64Encode(zipBlob);
}


    /**
     * @description Retrieves patient details based on a referral ID.
     * @param referralId The Name of the Referral__c record (e.g., 'RF-0001').
     * @return Map<String, Object> containing patient details and success status, including PHWC Doctor ID from latest Clinical Encounter.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, Object> getPatientDetailsByReferralId(String referralId) {
        Map<String, Object> result = new Map<String, Object>();
        result.put('success', false);
        System.debug('PmjayReferralService: Entering getPatientDetailsByReferralId with referralId: ' + referralId);

        if (String.isBlank(referralId)) {
            result.put('message', 'Referral ID cannot be blank.');
            System.debug('PmjayReferralService: Referral ID is blank.');
            return result;
        }

        try {
            List<Referral__c> referrals = [
                SELECT Id,
                    Name,
                    Encounter__c,
                    Patient__c, // Lookup to Account (Patient)
                    PrimarySpecialty__c,
                    Preliminary_diagnosis__c,
                    Patient__r.Name,
                    Patient__r.PersonEmail,
                    Patient__r.Birth_Date__c,
                    Patient__r.Marital_Status__c,
                    Patient__r.AADHAR_Number__c,
                    Patient__r.PM_JAY_ID__c, // Example custom field for PMJAY ID on Account
                    Patient__r.Member_ID__c, // Example custom field for Member ID on Account
                    Patient__r.Gender__c,
                    Patient__r.Phone,
                    Patient__r.Age__c, // Example custom field for Age on Account
                    Patient__r.PMJAY_Scheme_Verified__c, // Example custom field
                    Patient__r.ABHA_Number__c, // Example custom field
                    Patient__r.PMJAY_Family_ID__c, // Example custom field
                    Referred_By__r.Name,
                    Patient__r.Registered_At__r.Name,
                    Patient__r.Attendant_Name__c,
                    Patient__r.Attendant_Relationship__c,
                    Patient__r.Attendant_Phone__c,
                    Consent_Status__c,
                    Consent_Mode__c,
                    Consented_File_IDs__c, Patient_Received_Date__c
                FROM Referral__c
                WHERE Name = :referralId
                LIMIT 1
            ];
            System.debug('PmjayReferralService: Query for Referral__c executed. Found ' + referrals.size() + ' records.');


            if (!referrals.isEmpty()) {
                Referral__c referral = referrals[0];
                Boolean enforceConsent = referral.Consent_Mode__c != 'Manual';
                if (referral.Consent_Status__c != 'Granted') {
                    result.put('success', false);
                    result.put('consentGranted', false);
                    result.put(
                        'message',
                        'Patient consent is pending or not granted. Empanelled hospitals are not authorized to view patient details.'
                    );
                    return result; // ⛔ EXIT IMMEDIATELY
                }
                    // 1. Already Received
                Boolean alreadyReceived = referral.Patient_Received_Date__c != null;
                result.put('alreadyReceived', alreadyReceived);

                // 2. Care Plan Exists
                Boolean carePlanExists = [
                    SELECT COUNT()
                    FROM Care_Plan__c
                    WHERE Patient__c = :referral.Patient__c
                ] > 0;

                result.put('carePlanExists', carePlanExists);

                
                Account patientAccount = referral.Patient__r;
                if (patientAccount != null) {
                    result.put('consentGranted', true);
                    result.put('success', true);
                    result.put('patientAccountId', referral.Patient__c); // Return Patient's Account ID
                    result.put('patientFullName', patientAccount.Name);
                    result.put('patientAge', String.valueOf(patientAccount.Age__c));
                    result.put('patientGender', patientAccount.Gender__c);
                    result.put('pmjayId', patientAccount.PM_JAY_ID__c);
                    result.put('memberId', patientAccount.Member_ID__c);
                    result.put('message', 'Patient details fetched successfully.');
                    result.put('patientPhone', patientAccount.Phone);
                    result.put('drName', referral.Referred_By__r.Name);
                    result.put('phwcName',patientAccount.Registered_At__r.Name);
                    result.put('recommendedSpeciality',referral.PrimarySpecialty__c);
                    result.put('recommendedDiagnosis',referral.Preliminary_diagnosis__c);
                    result.put('attendantName',patientAccount.Attendant_Name__c);
                    result.put('attendantPhone',patientAccount.Attendant_Phone__c);
                    result.put('attendantRelation',patientAccount.Attendant_Relationship__c);
                    System.debug('PmjayReferralService: Patient details found. Patient ID: ' + referral.Patient__c);

                    Set<Id> consentedFileIds = new Set<Id>();

                    if (enforceConsent && String.isNotBlank(referral.Consented_File_IDs__c)) {
                        for (String idStr : referral.Consented_File_IDs__c.split(',')) {
                            try {
                                consentedFileIds.add((Id)idStr.trim());
                            } catch (Exception e) {
                                // ignore bad ids
                            }
                        }
                    }
                    
                    Set<Id> consentedDocIds = new Set<Id>();

                    if (enforceConsent && !consentedFileIds.isEmpty()) {

                        // Convert ContentVersion → ContentDocument
                        for (ContentVersion cv : [
                            SELECT Id, ContentDocumentId
                            FROM ContentVersion
                            WHERE Id IN :consentedFileIds
                        ]) {
                            consentedDocIds.add(cv.ContentDocumentId);
                        }

                        // Add direct ContentDocumentIds
                        consentedDocIds.addAll(consentedFileIds);
                    }

                    List<Map<String, String>> summaryFiles = new List<Map<String, String>>();
                    List<Map<String, String>> diagnosticFiles = new List<Map<String, String>>();
                    Set<Id> processedDocIds = new Set<Id>();

                    /* -------- CATEGORY 1: SUMMARY FILES (Directly on Referral) -------- */
                    
                    // Handle Classic Attachments
                    for (Attachment att : [SELECT Id, Name,Body FROM Attachment WHERE ParentId = :referral.Id]) {
                        // 🔒 Consent check
                        if (enforceConsent && !consentedFileIds.contains(att.Id)) {
                            continue;
                        }

                        String ext = att.Name.contains('.') ? att.Name.substringAfterLast('.') : 'unknown';
                        summaryFiles.add(new Map<String, String>{
                            'Id' => att.Id,
                            'Title' => att.Name,
                            'Type' => 'Attachment', // Crucial for JS
                            'Extension' => ext.toLowerCase(),
                            'Base64Data' => EncodingUtil.base64Encode(att.Body)
                        });
                    }

                    // Handle Salesforce Files (ContentDocument)
                    Set<Id> referralDocIds = new Set<Id>();
                    for (ContentDocumentLink cdl : [
                        SELECT ContentDocumentId 
                        FROM ContentDocumentLink 
                        WHERE LinkedEntityId = :referral.Id
                    ]) {
                        if (!enforceConsent || consentedFileIds.contains(cdl.ContentDocumentId)) {
                            referralDocIds.add(cdl.ContentDocumentId);
                            processedDocIds.add(cdl.ContentDocumentId);
                        }
                    }
                
                    if (String.isNotBlank(referral.Encounter__c)) {
                        List<String> encounterNames = referral.Encounter__c.split(',');
                        
                        // Get Clinical Service Requests linked to these encounters
                        Map<Id, ClinicalServiceRequest> csrMap = new Map<Id, ClinicalServiceRequest>([
                            SELECT Id FROM ClinicalServiceRequest 
                            WHERE Encounter.Name IN :encounterNames
                        ]);

                        if (!csrMap.isEmpty()) {
                            // Get Diagnostic Summaries linked to CSRs
                            Map<Id, DiagnosticSummary> dsMap = new Map<Id, DiagnosticSummary>([
                                SELECT Id FROM DiagnosticSummary 
                                WHERE Clinical_Service_Request__c IN :csrMap.keySet()
                            ]);

                            if (!dsMap.isEmpty()) {
                                Set<Id> diagDocIds = new Set<Id>();
                                for (ContentDocumentLink cdl : [
                                    SELECT ContentDocumentId
                                    FROM ContentDocumentLink 
                                    WHERE LinkedEntityId IN :dsMap.keySet()
                                ]) {
                                    // 🔒 Consent + duplicate check
                                    if (
                                        !processedDocIds.contains(cdl.ContentDocumentId) &&
                                        (
                                            !enforceConsent ||
                                            consentedDocIds.contains(cdl.ContentDocumentId)
                                        )
                                    ) {
                                        diagDocIds.add(cdl.ContentDocumentId);
                                    }
                                }

                                if (!diagDocIds.isEmpty()) {
                                    for (ContentVersion cv : [
                                        SELECT Id, Title, FileExtension, ContentDocumentId, VersionData
                                        FROM ContentVersion 
                                        WHERE ContentDocumentId IN :diagDocIds AND IsLatest = true
                                    ]) {
                                        diagnosticFiles.add(new Map<String, String>{
                                            'Id' => cv.Id,
                                            'Title' => cv.Title + '.' + cv.FileExtension,
                                            'Type' => 'File',
                                            'Extension' => cv.FileExtension.toLowerCase(),
                                            'Base64Data' => EncodingUtil.base64Encode(cv.VersionData)
                                        });
                                    }
                                }
                            }
                        }
                    }

                    result.put('summaryFiles', summaryFiles);
                    result.put('diagnosticFiles', diagnosticFiles);

                    // Query for the latest Clinical Encounter and its Prescribing Doctor
                    List<ClinicalEncounter> latestEncounters = [
                        SELECT Id, Prescribing_Doctor__c, Prescribing_Doctor__r.Name
                        FROM ClinicalEncounter
                        WHERE PatientId = :referral.Patient__c
                        ORDER BY StartDate DESC
                        LIMIT 1
                    ];

                    if (!latestEncounters.isEmpty() && latestEncounters[0].Prescribing_Doctor__c != null) {
                        result.put('phwcDoctorId', latestEncounters[0].Prescribing_Doctor__c);
                        result.put('phwcDoctorName', latestEncounters[0].Prescribing_Doctor__r.Name);
                        System.debug('PmjayReferralService: Found PHWC Doctor from latest Clinical Encounter: ' + latestEncounters[0].Prescribing_Doctor__r.Name + ' (ID: ' + latestEncounters[0].Prescribing_Doctor__c + ')');
                    } else {
                        System.debug('PmjayReferralService: No Prescribing Doctor found on latest Clinical Encounter for Patient ID: ' + referral.Patient__c);
                        result.put('phwcDoctorId', null);
                        result.put('phwcDoctorName', null);
                    }

                } else {
                    result.put('message', 'No patient account associated with this referral ID.');
                    System.debug('PmjayReferralService: No patient account associated with referral.');
                }
            } else {
                result.put('message', 'Referral ID not found.');
                System.debug('PmjayReferralService: Referral ID ' + referralId + ' not found.');
            }
        } catch (QueryException qe) {
            result.put('message', 'Query Error: ' + qe.getMessage() + '. Please check your data and field permissions.');
            System.debug('PmjayReferralService Query Exception: ' + qe.getMessage());
        } catch (Exception e) {
            result.put('message', 'An unexpected error occurred: ' + e.getMessage());
            System.debug('PmjayReferralService General Exception: ' + e.getMessage());
        }
        System.debug('PmjayReferralService: Exiting getPatientDetailsByReferralId. Result: ' + result);
        return result;
    }


    /**
     * @description Sends an OTP to the nodal person's contact number of the selected hospital.
     * Generates and stores a new OTP if none exists.
     * @param selectedCity The city of the hospital.
     * @param selectedHospital The name of the hospital.
     * @return ResultWrapper indicating success or failure of OTP sending.
     */
    @AuraEnabled
    public static ResultWrapper sendOTP(String selectedCity, String selectedHospital) {
        ResultWrapper resultWrap = new ResultWrapper();
        try {
            List<HealthcareProvider> healthCareProviderList = [
                SELECT Id, Name, Nodal_Person_Contact_Number__c, OTP__c, Address__City__s
                FROM HealthcareProvider
                WHERE Name = :selectedHospital AND Address__City__s = :selectedCity AND Nodal_Person_Contact_Number__c != null
                LIMIT 1
            ];

            if(healthCareProviderList.isEmpty()){
                resultWrap.status = 'warning';
                resultWrap.message = 'No Hospital found or Nodal Person Contact Number is missing. Please select a different Hospital or city.';
                return resultWrap;
            } else {
                // Generate new OTP if it's null or expired (for demo, always generate new if null)
                if(healthCareProviderList[0].OTP__c == null){
                    Integer otpLength = 6;
                    String otpGenerated = String.valueOf(Math.abs(Crypto.getRandomLong())).substring(0, otpLength);
                    System.debug('otpGenerated::'+otpGenerated);
                    healthCareProviderList[0].OTP__c = Decimal.valueOf(otpGenerated);
                    update healthCareProviderList[0];
                }

                // String phoneNumber = healthCareProviderList[0].Nodal_Person_Contact_Number__c;
                String phoneNumber ='6202845249';
                String maskedPhoneNumber = '******' + phoneNumber.right(4); // Mask all but last 4 digits
                // String message = 'Please use this One Time Password(OTP) '+healthCareProviderList[0].OTP__c+' to validate your Mobile Number. Valid for 5 minutes.';
                // 1️⃣ Phone number format (+91)
                String formattedPhone = ReferralTriggerHelper.formatToE164(phoneNumber);

                // 2️⃣ Bilingual OTP message (optional but recommended)
                String smsMessage =
                    'Your OTP is ' + healthCareProviderList[0].OTP__c +
                    '. It is valid for 5 minutes. Do not share it with anyone.\n' +
                    'आपका ओटीपी ' + healthCareProviderList[0].OTP__c +
                    ' है। यह 5 मिनट के लिए मान्य है। कृपया इसे किसी से साझा न करें।\n\n' +
                    '- Dhanwantari Health Portal';

                ReferralTriggerHelper.sendSMSAsync1(formattedPhone, smsMessage);

                resultWrap.status = 'success';
                resultWrap.message = 'OTP has been sent to the registered mobile number (ending in ' + maskedPhoneNumber + ').';
                return resultWrap;
            }
        } catch(Exception ex) {
            System.debug('Exception in PmjayReferralService sendOTP: ' + ex.getMessage() + ' at line number: ' + ex.getLineNumber());
            resultWrap.status = 'error';
            resultWrap.message = 'Failed to send OTP: ' + String.valueOf(ex.getMessage());
            return resultWrap;
        }
    }

    @AuraEnabled
    public static String getCityFromLatLong(Decimal lat, Decimal lng) {
        try {
            Http http = new Http();
            HttpRequest req = new HttpRequest();

            String endpoint =
                'https://nominatim.openstreetmap.org/reverse'
                + '?format=json'
                + '&lat=' + lat
                + '&lon=' + lng
                + '&zoom=10'
                + '&addressdetails=1';

            req.setEndpoint(endpoint);
            req.setMethod('GET');

            // OSM requires User-Agent
            req.setHeader('User-Agent', 'Salesforce-PMJAY-Portal');

            HttpResponse res = http.send(req);

            if (res.getStatusCode() == 200 && String.isNotBlank(res.getBody())) {

                Map<String, Object> response = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());

                if (response.containsKey('address')) {

                    Map<String, Object> address =
                        (Map<String, Object>) response.get('address');

                    System.debug('🏠 Address Map = ' + address);

                    // 🔥 INDIA-SAFE fallback order
                    if (address.containsKey('city')) {
                        System.debug('✅ City found (city)');
                        return (String) address.get('city');
                    }
                    if (address.containsKey('city_district')) {
                        System.debug('✅ City found (city_district)');
                        return (String) address.get('city_district');
                    }
                    if (address.containsKey('state_district')) {
                        System.debug('✅ City found (state_district)');
                        return (String) address.get('state_district');
                    }
                    if (address.containsKey('town')) {
                        System.debug('✅ City found (town)');
                        return (String) address.get('town');
                    }
                    if (address.containsKey('village')) {
                        System.debug('✅ City found (village)');
                        return (String) address.get('village');
                    }
                    if (address.containsKey('county')) {
                        System.debug('✅ City found (county)');
                        return (String) address.get('county');
                    }

                    System.debug('⚠️ No suitable city key found in address');
                } else {
                    System.debug('❌ Address key missing in OSM response');
                }
            } else {
                System.debug('❌ OSM call failed or empty response');
            }
        } catch (Exception e) {
            System.debug('❌ Exception in getCityFromLatLong');
            System.debug('❌ Message = ' + e.getMessage());
            System.debug('❌ Line    = ' + e.getLineNumber());
            System.debug('❌ Stack   = ' + e.getStackTraceString());
        }

        System.debug('🚫 Returning NULL city');
        return null;
    }

    /**
     * @description Verifies the entered OTP against the one stored for the selected hospital.
     * @param selectedCity The city of the hospital.
     * @param selectedHospital The name of the hospital.
     * @param enteredOTP The OTP entered by the user.
     * @return ResultWrapper indicating success or failure of OTP verification.
     */
    @AuraEnabled
    public static ResultWrapper verifyOTP(String selectedCity, String selectedHospital, String enteredOTP) {
        ResultWrapper resultWrap = new ResultWrapper();
        try {
            List<HealthcareProvider> healthCareProviderList = [
                SELECT Id, Name, OTP__c
                FROM HealthcareProvider
                WHERE Name = :selectedHospital AND Address__City__s = :selectedCity
                LIMIT 1
            ];

            if (healthCareProviderList.isEmpty()) {
                resultWrap.status = 'error';
                resultWrap.message = 'Hospital not found for the selected city and name.';
                return resultWrap;
            }

            HealthcareProvider hospital = healthCareProviderList[0];
            if (hospital.OTP__c != null && String.valueOf(hospital.OTP__c).equals(enteredOTP)) {
                // Clear OTP after successful verification for security
                hospital.OTP__c = null;
                update hospital;
                resultWrap.status = 'success';
                resultWrap.message = 'OTP verified successfully.';
            } else {
                resultWrap.status = 'error';
                resultWrap.message = 'Invalid OTP. Please try again.';
            }
        } catch (Exception ex) {
            System.debug('Exception in PmjayReferralService verifyOTP: ' + ex.getMessage() + ' at line number: ' + ex.getLineNumber());
            resultWrap.status = 'error';
            resultWrap.message = 'An unexpected error occurred during OTP verification: ' + ex.getMessage();
        }
        return resultWrap;
    }

    /**
     * @description Retrieves a list of distinct cities from HealthcareProvider records.
     * @return List<Map<String, String>> of city options for a combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getDistinctCities() {
        List<Map<String, String>> cityList = new List<Map<String, String>>();
        List<AggregateResult> results = [SELECT Address__City__s FROM HealthcareProvider WHERE Address__City__s != NULL GROUP BY Address__City__s ORDER BY Address__City__s];

        for (AggregateResult ar : results) {
            String cityName = (String) ar.get('Address__City__s');
            cityList.add(new Map<String, String>{
                'label' => cityName,
                'value' => cityName
            });
        }
        return cityList;
    }

    /**
     * @description Retrieves a list of hospitals for a given city.
     * @param city The city to filter hospitals by.
     * @return List<Map<String, String>> of hospital options for a combobox.
     */
    @AuraEnabled(cacheable=true)
    public static List<Map<String, String>> getHospitalsByCity(String city) {
        List<Map<String, String>> hospitalList = new List<Map<String, String>>();
        if (String.isNotBlank(city)) {
            List<HealthcareProvider> hospitals = [SELECT Id, Name FROM HealthcareProvider WHERE Address__City__s = :city ORDER BY Name];
            for (HealthcareProvider hosp : hospitals) {
                hospitalList.add(new Map<String, String>{
                    'label' => hosp.Name,
                    'value' => hosp.Name
                });
            }
        }
        return hospitalList;
    }

    /**
     * @description Creates a new Care_Plan__c record or updates an existing one, linked to a Patient.
     * Now includes Care Instructions, Follow Up Date, Red Flags, AND Medications.
     * @param patientId The ID of the Patient (Account) record.
     * @param careInstructions The care instructions text to store on Care Plan.
     * @param nextFollowupDate The next follow-up date to store on Care Plan.
     * @param redFlagsToMonitor The red flags to monitor text to store on Care Plan.
     * @param medicationsJson JSON string of medication details to create MedicationRequest records.
     * @return ResultWrapper containing the status, message, and ID of the new Care Plan.
     */
    @AuraEnabled
    public static ResultWrapper createCarePlanRecord(
        Id patientId,
        String careInstructions,
        Date nextFollowupDate,
        String redFlagsToMonitor,
        String medicationsJson // NEW: Moved medication JSON here
    ) {
        ResultWrapper resultWrap = new ResultWrapper();
        System.debug('PmjayReferralService: Entering createCarePlanRecord.');
        System.debug('PmjayReferralService: Parameters received for Care Plan: patientId=' + patientId +
                      ', careInstructions=' + careInstructions +
                      ', nextFollowupDate=' + nextFollowupDate +
                      ', redFlagsToMonitor=' + redFlagsToMonitor +
                      ', medicationsJson length=' + (medicationsJson != null ? medicationsJson.length() : 0)); // Log medication JSON length

        Savepoint sp = Database.setSavepoint(); // Set a savepoint for transaction control

        try {
            if (patientId == null) {
                resultWrap.status = 'error';
                resultWrap.message = 'Patient ID is required to create a Care Plan.';
                System.debug('PmjayReferralService: Error - Patient ID is null for Care Plan.');
                return resultWrap;
            }

            List<Care_Plan__c> existingPlans = [
                SELECT Id
                FROM Care_Plan__c
                WHERE Patient__c = :patientId
                LIMIT 1
            ];

            if (!existingPlans.isEmpty()) {
                resultWrap.status = 'error';
                resultWrap.message = 'Care plan already exists for this patient.';
                return resultWrap;
            }

            Care_Plan__c newCarePlan = new Care_Plan__c(
                Patient__c = patientId,
                Start_Date__c = Date.today().addDays(1), // Set start date to today + 1 day
                Status__c = 'Active', // Set status to Active
                Care_Instruction__c = careInstructions, // Map care instructions to Care Plan
                Follow_Up_Date__c = nextFollowupDate, // Map follow up date to Care Plan
                Red_Flags_To_Monitor__c = redFlagsToMonitor // Map red flags to Care Plan
            );

            insert newCarePlan;
            System.debug('PmjayReferralService: New Care_Plan__c object inserted. ID: ' + newCarePlan.Id);

            // --- Handle MedicationRequest creation from the JSON string (MOVED HERE) ---
            System.debug('medicationsJson::'+medicationsJson);
            if (String.isNotBlank(medicationsJson)) {
                try {
                    List<Object> medsList = (List<Object>) JSON.deserializeUntyped(medicationsJson);
                    System.debug('medsList::'+medsList);
                    List<MedicationRequest> medicationRequestsToInsert = new List<MedicationRequest>();
                    
                    // You might need to query for existing Medication records
                    // or create them if the 'medicationName' is provided but not 'medicationId'.
                    // For simplicity, this example assumes 'medicationId' is always passed correctly
                    // or that `MedicationId` field on `MedicationRequest` is not required.
                    // If MedicationId is required and might be missing, add logic here to fetch or create Medication records.
                    
                       Id recordTypeId = Schema.SObjectType.MedicationRequest
                       .getRecordTypeInfosByDeveloperName()
                       .get('Care_Plan')
                       .getRecordTypeId();
                    
                    for (Object medicationObj : medsList) {
                        Map<String, Object> medicationMap = (Map<String, Object>) medicationObj;
                        
                        MedicationRequest medRequest = new MedicationRequest();
                        
                        // IMPORTANT: Correctly link to your custom Care_Plan__c object.
                        // You MUST have a custom lookup field on MedicationRequest named 'Care_Plan__c'
                        // that points to your custom Care_Plan__c object for this to work.
                        medRequest.Care_Plan__c = newCarePlan.Id; 
                        
                        // IMPORTANT: The standard MedicationRequest object has a PatientId lookup.
                        // You uncommented this line. Ensure this is linked.
                        medRequest.PatientId = patientId; 

                        if(medicationMap.containsKey('medicationId') && medicationMap.get('medicationId') != null){
                            medRequest.MedicationId = (Id)medicationMap.get('medicationId'); // Link to the standard Medication record
                        } else if (medicationMap.containsKey('medicationName') && String.isNotBlank((String)medicationMap.get('medicationName'))) {
                            // If your LWC sends 'medicationName' and you want to use it as a text field,
                            // you might have a custom text field on MedicationRequest like 'Medication_Name_Text__c'.
                            // medRequest.Medication_Name_Text__c = (String) medicationMap.get('medicationName');
                            // If MedicationId is required, you'd need to query for or create a standard Medication record here.
                        }
                        
                        if (medicationMap.containsKey('instructions')) {
                            medRequest.Instructions__c = (String) medicationMap.get('instructions');
                        }
                        if (medicationMap.containsKey('durationDays') && medicationMap.get('durationDays') != null && String.isNotBlank(String.valueOf(medicationMap.get('durationDays')))) {
                            try {
                                medRequest.Duration_Days__c = Decimal.valueOf(String.valueOf(medicationMap.get('durationDays')));
                            } catch (Exception e) {
                                System.debug('PmjayReferralService: Error converting durationDays "' + medicationMap.get('durationDays') + '" to Decimal. ' + e.getMessage());
                            }
                        }
                        if (medicationMap.containsKey('startFrom') && medicationMap.get('startFrom') != null && String.isNotBlank(String.valueOf(medicationMap.get('startFrom')))) {
                            try {
                                medRequest.Prescription_Start_Date__c = Date.valueOf(String.valueOf(medicationMap.get('startFrom')));
                            } catch (Exception e) {
                                System.debug('PmjayReferralService: Error converting startFrom date "' + medicationMap.get('startFrom') + '" to Date. ' + e.getMessage());
                            }
                        }
                        if (medicationMap.containsKey('morningDosage')) {
                            medRequest.Morning__c = (String) medicationMap.get('morningDosage');
                        }
                        if (medicationMap.containsKey('afternoonDosage')) {
                            medRequest.Afternoon__c = (String) medicationMap.get('afternoonDosage');
                        }
                        if (medicationMap.containsKey('eveningDosage')) {
                            medRequest.Night__c = (String) medicationMap.get('eveningDosage'); 
                        }
                        if (medicationMap.containsKey('beforeAfterFood')) {
                            medRequest.BF_AF__c = (String) medicationMap.get('beforeAfterFood');
                        }
                        
                        // Ensure this RecordTypeId is correct for your MedicationRequest object
                        // Double-check this ID against your org's actual Record Type for MedicationRequest
                      

                       medRequest.RecordTypeId = recordTypeId;

                        medicationRequestsToInsert.add(medRequest);
                    }

                    if (!medicationRequestsToInsert.isEmpty()) {
                        insert medicationRequestsToInsert;
                        System.debug('PmjayReferralService: Successfully inserted ' + medicationRequestsToInsert.size() + ' MedicationRequest records.');
                    }
                } catch (Exception jsonMedEx) {
                    // This block catches exceptions during JSON deserialization or DML on MedicationRequest
                    System.debug('PmjayReferralService JSON Deserialization or MedicationRequest creation Exception in createCarePlanRecord: ' + jsonMedEx.getMessage() + ' at line ' + jsonMedEx.getLineNumber());
                    resultWrap.message += ' (Warning: Could not process some medication requests due to an issue: ' + jsonMedEx.getMessage() + ')';
                }
            }
            // --- END MedicationRequest creation ---

            resultWrap.status = 'success';
            resultWrap.message = 'Care Plan created successfully with ID: ' + newCarePlan.Id;
            resultWrap.recordId = newCarePlan.Id; // Return the ID for the LWC to use
            System.debug('PmjayReferralService: Exiting createCarePlanRecord. Result: ' + resultWrap);
        } catch (DmlException dmlEx) {
            Database.rollback(sp); 
            resultWrap.status = 'error';
            String dmlMessage = dmlEx.getDmlMessage(0); // Get the first DML error message
            resultWrap.message = 'Database Error creating Care Plan: ' + dmlMessage;
            System.debug('PmjayReferralService DML Exception in createCarePlanRecord: ' + dmlEx.getMessage() + ' at line ' + dmlEx.getLineNumber() + '. DML Message: ' + dmlMessage);
        } catch (Exception ex) {
            Database.rollback(sp); 
            resultWrap.status = 'error';
            resultWrap.message = 'An unexpected error occurred creating Care Plan: ' + ex.getMessage();
            System.debug('PmjayReferralService General Exception in createCarePlanRecord: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
        }
        return resultWrap;
    }

    @AuraEnabled
    public static ResultWrapper createCareTransitionRecord(
        String officerFullName,
        String officerEmployeeId,
        Id patientAccountId,
        Id carePlanId,
        String notes,          // This will receive your consolidated notes string
        List<referralFiles> uploadedFileIds, // This will receive the list of ContentDocumentIds
        String proceduresPerformed,
        String outcomesOfIntervention,
        String treatingPhysicianNameDesignation,
        String dischargeSummary,
        String anyFurtherReferralPlanned,
        String furtherReferralTo,
        String patientMrnIdSpecificToTheirHms,
        Id phwcDoctorId,
        String finalConfirmedDiagnosis,
        String selectedHospitalName, // name from the login dropdown; resolved to the HealthcareProvider Id below
        String selectedCity
    ) {
        ResultWrapper resultWrap = new ResultWrapper();
        System.debug('PmjayReferralService: Entering createCareTransitionRecord.');
        System.debug('PmjayReferralService: Parameters received for Care Transition: ' +
                      'notes Length=' + (notes != null ? notes.length() : 0) +
                      ', uploadedFileIds=' + uploadedFileIds + // Log the received file IDs
                      ', officerFullName=' + officerFullName +
                      ', patientAccountId=' + patientAccountId +
                      ', carePlanId=' + carePlanId); // Simplified log for brevity, full log exists in prev response

        Savepoint sp = Database.setSavepoint(); 

        try {
            if (patientAccountId == null) {
                resultWrap.status = 'error';
                resultWrap.message = 'Patient ID is missing. Please ensure patient details are loaded from a valid Referral ID.';
                System.debug('PmjayReferralService: Error - Patient Account ID is null.');
                return resultWrap;
            }
            if (carePlanId == null) {
                resultWrap.status = 'error';
                resultWrap.message = 'Care Plan ID is missing. A Care Transition record requires a Care Plan to link back to.';
                System.debug('PmjayReferralService: Error - Care Plan ID is null for Care Transition linking.');
                return resultWrap;
            }

            // Id hospitalId = null;
            // if (String.isNotBlank(selectedHospitalName)) {
            //     List<HealthcareProvider> hospitals = [SELECT Id FROM HealthcareProvider WHERE Name = :selectedHospitalName LIMIT 1];
            //     if (!hospitals.isEmpty()) {
            //         hospitalId = hospitals[0].Id;
            //         System.debug('PmjayReferralService: Found HealthcareProvider ID: ' + hospitalId);
            //     } else {
            //         resultWrap.status = 'error';
            //         resultWrap.message = 'Selected Hospital not found in the system.';
            //         System.debug('PmjayReferralService: Error - Selected Hospital "' + selectedHospitalName + '" not found.');
            //         return resultWrap;
            //     }
            // } else {
            //     resultWrap.status = 'error';
            //     resultWrap.message = 'Hospital name is required to create a Care Transition record.';
            //     System.debug('PmjayReferralService: Error - Hospital name is blank.');
            //     return resultWrap;
            // }
            
            // Resolve the logged-in hospital to its HealthcareProvider Id (same match as verifyOTP: Name + City)
            Id hospitalId = null;
            if (String.isNotBlank(selectedHospitalName)) {
                String hospitalQuery = 'SELECT Id FROM HealthcareProvider WHERE Name = :selectedHospitalName';
                if (String.isNotBlank(selectedCity)) {
                    hospitalQuery += ' AND Address__City__s = :selectedCity';
                }
                List<HealthcareProvider> hospitals = Database.query(hospitalQuery + ' LIMIT 1');
                if (!hospitals.isEmpty()) {
                    hospitalId = hospitals[0].Id;
                }
            }
            if (hospitalId == null) {
                System.debug('PmjayReferralService: Warning - Hospital "' + selectedHospitalName + '" not found. Healthcare_Provider__c will not be populated.');
            }

            if (phwcDoctorId == null) {
                System.debug('PmjayReferralService: Warning - PHWC Doctor ID from Clinical Encounter is null. PHWC_Doctor__c will not be populated.');
            }

            // 1. Create the Care_Transition__c record
            Care_Transition__c newCareTransition = new Care_Transition__c(
                Employee_Name__c = officerFullName, 
                Employee_Id__c = officerEmployeeId, 
                Procedures_Performed__c = proceduresPerformed,
                Outcomes_of_the_Interventions__c = outcomesOfIntervention,
                Treating_Physician_Name_and_Designation__c = treatingPhysicianNameDesignation,
                Patient__c = patientAccountId,
                Notes_for_Attachments__c = notes, // This field will store the consolidated notes string
                Discharge_Summary__c = dischargeSummary,
                Any_Further_Referral_Planed__c = anyFurtherReferralPlanned,
                Further_Referral_To__c = (anyFurtherReferralPlanned == 'Yes' ? furtherReferralTo : null),
                Patient_MRN_ID_Specific_to_their_HMS__c = patientMrnIdSpecificToTheirHms,
                PHWC_Doctor__c = phwcDoctorId,
                Diagnosis__c = finalConfirmedDiagnosis,
                Healthcare_Provider__c = hospitalId
            );
            System.debug('PmjayReferralService: New Care_Transition__c object created in memory: ' + newCareTransition);

            insert newCareTransition;
            System.debug('PmjayReferralService: Care_Transition__c record successfully inserted. ID: ' + newCareTransition.Id);


            // 2. Update the existing Care_Plan__c record to link to this new Care_Transition__c
            Care_Plan__c carePlanToUpdate = new Care_Plan__c(Id = carePlanId);
            carePlanToUpdate.Care_Transition__c = newCareTransition.Id; // Link to the new Care Transition record
            update carePlanToUpdate;
            System.debug('PmjayReferralService: Care_Plan__c ' + carePlanId + ' updated with Care_Transition__c ID: ' + newCareTransition.Id);

            
            // 3. Link uploaded files to the newly created Care_Transition__c record
            system.debug('uploadedFileIds::'+uploadedFileIds);
            if (uploadedFileIds != null && !uploadedFileIds.isEmpty()) {
                List<ContentVersion> contentVersionList = new List<ContentVersion>();
                Map<Blob,ContentVersion> contentVersionMap = new Map<Blob,ContentVersion>();
                for(referralFiles eachReferral : uploadedFileIds)
                {
                    Blob fileBody = EncodingUtil.base64Decode(eachReferral.base64);
                    
                    ContentVersion contentVersion = new ContentVersion();
                    contentVersion.VersionData = fileBody;
                    contentVersion.Title = eachReferral.fileName;
                    contentVersion.PathOnClient = '/' + eachReferral.fileName;
                    contentVersionMap.put(fileBody,contentVersion);
                }

                if(!contentVersionMap.isEmpty()){
                    insert contentVersionMap.values();
                    system.debug('contentVersionMap:::'+contentVersionMap);

                    Set<Id> contentVersionSet = new Set<Id>();
                    for(contentVersion eachCV : contentVersionMap.values()){
                        contentVersionSet.add(eachCV.Id);
                    }


List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
                    for(contentVersion eachContentVersion : [SELECT VersionData,ContentDocumentId FROM ContentVersion WHERE Id In: contentVersionSet]){
                        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = eachContentVersion.ContentDocumentId;
        cdl.LinkedEntityId = newCareTransition.Id;
        cdl.ShareType = 'V'; // View permission
        cdl.Visibility = 'AllUsers';
        linksToInsert.add(cdl);
                    }


                /* for(referralFiles eachReferral : uploadedFileIds)
                {
                    Blob fileBody = EncodingUtil.base64Decode(eachReferral.base64);
ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = contentVersionMap.get(fileBody).ContentDocumentId;
        cdl.LinkedEntityId = newCareTransition.Id;
        cdl.ShareType = 'V'; // View permission
        cdl.Visibility = 'AllUsers';
        linksToInsert.add(cdl);
                }*/

                                if(!linksToInsert.isEmpty()){
                    insert linksToInsert;
                }

                }




               /* List<ContentDocumentLink> linksToInsert = new List<ContentDocumentLink>();
                for (Id contentDocId : uploadedFileIds) {
                       system.debug('contentDocId::'+contentDocId);
                    if(contentDocId != null){
                        linksToInsert.add(new ContentDocumentLink(
                        ContentDocumentId = contentDocId,
                        LinkedEntityId = newCareTransition.Id, // Link to the newly created Care_Transition__c record
                        ShareType = 'V', // 'V' for Viewer access
                        Visibility = 'AllUsers' // 'AllUsers' makes it visible to all users with access to the record
                    ));
                    }
                }
                if (!linksToInsert.isEmpty()) {
                    insert linksToInsert; // This is the DML operation that creates the link
                    System.debug('PmjayReferralService: Successfully linked ' + linksToInsert.size() + ' attachments to Care Transition record ' + newCareTransition.Id);
                } else {
                    System.debug('PmjayReferralService: No ContentDocumentLink records to insert despite uploadedFileIds not being empty. This should not happen.');
                }*/
            } else {
                System.debug('PmjayReferralService: No uploadedFileIds provided, so no attachments to link to Care Transition record.');
            }
            
            resultWrap.status = 'success';
            resultWrap.message = 'Care Transition record created and linked to Care Plan successfully with ID: ' + newCareTransition.Id;
            resultWrap.recordId = newCareTransition.Id; 
            System.debug('PmjayReferralService: Exiting createCareTransitionRecord. Final Result: ' + resultWrap);

        } catch (DmlException dmlEx) {
            Database.rollback(sp); 
            resultWrap.status = 'error';
            String dmlMessage = dmlEx.getDmlMessage(0); // Get the first DML error message
            System.debug('PmjayReferralService DML Exception in createCareTransitionRecord: ' + dmlEx.getMessage() + ' at line ' + dmlEx.getLineNumber() + '. First DML message: ' + dmlMessage);
            
            // Provide more specific error messages based on what DML failed
            if (dmlMessage.containsIgnoreCase('Healthcare_Provider__c')) {
                resultWrap.message = 'Database Error: Selected Hospital might not be valid or accessible. ' + dmlMessage;
            } else if (dmlMessage.containsIgnoreCase('Care_Transition__c')) {
                resultWrap.message = 'Database Error creating Care Transition record: ' + dmlMessage;
            } else if (dmlMessage.containsIgnoreCase('Care_Plan__c')) {
                resultWrap.message = 'Database Error updating Care Plan record: ' + dmlMessage;
            } else if (dmlMessage.containsIgnoreCase('ContentDocumentLink')) {
                resultWrap.message = 'Database Error linking attachments. Check permissions on ContentDocumentLink object. ' + dmlMessage;
            } else {
                resultWrap.message = 'An unexpected database error occurred during Care Transition creation: ' + dmlMessage;
            }
        } catch (Exception ex) {
            Database.rollback(sp); 
            resultWrap.status = 'error';
            resultWrap.message = 'An unexpected error occurred during referral completion: ' + ex.getMessage();
            System.debug('PmjayReferralService General Exception in createCareTransitionRecord: ' + ex.getMessage() + ' at line ' + ex.getLineNumber());
        }
        return resultWrap;
    }

    public class referralFiles
    {
        @AuraEnabled
        public string base64{get;set;}
        @AuraEnabled
        public string fileName{get;set;}
    }
     

    public static Id uploadFile(String base64Data, String fileName, String recordId) {
        // Decode base64 string to Blob
        Blob fileBody = EncodingUtil.base64Decode(base64Data);

        ContentVersion contentVersion = new ContentVersion();
        contentVersion.VersionData = fileBody;
        contentVersion.Title = fileName;
        contentVersion.PathOnClient = '/' + fileName;
        insert contentVersion;

        // Link the file to a record if needed
        ContentDocumentLink cdl = new ContentDocumentLink();
        cdl.ContentDocumentId = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :contentVersion.Id].ContentDocumentId;
        cdl.LinkedEntityId = recordId;
        cdl.ShareType = 'V'; // View permission
        cdl.Visibility = 'AllUsers';
        insert cdl;

        return contentVersion.Id;
    }


    @AuraEnabled
    public static ResultWrapper updateReferralReceivedDate(String referralName, Date receivedDate) {
        ResultWrapper resultWrap = new ResultWrapper();
        System.debug('PatientReceivedService: Entering updateReferralReceivedDate with referralName: ' + referralName + ' and receivedDate: ' + receivedDate);

        if (String.isBlank(referralName)) {
            resultWrap.status = 'error';
            resultWrap.message = 'Referral ID (Name) cannot be blank.';
            System.debug('PatientReceivedService: Referral ID (Name) is blank.');
            return resultWrap;
        }

        if (receivedDate == null) {
            resultWrap.status = 'error';
            resultWrap.message = 'Received Date cannot be blank.';
            System.debug('PatientReceivedService: Received Date is null.');
            return resultWrap;
        }

        try {
            // Find the Referral__c record by its Name (Referral ID)
            List<Referral__c> referrals = [SELECT Id, Name, Patient_Received_Date__c FROM Referral__c WHERE Name = :referralName LIMIT 1];

            if (referrals.isEmpty()) {
                resultWrap.status = 'error';
                resultWrap.message = 'Referral ID ' + referralName + ' not found.';
                System.debug('PatientReceivedService: Referral ID ' + referralName + ' not found.');
                return resultWrap;
            }

            Referral__c referralToUpdate = referrals[0];
                if (referralToUpdate.Patient_Received_Date__c != null) {
                resultWrap.status = 'error';
                resultWrap.message = 'Patient is already received for this referral. / मरीज पहले ही प्राप्त किया जा चुका है।';
                return resultWrap;
            }
            // **Crucially, this line now uses the provided field name:**
            referralToUpdate.Patient_Received_Date__c = receivedDate; // Update the custom date field

            update referralToUpdate;

            resultWrap.status = 'success';
            resultWrap.message = 'Referral ' + referralToUpdate.Name + ' successfully updated with Received Date ' + receivedDate.format();
            System.debug('PatientReceivedService: Referral ' + referralToUpdate.Id + ' updated. New Patient_Received_Date__c: ' + referralToUpdate.Patient_Received_Date__c);

        } catch (DmlException dmlEx) {
            resultWrap.status = 'error';
            String dmlMessage = dmlEx.getDmlMessage(0);
            resultWrap.message = 'Database Error updating Referral: ' + dmlMessage;
            System.debug('PatientReceivedService DML Exception: ' + dmlEx.getMessage() + ' at line ' + dmlEx.getLineNumber());
        } catch (Exception e) {
            resultWrap.status = 'error';
            resultWrap.message = 'An unexpected error occurred: ' + e.getMessage();
            System.debug('PatientReceivedService General Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
        }
        return resultWrap;
    }

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