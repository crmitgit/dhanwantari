/**
* @description       : 
* @author            : Karishma
* @group             : 
* @last modified on  : 16-06-2025
* @last modified by  : Karishma
**/

public without sharing class SystemLogHelper 
{
    public static void addIntegrationLogRecord(String sourceName, String methodName, String recordId, HttpResponse resp, HttpRequest req , Boolean doInsert , String jsonRequestBody)
    {
        String logMessage = resp.toString();
        String stackTraceMessage = req.toString() + '\n System.HttpResponse Body '  + resp.getbody();
        
        System_Log__c log = new System_Log__c();
        log.Source_Name__c = sourceName;
        log.Method__c = methodName;
        log.Record_Id__c = recordId;
        log.Message__c = logMessage.left(250);
        log.Stack_Trace__c = stackTraceMessage;
        log.Request_Body__c = jsonRequestBody;
        if(doInsert){
            insert log;
        }
    }
}