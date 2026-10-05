/**
* @description       : 
* @author            : Karishma
* @group             : 
* @last modified on  : 06-26-2025
* @last modified by  : Karishma
**/

public with sharing class resendEmailHCProviderController 
{
    
    @AuraEnabled
    public static resultWrapper getEmailBody(string referralId)
    {
        resultWrapper resultWrap = new resultWrapper();
        Referral__c eachReferral = [Select Id, Name, Referred_To__c, PrimarySpecialty__c, Primary_Specialty__c, SecondarySpecialty__c, Secondary_Specialty__c, Referred_To__r.name, Primary_Specialty__r.name, Referred_By__r.name, Referred_By__r.Phone, Referred_By__r.Email, Referred_To__r.Nodal_Person_Email_Address__c, Referred_To__r.Nodal_Person_Contact_Number__c, Patient__r.Name, Patient__r.Age__c, Patient__r.Gender__c, Clinical_Encounter__r.Facility.Name, Patient__r.Phone, Clinical_Encounter__r.Facility.Phone_Number__c, Recommended_Visit_By__c,Referral_Status__c from Referral__c where Id =: referralId];
        if(eachReferral.Referral_Status__c == 'Draft'){
            resultWrap.status = 'warning';
            resultWrap.body = 'Email cannot be send while the status is Draft / स्टेटस ड्राफ्ट होने पर ईमेल नहीं भेजा जा सकता है।';
            return resultWrap;
        }else{
            String formattedDate = '';
            if(eachReferral.Recommended_Visit_By__c != null){
                Integer day = eachReferral.Recommended_Visit_By__c.day();
                String monthName = DateTime.newInstance(eachReferral.Recommended_Visit_By__c.year(), eachReferral.Recommended_Visit_By__c.month(), eachReferral.Recommended_Visit_By__c.day()).format('MMMM');
                Integer year = eachReferral.Recommended_Visit_By__c.year(); 
                
                formattedDate = day + ' ' + monthName + ' ' + year;
            }
            
            String secondarySpecialty = '';
            String hindiSecondarySpecialty = '';
            if(eachReferral.SecondarySpecialty__c != null){
                secondarySpecialty = ' and ' + eachReferral.SecondarySpecialty__c;
                hindiSecondarySpecialty = ' और ' + eachReferral.SecondarySpecialty__c;
            }
            
            String body = 'Dear Sir/Madam, <br/>';
            body += '<br/>Greetings from PHWC Chamoli.<br/>';
            body += '<br/> We are referring <b>' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Name)  + '</b> (<b>' + ReferralTriggerHelper.getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + ' </b>-year old ' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Gender__c)+ ')' + ', currently under <b>PHWC Chamoli</b> care to <b>' + ReferralTriggerHelper.getNonNullString(eachReferral.Referred_To__r.name) + '</b> for further evaluation to the <b>' + ReferralTriggerHelper.getNonNullString(eachReferral.PrimarySpecialty__c) + secondarySpecialty + ' </b>department. He has undergone preliminary diagnosis/treatment at our facility and now requires advanced specialized care.<br/>';
            body += '<br/><b> Patient Details:</b><br/>';
            body += '<ul><li>' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Name) + ', ' + ReferralTriggerHelper.getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + 'Y/'+ ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Gender__c) + ', [' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Phone) +'].</li></ul>' ; 
            body += '<b>Referring Doctor:</b>';
            body += '<br/><ul><li>[' + eachReferral.Referred_By__r.Name + '/ PHWC Medical Officer] ['+ eachReferral.Referred_By__r.email +'].</li>';
            body += '<li> PHWC Chamoli.</li></ul>';
            body += '<b>Referred Specialty(s):</b>';
            body += '<br/><ul><li>' + eachReferral.PrimarySpecialty__c + '</li>';
            if(eachReferral.SecondarySpecialty__c != null){
                body += '<li>' + eachReferral.SecondarySpecialty__c + '</li>';
            }
            body += '</ul>';
            body += '<b>Enclosed Documents for Review:</b>';
            body += '<br/><ul><li>Patient Case File.</li>';
            body += '<li>Laboratory Reports.<br/></li></ul>';
            body += 'We request to take this case forward and extend the required specialized care. The patient has been advised to report to your hospital on or before <b>' + formattedDate +'</b> <br/>.';
            body += '<br/><i>For any additional details or clarifications, please feel free to reach us at ' + eachReferral.Referred_To__r.Nodal_Person_Contact_Number__c  +'.<br/>';
            body += '<br/>This is a system‑generated message from a no‑reply email. Please do not respond to this email.<br/>';
            body += '<br/><b>Regards,</b>';
            body += '<br/>PHWC Chamoli.</i><br/><br/>';
            body += '-----------------------------------------------------------------------------------<br/>';
            body += '<br/>मान्यवर/मान्यवरी,<br/>';
            body += '<br/>PHWC चमोली हॉस्पिटल से शुभकामनाएँ।<br/>';
            body += '<br/>हम ' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Name) + ' (' + ReferralTriggerHelper.getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + ' - साल, ' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Gender__c) + ') जो इस समय PHWC चमोली की देखरेख में हैं, को आगे की जाँच और इलाज के लिए <b>' + ReferralTriggerHelper.getNonNullString(eachReferral.Referred_To__r.name) + '</b> के <b>'+ ReferralTriggerHelper.getNonNullString(eachReferral.PrimarySpecialty__c) + hindiSecondarySpecialty +'</b> विभाग में रेफर कर रहे हैं। हमारे यहां इनका शुरुआती जांच/इलाज किया गया है, लेकिन अब इन्हें सेकेंडरी/टरशियरी लेवल की देखभाल की जरूरत है।<br/>';
            body += '<br/><b>पेशेंट डिटेल्स:</b><br/>';
            body += '<ul><li>पेशेंट का नाम: ' + ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Name) + ', (उम्र ' + ReferralTriggerHelper.getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) +'/'+ ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Gender__c) +'), ['+ ReferralTriggerHelper.getNonNullString(eachReferral.Patient__r.Phone)+ '].</li></ul>';
            body += '<b>रेफर करने वाले डॉक्टर:</b>';
            body += '<br/><ul><li>[' + eachReferral.Referred_By__r.Name + '/PHWC चमोली मेडिकल ऑफिसर], ['+ eachReferral.Referred_By__r.email +']</li>';
            body += '<li> PHWC चमोली.</li></ul>';
            body += '<b>रेफर की गई विशेषज्ञता:</b>';
            body += '<br/><ul><li>' + eachReferral.PrimarySpecialty__c + '</li>';
            if(eachReferral.SecondarySpecialty__c != null){
                body += '<li>' + eachReferral.SecondarySpecialty__c + '</li>';
            }
            body += '</ul>';
            body += '<b>संलग्न दस्तावेज़:</b>';
            body += '<br/><ul><li>पेशेंट केस फ़ाइल</li>';
            body += '<li>लैब रिपोर्ट्स</li></ul>';
            body += 'हम आपसे निवेदन करते हैं कि कृपया इस केस को आगे बढ़ाएं और ज़रूरत अनुसार विशेषज्ञ इलाज प्रदान करें। रोगी को  <b>'+ formattedDate +'</b>  तक आपके अस्पताल में उपस्थित होने की सलाह दी गई है।<br/>';
            body += '<br/>आपके सहयोग और मरीजों की सेवा के लिए धन्यवाद।<br/>';
            body += '<br/><i>अगर आपको किसी भी तरह की और जानकारी चाहिए तो कृपया हमसे ' + eachReferral.Referred_To__r.Nodal_Person_Contact_Number__c +' पर संपर्क करें।<br/>';
            body += '<br/>यह एक सिस्टम द्वारा जनरेट किया गया ईमेल है। कृपया इसका उत्तर न दें। <br/>';
            body += '<br/><b>सादर,</b>';
            body += '<br/>PHWC चमोली.';
            
            resultWrap.status = 'success';
            resultWrap.body = body;
            return resultWrap;
        }
    }
    
    public class resultWrapper
    {
        @AuraEnabled 
        public String status { get; set; }
        @AuraEnabled 
        public String body { get; set; }
    }
    
    @AuraEnabled
    public static resultWrapper sendReferralEmail(string referralId)
    {
        List<Id> referralIdList = new List<Id>();
        referralIdList.add(referralId);
        
        Map<Id,resultWrapper> resultMap = ReferralTriggerHelper.sendReferralEmail(referralIdList);
        if(resultMap.containsKey(referralId)){
            return resultMap.get(referralId); 
        }else{
            return null;
        } 
    }  
}