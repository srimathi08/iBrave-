@IsTest
public class ProcessQueuedPrompts_DataSetup {
    public static List<Id> createTestServices(Integer count) {
        List<Service__c> services = new List<Service__c>();
        for (Integer i = 0; i < count; i++) {
            services.add(new Service__c(
                Name = 'Service_' + i,
                Whatsapp__c = true,
                WhatsappFrom__c = '+91987654321' + i
            ));
        }
        insert services;

        // ✅ Return the Ids of inserted records
        List<Id> serviceIds = new List<Id>();
        for (Service__c svc : services) {
            serviceIds.add(svc.Id);
        }
        return serviceIds;
    }
}