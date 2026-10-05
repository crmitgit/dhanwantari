public with sharing class FlowJsonParser {
    
    public class AuditResult {
        @InvocableVariable public String safety_status;
        @InvocableVariable public String primary_reason;
        @InvocableVariable public String notes;

        // MUST be List<String>
        public List<String> violation_category;

        // Flow-friendly string output
        @InvocableVariable public String violation_category_text;
    }

    @InvocableMethod(label='Parse Safety Audit JSON')
    public static List<AuditResult> parseJson(List<String> jsonInput) {

        List<AuditResult> results = new List<AuditResult>();

        for(String jsonStr : jsonInput){

            System.debug('📌 Raw JSON String: ' + jsonStr);

            AuditResult ar = (AuditResult) JSON.deserialize(jsonStr, AuditResult.class);

            // Convert list to string for flow usage
            if(ar.violation_category != null){
                ar.violation_category_text = String.join(ar.violation_category, ',');
            }

            results.add(ar);
        }

        return results;
    }
}