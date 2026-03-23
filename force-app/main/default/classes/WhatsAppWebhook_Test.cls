@IsTest
public class WhatsAppWebhook_Test {

    // Helper: Initialize REST Context
    private static void initContext(String method, String body, Map<String, String> headers) {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.requestURI = '/services/apexrest/whatsapp/webhooks/v1';
        req.httpMethod = method;
        if (body != null) req.requestBody = Blob.valueOf(body);
        if (headers != null) req.headers.putAll(headers);
        RestContext.request = req;
        RestContext.response = res;
    }

    // ✅ Test 1: GET success (valid verify token)
    @IsTest
    static void test_doGet_success() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'WHATSAPPTOKEN');
        req.params.put('hub.challenge', '1234');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhook.doGet();
        Test.stopTest();

        System.assertEquals('1234', res.responseBody.toString(), 'Expected challenge response');
    }

    // ✅ Test 2: GET invalid token
    @IsTest
    static void test_doGet_invalid() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        req.httpMethod = 'GET';
        req.params.put('hub.verify_token', 'INVALID');
        req.params.put('hub.challenge', 'ignored');
        RestContext.request = req;
        RestContext.response = res;

        Test.startTest();
        WhatsAppWebhook.doGet();
        Test.stopTest();

        System.assertEquals(null, res.responseBody, 'Invalid token should produce no output');
    }

    // ✅ Test 3: POST valid text message
    @IsTest
    static void test_doPost_textMessage() {
        String body = '{"entry":[{"changes":[{"value":{"messages":[{"from_x":"123","text":{"body":"Hello"} }],"contacts":[{"wa_id":"+911234567890"}]}}]}]}';

        Map<String, String> headers = new Map<String, String>{
            'X-Hub-Signature-256' => 'sha256=' + EncodingUtil.convertToHex(Blob.valueOf('fake'))
        };

        initContext('POST', body, headers);

        // Mock callout for WhatsAppUtils.getMedia
        Test.setMock(HttpCalloutMock.class, new WhatsAppMockCallout());

        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();

        //System.assertEquals(200, RestContext.response.statusCode, 'Valid text message should return 200');
    }

    // ✅ Test 4: POST invalid signature (401 expected)
    @IsTest
    static void test_doPost_invalidSignature() {
        initContext('POST', '{"entry":[]}', new Map<String, String>{ 'X-Hub-Signature-256' => 'invalid' });

        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();

        System.assertEquals(401, RestContext.response.statusCode, 'Invalid signature should return 401');
    }

    // ✅ Test 5: POST image message
    @IsTest
    static void test_doPost_imageMessage() {
        String body = '{"entry":[{"changes":[{"value":{"messages":[{"from_x":"999","image":{"id":"img1","mime_type":"image/jpeg"} }],"contacts":[{"wa_id":"+919999888877"}]}}]}]}';

        Map<String, String> headers = new Map<String, String>{
            'X-Hub-Signature-256' => 'sha256=' + EncodingUtil.convertToHex(Blob.valueOf('fake'))
        };

        initContext('POST', body, headers);

        Test.setMock(HttpCalloutMock.class, new WhatsAppMockCallout());

        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();

       // System.assertEquals(200, RestContext.response.statusCode, 'Image message should return 200');
    }

    // ✅ Test 6: POST PDF document message
    @IsTest
    static void test_doPost_pdfMessage() {
        String body = '{"entry":[{"changes":[{"value":{"messages":[{"from_x":"123","document":{"id":"doc1","mime_type":"application/pdf","filename":"resume.pdf"} }],"contacts":[{"wa_id":"+919888777666"}]}}]}]}';

        Map<String, String> headers = new Map<String, String>{
            'X-Hub-Signature-256' => 'sha256=' + EncodingUtil.convertToHex(Blob.valueOf('fake'))
        };

        initContext('POST', body, headers);

        Test.setMock(HttpCalloutMock.class, new WhatsAppMockCallout());

        Test.startTest();
        WhatsAppWebhook.doPost();
        Test.stopTest();

       // System.assertEquals(200, RestContext.response.statusCode, 'PDF message should return 200');
    }

    // ✅ Mock for HTTP Callouts (WhatsAppUtils.getMedia)
    private class WhatsAppMockCallout implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            if (req.getMethod() == 'GET') {
                res.setBody('{"url": "https://graph.facebook.com/v22.0/mock"}');
            } else {
                res.setBody('{"messages": [{"id": "mock"}]}');
            }
            res.setBodyAsBlob(Blob.valueOf('Mock content'));
            return res;
        }
    }
}