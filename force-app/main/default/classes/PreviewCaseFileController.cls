public with sharing class PreviewCaseFileController {

    private static String formatAadharNumber(String aadharNumber) {
        if (String.isBlank(aadharNumber)) {
            return 'N/A';
        }
        if (aadharNumber.length() >= 3) {
            return '*********' + aadharNumber.substring(aadharNumber.length() - 3);
        }
        return aadharNumber;
    }
            
    @AuraEnabled(cacheable=true)
    public static CaseFileData getCaseFileData(Id accountId) {
        try {
            CaseFileData caseData = new CaseFileData();
            
            Account patient = [
                SELECT Id, Name, Phone, Age__c,Gender__c, PM_JAY_ID__c, PMJAY_Family_ID__c, PMJAY_Scheme_Verified__c,
                       Attendant_Phone__c,AADHAR_Number__c, Attendant_Name__c
                FROM Account 
                WHERE Id = :accountId 
                LIMIT 1
            ];
     
            
            caseData.patientName = patient.Name;
            caseData.patientPhone = patient.Phone;
            caseData.patientAge = patient.Age__c;
            caseData.gender = patient.Gender__c;
            caseData.pmJayId = patient.PM_JAY_ID__c;
            caseData.attendantName = patient.Attendant_Name__c;
            caseData.attendantPhone = patient.Attendant_Phone__c;
            caseData.aadharNumber = formatAadharNumber(patient.AADHAR_Number__c);
            caseData.familyId = patient.PMJAY_Family_ID__c;
            caseData.pmjayVerified = patient.PMJAY_Scheme_Verified__c;
            
           
            List<ClinicalEncounter> encounters = [
                SELECT Id, Name, StartDate, Facility.Name,
                       Prescribing_Doctor__r.Name, Prescribing_Doctor__r.Phone, Symptoms__c, Clinical_Findings__c,owner.name,
               (SELECT Id, Clinical_Diagnosis__c, Diagnosis_Description__c, Diagnosis_Type__c
            FROM Diagnoses__r)
                FROM ClinicalEncounter 
                WHERE PatientId = :accountId 
                ORDER BY StartDate DESC 
            ];

            caseData.latestEncounterId = new List<Id>();

            if (!encounters.isEmpty()) {
                caseData.latestEncounterId.add(encounters[0].Id);
            }
            
            if (!encounters.isEmpty()) {
                ClinicalEncounter latestEncounter = encounters[0];
                caseData.facilityName = latestEncounter.Facility.Name;
                caseData.doctorName = latestEncounter.Prescribing_Doctor__r.Name;
                caseData.doctorPhone = latestEncounter.Prescribing_Doctor__r.Phone;
                caseData.encounterDate = latestEncounter.StartDate;
                caseData.latestChiefComplaints = latestEncounter.Symptoms__c;

                System.debug('Assigned caseData doctor/facility info: ' + JSON.serializePretty(caseData));
                
            }
            for (ClinicalEncounter encounter : encounters) {
                if (encounter.Diagnoses__r != null && !encounter.Diagnoses__r.isEmpty()) {
                    caseData.latestDiagnosis = encounter.Diagnoses__r[0].Clinical_Diagnosis__c;
                    caseData.latestDiagnosisDesc = encounter.Diagnoses__r[0].Diagnosis_Description__c;
                    caseData.latestDiagType = encounter.Diagnoses__r[0].Diagnosis_Type__c;
                     System.debug('Latest Diagnosis found: ' + JSON.serializePretty(encounter.Diagnoses__r[0]));
                    break;
                }
            }
            
            return caseData;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching case file data: ' + e.getMessage());
        }
    }
    
    
    @AuraEnabled(cacheable=true)
    public static List<Map<String, Object>> getClinicalEncounterTimeline(List<String> clinicalEncounterIds) {
        try {
            List<ClinicalEncounter> encounters = [
                SELECT Id, StartDate, Symptoms__c, 
                       Prescribing_Doctor__r.Name, 
                       Facility.Name,
                       (SELECT Id, Clinical_Diagnosis__c, Diagnosis_Description__c 
                        FROM Diagnoses__r 
                        ORDER BY CreatedDate ASC 
                        LIMIT 1)
                FROM ClinicalEncounter 
                WHERE Id IN :clinicalEncounterIds
                ORDER BY StartDate DESC
            ];

            
            
            List<Map<String, Object>> timelineData = new List<Map<String, Object>>();
            
            for (ClinicalEncounter encounter : encounters) {
                Map<String, Object> encounterData = new Map<String, Object>();
                
                // Basic encounter information
                encounterData.put('id', encounter.Id);
                
                // Format date properly - only date, no time
                if (encounter.StartDate != null) {
                    encounterData.put('date', encounter.StartDate.format('dd-MMM-yyyy'));
                } else {
                    encounterData.put('date', 'N/A');
                }
                
                // Combine Doctor and Facility with proper formatting
                String doctorName = encounter.Prescribing_Doctor__r?.Name;
                String facilityName = encounter.Facility?.Name;
                
                String doctorFacility = '';
                if (doctorName != null && facilityName != null) {
                    doctorFacility = doctorName + '/' + facilityName;
                } else if (doctorName != null) {
                    doctorFacility = doctorName + '/N/A';
                } else if (facilityName != null) {
                    doctorFacility = 'N/A/' + facilityName;
                } else {
                    doctorFacility = 'N/A/N/A';
                }
                
                encounterData.put('doctorFacility', doctorFacility);
                
                // Handle symptoms with proper text wrapping
                String symptoms = encounter.Symptoms__c;
                if (String.isNotBlank(symptoms)) {
                    encounterData.put('symptoms', symptoms);
                } else {
                    encounterData.put('symptoms', 'No symptoms recorded');
                }
                
                // Handle diagnosis with rich text formatting
                String combinedDiagnosis = formatDiagnosis(encounter.Diagnoses__r);
                encounterData.put('diagnosis', combinedDiagnosis);
                
                timelineData.add(encounterData);
            }
            
            return timelineData;
            
        } catch (Exception e) {
            System.debug('Error in getClinicalEncounterTimeline: ' + e.getMessage());
            throw new AuraHandledException('Failed to retrieve clinical encounter timeline: ' + e.getMessage());
        }
    }
    
    public static String formatDiagnosis(List<Diagnosis__c> diagnoses) {
        if (diagnoses == null || diagnoses.isEmpty()) {
            return 'No diagnosis recorded';
        }
        
        Diagnosis__c primaryDiagnosis = diagnoses[0];
        String clinicalDiagnosis = primaryDiagnosis.Clinical_Diagnosis__c;
        String diagnosisDescription = primaryDiagnosis.Diagnosis_Description__c;
        
        String formattedDiagnosis = '';
        
        // Add clinical diagnosis in bold if available
        if (String.isNotBlank(clinicalDiagnosis)) {
            formattedDiagnosis = '<strong>' + String.escapeSingleQuotes(clinicalDiagnosis) + '</strong>';
        }
        
        // Add description with line break if available
        if (String.isNotBlank(diagnosisDescription)) {
            if (String.isNotBlank(formattedDiagnosis)) {
                formattedDiagnosis += '<br/>' + String.escapeSingleQuotes(diagnosisDescription);
            } else {
                formattedDiagnosis = String.escapeSingleQuotes(diagnosisDescription);
            }
        }
        
        // If both are blank, return default message
        if (String.isBlank(formattedDiagnosis)) {
            formattedDiagnosis = 'No diagnosis details available';
        }
        
        return formattedDiagnosis;
    }
    
    public class CaseFileData {
        @AuraEnabled public String patientName;
        @AuraEnabled public String patientPhone;
        @AuraEnabled public Decimal patientAge;
        @AuraEnabled public String gender;
        @AuraEnabled public String pmJayId;
        @AuraEnabled public String attendantName;
        @AuraEnabled public String attendantPhone;
        @AuraEnabled public String facilityName;
        @AuraEnabled public String doctorName;
        @AuraEnabled public String doctorPhone;
        @AuraEnabled public DateTime encounterDate;
        @AuraEnabled public String aadharNumber;
        @AuraEnabled public String latestDiagnosis;
        @AuraEnabled public String latestDiagnosisDesc;
        @AuraEnabled public String latestDiagType;
        @AuraEnabled public String latestChiefComplaints;
        @AuraEnabled public String familyId;
        @AuraEnabled public List<Id> latestEncounterId;
        @AuraEnabled public Boolean pmjayVerified;
        
     
    }
}