public class CustomLookupController {
    @AuraEnabled(cacheable=true)
    public static List<sObject> search(String searchTerm, string myObject, String filter) {
        String myQuery = null;
        System.debug('searchTerm::' + searchTerm);
        System.debug('myObject::' + myObject);

        if (filter != null && filter != '') {
            myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\' AND ' + filter + ' LIMIT 20';
        } else {
            if (searchTerm == null || searchTerm == '') {
                myQuery = 'SELECT Id, Name FROM ' + myObject + ' ORDER BY Name ASC LIMIT 20';
            } else {
                myQuery = 'SELECT Id, Name FROM ' + myObject + ' WHERE Name LIKE \'%' + String.escapeSingleQuotes(searchTerm) + '%\' LIMIT 5';
            }
        }
        System.debug('myQuery::' + myQuery);
        List<sObject> lookUpList = Database.query(myQuery);
        System.debug('lookUpList::' + lookUpList);
        return lookUpList;
    }
}