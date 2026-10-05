public with sharing class HealthcareProviderController {
   
    @AuraEnabled(cacheable=true)
    public static List<SpecialtyOption> getSpecialties() {
        try {
            // Use a Set to eliminate duplicates more efficiently
            Set<String> uniqueSpecialtyNames = new Set<String>();
            
            List<HealthcareProviderSpecialty> allSpecialties = [
                SELECT Id, Name
                FROM HealthcareProviderSpecialty
                WHERE Name != null AND Name != ''
                ORDER BY Name ASC
            ];
            
            // Create unique specialty options
            List<SpecialtyOption> specialtyOptions = new List<SpecialtyOption>();
            
            for (HealthcareProviderSpecialty specialty : allSpecialties) {
                String lowerName = specialty.Name.toLowerCase().trim();
                if (!uniqueSpecialtyNames.contains(lowerName)) {
                    specialtyOptions.add(new SpecialtyOption(specialty.Name, specialty.Id));
                    uniqueSpecialtyNames.add(lowerName);
                }
            }
            
            return specialtyOptions;
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving specialties: ' + e.getMessage());
        }
    }
   
   @AuraEnabled
public static List<ProviderSearchResult> searchProviders(Map<String, Object> searchCriteria) {
    try {
        String city = (String) searchCriteria.get('city');
        String hospitalType = (String) searchCriteria.get('hospitalType');
        String primarySpecialty = (String) searchCriteria.get('primarySpecialty');
        String secondarySpecialty = (String) searchCriteria.get('secondarySpecialty');
       
        // Build dynamic SOQL query with address fields
        String soqlQuery = 'SELECT Id, Name, Address__Street__s, Address__City__s, Address__PostalCode__s, Hospital_Type__c FROM HealthcareProvider WHERE ';
        List<String> conditions = new List<String>();
       
        // Add city condition
        if (String.isNotBlank(city)) {
            conditions.add('Address__City__s LIKE \'%' + String.escapeSingleQuotes(city) + '%\'');
        }
       
        // Add hospital type condition
        if (String.isNotBlank(hospitalType)) {
            conditions.add('Hospital_Type__c = \'' + String.escapeSingleQuotes(hospitalType) + '\'');
        }
       
        // Handle specialty conditions - BOTH specialties required when both are provided
        if (String.isNotBlank(primarySpecialty) && String.isNotBlank(secondarySpecialty)) {
            // Provider must have BOTH specialties
            String bothSpecialtiesCondition = 'Id IN (SELECT Healthcare_Provider__c FROM HealthcareProviderSpecialty WHERE Name = \'' + 
                String.escapeSingleQuotes(primarySpecialty) + '\') AND ' +
                'Id IN (SELECT Healthcare_Provider__c FROM HealthcareProviderSpecialty WHERE Name = \'' + 
                String.escapeSingleQuotes(secondarySpecialty) + '\')';
            conditions.add(bothSpecialtiesCondition);
        } else if (String.isNotBlank(primarySpecialty)) {
            // Provider must have primary specialty only
            String primarySpecialtyCondition = 'Id IN (SELECT Healthcare_Provider__c FROM HealthcareProviderSpecialty WHERE Name = \'' + 
                String.escapeSingleQuotes(primarySpecialty) + '\')';
            conditions.add(primarySpecialtyCondition);
        } else if (String.isNotBlank(secondarySpecialty)) {
            // Provider must have secondary specialty only
            String secondarySpecialtyCondition = 'Id IN (SELECT Healthcare_Provider__c FROM HealthcareProviderSpecialty WHERE Name = \'' + 
                String.escapeSingleQuotes(secondarySpecialty) + '\')';
            conditions.add(secondarySpecialtyCondition);
        }
       
        // If no conditions, return empty list
        if (conditions.isEmpty()) {
            return new List<ProviderSearchResult>();
        }
       
        soqlQuery += String.join(conditions, ' AND ');
        soqlQuery += ' ORDER BY Name ASC LIMIT 50';
       
        System.debug('Generated SOQL: ' + soqlQuery);
       
        List<HealthcareProvider> providers = Database.query(soqlQuery);
        
        // Convert to result wrapper objects with formatted addresses
        List<ProviderSearchResult> results = new List<ProviderSearchResult>();
        for (HealthcareProvider provider : providers) {
            results.add(new ProviderSearchResult(provider));
        }
        
        return results;
       
    } catch (Exception e) {
        System.debug('Error in searchProviders: ' + e.getMessage());
        throw new AuraHandledException('Error searching providers: ' + e.getMessage());
    }
}
    
    // Helper method to format address from individual components
    private static String formatAddress(String street, String city, String postalCode) {
        List<String> addressParts = new List<String>();
        
        if (String.isNotBlank(street)) {
            addressParts.add(street);
        }
        
        if (String.isNotBlank(city)) {
            addressParts.add(city);
        }
        
        if (String.isNotBlank(postalCode)) {
            addressParts.add(postalCode);
        }
        
        return addressParts.isEmpty() ? '' : String.join(addressParts, ', ');
    }
    
    // Wrapper class for specialty options to eliminate duplicates
    public class SpecialtyOption {
        @AuraEnabled public String label { get; set; }
        @AuraEnabled public String value { get; set; }
        
        public SpecialtyOption(String label, String value) {
            this.label = label;
            this.value = value;
        }
    }
    
    // Wrapper class for search results with formatted address
    public class ProviderSearchResult {
        @AuraEnabled public String id { get; set; }
        @AuraEnabled public String name { get; set; }
        @AuraEnabled public String formattedAddress { get; set; }
        @AuraEnabled public String hospitalType { get; set; }
        @AuraEnabled public String street { get; set; }
        @AuraEnabled public String city { get; set; }
        @AuraEnabled public String postalCode { get; set; }
        
        public ProviderSearchResult(HealthcareProvider provider) {
            this.id = provider.Id;
            this.name = provider.Name;
            this.hospitalType = provider.Hospital_Type__c;
            this.street = provider.Address__Street__s;
            this.city = provider.Address__City__s;
            this.postalCode = provider.Address__PostalCode__s;
            
            // Format the address using the helper method
            List<String> addressParts = new List<String>();
            
            if (String.isNotBlank(provider.Address__Street__s)) {
                addressParts.add(provider.Address__Street__s);
            }
            
            if (String.isNotBlank(provider.Address__City__s)) {
                addressParts.add(provider.Address__City__s);
            }
            
            if (String.isNotBlank(provider.Address__PostalCode__s)) {
                addressParts.add(provider.Address__PostalCode__s);
            }
            
            this.formattedAddress = addressParts.isEmpty() ? '' : String.join(addressParts, ', ');
        }
    }
}