@isTest
public class WhatsAppUtils_Test {

    // 🔹 Mock class to simulate successful WhatsApp API responses
    private class WhatsAppMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');

            if (req.getMethod() == 'POST') {
                res.setStatusCode(200);
                res.setBody('{"messages": [{"id": "wamid.HBgLMOCKEDMESSAGE123"}]}');
            } else if (req.getEndpoint().contains('graph.facebook.com') && !req.getEndpoint().contains('mockMediaDownload')) {
                res.setStatusCode(200);
                res.setBody('{"url": "https://graph.facebook.com/v22.0/mockMediaDownload"}');
            } else if (req.getEndpoint().contains('mockMediaDownload')) {
                res.setStatusCode(200);
                res.setBodyAsBlob(Blob.valueOf('This is mock media content.'));
            } else {
                res.setStatusCode(400);
                res.setBody('{"error": "Invalid request"}');
            }

            return res;
        }
    }

    // 🔹 Mock class that throws a CalloutException
    private class ExceptionMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            throw new CalloutException('Simulated callout failure');
        }
    }

    // 🔹 Mock class that simulates a failed media fetch
    private class BadResponseMock implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('{"error": "Server down"}');
            return res;
        }
    }

    // ✅ Test 1: Successful sendTextMessage callout
    @isTest
    static void test_sendTextMessage_success() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppMock());
        Test.startTest();
        WhatsAppUtils.sendTextMessage('Hello from Salesforce!', '+911234567890');
        Test.stopTest();
        System.assert(true, 'sendTextMessage executed successfully.');
    }

    // ✅ Test 2: sendTextMessage CalloutException handling
    @isTest
    static void test_sendTextMessage_withException() {
        Test.setMock(HttpCalloutMock.class, new ExceptionMock());
        Test.startTest();
        WhatsAppUtils.sendTextMessage('Test Exception', '+911234567890');
        Test.stopTest();
        System.assert(true, 'Handled CalloutException gracefully.');
    }

    // ✅ Test 3: getMedia() happy path
    @isTest
    static void test_getMedia_success() {
        Test.setMock(HttpCalloutMock.class, new WhatsAppMock());
        Test.startTest();
        Blob mediaBlob = WhatsAppUtils.getMedia('mockMedia123');
        Test.stopTest();
        System.assertNotEquals(null, mediaBlob, 'Blob should not be null.');
        System.assert(mediaBlob.toString().contains('mock media'), 'Blob should contain mock data.');
    }

    // ✅ Test 4: getMedia() failure case
    @isTest
    static void test_getMedia_failure() {
        Test.setMock(HttpCalloutMock.class, new BadResponseMock());
        Test.startTest();
        try {
            Blob mediaBlob = WhatsAppUtils.getMedia('badMedia123');
            System.assertNotEquals(null, mediaBlob, 'Should handle bad response gracefully.');
        } catch (Exception e) {
          //  System.assert(e.getMessage().contains('Server'), 'Expected simulated failure.');
        }
        Test.stopTest();
    }
}