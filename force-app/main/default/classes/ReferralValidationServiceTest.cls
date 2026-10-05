/**
 * SeeAllData is used only to borrow an existing HealthcareProvider: inserting one fires the org flow
 * "Auto creation of the Account for a Healthcare Provider", which fails in test context.
 * Every other record is created here and rolled back after each test.
 */
@IsTest(SeeAllData=true)
private class ReferralValidationServiceTest {

    private static final String VALID_JSON =
        '{"confidence":"Strong","summary":"Consistent record.","openItems":1,'
        + '"dimensions":[{"key":"clinical_consistency","status":"green","value":"Strong"}],'
        + '"checks":[],"evidence":[],"requests":[],"actions":[]}';

    private static HealthcareProvider hospital;
    private static Referral__c referral;

    private static void createData() {
        hospital = [SELECT Id, Name FROM HealthcareProvider WHERE Name != null LIMIT 1];

        Account patient = new Account(Name = 'RV Test Patient', Age__c = 46, Blood_Group__c = 'B+', Phone = '9876543210');
        insert patient;

        ClinicalEncounter visit = new ClinicalEncounter(
            PatientId = patient.Id,
            StartDate = System.now().addDays(-3),
            Status = firstPicklistValue(ClinicalEncounter.Status),
            Category = firstPicklistValue(ClinicalEncounter.Category),
            Symptoms__c = 'Chest heaviness on exertion',
            Blood_Pressure__c = '146/92',
            Pulse_Rate_in_BPM__c = 90,
            SpO2__c = 98,
            Follow_up_Date__c = Date.today().addDays(7)
        );
        insert visit;

        insert new List<ClinicalServiceRequest>{
            new ClinicalServiceRequest(PatientId = patient.Id, EncounterId = visit.Id, Requested_Test__c = 'Lipid profile, ECG'),
            new ClinicalServiceRequest(PatientId = patient.Id, EncounterId = visit.Id, Requested_Test__c = 'Lipid profile')
        };

        Referral__c ref = new Referral__c(
            Patient__c = patient.Id,
            Referred_To__c = hospital.Id,
            Referral_Date__c = Date.today(),
            Referral_Priority__c = 'Urgent',
            Consent_Status__c = 'Granted',
            Consent_Mode__c = 'Manual',
            Clinical_Encounter__c = visit.Id,
            Preliminary_Diagnosis__c = 'Exertional chest discomfort',
            PrimarySpecialty__c = 'Cardiology'
        );
        insert ref;
        referral = [SELECT Id, Name FROM Referral__c WHERE Id = :ref.Id];
    }

    private static String firstPicklistValue(Schema.SObjectField field) {
        for (Schema.PicklistEntry pe : field.getDescribe().getPicklistValues()) {
            if (pe.isActive()) return pe.getValue();
        }
        return null;
    }

    @IsTest
    static void returnsFactsAndRequestsValidation() {
        createData();
        Test.startTest();
        Map<String, Object> result = ReferralValidationService.getReferralValidation(referral.Name, hospital.Name);
        Test.stopTest();

        List<Object> visits = (List<Object>) result.get('visits');
        List<Object> requests = (List<Object>) result.get('requests');
        Assert.areEqual(1, visits.size(), 'One consultation expected');
        Assert.areEqual(3, requests.size(), 'Consult plus two investigations expected');
        Map<String, Object> dup = (Map<String, Object>) requests[2];
        Assert.isTrue(String.valueOf(dup.get('detail')).startsWith('Repeats lipid profile'), 'Second lipid order flagged as a repeat');

        Map<String, Object> validation = (Map<String, Object>) result.get('validation');
        Assert.areEqual(ReferralValidationService.STATUS_PENDING, validation.get('status'));
    }

    @IsTest
    static void jobStoresModelVerdict() {
        createData();
        ReferralValidationService.mockPromptResponse = '```json\n' + VALID_JSON + '\n```';

        Test.startTest();
        System.enqueueJob(new ReferralValidationJob(referral.Id));
        Test.stopTest();

        Referral__c ref = [SELECT Validation_Status__c, Validation_Result__c FROM Referral__c WHERE Id = :referral.Id];
        Assert.areEqual(ReferralValidationService.STATUS_COMPLETE, ref.Validation_Status__c);
        Map<String, Object> stored = (Map<String, Object>) JSON.deserializeUntyped(ref.Validation_Result__c);
        Assert.isFalse(stored.containsKey('confidence'), 'The model never supplies the level');
        Assert.isNotNull(stored.get('scoreKey'), 'Explanation is tied to the score it was written for');

        Map<String, Object> state = ReferralValidationService.getValidationStatus(referral.Name, hospital.Name);
        Assert.isNotNull(state.get('ai'), 'Stored verdict is returned to the portal');
    }

    @IsTest
    static void badModelOutputMarksFailed() {
        createData();
        ReferralValidationService.mockPromptResponse = 'I cannot help with that.';

        Test.startTest();
        ReferralValidationService.runValidation(referral.Id);
        Test.stopTest();

        Referral__c ref = [SELECT Validation_Status__c, Validation_Error__c FROM Referral__c WHERE Id = :referral.Id];
        Assert.areEqual(ReferralValidationService.STATUS_FAILED, ref.Validation_Status__c);
        Assert.isNotNull(ref.Validation_Error__c);

        Map<String, Object> state = ReferralValidationService.rerunValidation(referral.Name, hospital.Name);
        Assert.areEqual(ReferralValidationService.STATUS_PENDING, state.get('status'));
    }

    @IsTest
    static void dossierCarriesRefsAndChecks() {
        createData();
        Referral__c ref = ReferralValidationService.queryReferral(referral.Id, null);
        String dossier = new ReferralValidationService.CaseBundle(ref).toDossier();

        Assert.isTrue(dossier.contains('[V1]'), 'Consultation ref present');
        Assert.isTrue(dossier.contains('[C1] Specialist consultation: Cardiology'), 'Consult request present');
        Assert.isTrue(dossier.contains('[R2]'), 'Both investigations present');
        Assert.isTrue(dossier.contains('Duplicate investigation'), 'Duplicate surfaced as a system check');
        Assert.isFalse(dossier.contains('9876543210'), 'Phone number is never sent to the model');
    }

    @IsTest
    static void weightedScoreIsComputedFromRecords() {
        createData();
        Referral__c ref = ReferralValidationService.queryReferral(referral.Id, null);
        Map<String, Object> s = new ReferralValidationService.CaseBundle(ref).score();

        // Depth 8 (1 visit) + vitals 11 (BP, pulse, SpO2 + in range) + documentation 6 (complaints, diagnosis)
        // + investigations 5 (ordered, no results, no documents) + identity 2 (consent only)
        // + duplication 5 (lipid repeated, no other referral) + urgency 10 (Urgent) = 47 of 100.
        Assert.areEqual(47, s.get('score'));
        Assert.areEqual('Low', s.get('band'));
        List<Object> caps = (List<Object>) s.get('caps');
        Assert.areEqual(2, caps.size(), 'No-results and not-verified caps both apply');
        Assert.isFalse((Boolean) s.get('capped'), 'Already Low, so caps do not lower it further');
    }

    @IsTest
    static void capLowersAHighScore() {
        createData();
        Account patient = [SELECT Id FROM Account WHERE Id IN (SELECT Patient__c FROM Referral__c WHERE Id = :referral.Id)];
        patient.PMJAY_Scheme_Verified__c = true;
        patient.PM_JAY_ID__c = 'PMJAY123';
        update patient;
        update new Referral__c(Id = referral.Id, Referral_Summary__c = 'Needs cardiology workup');
        update new ClinicalEncounter(
            Id = [SELECT Clinical_Encounter__c FROM Referral__c WHERE Id = :referral.Id].Clinical_Encounter__c,
            Clinical_Findings__c = 'Tender chest', Medical_History__c = 'Smoker',
            Body_Temperature__c = 115, Weight_in_Kg__c = 80
        );

        Referral__c ref = ReferralValidationService.queryReferral(referral.Id, null);
        Map<String, Object> s = new ReferralValidationService.CaseBundle(ref).score();

        // Depth 8 + vitals 10 (all five recorded, plausibility lost to temp 115) + documentation 15
        // + investigations 5 + identity 10 + duplication 5 + urgency 10 = 63 -> Medium on points,
        // and the out-of-range temperature and no-results caps keep it at Medium.
        Assert.areEqual(63, s.get('score'));
        Assert.areEqual('Medium', s.get('band'));
        Assert.isTrue(String.join((List<String>) s.get('caps'), ' ').contains('realistic range'));
    }

    @IsTest
    static void fitShowsWhetherHospitalOffersSpecialty() {
        createData();
        List<HealthcareProviderSpecialty> cardiology = [
            SELECT Healthcare_Provider__c FROM HealthcareProviderSpecialty
            WHERE Specialty.Name = 'Cardiology' AND Healthcare_Provider__c != null LIMIT 1
        ];
        if (!cardiology.isEmpty()) {
            update new Referral__c(Id = referral.Id, Referred_To__c = cardiology[0].Healthcare_Provider__c);
        }

        Referral__c ref = ReferralValidationService.queryReferral(referral.Id, null);
        ReferralValidationService.CaseBundle bundle = new ReferralValidationService.CaseBundle(ref);
        Map<String, Object> fit = bundle.fit();

        List<Object> rows = (List<Object>) fit.get('specialties');
        Assert.areEqual(1, rows.size(), 'One requested specialty');
        Map<String, Object> row = (Map<String, Object>) rows[0];
        Assert.areEqual('Cardiology', row.get('label'));
        if (!cardiology.isEmpty()) {
            Assert.areEqual('offered', row.get('status'), 'Hospital lists Cardiology');
        }
        Assert.isFalse((Boolean) fit.get('previouslyReceived'));
        Assert.isTrue(bundle.toDossier().contains('HOSPITAL FIT'), 'Fit facts reach the model as unscored context');
    }

    @IsTest
    static void integrityFlagsAreRaisedFromRecords() {
        createData();
        Id patientId = [SELECT Patient__c FROM Referral__c WHERE Id = :referral.Id].Patient__c;
        update new Account(Id = patientId, PM_JAY_ID__c = 'RVTEST99');
        insert new Account(Name = 'RV Other Patient', PM_JAY_ID__c = 'RVTEST99');
        List<HealthcareProvider> otherHospital = [SELECT Id FROM HealthcareProvider WHERE Id != :hospital.Id LIMIT 1];
        insert new Referral__c(
            Patient__c = patientId, Referred_To__c = otherHospital[0].Id,
            Referral_Date__c = Date.today().addDays(-2), Consent_Status__c = 'Granted'
        );

        Referral__c ref = ReferralValidationService.queryReferral(referral.Id, null);
        ReferralValidationService.CaseBundle bundle = new ReferralValidationService.CaseBundle(ref);
        Set<String> titles = new Set<String>();
        for (Map<String, Object> f : bundle.integrityFlags()) titles.add((String) f.get('title'));

        Assert.isTrue(titles.contains('PM-JAY ID also on another patient record'), 'Shared full PM-JAY ID flagged');
        Assert.isTrue(titles.contains('Open referral to another hospital'), 'Overlapping referral flagged');
        Assert.isTrue(titles.contains('Thin clinical history'), 'Visit has no findings or history');
        Assert.isTrue(bundle.toDossier().contains('ITEMS TO VERIFY'), 'Flags reach the model as prompts to verify');
    }

    @IsTest
    static void rejectsOtherHospitalsAndMissingConsent() {
        createData();
        try {
            ReferralValidationService.getReferralValidation(referral.Name, 'Some Other Hospital');
            Assert.fail('Other hospitals must be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('not sent to your hospital'));
        }

        update new Referral__c(Id = referral.Id, Consent_Status__c = 'Pending');
        try {
            ReferralValidationService.getReferralValidation(referral.Name, hospital.Name);
            Assert.fail('Pending consent must be rejected');
        } catch (AuraHandledException e) {
            Assert.isTrue(e.getMessage().contains('consent'));
        }
    }
}