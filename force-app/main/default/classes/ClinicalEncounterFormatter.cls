public class ClinicalEncounterFormatter {
	
	public class PromptWrapperClass {
    @AuraEnabled
    public String finalContent;

    @AuraEnabled
    public Boolean success; 
    }

	public class CustomException extends Exception {}
    
    public static String generateFormattedSummary(List<Id> clinicalEncounterIds) {
    
        List<ClinicalEncounter> encounters = [
            SELECT Id, StartDate, Symptoms__c, Medical_History__c, Clinical_Findings__c,
                (SELECT Id, Clinical_Diagnosis__c, Diagnosis_Description__c FROM Diagnoses__r),
                (SELECT Id, Medication.Name, Prescription_Start_Date__c FROM MedicationRequest_ClinicalEncounter),
                (SELECT Id, Requested_Test__c FROM Clinical_Service_Requests__r)
            FROM ClinicalEncounter
            WHERE Id IN :clinicalEncounterIds
        ];

        String summary = '';

        for (ClinicalEncounter encounter : encounters) {
            summary += 'Clinical Encounters Data\n';
            summary += 'Encounter Date: ' + (encounter.StartDate != null ? String.valueOf(encounter.StartDate) : 'N/A') + '\n';

            // Symptoms and Medical History 
            summary += 'Symptoms: ' + (encounter.Symptoms__c != null ? encounter.Symptoms__c : 'N/A') + '\n';
            summary += 'Medical History: ' + (encounter.Medical_History__c != null ? encounter.Medical_History__c : 'N/A') + '\n\n';

            /* Clinical Diagnosis 
            if (!encounter.Diagnoses__r.isEmpty()) {
                Diagnosis__c diag = encounter.Diagnoses__r[0]; // assume primary diagnosis
                summary += 'Clinical Diagnosis\n';
               summary += 'Diagnosis: ' + (diag.Clinical_Diagnosis__c != null ? diag.Clinical_Diagnosis__c : 'N/A') + '\n';
                summary += 'Description: ' + (diag.Diagnosis_Description__c != null ? diag.Diagnosis_Description__c : 'N/A') + '\n\n';
            } else {
                summary += 'Clinical Diagnosis\nDiagnosis: N/A\nDescription: N/A\n\n';
            } */
			
             summary += 'Clinical Findings: ' + (encounter.Clinical_Findings__c	 != null ? encounter.Clinical_Findings__c : 'N/A') + '\n\n';

            // Prescription
            if (!encounter.MedicationRequest_ClinicalEncounter.isEmpty()) {
                summary += 'Prescription\n';
                for (MedicationRequest med : encounter.MedicationRequest_ClinicalEncounter) {
                    summary += (med.Medication != null ? med.Medication.Name : 'Unknown Medication') + '\n';
                }
            } else {
                summary += 'Prescription\nNone\n';
            }
            summary += '\n';

            // Clinical Service Requests
            if (!encounter.Clinical_Service_Requests__r.isEmpty()) {
                summary += 'Clinical Service Requests\n';
                for (ClinicalServiceRequest csr : encounter.Clinical_Service_Requests__r) {
                    summary += (csr.Requested_Test__c != null ? csr.Requested_Test__c : 'Unknown Test') + '\n';
                }
            } else {
                summary += 'Clinical Service Requests\nNone\n';
            }

            summary += '\n---\n\n';
        }

        return summary;
    }

  	@AuraEnabled
	public static PromptWrapperClass sendPatientCasePrompt(String accountId, List<Id> encounterIds) {
    	PromptWrapperClass wp = new PromptWrapperClass();
    
    try {
        // Input validation
        if (String.isEmpty(accountId) || accountId.length() != 18) {
            throw new CustomException('Invalid or missing Account Id.');
        }

        if (encounterIds == null || encounterIds.isEmpty()) {
            throw new CustomException('No clinical encounters selected.');
        }

        // Fetch Account (optional, in case name or other fields needed)
        Account acc = [SELECT Id FROM Account WHERE Id = :accountId LIMIT 1];
        if (acc == null) {
            throw new CustomException('Account not found for Id: ' + accountId);
        }

        // Generate the formatted clinical encounter summary
        String clinicalSummary = ClinicalEncounterFormatter.generateFormattedSummary(encounterIds);
		System.debug(clinicalSummary);
		//ClinicalEncounterFormatter.generateFormattedSummary(encounterIds);

        // Prepare input: account
        Map<String, String> accountInput = new Map<String, String>();
        accountInput.put('id', acc.Id);

        ConnectApi.WrappedValue accountWrapped = new ConnectApi.WrappedValue();
        accountWrapped.value = accountInput;

        // Prepare input: clinicalEncountersSummary
        ConnectApi.WrappedValue summaryWrapped = new ConnectApi.WrappedValue();
        summaryWrapped.value = clinicalSummary;

        // InputParams map
        Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
        inputParams.put('Input:account', accountWrapped);
        inputParams.put('Input:clinicalEncountersSummary', summaryWrapped);

        // Prepare Prompt Template Input
        ConnectApi.EinsteinPromptTemplateGenerationsInput templateInput = new ConnectApi.EinsteinPromptTemplateGenerationsInput();
        templateInput.isPreview = false;
        templateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();
        templateInput.inputParams = inputParams;
         
       // Patient_Case_File
		//account
		//clinicalEncountersSummary
        // Call Prompt Template
        ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Patient_Case_File', templateInput);

        // Handle response
        if (result != null && !result.generations.isEmpty()) {
            String generatedText = result.generations[0].text;
            wp.finalContent = generatedText; // This will be shown in LWC
        } else {
            wp.finalContent = 'No generations returned from prompt.';
        }

    } catch (CustomException ce) {
        wp.finalContent = 'Custom Exception: ' + ce.getMessage();
		
    } catch (Exception ex) {
        wp.finalContent = 'General Exception: ' + ex.getMessage();
        System.debug('--- STACK TRACE ---');
    	System.debug(ex.getStackTraceString());
    }

    return wp;
}
}