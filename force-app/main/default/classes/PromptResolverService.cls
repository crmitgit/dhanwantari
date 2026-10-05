public class PromptResolverService {

    public class Request {
        @InvocableVariable(required=true)
        public String templateDevName;

        @InvocableVariable(required=true)
        public Id encounterId;

        @InvocableVariable(required=true)
        public String draftPrescription;
    }

    public class Response {
        @InvocableVariable
        public String resolvedPrompt;
    }

    @InvocableMethod(label='Get Resolved Prompt')
    public static List<Response> getResolvedPrompt(List<Request> requests) {

        List<Response> responses = new List<Response>();
        Response res = new Response();
        responses.add(res);

        if (requests == null || requests.isEmpty()) {
            return responses;
        }

        String templateDevName = requests[0].templateDevName;
        Id encounterId = requests[0].encounterId;
        String draftPrescription = requests[0].draftPrescription;

        // 1) Fetch template from Custom Metadata
        Prompt_Template__mdt templateRec = [
            SELECT Template_Body__c
            FROM Prompt_Template__mdt
            WHERE DeveloperName = :templateDevName
            LIMIT 1
        ];

        if (templateRec == null || String.isBlank(templateRec.Template_Body__c)) {
            System.debug('❌ Template not found or empty: ' + templateDevName);
            return responses;
        }

        // 2) Get Encounter Prompt from formatter class
        ClinicalEncounterPromptDataFormatter.Request req =
            new ClinicalEncounterPromptDataFormatter.Request();
        req.encounterId = encounterId;

        List<ClinicalEncounterPromptDataFormatter.Response> respList =
            ClinicalEncounterPromptDataFormatter.getPrompt(
                new List<ClinicalEncounterPromptDataFormatter.Request>{ req }
            );

        if (respList == null || respList.isEmpty() || String.isBlank(respList[0].Prompt)) {
            System.debug('❌ Encounter prompt not found for encounterId: ' + encounterId);
            return responses;
        }

        String encounterPrompt = respList[0].Prompt;

        // 3) Replace placeholders
        String resolvedPrompt = templateRec.Template_Body__c;

        resolvedPrompt = resolvedPrompt.replace(
            '{!$Apex:ClinicalEncounterPromptDataFormatter.Prompt}',
            encounterPrompt
        );

        resolvedPrompt = resolvedPrompt.replace(
            '{!$Input:draftPrescription}',
            (draftPrescription != null ? draftPrescription : '')
        );

        res.resolvedPrompt = resolvedPrompt;

        System.debug('✅ Resolved Prompt Generated for Template: ' + templateDevName);
        System.debug('📌 Resolved Prompt: ' + res.resolvedPrompt);

        return responses;
    }
}