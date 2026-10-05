public without sharing class ayushPrescriptionPromptHelper {

    /* =========================
       INVOCABLE INPUT / OUTPUT
    ========================== */

    public class Request {
        @InvocableVariable(required=true)
        public Id consultantId;
    }

    public class Response {
        @InvocableVariable
        public String Prompt;
    }

    /* =========================
       AYUSH SEASON HELPER
    ========================== */

    public static String getCurrentAyushSeason() {
        Integer month = Date.today().month();

        Map<Integer, String> seasonMap = new Map<Integer, String>{
            1  => 'Shishir (Winter)',
            2  => 'Shishir (Winter)',
            3  => 'Vasanta (Spring)',
            4  => 'Vasanta (Spring)',
            5  => 'Grishma (Summer)',
            6  => 'Grishma (Summer)',
            7  => 'Varsha (Monsoon)',
            8  => 'Varsha (Monsoon)',
            9  => 'Sharad (Autumn)',
            10 => 'Sharad (Autumn)',
            11 => 'Hemant (Pre-Winter)',
            12 => 'Hemant (Pre-Winter)'
        };

        String monthName = DateTime.now().format('MMMM');
        return monthName + ' / ' + seasonMap.get(month);
    }

    /* =========================
       INVOCABLE METHOD
    ========================== */

    @InvocableMethod(label='Get Ayush Encounter Prompt')
    public static List<Response> getPrompt(List<Request> requests) {

        List<Response> responses = new List<Response>();
        Response output = new Response();
        responses.add(output);

        if (requests == null || requests.isEmpty() || requests[0].consultantId == null) {
            output.Prompt = 'No Encounter Id provided.';
            return responses;
        }

        Id encounterId = requests[0].consultantId;

        ClinicalEncounter encounter = [
            SELECT Name, StartDate, EndDate, Status,
                   Height_in_cm__c, Patient.Weight_in_Kg__c, Pulse_Rate_in_BPM__c,
                   Blood_Pressure__c, Body_Temperature__c, Patient.Age__c,Vikriti__c,
                   Symptoms__c, Medical_History__c, Clinical_Findings__c,Patient.Secondary_Prakriti__c,
                   Contact__r.Name, Patient.Body_type__c,Additional_Information__c, Prescribing_Doctor__r.Name,
                   (
                       SELECT Clinical_Diagnosis__c, Diagnosis_Description__c
                       FROM Diagnoses__r
                   ),
                   (
                       SELECT Existing_Medications__c,
                              Lifestyle_Habits__c,
                              Has_Allergies__c,
                              Allergy_Details__c,
                              Pregnancy_Status__c,
                              Existing_Allopathic_Medicines__c,
                              Smoking__c,
                              Sleep_Deprivation__c,
                              Physical_Inactivity__c,
                              Alcohol_Use__c
                       FROM Ayush_Prescription_Inputs__r
                   )
            FROM ClinicalEncounter
            WHERE Id = :encounterId
            LIMIT 1
        ];

        /* =========================
           ENCOUNTER SUMMARY
        ========================== */

        String prompt = '';

        prompt += 'Height: ' +
            (encounter.Height_in_cm__c != null ? encounter.Height_in_cm__c + ' cm' : 'N/A') + '\n';

        prompt += 'Weight: ' +
            (encounter.Patient.Weight_in_Kg__c != null ? encounter.Patient.Weight_in_Kg__c + ' kg' : 'N/A') + '\n';

        prompt += 'Pulse Rate: ' +
            (encounter.Pulse_Rate_in_BPM__c != null ? encounter.Pulse_Rate_in_BPM__c + ' BPM' : 'N/A') + '\n';

        prompt += 'Age: ' +
            (encounter.Patient.Age__c != null ? encounter.Patient.Age__c : null) + '\n';

        prompt += 'Blood Pressure: ' +
            (String.isNotBlank(encounter.Blood_Pressure__c) ? encounter.Blood_Pressure__c : 'N/A') + '\n';

        prompt += 'Body Temperature: ' +
            (encounter.Body_Temperature__c != null ? encounter.Body_Temperature__c + ' °F' : 'N/A') + '\n';

        /* =========================
           AYUSH PRESCRIPTION DETAILS
        ========================== */

        Boolean hasAyushData = false;

        if (encounter.Ayush_Prescription_Inputs__r != null &&
            !encounter.Ayush_Prescription_Inputs__r.isEmpty()) {

            for (Ayush_Prescription_Input__c ayush : encounter.Ayush_Prescription_Inputs__r) {
                prompt += 'Prakriti (Primary): ' +
                    (String.isNotBlank(encounter.Patient.Body_type__c)
                        ? encounter.Patient.Body_type__c
                        : 'Not specified') + '\n';

                prompt += 'Prakriti (Secondary): ' +
                    (String.isNotBlank(encounter.Patient.Secondary_Prakriti__c)
                        ? encounter.Patient.Secondary_Prakriti__c
                        : 'Not specified') + '\n';

                prompt += 'Vikriti (Current Imbalance): ' +
                    (String.isNotBlank(encounter.Vikriti__c)
                        ? encounter.Vikriti__c
                        : 'Not specified') + '\n';

                prompt += 'Current Month/Season: ' + getCurrentAyushSeason() + '\n';
                
                prompt += 'Chief Complaints: ' +
                    (String.isNotBlank(encounter.Symptoms__c)
                        ? encounter.Symptoms__c
                        : 'None reported') + '\n';

                prompt += 'Medical History: ' +
                    (String.isNotBlank(encounter.Medical_History__c)
                        ? encounter.Medical_History__c
                        : 'None reported') + '\n';

                prompt += 'Clinical Findings: ' +
                    (String.isNotBlank(encounter.Clinical_Findings__c)
                        ? encounter.Clinical_Findings__c
                        : 'None reported')+'\n';

                List<String> diagnoses = new List<String>();
                for (Diagnosis__c d : encounter.Diagnoses__r) {
                    if (String.isNotBlank(d.Clinical_Diagnosis__c)) {
                        diagnoses.add(d.Clinical_Diagnosis__c +
                            (String.isNotBlank(d.Diagnosis_Description__c) ? ' - ' + d.Diagnosis_Description__c : ''));
                    }
                }
                prompt += 'Confirmed Diagnosis: ' +
                    (diagnoses.isEmpty() ? 'Not specified' : String.join(diagnoses, '; ')) + '\n';

                prompt += 'Active Ayurvedic Medicines: ' +
                    (String.isNotBlank(ayush.Existing_Medications__c)
                        ? ayush.Existing_Medications__c
                        : 'None prescribed') + '\n';

                prompt += 'Active Allopathic Medicines: ' +
                    (String.isNotBlank(ayush.Existing_Allopathic_Medicines__c)
                        ? ayush.Existing_Allopathic_Medicines__c
                        : 'None prescribed') + '\n';

                prompt += 'Allergies: ';
                if (ayush.Has_Allergies__c == true &&
                    String.isNotBlank(ayush.Allergy_Details__c)) {
                    prompt += ayush.Allergy_Details__c + '\n';
                } else {
                    prompt += 'No known allergies\n';
                }

                prompt += 'Pregnancy / Lactation Status: ' +
                    (String.isNotBlank(ayush.Pregnancy_Status__c)
                        ? ayush.Pregnancy_Status__c
                        : 'Not specified') + '\n';

                prompt += 'Yoga Practice: ' +
                    (ayush.Physical_Inactivity__c == true ? 'Yes' : 'No') + '\n';

                List<String> habits = new List<String>();
                if (ayush.Smoking__c == true) habits.add('Smoking');
                if (ayush.Alcohol_Use__c == true) habits.add('Alcohol Use');
                if (ayush.Sleep_Deprivation__c == true) habits.add('Sleep Deprivation');

                prompt += 'Lifestyle Habits: ' +
                    (habits.isEmpty() ? '- None reported\n' : '- ' + String.join(habits, ', ') + '\n');

                prompt += 'Additional Information: ' +
                (String.isNotBlank(encounter.Additional_Information__c)
                    ? encounter.Additional_Information__c
                    : 'Not specified') + '\n';

                hasAyushData = true;
            }
        }

        if (!hasAyushData) {
            prompt += '\nNo Ayush prescription data recorded\n\n';
        }

        output.Prompt = prompt;
        return responses;
    }
}