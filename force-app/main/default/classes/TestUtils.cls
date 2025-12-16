public class TestUtils {
    public static User createUser(Boolean isActive) {
        Profile p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];

        User u = new User(
            ProfileId = p.Id,
            Username = 'test' + Math.random() + '@test.com',
            Email = 'test@test.com',
            LastName = 'User',
            Alias = 'tusr',
            TimeZoneSidKey = 'Asia/Kolkata',
            LocaleSidKey = 'en_US',
            EmailEncodingKey = 'UTF-8',
            LanguageLocaleKey = 'en_US',
            IsActive = isActive
        );
        insert u;
        return u;
    }
}