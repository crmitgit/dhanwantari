public with sharing class ActiveMedicationController {

    /* =========================================================
       SAVE
       ========================================================= */
    @AuraEnabled
    public static void saveActiveMedications(
        Id consultationId,
        String existingMeds,
        String userMeds,
        Boolean hasAllergies,
        String allergyDetails,

        // 🔹 NEW
        String pregnancyStatus,
        Boolean smoking,
        Boolean alcoholUse,
        Boolean physicalInactivity,
        Boolean sleepDeprivation,
        String lifestyleHabits,

        String existingConditions, // full free-text conditions
        String otherCondition     // newly added condition by user
    ) {
        Active_Medications__c recordToSave;

        List<Active_Medications__c> existing = [
            SELECT Id
            FROM Active_Medications__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            recordToSave = existing[0];
        } else {
            recordToSave = new Active_Medications__c(
                Consultation__c = consultationId
            );
        }

        /* ================== MEDICATIONS ================== */
        recordToSave.User_entered_medications__c = userMeds;

        /* ================== ALLERGIES ================== */
        recordToSave.Has_Allergies__c = hasAllergies;
        recordToSave.Allergy_Details__c = hasAllergies ? allergyDetails : null;

        /* ================== PREGNANCY ================== */
        recordToSave.Pregnancy_Status__c = pregnancyStatus;

        /* ================== LIFESTYLE ================== */
        recordToSave.Smoking__c = smoking;
        recordToSave.Alcohol_Use__c = alcoholUse;
        recordToSave.Physical_Inactivity__c = physicalInactivity;
        recordToSave.Sleep_Deprivation__c = sleepDeprivation;

        // Optional but highly recommended
        recordToSave.Lifestyle_Habits__c = lifestyleHabits;


        /* ================== EXISTING HEALTH CONDITIONS ================== */
        // Merge existing conditions with newly added condition if any
        String finalConditions = existingConditions;
        if (!String.isBlank(otherCondition)) {
            finalConditions = String.isBlank(finalConditions)
                ? otherCondition
                : finalConditions + ', ' + otherCondition;
        }
        recordToSave.Existing_Conditions__c = finalConditions;

        /* ================== MED NAMES (HUMAN READABLE) ================== */
        List<String> medicationNames = new List<String>();
        if (String.isNotBlank(userMeds)) {
            List<Id> medIds = new List<Id>();
            for (String token : userMeds.split(',')) {
                token = token.trim();
                if (token.length() == 15 || token.length() == 18) {
                    try {
                        medIds.add((Id) token);
                    } catch (Exception e) {
                        // ignore invalid ids
                    }
                }
            }
            if (!medIds.isEmpty()) {
                for (Medication m : [SELECT Name FROM Medication WHERE Id IN :medIds]) {
                    medicationNames.add(m.Name);
                }
            }
        }
        recordToSave.Existing_Medications__c = String.join(medicationNames, ', ');

        upsert recordToSave;
    }

    /*========================================================= */
    @AuraEnabled
    public static void saveAayushMedicine(
        Id consultationId,
        String userAllopathicMeds,
        String userMeds,
        Boolean hasAllergies,
        String allergyDetails,
        String pregnancyStatus,
        Boolean smoking,
        Boolean alcoholUse,
        Boolean physicalInactivity,
        Boolean sleepDeprivation,
        String lifestyleHabits,
        String existingConditions, // full free-text conditions
        String otherCondition
    ) {
        Ayush_Prescription_Input__c recordToSave;

        List<Ayush_Prescription_Input__c> existing = [
            SELECT Id
            FROM Ayush_Prescription_Input__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];

        if (!existing.isEmpty()) {
            recordToSave = existing[0];
        } else {
            recordToSave = new Ayush_Prescription_Input__c(
                Consultation__c = consultationId
            );
        }

        recordToSave.User_entered_medications__c = userMeds;
        recordToSave.User_entered_medications1__c = userAllopathicMeds;

        /* ================== ALLERGIES ================== */
        recordToSave.Has_Allergies__c = hasAllergies;
        recordToSave.Allergy_Details__c = hasAllergies ? allergyDetails : null;

        /* ================== PREGNANCY ================== */
        recordToSave.Pregnancy_Status__c = pregnancyStatus;

        /* ================== LIFESTYLE ================== */
        recordToSave.Smoking__c = smoking;
        recordToSave.Alcohol_Use__c = alcoholUse;
        recordToSave.Physical_Inactivity__c = physicalInactivity;
        recordToSave.Sleep_Deprivation__c = sleepDeprivation;
        recordToSave.Lifestyle_Habits__c = lifestyleHabits;

        /* ================== EXISTING HEALTH CONDITIONS ================== */
        // Merge existing conditions with newly added condition if any
        String finalConditions = existingConditions;
        if (!String.isBlank(otherCondition)) {
            finalConditions = String.isBlank(finalConditions)
                ? otherCondition
                : finalConditions + ', ' + otherCondition;
        }
        recordToSave.Existing_Conditions__c = finalConditions;

                /* ================== MED NAMES (HUMAN READABLE) ================== */
        List<String> medicationNames = new List<String>();
        if (String.isNotBlank(userMeds)) {
            List<Id> medIds = new List<Id>();
            for (String token : userMeds.split(',')) {
                token = token.trim();
                if (token.length() == 15 || token.length() == 18) {
                    try {
                        medIds.add((Id) token);
                    } catch (Exception e) {
                        // ignore invalid ids
                    }
                }
            }
            if (!medIds.isEmpty()) {
                for (Ayurvedic_Medication__c m : [SELECT Name FROM Ayurvedic_Medication__c WHERE Id IN :medIds]) {
                    medicationNames.add(m.Name);
                }
            }
        }
        recordToSave.Existing_Medications__c = String.join(medicationNames, ', ');

         /* ================== MED NAMES (HUMAN READABLE) ================== */
        List<String> allopathicMedicationNames = new List<String>();
        if (String.isNotBlank(userAllopathicMeds)) {
            List<Id> medIds = new List<Id>();
            for (String token : userAllopathicMeds.split(',')) {
                token = token.trim();
                if (token.length() == 15 || token.length() == 18) {
                    try {
                        medIds.add((Id) token);
                    } catch (Exception e) {
                        // ignore invalid ids
                    }
                }
            }
            if (!medIds.isEmpty()) {
                for (Medication m : [SELECT Name FROM Medication WHERE Id IN :medIds]) {
                    allopathicMedicationNames.add(m.Name);
                }
            }
        }
        recordToSave.Existing_Allopathic_Medicines__c = String.join(allopathicMedicationNames, ', ');

        upsert recordToSave;
    }

    /* =========================================================
       WRAPPER
       ========================================================= */
    public class ActiveMedicationWrapper {
        @AuraEnabled public List<Medication> medications;
        @AuraEnabled public List<Ayurvedic_Medication__c> ayurvedaMedications;
        @AuraEnabled public Boolean hasAllergies;
        @AuraEnabled public String allergyDetails;

        // 🔹 NEW
        @AuraEnabled public String pregnancyStatus;
        @AuraEnabled public Boolean smoking;
        @AuraEnabled public Boolean alcoholUse;
        @AuraEnabled public Boolean physicalInactivity;
        @AuraEnabled public Boolean sleepDeprivation;
        @AuraEnabled public String lifestyleHabits;


        // 🔹 NEW – for health conditions
        @AuraEnabled public String existingConditions;
        @AuraEnabled public String otherCondition;

    }

    /* =========================================================
       FETCH
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static ActiveMedicationWrapper getActiveMedicationsUser(Id consultationId) {

        ActiveMedicationWrapper result = new ActiveMedicationWrapper();
        result.medications = new List<Medication>();
        result.hasAllergies = false;
        result.allergyDetails = '';
        result.pregnancyStatus = 'Not Applicable';
        result.smoking = false;
        result.alcoholUse = false;
        result.physicalInactivity = false;
        result.sleepDeprivation = false;
        result.lifestyleHabits = '';
        result.existingConditions = '';
        result.otherCondition = '';

        /* ------------------ FETCH ACTIVE MEDICATIONS ------------------ */
        List<Active_Medications__c> records = [
            SELECT User_entered_medications__c,
                   Has_Allergies__c,
                   Allergy_Details__c,
                   Pregnancy_Status__c,
                   Smoking__c,
                   Alcohol_Use__c,
                   Physical_Inactivity__c,
                   Sleep_Deprivation__c,
                   Existing_Conditions__c,
                   Lifestyle_Habits__c
            FROM Active_Medications__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];

        if (!records.isEmpty()) {
            Active_Medications__c rec = records[0];

            result.hasAllergies = rec.Has_Allergies__c;
            result.allergyDetails = rec.Allergy_Details__c;
            result.pregnancyStatus = rec.Pregnancy_Status__c;
            result.smoking = rec.Smoking__c;
            result.alcoholUse = rec.Alcohol_Use__c;
            result.physicalInactivity = rec.Physical_Inactivity__c;
            result.sleepDeprivation = rec.Sleep_Deprivation__c;
            result.lifestyleHabits = rec.Lifestyle_Habits__c;
            

            if (!String.isBlank(rec.Existing_Conditions__c)) {
                result.existingConditions = rec.Existing_Conditions__c;
            }
        }

        /* ------------------ FETCH MEDICATION DETAILS ------------------ */
        if (!String.isBlank(records.isEmpty() ? '' : records[0].User_entered_medications__c)) {
            List<Id> medIds = new List<Id>();
            for (String token : records[0].User_entered_medications__c.split(',')) {
                try { medIds.add((Id) token.trim()); } catch (Exception e) {}
            }
            if (!medIds.isEmpty()) {
                result.medications = [SELECT Id, Name FROM Medication WHERE Id IN :medIds];
            }
        }

        /* ------------------ FETCH CLINICAL ENCOUNTER MEDICAL HISTORY IF NO SAVED CONDITIONS ------------------ */
        if (String.isBlank(result.existingConditions)) {
            List<ClinicalEncounter> ceList = [
                SELECT Medical_History__c
                FROM ClinicalEncounter
                WHERE Id = :consultationId
                LIMIT 1
            ];
            if (!ceList.isEmpty() && !String.isBlank(ceList[0].Medical_History__c)) {
                result.existingConditions = ceList[0].Medical_History__c;
            }
        }

        applyPatientKnownAllergies(result, consultationId);

        return result;
    }


     /* =========================================================
       Ayush FETCH
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static ActiveMedicationWrapper getAyushActiveMedicationsUser(Id consultationId) {

        ActiveMedicationWrapper result = new ActiveMedicationWrapper();
        result.ayurvedaMedications = new List<Ayurvedic_Medication__c>();
        result.medications = new List<Medication>();
        result.hasAllergies = false;
        result.allergyDetails = '';
        result.pregnancyStatus = 'Not Applicable';
        result.smoking = false;
        result.alcoholUse = false;
        result.physicalInactivity = false;
        result.sleepDeprivation = false;
        result.lifestyleHabits = '';
        result.existingConditions = '';
        result.otherCondition = '';

        /* ------------------ FETCH ACTIVE MEDICATIONS ------------------ */
        List<Ayush_Prescription_Input__c> records = [
            SELECT Has_Allergies__c,User_entered_medications__c,
                   Allergy_Details__c,
                   Pregnancy_Status__c,
                   Smoking__c,
                   Alcohol_Use__c,
                   Physical_Inactivity__c,
                   Sleep_Deprivation__c,
                   Existing_Conditions__c,
                   Lifestyle_Habits__c,
                   User_entered_medications1__c
            FROM Ayush_Prescription_Input__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];

        if (!records.isEmpty()) {
            Ayush_Prescription_Input__c rec = records[0];

            result.hasAllergies = rec.Has_Allergies__c;
            result.allergyDetails = rec.Allergy_Details__c;
            result.pregnancyStatus = rec.Pregnancy_Status__c;
            result.smoking = rec.Smoking__c;
            result.alcoholUse = rec.Alcohol_Use__c;
            result.physicalInactivity = rec.Physical_Inactivity__c;
            result.sleepDeprivation = rec.Sleep_Deprivation__c;
            result.lifestyleHabits = rec.Lifestyle_Habits__c;
            

            if (!String.isBlank(rec.Existing_Conditions__c)) {
                result.existingConditions = rec.Existing_Conditions__c;
            }
        }

        /* ------------------ FETCH MEDICATION DETAILS ------------------ */
        if (!String.isBlank(records.isEmpty() ? '' : records[0].User_entered_medications__c)) {
            List<Id> medIds = new List<Id>();
            for (String token : records[0].User_entered_medications__c.split(',')) {
                try { medIds.add((Id) token.trim()); } catch (Exception e) {}
            }
            if (!medIds.isEmpty()) {
                result.ayurvedaMedications = [SELECT Id, Name FROM Ayurvedic_Medication__c WHERE Id IN :medIds];
            }
        }

        /* ------------------ FETCH MEDICATION DETAILS ------------------ */
        if (!String.isBlank(records.isEmpty() ? '' : records[0].User_entered_medications__c)) {
            List<Id> medIds = new List<Id>();
            for (String token : records[0].User_entered_medications__c.split(',')) {
                try { medIds.add((Id) token.trim()); } catch (Exception e) {}
            }
            if (!medIds.isEmpty()) {
                result.medications = [SELECT Id, Name FROM Medication WHERE Id IN :medIds];
            }
        }

        /* ------------------ FETCH CLINICAL ENCOUNTER MEDICAL HISTORY IF NO SAVED CONDITIONS ------------------ */
        if (String.isBlank(result.existingConditions)) {
            List<ClinicalEncounter> ceList = [
                SELECT Medical_History__c
                FROM ClinicalEncounter
                WHERE Id = :consultationId
                LIMIT 1
            ];
            if (!ceList.isEmpty() && !String.isBlank(ceList[0].Medical_History__c)) {
                result.existingConditions = ceList[0].Medical_History__c;
            }
        }

        applyPatientKnownAllergies(result, consultationId);

        return result;
    }

    /* ------------------ ALLERGIES FROM PATIENT RECORD ------------------ */
    // Allergies always come from the patient's Known_Allergies__c, never from the consultation's saved input
    private static void applyPatientKnownAllergies(ActiveMedicationWrapper result, Id consultationId) {
        result.hasAllergies = false;
        result.allergyDetails = '';

        List<ClinicalEncounter> ceList = [
            SELECT PatientId
            FROM ClinicalEncounter
            WHERE Id = :consultationId
            LIMIT 1
        ];
        if (ceList.isEmpty() || ceList[0].PatientId == null) {
            return;
        }

        List<Account> patients = [
            SELECT Known_Allergies__c
            FROM Account
            WHERE Id = :ceList[0].PatientId
            LIMIT 1
        ];
        if (!patients.isEmpty() && String.isNotBlank(patients[0].Known_Allergies__c)) {
            result.hasAllergies = true;
            result.allergyDetails = patients[0].Known_Allergies__c.trim();
        }
    }

    /* =========================================================
       UTILITY
       ========================================================= */
    @AuraEnabled(cacheable=true)
    public static List<Medication> getMedications() {
        return [
            SELECT Id, Name
            FROM Medication
            ORDER BY Name
            LIMIT 50000
        ];
    }
    @AuraEnabled(cacheable=true)
    public static String getPatientGender(Id consultationId) {

        ClinicalEncounter ce = [
            SELECT PatientId
            FROM ClinicalEncounter
            WHERE Id = :consultationId
            LIMIT 1
        ];

        if (ce.PatientId == null) {
            return null;
        }

        Account acc = [
            SELECT Gender__c
            FROM Account
            WHERE Id = :ce.PatientId
            LIMIT 1
        ];

        return acc.Gender__c;
    }

    @AuraEnabled(cacheable=true)
    public static List<ConsiderationRow> getPatientConsiderations(Id consultationId) {

        List<ConsiderationRow> rows = new List<ConsiderationRow>();

        /* ================== FETCH CLINICAL ENCOUNTER ================== */
        ClinicalEncounter ce = [
            SELECT Symptoms__c,
                Medical_History__c,
                Clinical_Findings__c,
                (SELECT Clinical_Diagnosis__c, Diagnosis_Description__c FROM Diagnoses__r)
            FROM ClinicalEncounter
            WHERE Id = :consultationId
            LIMIT 1
        ];

        /* ================== FETCH ACTIVE MEDICATION ================== */
        Active_Medications__c am;
        List<Active_Medications__c> amList = [
            SELECT Existing_Medications__c,
                Smoking__c,
                Alcohol_Use__c,
                Pregnancy_Status__c,
                Allergy_Details__c,
                Existing_Conditions__c,
                Has_Allergies__c
            FROM Active_Medications__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];
        if (!amList.isEmpty()) {
            am = amList[0];
        }

        /* ================== ROW 1: SYMPTOMS + FINDINGS ================== */
      List<String> parts1 = new List<String>();

        if (String.isNotBlank(ce.Symptoms__c)) {
            parts1.add(ce.Symptoms__c);
        }

        if (String.isNotBlank(ce.Clinical_Findings__c)) {
            parts1.add(ce.Clinical_Findings__c);
        }

        rows.add(new ConsiderationRow(
            'Symptoms & Clinical Findings',
            parts1.isEmpty() ? 'N/A' : String.join(parts1, ' | ')
        ));

        /* ================== ROW 2: DIAGNOSIS + HISTORY ================== */
        List<String> diagnoses = new List<String>();

        for (Diagnosis__c d : ce.Diagnoses__r) {
            if (String.isNotBlank(d.Clinical_Diagnosis__c)) {
                diagnoses.add(
                    d.Clinical_Diagnosis__c +
                    (String.isBlank(d.Diagnosis_Description__c) ? '' : ' – ' + d.Diagnosis_Description__c)
                );
            }
        }

        // Build final parts safely
        List<String> parts = new List<String>();

        if (!diagnoses.isEmpty()) {
            parts.add(String.join(diagnoses, ', '));
        }

        if (String.isNotBlank(ce.Medical_History__c)) {
            parts.add(ce.Medical_History__c);
        }

        rows.add(new ConsiderationRow(
            'Diagnosis & Medical History',
            parts.isEmpty() ? 'N/A' : String.join(parts, ' | ')
        ));

        /* ================== ROW 3: ALLERGIES ================== */
        rows.add(new ConsiderationRow(
            'Drug Allergies',
            (am != null && am.Has_Allergies__c)
                ? am.Allergy_Details__c
                : 'No known allergies'
        ));

        /* ================== ROW 4: EXISTING CONDITIONS ================== */
        rows.add(new ConsiderationRow(
            'Existing Conditions',
            am != null ? am.Existing_Conditions__c : ce.Medical_History__c
        ));

        /* ================== ROW 5: CURRENT MEDICATIONS ================== */
        rows.add(new ConsiderationRow(
            'Current Medications',
            am != null ? am.Existing_Medications__c : null
        ));

        /* ================== ROW 6: LIFESTYLE ================== */
        if (am != null) {
            List<String> lifestyle = new List<String>();

            if (am.Smoking__c != null) {
                lifestyle.add('Smoking: ' + (am.Smoking__c ? 'Yes' : 'No'));
            }
            if (am.Alcohol_Use__c != null) {
                lifestyle.add('Alcohol use: ' + (am.Alcohol_Use__c ? 'Yes' : 'No'));
            }

            if (!lifestyle.isEmpty()) {
                rows.add(new ConsiderationRow(
                    'Lifestyle Factors',
                    String.join(lifestyle, ', ')
                ));
            }
        }

        /* ================== ROW 7: PREGNANCY ================== */
        rows.add(new ConsiderationRow(
            'Pregnancy Status',
            am != null ? am.Pregnancy_Status__c : 'Not Applicable'
        ));

        return rows;
    }


    @AuraEnabled(cacheable=true)
    public static List<ConsiderationRow> getAyushPatientConsiderations(Id consultationId) {

        List<ConsiderationRow> rows = new List<ConsiderationRow>();

        /* ================== FETCH CLINICAL ENCOUNTER ================== */
        ClinicalEncounter ce = [
            SELECT Symptoms__c,
                    Medical_History__c,
                    Clinical_Findings__c,
                    (SELECT Clinical_Diagnosis__c, Diagnosis_Description__c FROM Diagnoses__r)
            FROM ClinicalEncounter
            WHERE Id = :consultationId
            LIMIT 1
        ];

        /* ================== FETCH ACTIVE MEDICATION ================== */
        Ayush_Prescription_Input__c am;
        List<Ayush_Prescription_Input__c> amList = [
            SELECT Smoking__c,
                    Alcohol_Use__c,
                    Pregnancy_Status__c,
                    Allergy_Details__c,
                    Existing_Conditions__c,
                    Has_Allergies__c,Physical_Inactivity__c,Sleep_Deprivation__c
            FROM Ayush_Prescription_Input__c
            WHERE Consultation__c = :consultationId
            LIMIT 1
        ];
        if (!amList.isEmpty()) {
            am = amList[0];
        }

        /* ================== ROW 1: SYMPTOMS + FINDINGS ================== */
        rows.add(new ConsiderationRow(
            'Symptoms & Clinical Findings',
            String.join(new List<String>{
                ce.Symptoms__c,
                ce.Clinical_Findings__c
            }, ' , ')
        ));
//changed - by krati only operator change '|' to ','
        /* ================== ROW 2: DIAGNOSIS + HISTORY ================== */
        List<String> diagnoses = new List<String>();
        for (Diagnosis__c d : ce.Diagnoses__r) {
            diagnoses.add(
                d.Clinical_Diagnosis__c +
                (String.isBlank(d.Diagnosis_Description__c) ? '' : ' – ' + d.Diagnosis_Description__c)
            );
        }

        rows.add(new ConsiderationRow(
            'Diagnosis & Medical History',
            String.join(new List<String>{
                String.join(diagnoses, ', '),
                ce.Medical_History__c
            }, '')
        ));
////changed - by krati only operator change ' | ' to ''
        /* ================== ROW 3: ALLERGIES ================== */
        rows.add(new ConsiderationRow(
            'Drug Allergies',
            (am != null && am.Has_Allergies__c)
                ? am.Allergy_Details__c
                : 'No known allergies'
        ));

        /* ================== ROW 4: EXISTING CONDITIONS ================== */
        rows.add(new ConsiderationRow(
            'Existing Conditions',
            am != null ? am.Existing_Conditions__c : ce.Medical_History__c
        ));

        /* ================== ROW 5: LIFESTYLE ================== */
        if (am != null) {
            List<String> lifestyle = new List<String>();

            if (am.Smoking__c != null) {
                lifestyle.add('Smoking: ' + (am.Smoking__c ? 'Yes' : 'No'));
            }
            if (am.Alcohol_Use__c != null) {
                lifestyle.add('Alcohol use: ' + (am.Alcohol_Use__c ? 'Yes' : 'No'));
            }
            if (am.Physical_Inactivity__c != null) {
                lifestyle.add('Yoga Practice: ' + (am.Physical_Inactivity__c ? 'Yes' : 'No'));
            }
            if (am.Sleep_Deprivation__c != null) {
                lifestyle.add('Sleep Deprivation: ' + (am.Sleep_Deprivation__c ? 'Yes' : 'No'));
            }

            if (!lifestyle.isEmpty()) {
                rows.add(new ConsiderationRow(
                    'Lifestyle Factors',
                    String.join(lifestyle, ', ')
                ));
            }
        }

        /* ================== ROW 7: PREGNANCY ================== */
        rows.add(new ConsiderationRow(
            'Pregnancy Status',
            am != null ? am.Pregnancy_Status__c : 'Not Applicable'
        ));

        return rows;
    }

    public class ConsiderationRow {
        @AuraEnabled public String label;
        @AuraEnabled public String value;

        public ConsiderationRow(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
}