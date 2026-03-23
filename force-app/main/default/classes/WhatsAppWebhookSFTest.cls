/**
 * @class WhatsAppWebhookSFTest
 * @desc  Test class for WhatsAppWebhookSF REST endpoint.
 *        Covers GET (verify token + HTML fallback) and POST (valid/invalid payloads).
 */
@isTest
private class WhatsAppWebhookSFTest {

    // ─── Helpers ────────────────────────────────────────────────────────────

    private static void setupRestContext(String method, String body, Map<String,String> params) {
        RestRequest req = new RestRequest();
        req.requestURI  = '/services/apexrest/whatsapp/webhook/v1/';
        req.httpMethod  = method;
        req.headers.put('Content-Type', 'application/json');
        if (body   != null) req.requestBody = Blob.valueOf(body);
        if (params != null) for (String k : params.keySet()) req.addParameter(k, params.get(k));
        RestContext.request  = req;
        RestContext.response = new RestResponse();
    }

    // ─── doGet Tests ────────────────────────────────────────────────────────

    @isTest
    static void testDoGet_WebhookVerification() {
        Map<String,String> params = new Map<String,String>{
            'hub.verify_token' => System.Label.WHATSAPP_VERIFY_TOKEN,
            'hub.challenge'    => 'challenge_abc123'
        };
        setupRestContext('GET', null, params);

        Test.startTest();
        WhatsAppWebhookSF.doGet();
        Test.stopTest();

        Assert.areEqual('challenge_abc123', RestContext.response.responseBody.toString(),
            'Challenge should be echoed back for valid verify token');
    }

    @isTest
    static void testDoGet_EmptyParams_ReturnsHtml() {
        setupRestContext('GET', null, new Map<String,String>());

        Test.startTest();
        WhatsAppWebhookSF.doGet();
        Test.stopTest();

        String body = RestContext.response.responseBody.toString();
        Assert.isTrue(body.contains('WhatsApp HRMS Webhook is Active'),
            'HTML health-check page should be returned for empty GET');
    }

    // ─── doPost Tests ───────────────────────────────────────────────────────

    @isTest
    static void testDoPost_ValidTextMessage_Returns200() {
        // WhatsApp sends "from" and "type" — our webhook sanitizes to from_x / typex
        String whatsappPayload =
            '{"entry":[{"changes":[{"value":{"messages":[{"from":"911234567890",' +
            '"type":"text","text":{"body":"Check in"}}]}}]}]}';

        setupRestContext('POST', whatsappPayload, new Map<String,String>());
        RestContext.request.headers.put('X-Hub-Signature-256', 'sha256=invalidsig');

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode,
            'Status should be 200 even with invalid signature (bypass is enabled)');
        Assert.areEqual('{"status":"received"}', RestContext.response.responseBody.toString());
    }

    @isTest
    static void testDoPost_MultipleMessages_Returns200() {
        String payload =
            '{"entry":[{"changes":[{"value":{"messages":[' +
            '{"from":"91111","type":"text","text":{"body":"Leave balance"}},' +
            '{"from":"91222","type":"text","text":{"body":"Check out"}}' +
            ']}}]}]}';

        setupRestContext('POST', payload, new Map<String,String>());
        RestContext.request.headers.put('X-Hub-Signature-256', 'sha256=invalidsig');

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @isTest
    static void testDoPost_InvalidJson_ErrorCaughtInternally() {
        setupRestContext('POST', 'NOT_VALID_JSON_AT_ALL', new Map<String,String>());
        RestContext.request.headers.put('X-Hub-Signature-256', 'sha256=invalidsig');

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        // Error is caught internally — endpoint still returns 200 with received status
        Assert.areEqual(200, RestContext.response.statusCode,
            'Endpoint must always return 200 to Meta even on parse errors');
    }

    @isTest
    static void testDoPost_EmptyEntry_NoException() {
        String payload = '{"entry":[]}';
        setupRestContext('POST', payload, new Map<String,String>());

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @isTest
    static void testDoPost_NullMessages_NoException() {
        String payload = '{"entry":[{"changes":[{"value":{}}]}]}';
        setupRestContext('POST', payload, new Map<String,String>());

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        Assert.areEqual(200, RestContext.response.statusCode);
    }

    @isTest
    static void testSignatureValidation_Invalid() {
        // Even with invalid signature, the bypass (if true) processes the message
        String payload = '{"entry":[{"changes":[{"value":{"messages":[{"from":"911","type":"text","text":{"body":"hi"}}]}}]}]}';
        setupRestContext('POST', payload, new Map<String,String>());
        RestContext.request.headers.put('X-Hub-Signature-256', 'sha256=wronghash');

        Test.startTest();
        WhatsAppWebhookSF.doPost();
        Test.stopTest();

        // Bypass active — still processes
        Assert.areEqual(200, RestContext.response.statusCode);
    }
}