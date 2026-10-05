/**
* @description       : 
* @author            : Karishma
* @group             : 
* @last modified on  : 30-06-2025
* @last modified by  : Karishma
**/

public class ZipController 
{   
    
    public static Map<Id,ContentVersion> zipAttachment(Map<Id,List<ContentVersion>> contentVersionIdMap)
    {
        Map<Id, ContentVersion> contentVersionMap = new Map<Id, ContentVersion>();
        Map<Id, Referral__c> referralMap = new Map<Id, Referral__c>();
        for(Referral__c eachReferral : [Select Id, Name, Patient__r.Name, Patient__r.Age__c, Patient__r.Gender__c from Referral__c where Id in: contentVersionIdMap.keySet()]){
            referralMap.put(eachReferral.Id, eachReferral);
        }
        Compression.ZipWriter writer = new Compression.ZipWriter();
        
        Datetime d = system.now();
        string dateTimeVariable = d.format('yyyy-MM-ddh:mma');
        
        for(Id referralId : contentVersionIdMap.keySet())
        {
            Set<String> usedNames = new Set<String>();
            for(ContentVersion eachContentVersion : contentVersionIdMap.get(referralId))
            {
                String fileName = eachContentVersion.Title;
                // Ensure unique file name
                Integer counter = 1;
                while (usedNames.contains(fileName)) {
                    fileName = eachContentVersion.Title + ' (' + counter + ')';
                    counter++;
                }
                usedNames.add(fileName);
                writer.AddEntry(fileName, eachContentVersion.VersionData);
                // writer.AddEntry(eachContentVersion.Title + eachContentVersion.Id, eachContentVersion.VersionData);
            }
            
            blob newZipArchive = writer.getArchive();
            
            ContentVersion zipContentVersion = new ContentVersion();
            zipContentVersion.VersionData = newZipArchive;
            if(referralMap.ContainsKey(referralId)){
                zipContentVersion.Title = referralMap.get(referralId).Patient__r.Name +' Reports'+ dateTimeVariable +'.zip';
            }else{
                zipContentVersion.Title = 'Reports'+ dateTimeVariable +'.zip';
            }
            zipContentVersion.Description = 'Zip files: '+referralId;
            zipContentVersion.PathOnClient = '/PatientFiles' + dateTimeVariable + '.zip';
            contentVersionMap.put(referralId,zipContentVersion);
        }
        
        return contentVersionMap;
    }
}