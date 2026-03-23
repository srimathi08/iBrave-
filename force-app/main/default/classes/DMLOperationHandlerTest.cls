@isTest
private class DMLOperationHandlerTest {

    // ─────────────────────────────────────────────
    // insertRecords — all succeed
    // ─────────────────────────────────────────────

    @isTest
    static void testInsertRecords_AllSuccess() {
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'InsertA'),
            new Contact(LastName = 'InsertB'),
            new Contact(LastName = 'InsertC')
        };

        Test.startTest();
        List<SObject> results = DMLOperationHandler.insertRecords(contacts);
        Test.stopTest();

        System.assertEquals(3, results.size(), 'All 3 contacts should be inserted successfully');
        for (SObject s : results) {
            System.assertNotEquals(null, s.get('Id'), 'Each inserted record should have an Id');
        }
    }

    // ─────────────────────────────────────────────
    // insertRecords — partial success (one invalid record)
    // Contact without LastName triggers a field-level failure
    // ─────────────────────────────────────────────

    @isTest
    static void testInsertRecords_PartialSuccess() {
        Contact validContact   = new Contact(LastName = 'ValidPartial');
        Contact invalidContact = new Contact(); // missing required LastName

        Test.startTest();
        List<SObject> results = DMLOperationHandler.insertRecords(
            new List<SObject>{ validContact, invalidContact }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only 1 of 2 records should succeed');
    }

    // ─────────────────────────────────────────────
    // insertRecords — empty list
    // ─────────────────────────────────────────────

    @isTest
    static void testInsertRecords_EmptyList() {
        Test.startTest();
        List<SObject> results = DMLOperationHandler.insertRecords(new List<SObject>());
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Empty input should return empty result');
    }

    // ─────────────────────────────────────────────
    // insertRecords — catch block: passing null triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testInsertRecords_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            // Passing null causes a NullPointerException inside Database.insert
            DMLOperationHandler.insertRecords(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown when null is passed');
    }

    // ─────────────────────────────────────────────
    // updateRecords — all succeed
    // ─────────────────────────────────────────────

    @isTest
    static void testUpdateRecords_AllSuccess() {
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'UpdateA'),
            new Contact(LastName = 'UpdateB')
        };
        insert contacts;

        contacts[0].LastName = 'UpdateA_Modified';
        contacts[1].LastName = 'UpdateB_Modified';

        Test.startTest();
        List<SObject> results = DMLOperationHandler.updateRecords(contacts);
        Test.stopTest();

        System.assertEquals(2, results.size(), 'Both contacts should update successfully');
        List<Contact> updated = [SELECT LastName FROM Contact WHERE Id IN :contacts];
        Set<String> names = new Set<String>();
        for (Contact c : updated) { names.add(c.LastName); }
        System.assert(names.contains('UpdateA_Modified'), 'First contact should be updated');
        System.assert(names.contains('UpdateB_Modified'), 'Second contact should be updated');
    }

    // ─────────────────────────────────────────────
    // updateRecords — partial success (one record without Id fails)
    // ─────────────────────────────────────────────

    @isTest
    static void testUpdateRecords_PartialSuccess() {
        Contact validContact = new Contact(LastName = 'PartialUpdateValid');
        insert validContact;
        validContact.LastName = 'PartialUpdateValid_Modified';

        // No Id — will fail on update
        Contact noIdContact = new Contact(LastName = 'NoId');

        Test.startTest();
        List<SObject> results = DMLOperationHandler.updateRecords(
            new List<SObject>{ validContact, noIdContact }
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Only the record with a valid Id should succeed');
    }

    // ─────────────────────────────────────────────
    // updateRecords — empty list
    // ─────────────────────────────────────────────

    @isTest
    static void testUpdateRecords_EmptyList() {
        Test.startTest();
        List<SObject> results = DMLOperationHandler.updateRecords(new List<SObject>());
        Test.stopTest();

        System.assertNotEquals(null, results, 'Result should not be null');
        System.assertEquals(0, results.size(), 'Empty input should return empty result');
    }

    // ─────────────────────────────────────────────
    // updateRecords — catch block: passing null triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testUpdateRecords_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DMLOperationHandler.updateRecords(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown when null is passed');
    }

    // ─────────────────────────────────────────────
    // deleteRecords — all succeed
    // ─────────────────────────────────────────────

    @isTest
    static void testDeleteRecords_AllSuccess() {
        List<Contact> contacts = new List<Contact>{
            new Contact(LastName = 'DeleteA'),
            new Contact(LastName = 'DeleteB')
        };
        insert contacts;

        Test.startTest();
        DMLOperationHandler.deleteRecords(contacts);
        Test.stopTest();

        List<Contact> remaining = [SELECT Id FROM Contact WHERE Id IN :contacts];
        System.assertEquals(0, remaining.size(), 'All contacts should be deleted');
    }

    // ─────────────────────────────────────────────
    // deleteRecords — empty list (no-op)
    // ─────────────────────────────────────────────

    @isTest
    static void testDeleteRecords_EmptyList() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DMLOperationHandler.deleteRecords(new List<SObject>());
        } catch (Exception e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Empty list delete should not throw an exception');
    }

    // ─────────────────────────────────────────────
    // deleteRecords — partial success (one already deleted)
    // ─────────────────────────────────────────────

    @isTest
    static void testDeleteRecords_PartialSuccess() {
        Contact c1 = new Contact(LastName = 'PartialDeleteA');
        Contact c2 = new Contact(LastName = 'PartialDeleteB');
        insert new List<Contact>{ c1, c2 };
        delete c2; // pre-delete c2 so it fails silently with allOrNone=false

        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DMLOperationHandler.deleteRecords(new List<SObject>{ c1, c2 });
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(!exceptionThrown, 'Partial delete should not throw with allOrNone=false');
        List<Contact> remaining = [SELECT Id FROM Contact WHERE Id = :c1.Id];
        System.assertEquals(0, remaining.size(), 'c1 should be successfully deleted');
    }

    // ─────────────────────────────────────────────
    // deleteRecords — catch block: passing null triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testDeleteRecords_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            DMLOperationHandler.deleteRecords(null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'AuraHandledException should be thrown when null is passed');
    }
}