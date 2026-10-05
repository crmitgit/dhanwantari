public with sharing class FollowUpReminderEmailScheduler {

    // Run this daily as a scheduled job
    public static void sendFollowUpReminders() {
        // Fetch encounters where Follow_Up_Date__c is 2 days from today
        Date targetDate = Date.today().addDays(2);

        List<ClinicalEncounter> encounters = [
            SELECT Id, Name, Follow_Up_Date__c, 
                   Contact__r.Name, Contact__r.Email,
                   Prescribing_Doctor__r.Name,
                   Facility.Name
            FROM ClinicalEncounter
            WHERE Follow_Up_Date__c = :targetDate
            AND Contact__r.Email != null
        ];

        List<Messaging.SingleEmailMessage> emailsToSend = new List<Messaging.SingleEmailMessage>();

        for (ClinicalEncounter encounter : encounters) {
            String patientName = encounter.Contact__r.Name;
            String email = encounter.Contact__r.Email;
            String followUpDate = encounter.Follow_Up_Date__c.format(); // format as needed
            String doctorName = encounter.Prescribing_Doctor__r != null ? 'Dr. ' + encounter.Prescribing_Doctor__r.Name : 'your doctor';
            String location = encounter.Facility != null && String.isNotBlank(encounter.Facility.Name) ? encounter.Facility.Name : 'our center';


            String subject = 'Your Follow-Up Appointment with ' + encounter.Prescribing_Doctor__r.Name + 'on ' + followUpDate + ' at '+ encounter.Facility.Name + ' | आपकी अगली मुलाक़ात ' + encounter.Prescribing_Doctor__r.Name + ' के साथ ' + followUpDate +' को ' + encounter.Facility.Name + 
                 ' में डॉ. ';

            String body = 
                'Dear ' + patientName + ',\n\n' +
                'This is a reminder that your follow-up appointment is scheduled on ' + followUpDate + 
                ' at ' + location + '.\n' +
                 doctorName + ', looks forward to seeing you.\n\n' +

                'प्रिय ' + patientName + ',\n\n' +
                'यह एक अनुस्मारक है कि आपकी अगली परामर्श तिथि ' + followUpDate + 
                ' को ' + location + ' पर निर्धारित है।\n' +
                doctorName + ' आपसे मिलने के लिए तत्पर हैं।\n\n' +

                'Kind regards,\n' +
                location + '\n\n' +

                '—\n' +
                'CONFIDENTIALITY NOTICE: This email and any attachments contain personal medical information intended solely for the addressee.\n' +
                'यह एक गोपनीय ईमेल है जिसमें केवल संबंधित व्यक्ति की व्यक्तिगत चिकित्सा जानकारी है।\n\n' +

                'This is a system‑generated message from a no‑reply email. Please do not respond to this email.\n' +
                'यह एक बिना-जवाब ईमेल से भेजा गया प्रणाली-जनित संदेश है। कृपया इस ईमेल का उत्तर न दें।';

            Messaging.SingleEmailMessage emailMsg = new Messaging.SingleEmailMessage();
            emailMsg.setToAddresses(new String[] { email });
            emailMsg.setSubject(subject);
            emailMsg.setPlainTextBody(body);
            emailMsg.setSenderDisplayName('PHWC Chamoli');
            emailMsg.setReplyTo('no-reply@phwc.in');

            emailsToSend.add(emailMsg);
        }

        if (!emailsToSend.isEmpty()) {
            Messaging.sendEmail(emailsToSend, false);
        }
    }
}