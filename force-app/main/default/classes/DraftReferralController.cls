public with sharing class DraftReferralController {

@AuraEnabled(cacheable=true)
public static List<DraftReferralWrapper> getDraftReferrals(String patientId) {
    List<DraftReferralWrapper> draftReferralWrappers = new List<DraftReferralWrapper>();
    
    try {
        // Query draft referrals for the patient with additional fields
        List<Referral__c> draftReferrals = [
            SELECT Id, Name, CreatedDate, 
                   PrimarySpecialty__c, SecondarySpecialty__c, Referred_To__c, Referred_By__c,
                   Referred_To__r.Name, Patient__c, Referral_Status__c,
                   Referral_Summary__c, Chief_Complaints_and_Presenting_Symptoms__c, Preliminary_Diagnosis__c,
                   Recommended_Visit_By__c, Referral_Priority__c,
                   Encounter__c
            FROM Referral__c 
            WHERE Patient__c = :patientId 
            AND Referral_Status__c = 'Draft'
            ORDER BY CreatedDate DESC
        ];
        
        // Convert to wrapper objects
        for (Referral__c referral : draftReferrals) {
            DraftReferralWrapper wrapper = new DraftReferralWrapper();
            wrapper.referralId = referral.Id;
            wrapper.referralName = referral.Name;
            wrapper.createdDate = referral.CreatedDate.format('dd-MMM-yyyy');
            wrapper.primarySpecialty = referral.PrimarySpecialty__c != null ? referral.PrimarySpecialty__c : '';
            wrapper.secondarySpecialty = referral.SecondarySpecialty__c != null ? referral.SecondarySpecialty__c : '';
            wrapper.referredTo = referral.Referred_To__c != null ? referral.Referred_To__c : '';
            wrapper.selected = false;
            
            // Additional fields for draft management
            wrapper.reasonForReferral = referral.Referral_Summary__c;
            wrapper.chiefComplaints = referral.Chief_Complaints_and_Presenting_Symptoms__c;
            wrapper.preliminaryDiagnosis = referral.Preliminary_Diagnosis__c;
            wrapper.recommendedVisitBy = referral.Recommended_Visit_By__c;
            wrapper.referralPriority = referral.Referral_Priority__c;
            wrapper.selectedEncounterIds = referral.Encounter__c;
            wrapper.referredToName = referral.Referred_To__r.Name;
            
            draftReferralWrappers.add(wrapper);
        }
        
    } catch(Exception e) {
        System.debug('Error fetching draft referrals: ' + e.getMessage());
        throw new AuraHandledException('Error fetching draft referrals: ' + e.getMessage());
    }
    
    return draftReferralWrappers;
}

@AuraEnabled
    public static String saveReferralAsDraft(ReferralData referralData) {
        try {
            Referral__c referral;
            
            // Check if updating existing draft or creating new
            if (String.isNotBlank(referralData.referralId)) {
                // Update existing draft
                referral = [SELECT Id FROM Referral__c WHERE Id = :referralData.referralId LIMIT 1];
            } else {
                // Create new draft
                referral = new Referral__c();
                referral.Patient__c = referralData.patientId;
                referral.Referral_Status__c = 'Draft';
            }
            
            // Populate referral fields
            referral.PrimarySpecialty__c = referralData.primarySpecialty;
            referral.SecondarySpecialty__c = referralData.secondarySpecialty;
            referral.Referred_To__c = referralData.referredTo;
            referral.Referred_By__c = referralData.referredBy;
            referral.Referral_Summary__c = referralData.reasonForReferral;
            referral.Chief_Complaints_and_Presenting_Symptoms__c = referralData.chiefComplaints;
            referral.Preliminary_Diagnosis__c = referralData.preliminaryDiagnosis;
            referral.Recommended_Visit_By__c = referralData.recommendedVisitBy;
            referral.Referral_Priority__c = referralData.referralPriority;
            referral.Encounter__c = referralData.selectedEncounterIds;
            
            upsert referral;
            
            return referral.Id;
            
        } catch(Exception e) {
            System.debug('Error saving referral as draft: ' + e.getMessage());
            throw new AuraHandledException('Error saving referral as draft: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String submitReferral(ReferralData referralData) {
        try {
            Referral__c referral;
            
            // Check if updating existing draft or creating new
            if (String.isNotBlank(referralData.referralId)) {
                // Update existing draft and change status
                referral = [SELECT Id FROM Referral__c WHERE Id = :referralData.referralId LIMIT 1];
                referral.Referral_Status__c = 'Referral Summarized';
            } else {
                // Create new referral
                referral = new Referral__c();
                referral.Patient__c = referralData.patientId;
                referral.Referral_Status__c = 'Referral Summarized';
            }
            
            // Populate referral fields
            referral.PrimarySpecialty__c = referralData.primarySpecialty;
            referral.SecondarySpecialty__c = referralData.secondarySpecialty;
            referral.Referred_To__c = referralData.referredTo;
            referral.Referred_By__c = referralData.referredBy;
            referral.Referral_Summary__c = referralData.reasonForReferral;
            referral.Chief_Complaints_and_Presenting_Symptoms__c = referralData.chiefComplaints;
            referral.Preliminary_Diagnosis__c = referralData.preliminaryDiagnosis;
            referral.Recommended_Visit_By__c = referralData.recommendedVisitBy;
            referral.Referral_Priority__c = referralData.referralPriority;
            referral.Encounter__c = referralData.selectedEncounterIds;
            
            upsert referral;
            
            return referral.Id;
            
        } catch(Exception e) {
            System.debug('Error submitting referral: ' + e.getMessage());
            throw new AuraHandledException('Error submitting referral: ' + e.getMessage());
        }
    }

// Wrapper class for draft referrals
public class DraftReferralWrapper {
    @AuraEnabled public String referralId { get; set; }
    @AuraEnabled public String referralName { get; set; }
    @AuraEnabled public String createdDate { get; set; }
    @AuraEnabled public String primarySpecialty { get; set; }
    @AuraEnabled public String secondarySpecialty { get; set; }
    @AuraEnabled public String referredTo { get; set; }
    @AuraEnabled public Boolean selected { get; set; }
    @AuraEnabled public String reasonForReferral { get; set; }
    @AuraEnabled public String chiefComplaints { get; set; }
    @AuraEnabled public String preliminaryDiagnosis { get; set; }
    @AuraEnabled public Date recommendedVisitBy { get; set; }
    @AuraEnabled public String referralPriority { get; set; }
    @AuraEnabled public String selectedEncounterIds { get; set; }
    @AuraEnabled public String referredToName { get; set; }
}

 public class ReferralData {
        @AuraEnabled public String referralId { get; set; }
        @AuraEnabled public String patientId { get; set; }
        @AuraEnabled public String primarySpecialty { get; set; }
        @AuraEnabled public String secondarySpecialty { get; set; }
        @AuraEnabled public String referredTo { get; set; }
        @AuraEnabled public String referredBy { get; set; }
        @AuraEnabled public String reasonForReferral { get; set; }
        @AuraEnabled public String chiefComplaints { get; set; }
        @AuraEnabled public String preliminaryDiagnosis { get; set; }
        @AuraEnabled public Date recommendedVisitBy { get; set; }
        @AuraEnabled public String referralPriority { get; set; }
        @AuraEnabled public String selectedEncounterIds { get; set; }
    }

}