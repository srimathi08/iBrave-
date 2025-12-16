@isTest
public class LocationServiceTest {

    // -------------------------------------------------------
    // Mock Class for Successful API Response
    // -------------------------------------------------------
    private class ReverseGeoMockSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {

            // Sample OpenStreetMap Nominatim API JSON response
            String responseBody = '{' +
                '"place_id": 12345,' +
                '"address": {' +
                '   "neighbourhood": "T Nagar",' +
                '   "city": "Chennai",' +
                '   "state": "Tamil Nadu",' +
                '   "country": "India",' +
                '   "postcode": "600017",' +
                '   "road": "North Usman Road",' +
                '   "house_number": "45"' +
                '}' +
            '}';

            HttpResponse res = new HttpResponse();
            res.setStatusCode(200);
            res.setBody(responseBody);
            return res;
        }
    }

    // -------------------------------------------------------
    // Mock Class for Error Response
    // -------------------------------------------------------
    private class ReverseGeoMockError implements HttpCalloutMock {
        public HttpResponse respond(HttpRequest req) {
            HttpResponse res = new HttpResponse();
            res.setStatusCode(500);
            res.setBody('Internal Server Error');
            return res;
        }
    }

    // -------------------------------------------------------
    // TEST: Successful Reverse Geocode
    // -------------------------------------------------------
    @isTest
    static void testReverseGeocodeSuccess() {

        Test.setMock(HttpCalloutMock.class, new ReverseGeoMockSuccess());

        Test.startTest();
        Map<String, Object> result = LocationService.getReverseGeocode(13.0827, 80.2707);
        Test.stopTest();

        System.debug('RESULT => ' + result);

        System.assertEquals(true, result.get('success'), 'Success flag should be true');
        System.assertEquals('T Nagar', result.get('areaName'));
        System.assertEquals('Chennai', result.get('cityName'));
        System.assertEquals('Tamil Nadu', result.get('stateName'));
        System.assertEquals('India', result.get('countryName'));

        System.assert(result.containsKey('displayName'), 'Display name missing');
        System.assert(result.containsKey('fullAddress'), 'Full address missing');

        System.assert(result.get('fullAddress').toString().contains('North Usman Road'),
            'Full address should contain road');
    }

    // -------------------------------------------------------
    // TEST: Error Handling / Fallback Branch
    // -------------------------------------------------------
    @isTest
    static void testReverseGeocodeError() {

        Test.setMock(HttpCalloutMock.class, new ReverseGeoMockError());

        Test.startTest();
        Map<String, Object> result = LocationService.getReverseGeocode(0, 0);
        Test.stopTest();

        System.debug('ERROR RESULT => ' + result);

        System.assertEquals(false, result.get('success'), 'Success flag should be false');
        System.assert(result.get('displayName').toString().contains('Coordinates'),
            'Fallback display must show coordinates');
        System.assertEquals('Unknown Area', result.get('areaName'));
        System.assertEquals('Location', result.get('cityName'));
        System.assertEquals('Unknown', result.get('stateName'));
        System.assertEquals('Unknown', result.get('countryName'));
    }
}