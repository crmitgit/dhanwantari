/**
 * @description       : 
 * @author            : Karishma
 * @group             : 
 * @last modified on  : 17-07-2025
 * @last modified by  : Karishma
**/

public without sharing class SearchJanAushadhiKendraController 
{
    @AuraEnabled(cacheable=true)
    public static List<janaushadhiDetails> getJanaushadhiDetails()
    {
        List<janaushadhiDetails> janaushadhiDetailsList = new List<janaushadhiDetails>();
        Integer index = 1;
        for(Janaushadhi_Pharmacy__c eachJanaushadhi : [SELECT Id,Name,Owner_Name__c,Contact_Number__c,Address__c,Address__StateCode__s,Address__City__s,Address__PostalCode__s, Address__Street__s FROM Janaushadhi_Pharmacy__c ])
        {
            janaushadhiDetails janaushadhi = new janaushadhiDetails();
            janaushadhi.janaushadhiId = eachJanaushadhi.Id;
            janaushadhi.KendraCode = eachJanaushadhi.Name;
            janaushadhi.OwnerName = eachJanaushadhi.Owner_Name__c;
            janaushadhi.ContactNumber = eachJanaushadhi.Contact_Number__c;
            janaushadhi.State = eachJanaushadhi.Address__c.getState();
            janaushadhi.City = eachJanaushadhi.Address__City__s;
            janaushadhi.PostalCode = eachJanaushadhi.Address__PostalCode__s;
            janaushadhi.Street = eachJanaushadhi.Address__Street__s;
            janaushadhi.index = index++;
            janaushadhi.isSelected = false;
            janaushadhiDetailsList.add(janaushadhi);
        }
        return janaushadhiDetailsList;   
    }
    
    @AuraEnabled(cacheable=true)
    public static List<String> getCities() {
        Set<String> cities = new Set<String>();
        for(Janaushadhi_Pharmacy__c eachJanaushadhi : [SELECT Address__City__s FROM Janaushadhi_Pharmacy__c WHERE Address__City__s != null]) {
            cities.add(eachJanaushadhi.Address__City__s);
        }
        return new List<String>(cities);
    }
    
    public class janaushadhiDetails
    {
        @AuraEnabled
        public String janaushadhiId { get; set;} 
        @AuraEnabled
        public String KendraCode { get; set;}
        @AuraEnabled
        public String OwnerName { get; set;}
        @AuraEnabled
        public String ContactNumber { get; set;}
        @AuraEnabled
        public String State { get; set;}
        @AuraEnabled
        public String City { get; set;}
        @AuraEnabled
        public String PostalCode { get; set;}
        @AuraEnabled
        public String Street { get; set;}
        @AuraEnabled
        public Integer index { get; set;}
        @AuraEnabled 
        public Boolean isSelected { get; set; }
    }
}