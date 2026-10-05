public with sharing class ClinicalTestSuggestionService {

    // Wrapper for response (optional but clean for LWC)
    public class ResponseWrapper {
        @AuraEnabled public String suggestedTests;
        @AuraEnabled public Boolean success;
        @AuraEnabled public String message;
    }

    @AuraEnabled(cacheable=true)
    public static String getPatientGender(Id encounterId) {

        ClinicalEncounter enc = [
            SELECT Patient.Gender__c
            FROM ClinicalEncounter
            WHERE Id = :encounterId
            LIMIT 1
        ];

        return enc.Patient.Gender__c;
    }

    // 🔹 STEP 1: Format input data for AI
    public static String generateClinicalTestInput(List<Id> encounterIds) {

        List<ClinicalEncounter> encounters = [ SELECT Id, Symptoms__c,Medical_History__c,Clinical_Findings__c, Patient.Age__c, Patient.Gender__c,
                   Height_in_cm__c, Weight_in_Kg__c,
                   Pulse_Rate_in_BPM__c, Body_Temperature__c,
                   Blood_Pressure__c, SpO2__c
            FROM ClinicalEncounter
            WHERE Id IN :encounterIds
        ];

        String inputText = '';

        for (ClinicalEncounter enc : encounters) {

            inputText += 'Chief Complaints: ' +
                (enc.Symptoms__c != null ? enc.Symptoms__c : 'N/A') + '\n';
            inputText += 'Medical History: ' +
                (enc.Medical_History__c != null ? enc.Medical_History__c : 'N/A') + '\n';

            inputText += 'Vitals:\n';
            inputText += 'Height: ' +
                (enc.Height_in_cm__c != null ? enc.Height_in_cm__c + ' cm' : 'N/A') + '\n';

            inputText += 'Weight: ' +
                (enc.Weight_in_Kg__c != null ? enc.Weight_in_Kg__c + ' kg' : 'N/A') + '\n';

            inputText += 'Pulse Rate: ' +
                (enc.Pulse_Rate_in_BPM__c != null ? enc.Pulse_Rate_in_BPM__c + ' bpm' : 'N/A') + '\n';

            inputText += 'Blood Pressure: ' +
                (enc.Blood_Pressure__c != null ? enc.Blood_Pressure__c : 'N/A') + '\n';

            inputText += 'Temperature: ' +
                (enc.Body_Temperature__c != null ? enc.Body_Temperature__c + ' °C' : 'N/A') + '\n';

            inputText += 'SpO2: ' +
                (enc.SpO2__c != null ? enc.SpO2__c + '%' : 'N/A') + '\n';

			inputText += 'Patient age: '+
				(enc.Patient.Age__c != null ? String.valueOf(enc.Patient.Age__c) : 'N/A') + '\n';

			inputText += 'Patient gender: '+
				(enc.Patient.Gender__c != null ? enc.Patient.Gender__c : 'N/A') + '\n';

            inputText += '\n---\n';
        }

        System.debug('AI Input Data: ' + inputText);

        return inputText;
    }


    // 🔹 STEP 2: Main AI method
    @AuraEnabled
    public static ResponseWrapper suggestClinicalTests(List<Id> encounterIds, String pregnancyStatus) {

        ResponseWrapper response = new ResponseWrapper();

        try {
            
            if (encounterIds == null || encounterIds.isEmpty()) {
                throw new AuraHandledException('No encounters provided');
            }

            // 🔸 Generate input text
            String clinicalData = generateClinicalTestInput(encounterIds);

            // 🔸 Wrap input for prompt
            ConnectApi.WrappedValue clinicalDataWrapped = new ConnectApi.WrappedValue();
            clinicalDataWrapped.value = clinicalData;

            ConnectApi.WrappedValue pregnancyWrapped = new ConnectApi.WrappedValue();
            pregnancyWrapped.value = pregnancyStatus != null ? pregnancyStatus : 'Not Applicable';

            Map<String, ConnectApi.WrappedValue> inputParams = new Map<String, ConnectApi.WrappedValue>();
            inputParams.put('Input:Clinical_Encounter_Summary', clinicalDataWrapped);
            inputParams.put('Input:pregnancyStatus', pregnancyWrapped);

            // 🔸 Prepare prompt input
            ConnectApi.EinsteinPromptTemplateGenerationsInput templateInput =
                new ConnectApi.EinsteinPromptTemplateGenerationsInput();

            templateInput.inputParams = inputParams;
            templateInput.isPreview = false;
            templateInput.additionalConfig = new ConnectApi.EinsteinLlmAdditionalConfigInput();

            // 🔸 Call AI
            ConnectApi.EinsteinPromptTemplateGenerationsRepresentation result =
            ConnectApi.EinsteinLLM.generateMessagesForPromptTemplate('Clinical_Tests_Suggestion', templateInput);

            // 🔸 Handle response
            if (result != null && !result.generations.isEmpty()) {
                response.suggestedTests = result.generations[0].text;
                response.success = true;
                response.message = 'Test suggestions generated successfully';
            } else {
                response.suggestedTests = '';
                response.success = false;
                response.message = 'No response from AI';
            }

        } catch (AuraHandledException ae) {
            response.success = false;
            response.message = ae.getMessage();

        } catch (Exception e) {
            response.success = false;
            response.message = 'Unexpected error: ' + e.getMessage();
            System.debug('Error: ' + e.getStackTraceString());
        }

        return response;
    }

    @AuraEnabled(cacheable=true)
    public static String getFormattedClinicalData(Id encounterId) {

        List<Id> ids = new List<Id>{ encounterId };

        String formattedData = generateClinicalTestInput(ids);

        System.debug('Formatted Data: ' + formattedData);

        return formattedData;
    }
}