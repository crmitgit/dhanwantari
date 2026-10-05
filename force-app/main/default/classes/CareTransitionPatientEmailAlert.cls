/**
* @description       : 
* @author            : Karishma
* @group             : 
* @last modified on  : 01-07-2025
* @last modified by  : Karishma
**/

public class CareTransitionPatientEmailAlert 
{
    
    @InvocableMethod
    Public static void sendPatientEmail(list<id> CareTransitionId) 
    {
        try{            
            //List<EmailTemplate> emailTemplate = [SELECT Id FROM EmailTemplate WHERE Name = 'Care Transition Email Alert' LIMIT 1];
            List<Messaging.SingleEmailMessage> emailList = new list <Messaging.SingleEmailMessage>();
            OrgWideEmailAddress[] owea = [select Id,Address from OrgWideEmailAddress where Address = 'shaik.karishma@crmit.com'];
            for(Care_Transition__c eachCareTransition :[Select Id, Name, Patient__r.Name, Employee_Name__c, Healthcare_Provider__r.Name, Patient__r.Registered_At__r.Name, PHWC_Doctor__r.Name,Patient__r.Age__c,Patient__r.Gender__c from Care_Transition__c where id in:CareTransitionId]){
                if(eachCareTransition.Id!= null){
                    String body = 'Dear <b>' + eachCareTransition.Patient__r.Name + ',</b><br/>';
                    body += '<br/>Your care at <b>' + eachCareTransition.Healthcare_Provider__r.Name + '</b> is now concluded. For follow-up and continued care, please visit <b>'+ eachCareTransition.Patient__r.Registered_At__r.Name +'.</b>';
                    body += '<br/>Your discharge summary have been shared with the '+ eachCareTransition.Patient__r.Registered_At__r.Name +' to ensure a smooth transition.<br/>';
                    body += '<br/>For any questions, feel free to contact us.';
                    body += '<br/>Wishing you good health.<br/>';
                    body += '<br/><i>This is a system‑generated message from a no‑reply email. Please do not respond to this email.';
                    body += '<br/><br/><b>Regards,</b>';
                    // body += '<br/>' + eachCareTransition.Employee_Name__c +'/Care Team,';
                    body += '<br/>' + eachCareTransition.Healthcare_Provider__r.Name + '.</i><br/><br/>';	
                    body += '---------------------------------------------------------------------<br/>';
                    body += '<br/>प्रिय '+ eachCareTransition.Patient__r.Name +'<br/>';
                    body += '<br/>आपका इलाज <b>' + eachCareTransition.Healthcare_Provider__r.Name + '</b> में अब पूर्ण हो चुका है।. आगे की देखभाल और फॉलो-अप के लिए कृपया <b>'+ eachCareTransition.Patient__r.Registered_At__r.Name +'</b> से संपर्क करें।.';
                    body += '<br/>आपकी चिकित्सा संबंधी जानकारी <b>'+ eachCareTransition.Patient__r.Registered_At__r.Name +'</b> को भेज दी गई है।<br/>';
                    body += '<br/>यदि आपके कोई प्रश्न हों, तो आप हमसे संपर्क करने में संकोच न करें।';
                    body += '<br/>आपके उत्तम स्वास्थ्य की कामना है।<br/>';
                    body += '<br/><i>यह एक सिस्टम द्वारा जनरेट किया गया ईमेल है। कृपया इसका उत्तर न दें।.';
                    body += '<br/><br/><b>सादर,</b>';
                    body += '<br/>' + eachCareTransition.Healthcare_Provider__r.Name + '.</i><br/><br/>';
                    String emailSubject = 'Follow-Up Care at ' + eachCareTransition.Patient__r.Registered_At__r.Name; 
                    // Messaging.SingleEmailMessage email =  Messaging.renderStoredEmailTemplate(emailTemplate.get(0).Id, null, eachCareTransition.Id);
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    emailList.add(email);
                    String[] toAddresses = New String[]{'shruti.gupta@crmit.com'};
                        email.setHtmlBody(body);
                    email.setSubject(emailSubject);
                    email.setToAddresses(toAddresses);
                    if(owea!= null && !owea.isEmpty()){
                        email.setOrgWideEmailAddressId(owea.get(0).Id);
                    }
                    
                }
                if(eachCareTransition.Id!= null){
                    String body = 'Dear <b>Medical Officer,</b><br/>';
                    //body += '<br/>PHWC Chamoli<br/>';
                    body += '<br/>Greetings from <b>' + eachCareTransition.Healthcare_Provider__r.Name +'</b><br/>';
                    body += '<br/>This is to inform you that the referred patient,<b> '+eachCareTransition.Patient__r.Name + ' ('+eachCareTransition.Patient__r.Age__c +'/'+ eachCareTransition.Patient__r.Gender__c+'),</b> has completed his care at our facility.<br/>';
                    body += '<br/>All relevant clinical details including discharge summary, diagnosis, investigations, and treatment provided, have been documented and are now available in your system for reference.<br/>';
                    body += '<br/>Please feel free to reach out if any further clarification is required.<br/>';
                    body += '<br/><i>This is a system‑generated message from a no‑reply email. Please do not respond to this email.<br/>';
                    body += '<br/><b>Regards,</b>';
                    body += '<br/>'+eachCareTransition.Healthcare_Provider__r.Name + '.</i>';
                    body += '<br/>---------------------------------------------------------------------<br/>';
                    body += '<br/>माननीय <b>मेडिकल ऑफिसर,</b><br/>';
                    body += '<br/> <b>'+ eachCareTransition.Healthcare_Provider__r.Name + '</b> की ओर से सादर नमस्कार।<br/>';
                    body += '<br/>आपको यह सूचित किया जाता है कि संदर्भित मरीज <b>'+ eachCareTransition.Patient__r.Name + ' ('+ eachCareTransition.Patient__r.Age__c +'/'+ eachCareTransition.Patient__r.Gender__c+') </b>ने हमारे अस्पताल में अपना उपचार पूर्ण कर लिया है। <br/>';
                    body += '<br/>डिस्चार्ज समरी, निदान, जांचें और उपचार सहित सभी जरूरी मेडिकल जानकारी दर्ज की जा चुकी है और अब आपकी सिस्टम में देखने के लिए उपलब्ध है।<br/>';
                    body += '<br/>यदि किसी अतिरिक्त जानकारी की आवश्यकता हो, तो कृपया हमसे संपर्क करें।<br/>';
                    body += '<br/><i>यह एक सिस्टम द्वारा जनरेट किया गया ईमेल है। कृपया इसका उत्तर न दें।.';
                    body += '<br/><br/><b>सादर,</b>';
                    body += '<br/>'+ eachCareTransition.Healthcare_Provider__r.Name +'</i>';
                    String phwcEmailSubject = 'Care Completion Notification –' + eachCareTransition.Patient__r.Name + '('+ eachCareTransition.Patient__r.Age__c +'/' + eachCareTransition.Patient__r.Gender__c +')'; 
                    // Messaging.SingleEmailMessage email =  Messaging.renderStoredEmailTemplate(emailTemplate.get(0).Id, null, eachCareTransition.Id);
                    Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
                    emailList.add(email);
                    String[] toAddresses = New String[]{'shaik.karishma@crmit.com'};
                        email.setHtmlBody(body);
                    email.setSubject(phwcEmailSubject);
                    email.setToAddresses(toAddresses);
                    if(owea!= null && !owea.isEmpty())
                    {
                        email.setOrgWideEmailAddressId(owea.get(0).Id);
                    }
                }  
            }
            
            system.debug('size::'+emailList.size());
            if(!emailList.isEmpty()){
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emailList);
            }
        }catch(exception e){
            system.debug(e);
        }
    }
}