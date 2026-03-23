@isTest
private class QueryOperationHandlerTest {

    // ─────────────────────────────────────────────
    // Helper — insert a test Contact
    // ─────────────────────────────────────────────

    private static Contact createContact(String lastName) {
        Contact c = new Contact(LastName = lastName);
        insert c;
        return c;
    }

    // ─────────────────────────────────────────────
    // getRecords — basic select, all params provided
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_BasicSelect() {
        createContact('TestAlpha');
        createContact('TestBeta');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName LIKE \'Test%\'',
            'LastName ASC',
            10
        );
        Test.stopTest();

        System.assert(results.size() >= 2, 'Should return at least 2 contacts');
    }

    // ─────────────────────────────────────────────
    // getRecords — no whereClause (null)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_NoWhereClause() {
        createContact('NoWhereTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            null,
            'LastName ASC',
            50
        );
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should return records without a WHERE clause');
    }

    // ─────────────────────────────────────────────
    // getRecords — blank whereClause ('')
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_BlankWhereClause() {
        createContact('BlankWhereTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            '',
            'LastName ASC',
            50
        );
        Test.stopTest();

        System.assert(results.size() >= 1, 'Should handle blank WHERE clause gracefully');
    }

    // ─────────────────────────────────────────────
    // getRecords — no orderBy (null)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_NoOrderBy() {
        createContact('NoOrderTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName = \'NoOrderTest\'',
            null,
            10
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return exactly 1 record');
    }

    // ─────────────────────────────────────────────
    // getRecords — blank orderBy ('')
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_BlankOrderBy() {
        createContact('BlankOrderTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName = \'BlankOrderTest\'',
            '',
            10
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should handle blank ORDER BY gracefully');
    }

    // ─────────────────────────────────────────────
    // getRecords — null limitCount (no LIMIT clause)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_NullLimit() {
        createContact('NullLimitTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName = \'NullLimitTest\'',
            'LastName ASC',
            null
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'Should return records without LIMIT clause');
    }

    // ─────────────────────────────────────────────
    // getRecords — zero limitCount (no LIMIT clause)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_ZeroLimit() {
        createContact('ZeroLimitTest');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName = \'ZeroLimitTest\'',
            'LastName ASC',
            0
        );
        Test.stopTest();

        // limitCount = 0 → branch skipped, no LIMIT appended → returns record
        System.assert(results.size() >= 1, 'Zero limit should skip LIMIT clause and return records');
    }

    // ─────────────────────────────────────────────
    // getRecords — limit of 1
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_LimitOne() {
        createContact('LimitOneA');
        createContact('LimitOneB');

        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName LIKE \'LimitOne%\'',
            'LastName ASC',
            1
        );
        Test.stopTest();

        System.assertEquals(1, results.size(), 'LIMIT 1 should return exactly 1 record');
    }

    // ─────────────────────────────────────────────
    // getRecords — returns empty list (no matches)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_NoResults() {
        Test.startTest();
        List<SObject> results = QueryOperationHandler.getRecords(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            'LastName = \'ZZZNOMATCH_XYZ_999\'',
            'LastName ASC',
            10
        );
        Test.stopTest();

        System.assertNotEquals(null, results, 'Should return empty list, not null');
        System.assertEquals(0, results.size(), 'Should return 0 results for no match');
    }

    // ─────────────────────────────────────────────
    // getRecords — invalid object name triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecords_InvalidObject_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QueryOperationHandler.getRecords(
                'NonExistentObject__xyz',
                new List<String>{ 'Id' },
                null,
                null,
                10
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid object name');
    }

    // ─────────────────────────────────────────────
    // getRecordById — record found
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordById_Found() {
        Contact c = createContact('ByIdFound');

        Test.startTest();
        SObject result = QueryOperationHandler.getRecordById(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            c.Id
        );
        Test.stopTest();

        System.assertNotEquals(null, result, 'Should return the matching record');
        System.assertEquals(c.Id, result.get('Id'), 'Returned record Id should match');
    }

    // ─────────────────────────────────────────────
    // getRecordById — record not found (returns null)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordById_NotFound() {
        // Insert then delete to get a valid-format but non-existent Id
        Contact c = new Contact(LastName = 'DeletedForTest');
        insert c;
        Id deletedId = c.Id;
        delete c;

        Test.startTest();
        SObject result = QueryOperationHandler.getRecordById(
            'Contact',
            new List<String>{ 'Id', 'LastName' },
            deletedId
        );
        Test.stopTest();

        System.assertEquals(null, result, 'Should return null when no record matches');
    }

    // ─────────────────────────────────────────────
    // getRecordById — invalid object triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordById_InvalidObject_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QueryOperationHandler.getRecordById(
                'FakeObject__xyz',
                new List<String>{ 'Id' },
                '0010000000000001AAA'
            );
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid object');
    }

    // ─────────────────────────────────────────────
    // getRecordCount — with whereClause
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordCount_WithWhereClause() {
        createContact('CountTestA');
        createContact('CountTestB');
        createContact('CountTestC');

        Test.startTest();
        Integer count = QueryOperationHandler.getRecordCount(
            'Contact',
            'LastName LIKE \'CountTest%\''
        );
        Test.stopTest();

        System.assertEquals(3, count, 'Should count exactly 3 matching contacts');
    }

    // ─────────────────────────────────────────────
    // getRecordCount — no whereClause (null)
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordCount_NoWhereClause() {
        createContact('CountNoWhere');

        Test.startTest();
        Integer count = QueryOperationHandler.getRecordCount('Contact', null);
        Test.stopTest();

        System.assert(count >= 1, 'Should return total count without WHERE clause');
    }

    // ─────────────────────────────────────────────
    // getRecordCount — blank whereClause ('')
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordCount_BlankWhereClause() {
        createContact('CountBlankWhere');

        Test.startTest();
        Integer count = QueryOperationHandler.getRecordCount('Contact', '');
        Test.stopTest();

        System.assert(count >= 1, 'Should handle blank WHERE clause in count query');
    }

    // ─────────────────────────────────────────────
    // getRecordCount — zero matches
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordCount_ZeroMatches() {
        Test.startTest();
        Integer count = QueryOperationHandler.getRecordCount(
            'Contact',
            'LastName = \'ZZZNOMATCH_COUNT_999\''
        );
        Test.stopTest();

        System.assertEquals(0, count, 'Should return 0 when no records match');
    }

    // ─────────────────────────────────────────────
    // getRecordCount — invalid object triggers exception
    // ─────────────────────────────────────────────

    @isTest
    static void testGetRecordCount_InvalidObject_ThrowsException() {
        Boolean exceptionThrown = false;
        Test.startTest();
        try {
            QueryOperationHandler.getRecordCount('FakeObject__xyz', null);
        } catch (AuraHandledException e) {
            exceptionThrown = true;
        }
        Test.stopTest();

        System.assert(exceptionThrown, 'Should throw AuraHandledException for invalid object in count');
    }
}