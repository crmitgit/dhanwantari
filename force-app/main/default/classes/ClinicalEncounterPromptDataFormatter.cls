public without sharing class ClinicalEncounterPromptDataFormatter {

    /* =========================
       INVOCABLE INPUT
    ========================== */

    public class Request {
        @InvocableVariable(required=true)
        public Id encounterId;
    }

    /* =========================
       INVOCABLE OUTPUT
    ========================== */

    public class Response {
        @InvocableVariable
        public String Prompt;
    }

    /* =========================
       INVOCABLE METHOD
    ========================== */

    @InvocableMethod(label='Get Clinical Encounter Prompt')
    public static List<Response> getPrompt(List<Request> requests) {

        List<Response> responses = new List<Response>();
        Response output = new Response();
        responses.add(output);

        if (requests == null || requests.isEmpty() || requests[0].encounterId == null) {
            output.Prompt = 'No Encounter Id provided.';
            return responses;
        }

        Id encounterId = requests[0].encounterId;

        ClinicalEncounter encounter = [
            SELECT Name, Height_in_cm__c, Weight_in_Kg__c, Pulse_Rate_in_BPM__c, SpO2__c,
                   Blood_Pressure__c, Body_Temperature__c,
                   Patient.Age__c, Patient.Gender__c,
                   Symptoms__c, Medical_History__c, Clinical_Findings__c,Additional_Information__c,
                   (
                       SELECT Clinical_Diagnosis__c, Diagnosis_Description__c
                       FROM Diagnoses__r
                   ),
                   (
                       SELECT Existing_Medications__c,
                              Smoking__c,
                              Alcohol_Use__c,
                              Pregnancy_Status__c,
                              Allergy_Details__c,
                              Existing_Conditions__c,
                              Has_Allergies__c,
                              Sleep_Deprivation__c
                       FROM Active_Medications__r
                   )
            FROM ClinicalEncounter
            WHERE Id = :encounterId
            LIMIT 1
        ];

        String prompt = '';

        /* =========================
           ENCOUNTER SUMMARY
        ========================== */

        prompt += '=== ENCOUNTER SUMMARY ===\n';
        prompt += 'Age: ' +
            (encounter.Patient.Age__c != null ? encounter.Patient.Age__c + ' years' : 'N/A') + '\n';
        prompt += 'Gender: ' +
            (encounter.Patient.Gender__c != null ? encounter.Patient.Gender__c : 'N/A') + '\n';
        prompt += 'Height: ' +
            (encounter.Height_in_cm__c != null ? encounter.Height_in_cm__c + ' cm' : 'N/A') + '\n';
        prompt += 'Weight: ' +
            (encounter.Weight_in_Kg__c != null ? encounter.Weight_in_Kg__c + ' kg' : 'N/A') + '\n';
        prompt += 'Pulse Rate: ' +
            (encounter.Pulse_Rate_in_BPM__c != null ? encounter.Pulse_Rate_in_BPM__c + ' BPM' : 'N/A') + '\n';
        prompt += 'Blood Pressure: ' +
            (String.isNotBlank(encounter.Blood_Pressure__c) ? encounter.Blood_Pressure__c : 'N/A') + '\n';
        prompt += 'Body Temperature: ' +
            (encounter.Body_Temperature__c != null ? encounter.Body_Temperature__c + ' °F' : 'N/A') + '\n';
        prompt += 'SpO2: ' +
            (encounter.SpO2__c != null ? encounter.SpO2__c + '%' : 'N/A') + '\n';

        /* =========================
           SYMPTOMS & HISTORY
        ========================== */

        prompt += '\n=== SYMPTOMS & HISTORY ===\n';
        prompt += 'Chief Complaints:\n' +
            (String.isNotBlank(encounter.Symptoms__c)
                ? encounter.Symptoms__c
                : 'None reported') + '\n\n';

        prompt += 'Medical History:\n' +
            (String.isNotBlank(encounter.Medical_History__c)
                ? encounter.Medical_History__c
                : 'None reported') + '\n\n';

        prompt += 'Clinical Findings:\n' +
            (String.isNotBlank(encounter.Clinical_Findings__c)
                ? encounter.Clinical_Findings__c
                : 'None reported') + '\n';

        prompt += 'Additional Information: ' +
        (String.isNotBlank(encounter.Additional_Information__c)
            ? encounter.Additional_Information__c
            : 'Not specified') + '\n';

        prompt += '\n=== MEDICATIONS & LIFESTYLE ===\n';

        if (encounter.Active_Medications__r != null &&
            !encounter.Active_Medications__r.isEmpty()) {

            for (SObject med : encounter.Active_Medications__r) {

                String existingMeds     = (String) med.get('Existing_Medications__c');
                String pregnancyStatus  = (String) med.get('Pregnancy_Status__c');
                String allergyDetails   = (String) med.get('Allergy_Details__c');
                String existingCond     = (String) med.get('Existing_Conditions__c');
                Boolean hasAllergies    = (Boolean) med.get('Has_Allergies__c');
                Boolean smoking         = (Boolean) med.get('Smoking__c');
                Boolean alcoholUse      = (Boolean) med.get('Alcohol_Use__c');


                if (String.isNotBlank(existingMeds)) {
                    prompt += 'Active Medications: ' + existingMeds + '\n';
                }

                if (String.isNotBlank(pregnancyStatus)) {
                    prompt += 'Pregnancy Status: ' + pregnancyStatus + '\n';
                }

                if (hasAllergies != null) {
                    prompt += 'Has Allergies: ' + (hasAllergies ? 'Yes' : 'No') + '\n';
                }

                if (String.isNotBlank(allergyDetails)) {
                    prompt += 'Allergy Details: ' + allergyDetails + '\n';
                }

                if (String.isNotBlank(existingCond)) {
                    prompt += 'Existing Conditions: ' + existingCond + '\n';
                }
                
                if (smoking != null) {
                    prompt += 'Smoking: ' + (smoking ? 'Yes' : 'No') + '\n';
                }
                
                if (alcoholUse != null) {
                    prompt += 'Alcohol Use: ' + (alcoholUse ? 'Yes' : 'No') + '\n';
                }
                

                prompt += '\n'; // spacing between records
            }


        } else {
            prompt += 'None reported\n';
        }



        /* =========================
           DIAGNOSES
        ========================== */

        prompt += '\n=== DIAGNOSES ===\n';

        if (encounter.Diagnoses__r != null &&
            !encounter.Diagnoses__r.isEmpty()) {

            for (Diagnosis__c d : encounter.Diagnoses__r) {
                prompt += 'Clinical Diagnosis: ' + d.Clinical_Diagnosis__c;

                if (String.isNotBlank(d.Diagnosis_Description__c)) {
                    prompt += ' ; Description: ' + d.Diagnosis_Description__c;
                }
                prompt += '\n';
            }
        } else {
            prompt += 'None recorded\n';
        }

        output.Prompt = prompt.trim();
        return responses;
    }
}