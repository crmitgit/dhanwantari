/**
 * Prompt template data provider: the allopathic products in the org's Medication catalogue
 * (Indian market brand names with strength and form), one per line. Used by
 * Medication_Prescription_Assistant so drafts only name products that exist in this system.
 * Ayurvedic entries (those with Main_Indications__c) are excluded; the AYUSH assistant covers them.
 */
public without sharing class IndianMedicationCatalogProvider {

    private static final Integer MAX_PRODUCTS = 5000;

    public class Request {
        @InvocableVariable(required=true)
        public Id encounterId;
    }

    public class Response {
        @InvocableVariable
        public String Prompt;
    }

    @InvocableMethod(label='Get Indian Medication Catalogue' description='Allopathic products in the Medication catalogue, for grounding prescription drafts')
    public static List<Response> getCatalogue(List<Request> requests) {
        String catalogue = buildCatalogue();
        List<Response> responses = new List<Response>();
        Integer count = requests == null || requests.isEmpty() ? 1 : requests.size();
        for (Integer i = 0; i < count; i++) {
            Response res = new Response();
            res.Prompt = catalogue;
            responses.add(res);
        }
        return responses;
    }

    @TestVisible
    private static String buildCatalogue() {
        Set<String> seen = new Set<String>();
        List<String> lines = new List<String>();
        for (Medication m : [
            SELECT Name
            FROM Medication
            WHERE Main_Indications__c = null AND Name != null
            ORDER BY Name
            LIMIT :MAX_PRODUCTS
        ]) {
            String name = m.Name.normalizeSpace();
            if (name.length() > 1 && seen.add(name.toLowerCase())) {
                lines.add(name);
            }
        }
        return lines.isEmpty() ? 'CATALOGUE EMPTY' : String.join(lines, '\n');
    }
}