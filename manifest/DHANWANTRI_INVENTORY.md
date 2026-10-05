# Dhanwantri metadata inventory

Source org: naveen.guleria2026@crmit.com (alias `dhanwantri`, SDO demo org, instance cr1769668480593). Generated 2026-10-05 from a read-only analysis. Manifest: `manifest/package.xml` (API 67.0, matching the sfdx-project sourceApiVersion).

## Method
- The org was provisioned (SDO install) on 2026-01-29. Every non-namespaced component that the Dhanwantri team (Nitheesh G / Naveen Guleria) created after that date was treated as a candidate. Reference analysis then confirmed each one.
- References were found two ways: a text scan of retrieved source (Apex/LWC/Aura/flows/quick actions/flexipages/prompt templates/site bundles) and the Tooling `MetadataComponentDependency` API (1,347 dependency rows for 270 Dhanwantri component Ids). Dhanwantri references nothing outside this set except the platform and managed items listed under "Excluded but referenced". Every `__c` field it references resolves to an included field or object.
- Validation: `sf project retrieve start -x manifest/package.xml --target-metadata-dir <scratch>` -> **Succeeded, 0 warnings**.

## Included (by type)

### ApexClass (41)
_All non-namespaced classes created after org provisioning (2026-01-29) by the Dhanwantri team; each is reached from a Dhanwantri LWC/Aura/flow/prompt/trigger/site, or is a test. Only 2 test classes exist in the org (IndianMedicationCatalogProviderTest, ReferralValidationServiceTest); none of the other must-include classes has a test class._

`AayushGuideController`, `ActiveMedicationController`, `CareTransitionPatientEmailAlert`, `ClinicalEncounterController2`, `ClinicalEncounterFormatter`, `ClinicalEncounterPromptDataFormatter`, `ClinicalServiceRequestController`, `ClinicalTestSuggestionService`, `ConsultationController`, `CustomLookupController`, `DiagnosisController`, `DraftReferralController`, `EncounterSummaryController`, `FlowJsonParser`, `FollowUpReminderEmailScheduler`, `FollowUpReminderScheduler`, `HealthcareProviderController`, `IndianMedicationCatalogProvider`, `IndianMedicationCatalogProviderTest`, `MedicationController`, `MedicationGuideController`, `MedicationRequestController`, `PmjayReferralConsentService`, `PmjayReferralService`, `PortalConfigController`, `PrescriptionApprovalController`, `PrescriptionController`, `PreviewCaseFileController`, `PrintEncounterController`, `PromptResolverService`, `QRCodeService`, `ReferralToAnotherProvider`, `ReferralTriggerHelper`, `ReferralValidationJob`, `ReferralValidationService`, `ReferralValidationServiceTest`, `SearchJanAushadhiKendraController`, `SystemLogHelper`, `ZipController`, `ayushPrescriptionPromptHelper`, `resendEmailHCProviderController`

### ApexPage (2)
_PDF renderers: PrintEncounterSummary (EncounterSummaryController) and ReferralCaseFilePDF (ClinicalEncounterController2 case file)._

`PrintEncounterSummary`, `ReferralCaseFilePDF`

### ApexTrigger (7)
_ClinicalEncounterTrigger (-> QRCodeService), DiagnosisTrigger, ReferralValidationRequestTrigger (platform event), UpdateCheckbox (HealthcareProvider), ContentDocumentLinkTrigger (DiagnosticSummary file visibility). ClinicalEncounterStatusValidation and PatientAgeTrigger are Inactive in the org. No trigger calls ReferralTriggerHelper directly. It is called from ClinicalEncounterController2, PmjayReferralService, PmjayReferralConsentService, ReferralToAnotherProvider and resendEmailHCProviderController._

`ClinicalEncounterStatusValidation`, `ClinicalEncounterTrigger`, `ContentDocumentLinkTrigger`, `DiagnosisTrigger`, `PatientAgeTrigger`, `ReferralValidationRequestTrigger`, `UpdateCheckbox`

### AuraDefinitionBundle (16)
_Quick-action wrappers (AayushGuideAura, MedicationGuideAura, MS_Phi3_Prescription_Assistant, DiagnosisAura, serviceRequest, Prescription, EncounterSummaryWrapper, Consultation, medicationRequestEditWrapper) and New Patient wrappers/apps (NewPatient*)._

`AayushGuideAura`, `Consultation`, `DiagnosisAura`, `EncounterSummaryWrapper`, `MS_Phi3_Prescription_Assistant`, `MedicationGuideAura`, `NewPatientApp`, `NewPatientAppWrapper`, `NewPatientAppWrapperr`, `NewPatientAppp`, `NewPatientAuraWrapper`, `NewPatientWrapper`, `Prescription`, `medicationRequestEditWrapper`, `newPatientAuraWrapperr`, `serviceRequest`

### CompactLayout (4)
`ClinicalEncounter.Clinical_Encounter`, `ClinicalServiceRequest.Clinical_Service_Request_Compact_Layout`, `MedicationRequest.Medication_Request_Compact_Layout`, `PersonAccount.Patient_Layout`

### CspTrustedSite (1)
_qrcode -> api.qrserver.com, used by QRCodeService._

`qrcode`

### CustomApplication (1)
_PMJAY PHWC Lightning app. It overrides Account view -> Patient_Record_Page and ClinicalEncounter view -> Consultation_New_page._

`PMJAY_PHWC`

### CustomField (131)
_Dhanwantri custom fields on STANDARD objects only (Account, ClinicalEncounter, ClinicalServiceRequest, DiagnosticSummary, HealthcareFacility, HealthcareProvider, HealthcareProviderSpecialty, Medication, MedicationRequest, User, CarePlan.Care_Transition__c). Every __c field that Dhanwantri code or flows reference resolves to this list or to a Dhanwantri object._

`Account.AADHAR_Number_Original__c`, `Account.AADHAR_Number__c`, `Account.ABHA_Number__c`, `Account.Abha_Number_Original__c`, `Account.Age__c`, `Account.Alternate__c`, `Account.Attendant_Name__c`, `Account.Attendant_Phone__c`, `Account.Attendant_Relationship__c`, `Account.Attendent_Email__c`, `Account.Birth_Date__c`, `Account.Blood_Group__c`, `Account.Blood_Presssure_in_mm_Hg__c`, `Account.Body_type__c`, `Account.Emergency_Contact_Name1__c`, `Account.Emergency_Contact_Number__c`, `Account.Gender__c`, `Account.Height_in_cm__c`, `Account.Immunizations__c`, `Account.Known_Allergies__c`, `Account.Marital_Status__c`, `Account.Member_ID__c`, `Account.PMJAY_Beneficiary_Link__c`, `Account.PMJAY_Family_ID__c`, `Account.PMJAY_Scheme_Verified__c`, `Account.PM_JAY_ID__c`, `Account.Patient_ID__c`, `Account.Registered_At__c`, `Account.Secondary_Prakriti__c`, `Account.Weight_in_Kg__c`, `CarePlan.Care_Transition__c`, `ClinicalEncounter.Additional_Information__c`, `ClinicalEncounter.Approved_Date__c`, `ClinicalEncounter.Blood_Pressure__c`, `ClinicalEncounter.Body_Temperature__c`, `ClinicalEncounter.Care_Instructions__c`, `ClinicalEncounter.Clinical_Encounter_Diagnosis__c`, `ClinicalEncounter.Clinical_Findings__c`, `ClinicalEncounter.Clinical_Service_Request__c`, `ClinicalEncounter.Comments_Remarks__c`, `ClinicalEncounter.Consultation__c`, `ClinicalEncounter.Contact__c`, `ClinicalEncounter.Doctor_Name__c`, `ClinicalEncounter.External_ID__c`, `ClinicalEncounter.Follow_up_Date__c`, `ClinicalEncounter.Height_in_cm__c`, `ClinicalEncounter.Medical_History__c`, `ClinicalEncounter.Owner__c`, `ClinicalEncounter.PHWC_Doctor__c`, `ClinicalEncounter.Patient_Type__c`, `ClinicalEncounter.Prescribing_Doctor__c`, `ClinicalEncounter.Pulse_Rate_in_BPM__c`, `ClinicalEncounter.Queue_Owner__c`, `ClinicalEncounter.Registration_Number__c`, `ClinicalEncounter.Requested_Physician_Assistant__c`, `ClinicalEncounter.Required_before_follow_up__c`, `ClinicalEncounter.SpO2__c`, `ClinicalEncounter.Symptoms__c`, `ClinicalEncounter.Vikriti__c`, `ClinicalEncounter.Weight_in_Kg__c`, `ClinicalServiceRequest.Clinical_Encounter2__c`, `ClinicalServiceRequest.Clinical_Encounter__c`, `ClinicalServiceRequest.Clinical_Service_Request__c`, `ClinicalServiceRequest.Completed_On__c`, `ClinicalServiceRequest.External_ID__c`, `ClinicalServiceRequest.Notes__c`, `ClinicalServiceRequest.Referral_Email__c`, `ClinicalServiceRequest.Requested_By__c`, `ClinicalServiceRequest.Requested_Completion_Date__c`, `ClinicalServiceRequest.Requested_Test__c`, `DiagnosticSummary.Clinical_Service_Request__c`, `DiagnosticSummary.Referring_Doctor__c`, `DiagnosticSummary.Sample_Drawn_Date__c`, `DiagnosticSummary.Sample_Type__c`, `HealthcareFacility.Clinical_Encounter__c`, `HealthcareFacility.Email_Address__c`, `HealthcareFacility.External_ID__c`, `HealthcareFacility.Facility_Capacity__c`, `HealthcareFacility.IsAlwaysOpen__c`, `HealthcareFacility.Location__c`, `HealthcareFacility.Operational_Hours__c`, `HealthcareFacility.Phone_Number__c`, `HealthcareFacility.Registration_Number__c`, `HealthcareProvider.Address__c`, `HealthcareProvider.Empanelment_Type__c`, `HealthcareProvider.External_ID__c`, `HealthcareProvider.Hospital_Id__c`, `HealthcareProvider.Hospital_Type__c`, `HealthcareProvider.Nodal_Person_Contact_Number__c`, `HealthcareProvider.Nodal_Person_Email_Address__c`, `HealthcareProvider.OTP__c`, `HealthcareProvider.OnBoarded_For_Convergence_Scheme__c`, `HealthcareProvider.Open_All_Day__c`, `HealthcareProvider.Operating_Hours__c`, `HealthcareProviderSpecialty.Healthcare_Provider__c`, `Medication.Dispensing_Pack_Size__c`, `Medication.Dose__c`, `Medication.Main_Indications__c`, `Medication.Precaution_Contraindication__c`, `Medication.Preferred_Use_OPD_IPD__c`, `Medication.Procedure__c`, `MedicationRequest.Afternoon__c`, `MedicationRequest.Afternoon_dose__c`, `MedicationRequest.Ayurvedic_Medication__c`, `MedicationRequest.BF_AF__c`, `MedicationRequest.CarePlanId__c`, `MedicationRequest.Care_Plan__c`, `MedicationRequest.Dosage_Frequency__c`, `MedicationRequest.Dosage_Instruction__c`, `MedicationRequest.Dosage_Strength__c`, `MedicationRequest.Dosage_Timing__c`, `MedicationRequest.Duration_Days__c`, `MedicationRequest.External_ID__c`, `MedicationRequest.Fulfilled_By__c`, `MedicationRequest.Instructions__c`, `MedicationRequest.Medication_Name__c`, `MedicationRequest.Medicine_Type__c`, `MedicationRequest.Morning__c`, `MedicationRequest.Morning_dose__c`, `MedicationRequest.Night__c`, `MedicationRequest.Night_dose__c`, `MedicationRequest.Prescribed_By__c`, `MedicationRequest.Prescription_End_Date__c`, `MedicationRequest.Prescription_Start_Date__c`, `MedicationRequest.Quantity__c`, `MedicationRequest.To_be_taken_in_afternoon__c`, `MedicationRequest.To_be_taken_in_morning__c`, `MedicationRequest.To_be_taken_in_night__c`, `User.Consultation_Logo__c`, `User.Doctor_Signature__c`, `User.Registration_Number__c`

### CustomLabel (1)
_No code references it. Kept because it is the Dhanwantri pharmacy URL._

`JanAushadhiPharmacy_Community_URL`

### CustomMetadata (49)
_Portal_Config.Default_Config, Portal_Email_Config.Default_Email, Prompt_Template.* (2), Referral_Validation_Rule.* (45)._

`Portal_Config.Default_Config`, `Portal_Email_Config.Default_Email`, `Prompt_Template.Primary_Prompt`, `Prompt_Template.allopathicReflectionPrompt`, `Referral_Validation_Rule.Backdated_Gap_Days`, `Referral_Validation_Rule.Band_High_Min`, `Referral_Validation_Rule.Band_Medium_Min`, `Referral_Validation_Rule.Cap_Other_Referral_Days`, `Referral_Validation_Rule.Consent_Granted`, `Referral_Validation_Rule.Depth_0_Visits`, `Referral_Validation_Rule.Depth_1_Visit`, `Referral_Validation_Rule.Depth_2_Visits`, `Referral_Validation_Rule.Depth_3_Plus_Visits`, `Referral_Validation_Rule.Diastolic_Max`, `Referral_Validation_Rule.Diastolic_Min`, `Referral_Validation_Rule.Documentation_Each`, `Referral_Validation_Rule.Documents_Shared`, `Referral_Validation_Rule.Duplicate_Test_Window_Days`, `Referral_Validation_Rule.Family_Referrals_Amber`, `Referral_Validation_Rule.No_Duplicate_Tests`, `Referral_Validation_Rule.No_Other_Open_Referral`, `Referral_Validation_Rule.Not_Received_Grace_Days`, `Referral_Validation_Rule.Other_Referral_Window_Days`, `Referral_Validation_Rule.PMJAY_Id_On_File`, `Referral_Validation_Rule.PMJAY_Verified`, `Referral_Validation_Rule.Patient_Referrals_Amber`, `Referral_Validation_Rule.Patient_Referrals_Red`, `Referral_Validation_Rule.Pulse_Max`, `Referral_Validation_Rule.Pulse_Min`, `Referral_Validation_Rule.Red_Flag_Pulse_Above`, `Referral_Validation_Rule.Red_Flag_SpO2_Below`, `Referral_Validation_Rule.Red_Flag_Systolic_Above`, `Referral_Validation_Rule.Red_Flag_Systolic_Below`, `Referral_Validation_Rule.Red_Flag_Temp_F_At_Least`, `Referral_Validation_Rule.SpO2_Max`, `Referral_Validation_Rule.SpO2_Min`, `Referral_Validation_Rule.Systolic_Max`, `Referral_Validation_Rule.Systolic_Min`, `Referral_Validation_Rule.Temp_F_Max`, `Referral_Validation_Rule.Temp_F_Min`, `Referral_Validation_Rule.Test_Results_Recorded`, `Referral_Validation_Rule.Tests_Ordered`, `Referral_Validation_Rule.Urgency_Match`, `Referral_Validation_Rule.Urgency_Mismatch`, `Referral_Validation_Rule.Utilisation_Window_Days`, `Referral_Validation_Rule.Vital_Recorded_Each`, `Referral_Validation_Rule.Vitals_Plausible`, `Referral_Validation_Rule.Weight_Kg_Max`, `Referral_Validation_Rule.Weight_Kg_Min`

### CustomNotificationType (1)
_New_Consultation_Request (PrescriptionApprovalController)._

`New_Consultation_Request`

### CustomObject (19)
_Dhanwantri custom objects, custom settings (Amazon_AWS__c, System_Log__c, allopathicPromptPrimary__c), CMDT types (Portal_Config__mdt, Portal_Email_Config__mdt, Prompt_Template__mdt, Referral_Validation_Rule__mdt) and the platform event Referral_Validation_Request__e. Each object brings its fields, list views, record types, compact layouts and validation rules._

`Active_medications__c`, `Amazon_AWS__c`, `Ayurvedic_Medication__c`, `Ayush_AI_Summary__c`, `Ayush_Prescription_Input__c`, `Care_Plan__c`, `Care_Transition__c`, `Diagnosis__c`, `Encounter_Summary__c`, `Janaushadhi_Pharmacy__c`, `Portal_Config__mdt`, `Portal_Email_Config__mdt`, `Prompt_Audit_Log__c`, `Prompt_Template__mdt`, `Referral_Validation_Request__e`, `Referral_Validation_Rule__mdt`, `Referral__c`, `System_Log__c`, `allopathicPromptPrimary__c`

### CustomPermission (1)
`Disable_trigger`

### CustomSite (6)
`Consent_Page`, `Dhanwantri_Prescription`, `Healthcare_Provider_Portal`, `MedicineCollection`, `Pharmacy_Jan_Aushadhi`, `Sample`

### CustomTab (8)
`Ayurvedic_Medication__c`, `Ayush_AI_Summary__c`, `Consultations_for_Approval`, `Diagnosis__c`, `Encounter_Summary__c`, `New_Patient_Registration_Form`, `Prompt_Audit_Log__c`, `Referral__c`

### DigitalExperienceBundle (5)
_LWR sites: Healthcare_Provider_Portal1 (pmjayReferralAppClone), Dhanwantri_Prescription1 (prescriptionsite), Pharmacy_Jan_Aushadhi1 (searchJanAushadhiKendra, qrDisplayComponent), Sample1 (no custom components), plus the CMS workspace content/Janaushadhi_Pharmacy._

`content/Janaushadhi_Pharmacy`, `site/Dhanwantri_Prescription1`, `site/Healthcare_Provider_Portal1`, `site/Pharmacy_Jan_Aushadhi1`, `site/Sample1`

### DigitalExperienceConfig (4)
`Dhanwantri_Prescription1`, `Healthcare_Provider_Portal1`, `Pharmacy_Jan_Aushadhi1`, `Sample1`

### DuplicateRule (1)
`Account.Patient_Deduplication_Updated`

### EmailTemplate (1)
_Classic text template for ClinicalEncounter approval. No retrieved code or flow references it (usage uncertain)._

`unfiled$public/Consultation_Submitted_for_Approval`

### ExperienceBundle (2)
_Aura sites Consent Page (patientConsentPortal) and MedicineCollection (medicineCollection). The other 4 Dhanwantri sites are LWR and cannot be retrieved as ExperienceBundle._

`Consent_Page1`, `MedicineCollection1`

### FlexiPage (15)
_Record pages for ClinicalEncounter (Consultation_New_page, Clinical_Encounter_Record_Page), Account (Patient_Record_Page), Diagnosis__c, Care_Plan__c, Referral__c, MedicationRequest, ClinicalServiceRequest, DiagnosticSummary, HealthcareProvider and Janaushadhi_Pharmacy__c. Also the app page New_Patient_Registration_Form and the utility bar PMJAY_PHWC_UtilityBar._

`Care_Plan_Record_Page`, `Care_Plan_Record_Page1`, `Clinical_Encounter_Record_Page`, `Clinical_Service_Request_Record_Page`, `Consultation_New_page`, `Diagnosis_Record_Page`, `Diagnosis_Record_Page1`, `Diagnostic_Summary_Record_Page`, `Healthcare_Provider_Record_Page`, `Janaushadhi_Pharmacy_Record_Page`, `Medication_Request_Record_Page`, `New_Patient_Registration_Form`, `PMJAY_PHWC_UtilityBar`, `Patient_Record_Page`, `Referral_Record_Page`

### Flow (21)
_Medication Guide = API name Medication_Guide (Medication_Guide1 is its obsolete Phi3 copy). Several ClinicalEncounter flows are Obsolete in the org (After_Insert_Doctor_Update, Clinical_Encounter_*, Consultation_Before_Update_Trigger_Owner_Assignment, Consultation_flow, Medication_Guide1, Update_Medication_Req_according_to_Record_Type). They are kept for history._

`Account_After_Create_Update_Registered_At`, `Account_before_insert_update_Maskind_Data`, `After_Create_Care_Transition_Patient_Email_Alert`, `After_Insert_Doctor_Update`, `Auto_creation_of_the_Account_for_a_Healthcare_Provider`, `Ayush_Prescription_Guide`, `Clinical_Encounter_Patient_field_update`, `Clinical_Encounter_Record_Type_Change`, `Clinical_Encounter_end_date_field_update`, `Clinical_Encounter_facility_field_update_PHWC_Chamoli`, `Consultation_Before_Update_Trigger_Owner_Assignment`, `Consultation_flow`, `Diagnostic_Summary_Record_Creation`, `MedicationRequest_Before_Insert`, `Medication_Guide`, `Medication_Guide1`, `New_Patient`, `Open_comment_box`, `Update_Medication_Req_according_to_Record_Type`, `Update_Medicine_Type_and_validate_if_same_type_of_medication_is_being_added`, `Update_record_type`

### GenAiPromptTemplate (7)
_All 7 prompt templates in the org. They are grounded by ayushPrescriptionPromptHelper, ClinicalEncounterPromptDataFormatter, IndianMedicationCatalogProvider and others, and invoked from the Medication_Guide / Ayush_Prescription_Guide flows and from Apex._

`Ayush_Prescription_Assistant`, `Clinical_Tests_Suggestion`, `MS_Phi3_Medication_Prescription_Assistant`, `Medication_Prescription_Assistant`, `Patient_Case_File`, `Referral_Validation`, `reflectionPromptAllopathic`

### Layout (30)
_Layouts of Dhanwantri objects, plus Health Cloud standard-object layouts the team edited (ClinicalEncounter, ClinicalEncounterDiagnosis, ClinicalServiceRequest, DiagnosticSummary, HealthcareProvider, HealthcareProviderSpecialty, Medication, MedicationRequest, PersonAccount x2). Six layouts have Hindi names. The manifest uses their decoded UTF-8 names, which retrieve correctly._

`Active_medications__c-Active medications Layout`, `Ayurvedic_Medication__c-Ayurvedic Medication %2F आयुर्वेदिक औषधि Layout`, `Ayush_AI_Summary__c-Ayurveda AI Summary Layout`, `Ayush_Prescription_Input__c-Ayush Prescription Inputs Layout`, `Care_Plan__c-Care Plan %2F सेवा निर्धारण Layout`, `Care_Transition__c-Care Transition %2F देखभाल हस्तांतरण Layout`, `ClinicalEncounter-Clinical Encounter Layout`, `ClinicalEncounter-New Clinical Encounter`, `ClinicalEncounter-View Clinical Encounter layout`, `ClinicalEncounterDiagnosis-Clinical Encounter Diagnosis Layout`, `ClinicalServiceRequest-Clinical Service Request Layout`, `Diagnosis__c-Diagnosis %2F निदान Layout`, `Diagnosis__c-Read only diagnosis layout`, `DiagnosticSummary-Diagnostic Summary Layout`, `Encounter_Summary__c-Encounter Summary Layout`, `HealthcareProvider-Healthcare Provider Layout`, `HealthcareProviderSpecialty-Healthcare Provider Specialty Layout`, `Janaushadhi_Pharmacy__c-Janaushadhi Pharmacy %2F जनऔषधि फार्मेसी Layout`, `Medication-Ayurvedic Layout`, `Medication-Medication Layout`, `MedicationRequest-Medication Request Layout`, `PersonAccount-Person Account Layout`, `PersonAccount-SDO - Person Account Layout`, `Portal_Config__mdt-Portal Config Layout`, `Portal_Email_Config__mdt-Portal Email Config Layout`, `Prompt_Audit_Log__c-Prompt Audit Log Layout`, `Prompt_Template__mdt-Prompt Template Layout`, `Referral_Validation_Rule__mdt-Referral Validation Rule Layout`, `Referral__c-Referral %2F रेफरल Layout`, `System_Log__c-System Log Layout`

### LightningComponentBundle (31)
_All 31 Dhanwantri LWCs, including every LWC on the must-include list._

`activeMedicationModal`, `ayushPrescriptionGuide`, `ayushPrescriptionModal`, `ayushPrescriptionParent`, `clinicalEncounterList`, `clinicalTestsAISuggestion`, `consultationSummaryDoctorApproval`, `consultationSummaryPreApproval`, `createConsultation`, `customLookup`, `encounterSummary`, `grantManualConsent`, `medicationFlow`, `medicationFlowPhi3`, `medicationGuide`, `medicationGuidePhi3`, `medicineCollection`, `newClinicalServiceRequest`, `newDiagnosis`, `newPatientForm`, `patientConsentPortal`, `pmjayReferralAppClone`, `prescriptionForms`, `prescriptionsite`, `qrDisplayComponent`, `referralComponentTest`, `referralToSecondaryProvider`, `referralValidationPanel`, `resendEmailHCProvider`, `searchJanAushadhiKendra`, `selectEmpanelledProvider`

### ListView (2)
_Account.All_Patients and ClinicalEncounter.MBBS_Doctors_ClinicalEncounter. List views on Dhanwantri custom objects come with the objects._

`Account.All_Patients`, `ClinicalEncounter.MBBS_Doctors_ClinicalEncounter`

### MatchingRules (1)
_Container Account. It holds Patient_Deduplication_Avoidance (Dhanwantri) but ALSO the standard Account/PersonAccount match rules, because a single MatchingRule cannot be retrieved alone. DuplicateRule Account.Patient_Deduplication_Updated needs it._

`Account`

### NamedCredential (1)
_AWS SageMaker Phi-3 (legacy NamedCredential with awsAccessKey). See Secrets._

`AWS_SageMaker_Phi3`

### NavigationMenu (6)
`SFDC_Default_Navigation_Consent_Page`, `SFDC_Default_Navigation_Dhanwantri_Prescription`, `SFDC_Default_Navigation_Healthcare_Provider_Portal`, `SFDC_Default_Navigation_MedicineCollection`, `SFDC_Default_Navigation_Pharmacy_UU002d_Jan_Aushadhi`, `SFDC_Default_Navigation_Sample`

### Network (6)
`Consent Page`, `Dhanwantri Prescription`, `Healthcare Provider Portal`, `MedicineCollection`, `Pharmacy - Jan Aushadhi`, `Sample`

### PermissionSet (1)
_Trigger_Bypass grants CustomPermission Disable_trigger. No code or flow references either one (uncertain)._

`Trigger_Bypass`

### Profile (8)
_6 site guest profiles + 2 internal user profiles (PHWC MBBS Doctor, PHWC Physician Assistant). Retrieved content covers only components in this manifest._

`Consent Page Profile`, `Dhanwantri Prescription Profile`, `Healthcare Provider Portal Profile`, `MedicineCollection Profile`, `PHWC MBBS Doctor`, `PHWC Physician Assistant`, `Pharmacy - Jan Aushadhi Profile`, `Sample Profile`

### Queue (1)
_MBBS_Doctors (used by PrescriptionApprovalController)._

`MBBS_Doctors`

### QuickAction (17)
_ClinicalEncounter, Account and Referral__c actions. ClinicalEncounter.AI_Clinical_Encounter_Summary launches the managed flow healthcloud__PatientRegistration._

`Account.New_Consultation`, `Account.New_Patient`, `Account.Refer`, `ClinicalEncounter.AI_Clinical_Encounter_Summary`, `ClinicalEncounter.AI_Medication_Assistant`, `ClinicalEncounter.Add_Clinical_Service_Request`, `ClinicalEncounter.Add_Diagnosis`, `ClinicalEncounter.Ayush_Medication_Assistant`, `ClinicalEncounter.Encounter_Summary`, `ClinicalEncounter.New_Consultation`, `ClinicalEncounter.New_Consultations`, `ClinicalEncounter.New_Prescription`, `ClinicalEncounter.Phi3_AI_Medication_Assistant`, `ClinicalEncounter.Test_New`, `Referral__c.Grant_Manual_Consent`, `Referral__c.Resend_Email`, `Referral__c.Send_Referral_Case_File`

### RecordType (6)
`ClinicalEncounter.Clinical_Encounter_Detail`, `ClinicalEncounter.New_Consultation`, `Medication.Alleopathy`, `Medication.Ayurvedic`, `MedicationRequest.Care_Plan`, `MedicationRequest.Clinical_Encounter`

### RemoteSiteSetting (1)
_SageMaker runtime endpoint._

`AWS_SageMaker_Runtime`

### StaticResource (19)
_Logos/CSS used by the LWCs, plus the SNA_*_sf_default_cdn_* CDN resources generated for the Experience sites._

`AyushLeafIcon`, `DoctorLogo`, `DoctorLogoNew`, `DoctorLogoWithoutBg`, `Government_logo`, `PMLOGO`, `PMLOGO2`, `SNA_QlkuZ_sf_default_cdn_Consent_Page1`, `SNA_Qsc2w_sf_default_cdn_Dhanwantri_Prescription1`, `SNA_SAA7j_sf_default_cdn_Pharmacy_Jan_Aushadhi1`, `SNA_sJkSx_sf_default_cdn_MedicineCollection1`, `SNA_tdMYM_sf_default_cdn_Healthcare_Provider_Portal1`, `cardContainer`, `caseFileLogo`, `crmitLogo`, `generatedByAI`, `hideHelpText`, `pmjayLogoNew`, `reduceCustomModalSize`

### ValidationRule (11)
`Account.Abha_verification`, `Account.Adhar_validation`, `Account.PMJAY_Verified_Requires_ID`, `ClinicalEncounter.Prevent_Status_Revert_From_Completed`, `ClinicalEncounter.Restrict_Status_Manual_Edit`, `ClinicalEncounter.Start_date_validation`, `ClinicalEncounter.Start_read_only`, `ClinicalServiceRequest.Complete_By`, `MedicationRequest.Dosage_details_check`, `MedicationRequest.Exactly_One_Medication_Required`, `MedicationRequest.Start_From`

### WebLink (3)
_PMJAY_Beneficiary_Check (Patient_Record_Page), Trial_Button (opens the New Patient Registration tab), AI_VaidyaMitra (ClinicalEncounter layouts)._

`Account.PMJAY_Beneficiary_Check`, `Account.Trial_Button`, `ClinicalEncounter.AI_VaidyaMitra`

## Must-include list (official component document): status
- All 17 LWCs, all 20 Apex classes and both flows on the list exist in the org and are in the manifest. "Medication Guide" = `Medication_Guide` (label "New Guide"). Its Phi3 copy `Medication_Guide1` is also included.
- **Missing:** the org has no test classes for any of the 20 listed Apex classes. Only `IndianMedicationCatalogProviderTest` and `ReferralValidationServiceTest` exist, and both are included. A production deploy will need new tests for coverage.
- No trigger calls `ReferralTriggerHelper`. Apex classes invoke it, and all of them are included.

## Uncertain
- **Sample site** (CustomSite/Network `Sample`, DigitalExperienceBundle `site/Sample1`, DigitalExperienceConfig `Sample1`, NavigationMenu `SFDC_Default_Navigation_Sample`, `Sample Profile`): UnderConstruction, no custom components. INCLUDED because the user confirmed the sites.
- `Trigger_Bypass` permission set + `Disable_trigger` custom permission: created by the team, referenced nowhere. INCLUDED.
- `allopathicPromptPrimary__c`, `Portal_Email_Config__mdt` (+ record), CustomLabel `JanAushadhiPharmacy_Community_URL`, EmailTemplate `Consultation_Submitted_for_Approval`: no code references them. INCLUDED.
- Test/dummy items, all INCLUDED: `referralComponentTest` (actually used by Account.Refer), `ClinicalEncounter.Test_New`, `Account.Trial_Button`, the empty Aura `NewPatientAppWrapper`, the duplicate wrappers `NewPatientAppp`/`newPatientAuraWrapperr`/`NewPatientAppWrapperr`, `Care_Plan_Record_Page1`, `Diagnosis_Record_Page1`.
- `MatchingRules: Account` also brings the 2 standard Account match rules. INCLUDED, because the single rule cannot be retrieved alone.
- **EXCLUDED, review:** Flow `Home_Health_New_Patient_SoC_Flow`. The team created it on ClinicalServiceRequest, but it is a Health Cloud "Home Health SoC" template that creates Tasks and references the SDO object AI_Agent_Conversation_Entry__c.
- **EXCLUDED, review:** the CarePlan custom fields other than `Care_Transition__c` (`Authorization_Type__c`, `CaseProceedingResultId__c`, `ClinicalEncounterId__c`, `CreatedById__c`, `CreatedDate__c`, `Description__c`, `EndDate__c`, `External_ID__c`, `LastModifiedById__c`, `LastModifiedDate__c`, `RecordedDateTime__c`, `StartDate__c`, `Status__c`, `TaskJobStatusMessage__c`) and `Contact.AccountId__c`. They look like a bulk/import artefact (2026-02-13) and Dhanwantri does not use them. `MedicationRequest.CarePlanId__c` from the same batch IS included with the MedicationRequest fields.
- **EXCLUDED, review:** SDO layouts the team edited to show Dhanwantri fields/related lists: `Account-Account Layout`, `Account-SDO - Account`, `Account-SDO - Account Community`, `Account-SDO - Partner Account`, `Contact-*` (4), `User-User Layout` (shows Doctor_Signature__c/Consultation_Logo__c/Registration_Number__c). Deploying them would overwrite org-wide/SDO layouts.
- **EXCLUDED:** FlexiPage `SDO_Account_Default`, an SDO page that also hosts Account.Refer.

## Excluded but referenced
- Standard community VF pages that the CustomSites reference: BandwidthExceeded, CommunitiesLanding, CommunitiesLogin, CommunitiesSelfReg, Exception, FileNotFound, ForgotPassword, InMaintenance, UnderConstruction (+ their SDO controllers). Salesforce generates them when Digital Experiences is enabled. They must exist in the target org.
- Managed/platform: Health Cloud flow `healthcloud__PatientRegistration` (QuickAction ClinicalEncounter.AI_Clinical_Encounter_Summary), `industries_common:generateSummaryWrapper` (Patient_Record_Page), the Health Cloud standard objects (ClinicalEncounter, MedicationRequest, Medication, DiagnosticSummary, HealthcareProvider(Specialty), HealthcareFacility, ClinicalServiceRequest, CarePlan, AllergyIntolerance, HealthCondition), Person Accounts, and Einstein Generative AI / Prompt Builder.
- Account record types `PersonAccount` (Id hardcoded in newPatientForm.js and in flow New_Patient) and `SDO_Account_Simple` (hardcoded in flow Auto_creation_of_the_Account_for_a_Healthcare_Provider): SDO record types, not included.
- The SDO class `recommendationController` (SDO B2B code) is enabled on the Consent Page guest profile and the PHWC profiles. It is not included, and the manifest-scoped profile retrieve drops it.
- CareTransitionPatientEmailAlert queries an EmailTemplate named "Care Transition Email Alert" that does **not exist** in the org. `PmjayReferralService` references a field that does not exist, `Medication_Name_Text__c` (in a string/query).
- The Experience sites use `naveen.guleria2026@crmit.com` as site admin and guest record owner. The Networks use `emailSenderAddress` naveen.guleria@crmit.com.
- The chartjs static resources are SDO. Dhanwantri does not use them.

## Secrets / org-specific (must fix before committing)
- **CRITICAL: `ReferralTriggerHelper.cls` (~line 379) hardcodes an AWS access key (`[AWS access key redacted]`) AND its secret key** for the SMS API Gateway `https://4a3o7o6prl.execute-api.ap-south-1.amazonaws.com/dev/send-sms`. Remove both from source (move them to a Named/External Credential) and rotate the key before pushing to GitHub, because git history would keep it.
- NamedCredential `AWS_SageMaker_Phi3` contains `awsAccessKey` [AWS access key redacted] (the secret was not retrieved). Strip it or replace it with a placeholder.
- Custom setting `Amazon_AWS__c` (AccessKey__c, SecretKey__c, EndPoint_URL__c): only the metadata is included. Its data holds secrets and was not exported.
- Connected App `CareRounds_POC` (consumer key in its metadata): NOT included. It is an unrelated POC.
- Hardcoded Ids: OrgWideEmailAddress `0D2KY000000PBA90AO` (No Reply, shaik.karishma@crmit.com) and User `005KY000003ABfAYAW` (Dr.Puneet Gupta) in PrescriptionApprovalController. RecordType `012KY000001OVLRYA4` in newPatientForm.js and the New_Patient flow, and `012KY000001OVKWYA4` in the Auto_creation_of_the_Account_for_a_Healthcare_Provider flow.
- Hardcoded site URLs (cr1769668480593.my.site.com): `/PatientConsent/s/` (ClinicalEncounterController2), `/Janaushadhi` (PrescriptionApprovalController), `/janAushadiKendraMedicineCollection/s` (QRCodeService), `/HealthCareProviders/` (ReferralTriggerHelper). PrescriptionApprovalController also has the placeholder `https://your-org.lightning.force.com`.
- External endpoints: api.qrserver.com (QR), nominatim.openstreetmap.org (PmjayReferralService), maps.google.com, runtime.sagemaker.us-east-1.amazonaws.com.
- The CustomSites/Networks embed site admin / guest record owner `naveen.guleria2026@crmit.com` and sender naveen.guleria@crmit.com. Change these for each target org.
