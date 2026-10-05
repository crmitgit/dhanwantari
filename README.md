# Dhanwantri – PMJAY PHWC (Salesforce)

Salesforce metadata for **Dhanwantri**, the PM-JAY Ayushman Arogya Mandir (PHWC) application built on Health Cloud and Experience Cloud.

## Modules

| Module | Main components |
|---|---|
| Consultation | `encounterSummary`, `newDiagnosis`, `prescriptionForms`, `newClinicalServiceRequest`, `clinicalEncounterList`, `consultationSummaryPreApproval`, `consultationSummaryDoctorApproval` · `EncounterSummaryController`, `PrescriptionApprovalController`, `PrintEncounterController`, `ClinicalServiceRequestController`, `MedicationRequestController`, `DiagnosisController`, `FollowUpReminderScheduler`, `FollowUpReminderEmailScheduler` |
| Allopathic Prescription Assistant | `medicationFlow`, `activeMedicationModal`, `medicationGuide` · `ActiveMedicationController` · flow `Medication_Guide` · prompt `Medication_Prescription_Assistant` |
| Ayurvedic Prescription Assistant | `ayushPrescriptionParent`, `ayushPrescriptionModal`, `ayushPrescriptionGuide` · `ActiveMedicationController`, `MedicationGuideController`, `ayushPrescriptionPromptHelper` · flow `Ayush_Prescription_Guide` · prompt `Ayush_Prescription_Assistant` |
| Referral | `referralComponentTest`, `patientConsentPortal` · `ClinicalEncounterController2`, `HealthcareProviderController`, `PreviewCaseFileController`, `MedicationController`, `DraftReferralController`, `PmjayReferralConsentService`, `ReferralTriggerHelper`, `ReferralToAnotherProvider` |
| Empanelled Healthcare Portal | `pmjayReferralAppClone`, `prescriptionForms`, `customLookup` · `PmjayReferralService`, `CustomLookupController` |
| Experience sites | Healthcare Provider Portal, Consent Page, Pharmacy – Jan Aushadhi, Dhanwantri Prescription, MedicineCollection |

The full component list (and why each item is included) is in [`manifest/DHANWANTRI_INVENTORY.md`](manifest/DHANWANTRI_INVENTORY.md).
[`manifest/package.xml`](manifest/package.xml) is the source of truth for what belongs to this project.

## Working with the org

```bash
# authenticate once
sf org login web --alias dhanwantri

# pull the latest Dhanwantri metadata from the org
sf project retrieve start -x manifest/package.xml --target-org dhanwantri

# deploy a change (validate first)
sf project deploy start -d force-app/main/default/classes/MyClass.cls --target-org dhanwantri --dry-run
sf project deploy start -d force-app/main/default/classes/MyClass.cls --target-org dhanwantri
```

When adding a new component, also add it to `manifest/package.xml`.

## Secrets and org-specific configuration

Never commit keys, passwords or patient data.

- **AWS (SMS gateway):** keys are stored in the `Amazon_AWS__c` custom setting (org default) in each org, not in code.
- **Named Credential `AWS_SageMaker_Phi3`:** the access key in this repo is a placeholder (`SET_IN_ORG_DO_NOT_COMMIT`). Do not deploy this file over a working org; set the key in Setup instead.
- **Org-specific values still hardcoded in code** (must be changed before deploying to another org): Org-Wide Email Address Id and a User Id in `PrescriptionApprovalController`, record type Ids in `newPatientForm` and flows, and the site domain `cr1769668480593.my.site.com` in several classes. See the Secrets section of the inventory.

## Prerequisites in a target org

Health Cloud, Person Accounts, Experience Cloud, Einstein / Prompt Builder (prompt templates use `sfdc_ai__DefaultGPT56Luna` / `sfdc_ai__DefaultGPT5Mini`), and the managed/platform items listed under "Excluded but referenced" in the inventory.

## Known gaps

- Most Apex classes have no test classes yet; production deployment needs 75% coverage.
- `CareTransitionPatientEmailAlert` references an email template that does not exist; `PmjayReferralService` references a field `Medication_Name_Text__c` that does not exist.
