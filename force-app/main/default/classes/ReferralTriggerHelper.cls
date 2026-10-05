public without sharing class ReferralTriggerHelper 
{
    public static Boolean isFirstRun = true; // Add this
    public static Amazon_AWS__c amazonAWSEndPoint = Amazon_AWS__c.getInstance(); // Get values of AmazonAWS from Custom Setting
    
    public static void checkReferralStatus(Map<Id, Referral__c> referralMap, Map<Id, Referral__c> oldReferralMap)
    {
        List<Id> referralIdList = new List<Id>();
        for(Referral__c eachReferral : referralMap.values()){
            if(trigger.isInsert && eachReferral.Referral_Status__c == 'Referral Summarized'){
                referralIdList.add(eachReferral.Id);
            }
            else if (trigger.isUpdate && eachReferral.Referral_Status__c == 'Referral Summarized' && oldReferralMap.containsKey(eachReferral.Id) && oldReferralMap.get(eachReferral.Id).Referral_Status__c != eachReferral.Referral_Status__c) {
                referralIdList.add(eachReferral.Id);
            }
        }
        
        if(!referralIdList.isEmpty()){
            sendEmailAsync(referralIdList);
        }
    }
    
    @future
    public static void sendEmailAsync(List<Id> referralIdList)
    {
        sendReferralEmail(referralIdList);
    }
    
    public static Map<Id,resendEmailHCProviderController.resultWrapper> sendReferralEmail(List<Id> referralIdList)
    {
        Map<Id,resendEmailHCProviderController.resultWrapper> resultMap = new Map<Id, resendEmailHCProviderController.resultWrapper>();
        try{
            List<Messaging.SingleEmailMessage> emailList = new list <Messaging.SingleEmailMessage>();
            OrgWideEmailAddress[] owea = [select Id,Address from OrgWideEmailAddress where Address = 'shaik.karishma@crmit.com' LIMIT 1];
            
            Map<Id,List<ContentVersion>> contentVersionMap = new Map<Id,List<ContentVersion>>();
            
            Map<Id,Id> referralContentDocumentMap = new Map<Id,Id>();
            for(ContentDocumentLink  eachContentDoc : [Select id, ContentDocumentId, LinkedEntityId from ContentDocumentLink Where LinkedEntityId IN: referralIdList]){
                referralContentDocumentMap.put(eachContentDoc.ContentDocumentId, eachContentDoc.LinkedEntityId);
            }
            
            Map<Id, List<String>> encounterMap = new Map<Id, List<String>>();
            List<String> encounterList = new List<String>();
            String selectedReferralId = '';
            Set<Id> patientId = new Set<Id>();
            for(Referral__c eachReferralReport : [select Id, Name, Encounter__c, Patient__c from Referral__c where Id in: referralIdList and Encounter__c !=null])
            {
                patientId.add(eachReferralReport.Patient__c);
                selectedReferralId = eachReferralReport.Id;
                if(eachReferralReport.Encounter__c.contains(',')){
                    encounterList = eachReferralReport.Encounter__c.split(',');
                }else{
                    encounterList.add(eachReferralReport.Encounter__c);
                }
            }
            /*Map<id, Diagnosis__c> diagnosisMap = new Map<id, Diagnosis__c>();
            for(Diagnosis__c eachDiagnosis :[SELECT Id, Name, Patient__c, Diagnosis_Type__c, Clinical_Diagnosis__c from Diagnosis__c where Patient__c in:patientId  order by CreatedDate desc]){
                if(!diagnosisMap.containsKey(eachDiagnosis.Patient__c)){
                   diagnosisMap.put(eachDiagnosis.Patient__c, eachDiagnosis); 
                }
                
            }*/
            
            Set<Id> clinicalServiceRequestId = new Set<Id>();
            Set<Id> diagnosticSummaryId = new Set<Id>();
            for(ClinicalServiceRequest eachCSR : [Select Id,Name from ClinicalServiceRequest Where EncounterId != null and Encounter.Name IN: encounterList]){
                clinicalServiceRequestId.add(eachCSR.Id);
            }
            for(DiagnosticSummary eachDS : [Select Id,Name from DiagnosticSummary Where Clinical_Service_Request__c IN:clinicalServiceRequestId]){
                diagnosticSummaryId.add(eachDS.Id);
            }
            
            for(ContentVersion eachContentVersion : [SELECT Id, Title, VersionData,FirstPublishLocationId,ContentDocumentId FROM ContentVersion WHERE FirstPublishLocationId in: diagnosticSummaryId /*ContentDocumentId IN: referralContentDocumentMap.keySet() FirstPublishLocationId in: diagnosticSummaryId*/])
            {
                Id referralId = selectedReferralId;
                if(contentVersionMap.containsKey(referralId))
                {
                    List<ContentVersion> contentVersionList = contentVersionMap.get(referralId);
                    contentVersionList.add(eachContentVersion);
                    
                    contentVersionMap.put(referralId,contentVersionList);
                    
                }else{
                    List<ContentVersion> contentVersionList = new List<ContentVersion>();
                    contentVersionList.add(eachContentVersion);
                    
                    contentVersionMap.put(referralId,contentVersionList);
                }
            }
            
            Map<Id,zipFiles> zipDataMap = new Map<Id,zipFiles>();
            Map<Id,Attachment> attachmentMap = new Map<Id,Attachment>();
            for(Attachment  eachAttachment : [SELECT Id, Name, Body, ContentType, ParentId FROM Attachment WHERE ParentId in: referralIdList])
            {
                Compression.ZipWriter writer = new Compression.ZipWriter();
                writer.AddEntry(eachAttachment.Name, eachAttachment.Body);
                blob newZipArchive = writer.getArchive();
                
                zipFiles zipWrapper = new zipFiles();
                zipWrapper.fileName = 'PatientFiles.zip';
                zipWrapper.fileBody = newZipArchive;
                
                zipDataMap.put(eachAttachment.ParentId,zipWrapper);
                attachmentMap.put(eachAttachment.ParentId,eachAttachment);
            }
            system.debug('attachmentMap::'+attachmentMap);
            
            Map<Id,ContentVersion> zipFiles = ZipController.zipAttachment(contentVersionMap); 
            
            for(Referral__c eachReferral : [Select Id, Name, Referred_To__c, PrimarySpecialty__c, Primary_Specialty__c, SecondarySpecialty__c, Secondary_Specialty__c, Referred_To__r.name, Primary_Specialty__r.name, Preliminary_diagnosis__c, Referred_By__r.name, Referred_By__r.Phone, Referred_By__r.Email, Referred_To__r.Nodal_Person_Email_Address__c, Referred_To__r.Nodal_Person_Contact_Number__c, Patient__r.Name, Patient__r.Age__c, Patient__r.Gender__c, Clinical_Encounter__r.Facility.Name, Patient__r.Phone, Clinical_Encounter__r.Facility.Phone_Number__c, Recommended_Visit_By__c, Patient__r.PersonEmail, Patient__r.Attendent_Email__c  from Referral__c where Id in: referralIdList /*and Referred_To__r.Nodal_Person_Email_Address__c != null*/]){
                
                String formattedDate = '';
                if(eachReferral.Recommended_Visit_By__c != null){
                    Integer day = eachReferral.Recommended_Visit_By__c.day();
                    String monthName = DateTime.newInstance(eachReferral.Recommended_Visit_By__c.year(), eachReferral.Recommended_Visit_By__c.month(), eachReferral.Recommended_Visit_By__c.day()).format('MMMM');
                    Integer year = eachReferral.Recommended_Visit_By__c.year(); 
                    
                    formattedDate = day + ' ' + monthName + ' ' + year;
                }
                
                String secondarySpecialty = '';
                String hindiSecondarySpecialty = '';
                if(eachReferral.SecondarySpecialty__c != null && eachReferral.SecondarySpecialty__c != 'N/A'){
                    secondarySpecialty = ' and ' + eachReferral.SecondarySpecialty__c;
                    hindiSecondarySpecialty = ' और ' + eachReferral.SecondarySpecialty__c;
                }
                String loginRedirectUrl = 'https://cr1769668480593.my.site.com/HealthCareProviders/';
                
                 String body = 'Dear Sir/Madam, <br/>';
                    body += '<br/>Greetings from PHWC Chamoli.<br/>';
                    body += '<br/> We are referring <b>' + getNonNullString(eachReferral.Patient__r.Name)  + '</b> (<b>' + getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + ' </b>-year old ' + getNonNullString(eachReferral.Patient__r.Gender__c)+ ')' + ', currently under <b>PHWC Chamoli</b> care to <b>' + getNonNullString(eachReferral.Referred_To__r.name) + '</b> for further evaluation to the <b>' + getNonNullString(eachReferral.PrimarySpecialty__c) + secondarySpecialty + ' </b>department. He has undergone provisional diagnosis/treatment at our facility and now requires advanced specialized care.<br/>';

                    body += '<br/><b> Patient Details:</b><br/>';
                    body += '<ul><li>' + getNonNullString(eachReferral.Patient__r.Name) + ', ' + getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + 'Y/'+ getNonNullString(eachReferral.Patient__r.Gender__c) + ', [' + getNonNullString(eachReferral.Patient__r.Phone) +'].</li></ul>' ; 

                    body += '<b>Referring Doctor:</b>';
                    body += '<br/><ul><li>[' + eachReferral.Referred_By__r.Name + '/ PHWC Medical Officer].</li>';
                    body += '<li> PHWC Chamoli.</li></ul>';

                    body += '<b>Referred Specialty(s):</b>';
                    body += '<br/><ul><li>' + eachReferral.PrimarySpecialty__c + '</li>';
                    if(eachReferral.SecondarySpecialty__c != null && eachReferral.SecondarySpecialty__c != 'N/A'){
                        body += '<li>' + eachReferral.SecondarySpecialty__c + '</li>';
                    }
                    body += '</ul>';

                    //if(diagnosisMap.containsKey(eachReferral.Patient__c)){
                    body += '<b>Diagnosis:</b>';
                    body += '<br/><ul><li>' + eachReferral.Preliminary_diagnosis__c + '</li></ul></br>';
                    //}

                    /* Updated section starts */
                    body += '<b>Patient Records and Reports:</b>';
                    body += '<br/>All patient records, clinical documents, laboratory reports, and referral-related information are securely available on the portal.';
                    body += '<br/>Kindly access and review the complete case details by logging in through this <a href="' + loginRedirectUrl + '" target="_blank">portal link</a>.';
                    body += '<br/><i>Please note that no documents are attached to this email.</i><br/><br/>';
                    /* Updated section ends */

                    body += 'We request to take this case forward and extend the required specialized care. The patient has been advised to report to your hospital on or before <b>' + formattedDate +'.</b> <br/>';

                    body += 'Once the patient arrives at the hospital, please use this <a href="' + loginRedirectUrl + '" target="_blank">portal link</a> to notify us of their arrival, including the date they were received.';
                    body += '<br/>After providing advance care or completing the post-intervention, please use the <a href="' + loginRedirectUrl + '" target="_blank">link</a> to share the post-intervention details with PHWC<br/>';

                    body += '<br/><i>For any additional details or clarifications, please feel free to reach us at ' + eachReferral.Referred_To__r.Nodal_Person_Contact_Number__c  +'.<br/>';
                    body += '<br/>This is a system-generated message from a no-reply email. Please do not respond to this email.<br/>';
                    body += '<br/><b>Regards,</b>';
                    body += '<br/>PHWC Chamoli.</i><br/><br/>';

                    body += '-----------------------------------------------------------------------------------<br/>';

                    body += '<br/>मान्यवर/मान्यवरी,<br/>';
                    body += '<br/>PHWC चमोली से शुभकामनाएँ।<br/>';

                    body += '<br/>हम ' + getNonNullString(eachReferral.Patient__r.Name) + ' (' + getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) + ' - साल, ' + getNonNullString(eachReferral.Patient__r.Gender__c) + ') जो इस समय PHWC चमोली की देखरेख में हैं, को आगे की जाँच और इलाज के लिए <b>' + getNonNullString(eachReferral.Referred_To__r.name) + '</b> के <b>'+ getNonNullString(eachReferral.PrimarySpecialty__c) + hindiSecondarySpecialty +'</b> विभाग में रेफर कर रहे हैं। हमारे यहां इनका शुरुआती जांच/इलाज किया गया है, लेकिन अब इन्हें सेकेंडरी/टरशियरी लेवल की देखभाल की जरूरत है।<br/>';

                    body += '<br/><b>पेशेंट डिटेल्स:</b><br/>';
                    body += '<ul><li>पेशेंट का नाम: ' + getNonNullString(eachReferral.Patient__r.Name) + ', (उम्र ' + getNonNullString(String.valueOf(eachReferral.Patient__r.Age__c)) +'/'+ getNonNullString(eachReferral.Patient__r.Gender__c) +'), ['+ getNonNullString(eachReferral.Patient__r.Phone)+ '].</li></ul>';

                    body += '<b>रेफर करने वाले डॉक्टर:</b>';
                    body += '<br/><ul><li>[' + eachReferral.Referred_By__r.Name + '/PHWC चमोली मेडिकल ऑफिसर], ['+ eachReferral.Referred_By__r.email +']</li>';
                    body += '<li> PHWC चमोली.</li></ul>';

                    body += '<b>रेफर की गई विशेषज्ञता:</b>';
                    body += '<br/><ul><li>' + eachReferral.PrimarySpecialty__c + '</li>';
                    if(eachReferral.SecondarySpecialty__c != null && eachReferral.SecondarySpecialty__c != 'N/A'){
                        body += '<li>' + eachReferral.SecondarySpecialty__c + '</li>';
                    }
                    body += '</ul>';

                    //if(diagnosisMap.containsKey(eachReferral.Patient__c)){
                    body += '<b>निदान:</b>';
                    body += '<br/><ul><li>' + eachReferral.Preliminary_diagnosis__c + '</li></ul></br>';
                    //}

                    /* Updated Hindi section */
                    body += '<b>पेशेंट रिकॉर्ड एवं रिपोर्ट्स:</b>';
                    body += '<br/>रोगी से संबंधित सभी मेडिकल रिकॉर्ड, जांच रिपोर्ट्स एवं रेफरल से जुड़ी जानकारी पोर्टल पर सुरक्षित रूप से उपलब्ध है।';
                    body += '<br/>कृपया इस <a href="' + loginRedirectUrl + '" target="_blank">पोर्टल लिंक</a> के माध्यम से लॉगिन कर संपूर्ण केस विवरण देखें।';
                    body += '<br/><i>इस ईमेल के साथ कोई भी दस्तावेज़ संलग्न नहीं है।</i><br/><br/>';

                    body += 'हम आपसे निवेदन करते हैं कि कृपया इस केस को आगे बढ़ाएं और ज़रूरत अनुसार विशेषज्ञ इलाज प्रदान करें। रोगी को  <b>'+ formattedDate +'</b>  तक आपके अस्पताल में उपस्थित होने की सलाह दी गई है।<br/>';

                    body += '<br/>जैसे ही मरीज अस्पताल पहुंचे, कृपया इस <a href="' + loginRedirectUrl + '" target="_blank">पोर्टल लिंक</a> के माध्यम से उनके आगमन की सूचना दें, साथ ही उन्हें कब रिसीव किया गया, यह तारीख भी दर्ज करें।';
                    body += '<br/>प्राथमिक देखभाल देने या इंटरवेंशन पूरा करने के बाद, कृपया इस <a href="' + loginRedirectUrl + '" target="_blank">लिंक</a> के ज़रिए PHWC के साथ उसकी जानकारी साझा करें।';

                    body += '<br/>आपके सहयोग और मरीजों की सेवा के लिए धन्यवाद।<br/>';
                    body += '<br/><i>अगर आपको किसी भी तरह की और जानकारी चाहिए तो कृपया हमसे ' + eachReferral.Referred_To__r.Nodal_Person_Contact_Number__c +' पर संपर्क करें।<br/>';
                    body += '<br/>यह एक सिस्टम द्वारा जनरेट किया गया ईमेल है। कृपया इसका उत्तर न दें। <br/>';
                    body += '<br/><b>सादर,</b>';
                    body += '<br/>PHWC चमोली.';

                                    
                String emailSubject =  eachReferral.Name + '- Referring ' + eachReferral.Patient__r.Name + ' - (' + eachReferral.Patient__r.Age__c + '/' + eachReferral.Patient__r.Gender__c + ') to ' + eachReferral.PrimarySpecialty__c + secondarySpecialty + ' department';
                emailSubject += ' | '+eachReferral.Name + ' - ' + eachReferral.Patient__r.Name +' ('+ eachReferral.Patient__r.Age__c + '/'+ eachReferral.Patient__r.Gender__c +') को ' + eachReferral.PrimarySpecialty__c + hindiSecondarySpecialty + ' विभाग के लिए रेफ़र किया जा रहा है।';
                //String[] toAddresses = New String[]{'sandesh.p@crmit.com', 'aayush.bajoria@crmit.com', 'shaik.karishma@crmit.com', 'shruti.gupta@crmit.com'};
                    String[] toAddress = New String[]{eachReferral.Referred_To__r.Nodal_Person_Email_Address__c};
                    list<String> ccAddresses = New list<String>();
                    if(eachReferral.Patient__r.Attendent_Email__c != null){
                        ccAddresses.add(eachReferral.Patient__r.Attendent_Email__c);
                    }
                    if(eachReferral.Patient__r.PersonEmail != null){
                        ccAddresses.add(eachReferral.Patient__r.PersonEmail);
                    }
                    /* String emailBody = HCProviderEmailLanguageConverter.getTranslatedLanguage(body);
                    if(emailBody != null){
                    body += '<br/><br/><br/>' + emailBody;
                    }*/
                    
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                email.setHtmlBody(body);
                email.setToAddresses(toAddress);
                email.setCcAddresses(ccAddresses);
                email.setSubject(emailSubject);
                
                // List<Messaging.EmailFileAttachment> attachmentList = new List<Messaging.EmailFileAttachment>();
                // if(attachmentMap.containsKey(eachReferral.Id))
                // {
                //     Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                //     attachment.setFileName(attachmentMap.get(eachReferral.Id).Name);
                //     attachment.setBody(attachmentMap.get(eachReferral.Id).Body);
                //     attachment.setContentType(attachmentMap.get(eachReferral.Id).ContentType);
                //     attachmentList.add(attachment);
                // }
                
                // if(!zipFiles.isEmpty()){
                //     Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
                //     attachment.setFileName(zipFiles.get(eachReferral.Id).Title);
                //     attachment.setBody(zipFiles.get(eachReferral.Id).VersionData);
                //     attachmentList.add(attachment);
                // }
                
                // email.setFileAttachments (attachmentList ); 
                
                email.setCcAddresses(ccAddresses);
                if(owea!= null && !owea.isEmpty()){
                   email.setOrgWideEmailAddressId(owea.get(0).Id);
                }
                emailList.add(email);    
            }
            
            if(!emailList.isEmpty())
            {
                List<Referral__c> referralsToUpdate = new List<Referral__c>();
                
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailList);
                
                for(Integer i = 0; i < results.size(); i++){
                    Messaging.SendEmailResult result = results[i];
                    Referral__c referralToUpdate = new Referral__c(Id = referralIdList[i]);
                    if (result.isSuccess()) {
                        referralToUpdate.Referral_Status__c = 'Referred';
                        System.debug('Email sent successfully');
                        
                        resendEmailHCProviderController.resultWrapper resultWrap = new resendEmailHCProviderController.resultWrapper();
                        resultWrap.status = 'Success';  
                        resultWrap.body = 'Email sent successfully';
                        resultMap.put(referralIdList[i],resultWrap);
                    } else {
                        referralToUpdate.Referral_Status__c = 'Referral Failed';
                        System.debug('Email sending failed. Errors: ' + result.getErrors());
                        
                        resendEmailHCProviderController.resultWrapper resultWrap = new resendEmailHCProviderController.resultWrapper();
                        resultWrap.status = 'Error';  
                        resultWrap.body = String.valueOf(result.getErrors());

                        resultMap.put(referralIdList[i],resultWrap);
                        for (Messaging.SendEmailError err : result.getErrors()) {
                            System.debug('Error: ' + err.getStatusCode() + ': ' + err.getMessage() + ' ID :' + err.getTargetObjectId());
                        }
                    }
                    
                    referralsToUpdate.add(referralToUpdate);
                }
                
                if(!referralsToUpdate.isEmpty()){
                    update referralsToUpdate;
                }
            }
            
            return resultMap;
        }catch(exception ex){
            system.debug('Exception in ReferralTriggerHelper class::'+ ex.getMessage());
            system.debug('Exception in ReferralTriggerHelper class at line number ::'+ ex.getLineNumber());
            return resultMap;
        }
    }
    
    public static string getNonNullString(String value)
    {
        if(String.isNotBlank(value)){
            return value;
        }else{
            return '';
        }
    }
    
    public class zipFiles
    {
        public string fileName{get;set;}
        public blob fileBody{get;set;}
    }
    
    // Added code by Ibrahim on 9th June for sending sms to patient phone number code start here.
    public static void sendSMS(Map<Id, Referral__c> referralMap)
    {
        try{
            Map<String,String> phoneMessageMap = new Map<String,String>();
            for(Referral__c eachReferral : [Select id,Name,Patient__c,Patient__r.Name,Patient__r.phone,Patient__r.Attendant_Phone__c,PrimarySpecialty__c,Primary_Specialty__c,Primary_Specialty__r.Name,Secondary_Specialty__r.Name,Referred_To__r.Name,Referral_Date__c from Referral__c Where Id in: referralMap.keySet() and Patient__c != null])
            {
                
                String smsMessage = 'Dear ' + eachReferral.Patient__r.Name + ',\n' +
                    'You have been referred to ' + eachReferral.PrimarySpecialty__c + '. Kindly visit ' + eachReferral.Referred_To__r.Name + ' by ' + eachReferral.Referral_Date__c + ', carrying your medical records. For help, call +91 99001 12110.';
                
                if(eachReferral.Patient__r.phone != null)
                {
                    String phone = formatToE164(eachReferral.Patient__r.phone);
                    if(!phoneMessageMap.containsKey(phone))
                    {
                        phoneMessageMap.put(phone,smsMessage); 
                    }
                }
                
                if(eachReferral.Patient__r.Attendant_Phone__c != null)
                {
                    String phone = formatToE164(eachReferral.Patient__r.Attendant_Phone__c);
                    if(!phoneMessageMap.containsKey(phone))
                    {
                        phoneMessageMap.put(phone,smsMessage); 
                    } 
                }
                
            }
            
            if(!phoneMessageMap.isEmpty())
            {
                for(string eachPhone : phoneMessageMap.keySet())
                {
                    // Send SMS using Amazon AWS
                    sendSMSAsync(eachPhone, phoneMessageMap.get(eachPhone));
                }
            }
            
        }catch(exception ex){
            system.debug('Exception in ReferralTriggerHelper class sendSMS method::'+ ex.getMessage());
            system.debug('Exception in ReferralTriggerHelper class sendSMS method at line number ::'+ ex.getLineNumber());
        }
    }

    @future(callout=true)
public static void sendSMSAsync1(String phoneNumber, String message) {

    try {
        // ---------------- CONFIG ----------------
        String endpoint = 'https://4a3o7o6prl.execute-api.ap-south-1.amazonaws.com/dev/send-sms';
        String region = 'ap-south-1';
        String service = 'execute-api';

        // Keys live in the Amazon_AWS__c custom setting (org default), never in source
        String accessKey = amazonAWSEndPoint?.AccessKey__c;
        String secretKey = amazonAWSEndPoint?.SecretKey__c;
        if (String.isBlank(accessKey) || String.isBlank(secretKey)) {
            System.debug('ReferralTriggerHelper.sendSMSAsync1: AWS keys missing in Amazon_AWS__c custom setting - SMS not sent');
            return;
        }

        // ---------------- BODY ----------------
        Map<String, Object> bodyMap = new Map<String, Object>{
            'phoneNumber' => phoneNumber,
            'message'     => message,
            'senderId'    => 'PMJAY'
        };

        String requestBody = JSON.serialize(bodyMap);
        String payloadHash = hash(requestBody);

        // ---------------- DATES ----------------
        String amzDate = Datetime.now().formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
        String dateStamp = Datetime.now().formatGMT('yyyyMMdd');

        // ---------------- CANONICAL REQUEST ----------------
        String canonicalUri = '/dev/send-sms';
        String canonicalHeaders =
            'content-type:application/json\n' +
            'host:4a3o7o6prl.execute-api.ap-south-1.amazonaws.com\n' +
            'x-amz-date:' + amzDate + '\n';

        String signedHeaders = 'content-type;host;x-amz-date';

        String canonicalRequest =
            'POST\n' +
            canonicalUri + '\n\n' +
            canonicalHeaders + '\n' +
            signedHeaders + '\n' +
            payloadHash;

        // ---------------- STRING TO SIGN ----------------
        String algorithm = 'AWS4-HMAC-SHA256';
        String credentialScope = dateStamp + '/' + region + '/' + service + '/aws4_request';

        String stringToSign =
            algorithm + '\n' +
            amzDate + '\n' +
            credentialScope + '\n' +
            hash(canonicalRequest);

        // ---------------- SIGNING KEY ----------------
        Blob signingKey = getSignatureKey(secretKey, dateStamp, region, service);
        String signature =
            EncodingUtil.convertToHex(
                Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey)
            );

        String authorizationHeader =
            algorithm + ' ' +
            'Credential=' + accessKey + '/' + credentialScope + ', ' +
            'SignedHeaders=' + signedHeaders + ', ' +
            'Signature=' + signature;

        // ---------------- HTTP CALL ----------------
        HttpRequest req = new HttpRequest();
        req.setEndpoint(endpoint);
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setHeader('X-Amz-Date', amzDate);
        req.setHeader('Authorization', authorizationHeader);
        req.setBody(requestBody);

        Http http = new Http();
        HttpResponse res = http.send(req);

        System.debug('SMS Status = ' + res.getStatusCode());
        System.debug('SMS Response = ' + res.getBody());

    } catch (Exception e) {
        System.debug('❌ SMS ERROR: ' + e.getMessage());
        System.debug('Line: ' + e.getLineNumber());
    }
}

    
    @future(callout=true)
    public static void sendSMSAsync(String PhoneNumber, String Message)
    {
        try{
            String requestBody = 'Action=' + EncodingUtil.urlEncode('Publish', 'UTF-8') +
                '&PhoneNumber=' + EncodingUtil.urlEncode(PhoneNumber, 'UTF-8') +
                '&Message=' + EncodingUtil.urlEncode(Message, 'UTF-8');
            
            String amzDate = getAmzDate();
            String dateStamp = getDateStamp();
            
            String canonicalURI = '/';
            String canonicalQueryString = '';
            String canonicalHeaders = 'content-type:application/x-www-form-urlencoded\n' +
                'host:sns.' + amazonAWSEndPoint.Region__c + '.amazonaws.com\n' +
                'x-amz-content-sha256:' + hash(requestBody) + '\n' +
                'x-amz-date:' + amzDate + '\n';
            
            String signedHeaders = 'content-type;host;x-amz-content-sha256;x-amz-date';
            String canonicalRequest = 'POST\n' + canonicalURI + '\n' + canonicalQueryString + '\n' +
                canonicalHeaders + '\n' + signedHeaders + '\n' + hash(requestBody);
            
            String algorithm = 'AWS4-HMAC-SHA256';
            String credentialScope = dateStamp + '/' + amazonAWSEndPoint.Region__c + '/' + amazonAWSEndPoint.Service__c + '/aws4_request';
            String stringToSign = algorithm + '\n' + amzDate + '\n' + credentialScope + '\n' + hash(canonicalRequest);
            
            Blob signingKey = getSignatureKey(amazonAWSEndPoint.SecretKey__c, dateStamp, amazonAWSEndPoint.Region__c, amazonAWSEndPoint.Service__c);
            String signature = EncodingUtil.convertToHex(Crypto.generateMac('HmacSHA256', Blob.valueOf(stringToSign), signingKey));
            
            String authorizationHeader = algorithm + ' ' +
                'Credential=' + amazonAWSEndPoint.AccessKey__c + '/' + credentialScope + ', ' +
                'SignedHeaders=' + signedHeaders + ', ' +
                'Signature=' + signature;
            
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            request.setEndpoint(amazonAWSEndPoint.EndPoint_URL__c);
            request.setMethod('POST');
            request.setHeader('Content-Type','application/x-www-form-urlencoded');
            request.setHeader('X-Amz-Date', amzDate);
            request.setHeader('X-Amz-Content-Sha256', hash(requestBody));
            request.setHeader('Authorization', authorizationHeader);
            request.setBody(requestBody);
            
            HttpResponse response = http.send(request);
            SystemLogHelper.addIntegrationLogRecord('SMSIntegration', 'sendSMSAsync', '', response, request, true, requestBody);
            system.debug('status'+response.getStatusCode());
            system.debug('response::'+response + ': body::'+response.getBody());
            
        }catch(exception ex){
            system.debug('Exception in future method::'+ ex.getMessage());
            system.debug('Exception in future method at line number ::'+ ex.getLineNumber());
        }
    }
    
    public static String formatToE164(String phone) {
        phone = phone.replaceAll('[^0-9]', ''); // Remove non-numeric
        if (!phone.startsWith('91')) {
            phone = '91' + phone;
        }
        return '+' + phone;
    }
    
    private static String hash(String text) {
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(text))).toLowerCase();
    }
    
    private static String getAmzDate() {
        return Datetime.now().formatGMT('yyyyMMdd\'T\'HHmmss\'Z\'');
    }
    
    private static String getDateStamp() {
        return Datetime.now().formatGMT('yyyyMMdd');
    }
    
    private static Blob HmacSHA256(String data, Blob key) {
        return Crypto.generateMac('HmacSHA256', Blob.valueOf(data), key);
    }
    
    private static Blob getSignatureKey(String key, String dateStamp, String regionName, String serviceName) {
        Blob kSecret = Blob.valueOf('AWS4' + key);
        Blob kDate = HmacSHA256(dateStamp, kSecret);
        Blob kRegion = HmacSHA256(regionName, kDate);
        Blob kService = HmacSHA256(serviceName, kRegion);
        return HmacSHA256('aws4_request', kService);
    }
    // Added code by Ibrahim on 9th June for sending sms to patient phone number code ended here.
}