public with sharing class ReferralToAnotherProvider {
    
    @AuraEnabled(cacheable=true)
    public static List<HealthcareProvider> getHealthcareProviders() {
        try {
            return [
                SELECT Id, Name, Nodal_Person_Email_Address__c
                FROM HealthcareProvider
                  WHERE Nodal_Person_Email_Address__c != null
                ORDER BY Name ASC
                LIMIT 1000
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Failed to retrieve Healthcare Providers: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static Id cloneReferralToNewProvider(Id originalReferralId, Id newProviderId, String reason) {
        try {
            if (originalReferralId == null || newProviderId == null) {
                throw new AuraHandledException('Invalid parameters provided');
            }
            
            // Get the original referral (query all fields you need)
            Referral__c originalReferral = [
                SELECT Id, Patient__c, Referred_By__c, Referral_Summary__c, 
                       PrimarySpecialty__c, SecondarySpecialty__c, Encounter__c,
                       Recommended_Visit_By__c, Referral_Priority__c, 
                       Chief_Complaints_and_Presenting_Symptoms__c, 
                       Preliminary_diagnosis__c, Referral_Status__c, Referral_Summary2__c
                FROM Referral__c 
                WHERE Id = :originalReferralId 
                LIMIT 1
            ];
            
            if (originalReferral == null) {
                throw new AuraHandledException('Original referral not found');
            }
            
            // Clone the record (excludes Id, system fields, auto-number fields)
            Referral__c clonedReferral = originalReferral.clone(false, false, false, false);
            
            // Update only the fields that need to change
            clonedReferral.Referred_To__c = newProviderId;
            clonedReferral.Referral_Date__c = Date.today();
            clonedReferral.Referral_Status__c = 'Referral Summarized';
			clonedReferral.Reason_for_Referral_to_Another_Provider__c = reason;

            
            // Insert the cloned referral
            insert clonedReferral;
			         
            cloneAttachments(originalReferralId, clonedReferral.Id);

			  List<Referral__c> referralList = [Select Id,Name,Referral_Status__c from Referral__c where Id=: clonedReferral.Id and Referral_Status__c = 'Referral Summarized'];
          if(!referralList.isEmpty()){
            List<Id> referralIdList = new List<Id>();
            referralIdList.add(referralList[0].Id);
            ReferralTriggerHelper.sendReferralEmail(referralIdList);
        }

            
            return clonedReferral.Id;
            
        } catch (Exception e) {
            System.debug('Error in cloneReferralToNewProvider: ' + e.getMessage());
            throw new AuraHandledException('Error cloning referral: ' + e.getMessage());
        }
    }
    
    private static void cloneAttachments(Id originalReferralId, Id newReferralId) {
        try {
            // Get all attachments from original referral
            List<Attachment> originalAttachments = [
                SELECT Name, Body, ContentType, Description
                FROM Attachment 
                WHERE ParentId = :originalReferralId
            ];
            
            if (!originalAttachments.isEmpty()) {
                List<Attachment> newAttachments = new List<Attachment>();
                
                for (Attachment originalAttachment : originalAttachments) {
                    Attachment newAttachment = new Attachment();
                    newAttachment.Name = originalAttachment.Name;
                    newAttachment.Body = originalAttachment.Body;
                    newAttachment.ContentType = originalAttachment.ContentType;
                    newAttachment.Description = originalAttachment.Description;
                    newAttachment.ParentId = newReferralId;
                    
                    newAttachments.add(newAttachment);
                }
                
                insert newAttachments;
            }
            
            // Also clone ContentDocumentLinks (Files) if using Files instead of Attachments
            cloneContentDocumentLinks(originalReferralId, newReferralId);
            
        } catch (Exception e) {
            System.debug('Error cloning attachments: ' + e.getMessage());
            // Don't throw exception as the referral was created successfully
        }
    }
    
    private static void cloneContentDocumentLinks(Id originalReferralId, Id newReferralId) {
        try {
            // Get all ContentDocumentLinks from original referral
            List<ContentDocumentLink> originalLinks = [
                SELECT ContentDocumentId, ShareType, Visibility
                FROM ContentDocumentLink 
                WHERE LinkedEntityId = :originalReferralId
            ];
            
            if (!originalLinks.isEmpty()) {
                List<ContentDocumentLink> newLinks = new List<ContentDocumentLink>();
                
                for (ContentDocumentLink originalLink : originalLinks) {
                    ContentDocumentLink newLink = new ContentDocumentLink();
                    newLink.ContentDocumentId = originalLink.ContentDocumentId;
                    newLink.LinkedEntityId = newReferralId;
                    newLink.ShareType = originalLink.ShareType;
                    newLink.Visibility = originalLink.Visibility;
                    
                    newLinks.add(newLink);
                }
                
                insert newLinks;
            }
            
        } catch (Exception e) {
            System.debug('Error cloning content document links: ' + e.getMessage());
            // Don't throw exception as the referral was created successfully
        }
    }

}