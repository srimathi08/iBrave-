public class UtilityClass {
    public static void createElog(exception e){
        Error_Log__c elog =new Error_Log__c();
       // elog.Class_Name__c=cName;
       // elog.Method_Name__c=mName;
        elog.Error_Message__c=e.getMessage();
        elog.Stack_Trace__c=e.getStackTraceString();
        insert elog;
    }
}