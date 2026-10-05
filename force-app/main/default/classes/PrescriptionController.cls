// PrescriptionController.cls
public without sharing class PrescriptionController {


	 public class KendraDetails {
        @AuraEnabled public String id;
        @AuraEnabled public String name;
        @AuraEnabled public String ownerName;
        @AuraEnabled public String contactNumber;
        //@AuraEnabled public String address;
        @AuraEnabled public String stateCode;
        @AuraEnabled public String city;
        @AuraEnabled public String postalCode;
        @AuraEnabled public String street;
        @AuraEnabled public Boolean isValid;
        @AuraEnabled public String message;
    }
    
    @AuraEnabled(cacheable=true)
    public static PrescriptionSummary getEncounterDetails(String encounterName) {
        try {
            // Query only essential fields for prescription
            ClinicalEncounter encounter = [
                SELECT Contact__r.Name, Patient.Name,
                       Contact__r.Account.Gender__c, Patient.Gender__c,
                       Contact__r.Account.Age__c, Patient.Age__c,
                       Prescribing_Doctor__r.Name,
                       Facility.Name,
                       (SELECT Id, Medication.Name, Duration_Days__c, Prescription_Start_Date__c,
                               Morning__c, Afternoon__c, Night__c, BF_AF__c 
                        FROM MedicationRequest_ClinicalEncounter)
                FROM ClinicalEncounter
                WHERE Id = :encounterName
                LIMIT 1
            ];

            PrescriptionSummary output = new PrescriptionSummary();

            // Essential Patient Details
            output.patientName = encounter.Patient?.Name;
            output.age = encounter.Patient.Age__c != null ? String.valueOf(encounter.Patient.Age__c) : 'N/A';
            output.gender = encounter.Patient.Gender__c != null ? encounter.Patient.Gender__c : 'N/A';

            // Doctor and Facility
            output.doctorName = encounter.Prescribing_Doctor__r?.Name;
            output.facilityName = encounter.Facility?.Name;

            // Medications only
            output.medications = new List<Map<String, String>>();
            for (MedicationRequest m : encounter.MedicationRequest_ClinicalEncounter) {
                Map<String, String> medMap = new Map<String, String>();
                medMap.put('id', m.Id);
                medMap.put('name', m.Medication.Name);
                medMap.put('duration', m.Duration_Days__c != null ? String.valueOf(m.Duration_Days__c) : 'N/A');
                medMap.put('startDate', m.Prescription_Start_Date__c != null
                    ? DateTime.newInstance(m.Prescription_Start_Date__c.year(), m.Prescription_Start_Date__c.month(), m.Prescription_Start_Date__c.day(), 0, 0, 0).format('dd-MMM-yyyy')
                    : 'N/A');
                medMap.put('morning', m.Morning__c != null && m.Morning__c != '0' ? m.Morning__c : 'N/A');
                medMap.put('afternoon', m.Afternoon__c != null && m.Afternoon__c != '0' ? m.Afternoon__c : 'N/A');
                medMap.put('night', m.Night__c != null && m.Night__c != '0' ? m.Night__c : 'N/A');
                medMap.put('food', m.BF_AF__c);
                output.medications.add(medMap);
            }

            return output;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching prescription details: ' + e.getMessage());
        }
    }


	@AuraEnabled(cacheable=false)
    public static KendraDetails verifyKendraCode(String kendraCode) {
        KendraDetails result = new KendraDetails();
        
        try {
            if (String.isBlank(kendraCode)) {
                result.isValid = false;
                result.message = 'Please enter a valid Kendra code';
                return result;
            }
            
            List<Janaushadhi_Pharmacy__c> kendraList = [
                SELECT Id, Name, Owner_Name__c, Contact_Number__c, 
                       Address__c, Address__StateCode__s, Address__City__s, 
                       Address__PostalCode__s, Address__Street__s 
                FROM Janaushadhi_Pharmacy__c 
                WHERE Name = :kendraCode 
                LIMIT 1
            ];
            
            if (kendraList.isEmpty()) {
                result.isValid = false;
                result.message = 'Invalid Kendra code. Please check and try again.';
                return result;
            }
            
            Janaushadhi_Pharmacy__c kendra = kendraList[0];
            
            // Populate the result with Kendra details
            result.id = kendra.Id;
            result.name = kendra.Name;
            result.ownerName = kendra.Owner_Name__c;
            result.contactNumber = kendra.Contact_Number__c;
            //result.address = kendra.Address__c;
            result.stateCode = kendra.Address__StateCode__s;
            result.city = kendra.Address__City__s;
            result.postalCode = kendra.Address__PostalCode__s;
            result.street = kendra.Address__Street__s;
            result.isValid = true;
            result.message = 'Kendra code verified successfully';
            
            return result;
            
        } catch (Exception ex) {
            result.isValid = false;
            result.message = 'An error occurred while verifying Kendra code: ' + ex.getMessage();
            System.debug('Error in verifyKendraCode: ' + ex.getMessage());
            return result;
        }
    }

		 @AuraEnabled
    public static void fulfillMedications(List<String> medicationIds, String kendraCode) {
        try {
            // Find Kendra by code using existing method structure
            List<Janaushadhi_Pharmacy__c> kendraList = [
                SELECT Id, Name, Owner_Name__c, Contact_Number__c, 
                       Address__c, Address__StateCode__s, Address__City__s, 
                       Address__PostalCode__s, Address__Street__s 
                FROM Janaushadhi_Pharmacy__c 
                WHERE Name = :kendraCode 
                LIMIT 1
            ];
            
            if (kendraList.isEmpty()) {
                throw new AuraHandledException('Invalid Kendra code. Please check and try again.');
            }
            
            Janaushadhi_Pharmacy__c kendra = kendraList[0];
            
            // Get medication requests to update
            List<MedicationRequest> medicationsToUpdate = [
                SELECT Id 
                FROM MedicationRequest 
                WHERE Id IN :medicationIds
            ];
            
            // Update fulfilled by field
            for (MedicationRequest med : medicationsToUpdate) {
                med.Fulfilled_By__c = kendra.Id;
            }
            
            update medicationsToUpdate;
            
        } catch (Exception e) {
            throw new AuraHandledException('Error fulfilling medications: ' + e.getMessage());
        }
    }

    // Simplified wrapper class for prescription data
    public class PrescriptionSummary {
        @AuraEnabled public String patientName;
        @AuraEnabled public String age;
        @AuraEnabled public String gender;
        @AuraEnabled public String doctorName;
        @AuraEnabled public String facilityName;
        @AuraEnabled public List<Map<String, String>> medications;

    } }