public with sharing class LocationService {
    
    /**
     * Get detailed location name with area from coordinates using OpenStreetMap Nominatim API
     * @param latitude Latitude coordinate
     * @param longitude Longitude coordinate
     * @return Map containing detailed location information
     */
    @AuraEnabled
    public static Map<String, Object> getReverseGeocode(Decimal latitude, Decimal longitude) {
        Map<String, Object> result = new Map<String, Object>();
        
        try {
            // Create HTTP request to OpenStreetMap Nominatim API
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            // Enhanced endpoint with higher zoom level for better area details
            String endpoint = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=' 
                + latitude + '&lon=' + longitude + '&zoom=16&addressdetails=1&accept-language=en';
            
            request.setEndpoint(endpoint);
            request.setMethod('GET');
            request.setHeader('User-Agent', 'AttendanceApp/1.0 Salesforce');
            request.setTimeout(30000); // 30 seconds timeout
            
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // Parse the JSON response
                Map<String, Object> responseData = (Map<String, Object>) JSON.deserializeUntyped(response.getBody());
                Map<String, Object> address = (Map<String, Object>) responseData.get('address');
                
                System.debug('Full API Response: ' + responseData);
                System.debug('Address Components: ' + address);
                
                if (address != null) {
                    // Extract detailed location information with enhanced priority
                    String areaName = getLocationValue(address, new List<String>{
                        'neighbourhood', 'suburb', 'quarter', 'district', 'sublocality', 
                        'village', 'hamlet', 'residential', 'commercial', 'industrial'
                    });
                    
                    String cityName = getLocationValue(address, new List<String>{
                        'city', 'town', 'municipality', 'city_district'
                    });
                    
                    String stateName = getLocationValue(address, new List<String>{
                        'state', 'province', 'region', 'administrative_area_level_1'
                    });
                    
                    String countryName = getLocationValue(address, new List<String>{'country'});
                    
                    // Build enhanced location display: "Area, City, State"
                    String displayLocation = '';
                    List<String> locationParts = new List<String>();
                    
                    if (areaName != null && areaName != 'Unknown Area') {
                        locationParts.add(areaName);
                    }
                    
                    if (cityName != null && cityName != 'Unknown Location') {
                        locationParts.add(cityName);
                    }
                    
                    if (stateName != null && stateName != 'Unknown State') {
                        locationParts.add(stateName);
                    }
                    
                    displayLocation = locationParts.size() > 0 ? String.join(locationParts, ', ') : 
                                     latitude + ', ' + longitude;
                    
                    // Build results with enhanced details
                    result.put('success', true);
                    result.put('areaName', areaName != null ? areaName : 'Unknown Area');
                    result.put('cityName', cityName != null ? cityName : 'Unknown Location');
                    result.put('stateName', stateName != null ? stateName : 'Unknown State');
                    result.put('countryName', countryName != null ? countryName : 'Unknown Country');
                    result.put('displayName', displayLocation);
                    
                    // Build full address with all components
                    String fullAddress = buildEnhancedFullAddress(address, areaName, cityName, stateName, countryName);
                    result.put('fullAddress', fullAddress);
                    
                    System.debug('Enhanced Location Result: ' + result);
                    
                } else {
                    throw new CalloutException('No address data found in response');
                }
                
            } else {
                throw new CalloutException('HTTP Error: ' + response.getStatusCode() + ' - ' + response.getStatus());
            }
            
        } catch (Exception e) {
            System.debug('Reverse geocoding error: ' + e.getMessage());
            System.debug('Stack trace: ' + e.getStackTraceString());
            result.put('success', false);
            result.put('error', e.getMessage());
            
            // Enhanced fallback data
            result.put('areaName', 'Unknown Area');
            result.put('cityName', 'Location');
            result.put('stateName', 'Unknown');
            result.put('countryName', 'Unknown');
            result.put('displayName', 'Coordinates: ' + latitude + ', ' + longitude);
            result.put('fullAddress', 'Coordinates: ' + latitude + ', ' + longitude);
        }
        
        return result;
    }
    
    /**
     * Helper method to get location value with fallbacks
     */
    private static String getLocationValue(Map<String, Object> address, List<String> keys) {
        for (String key : keys) {
            if (address.containsKey(key) && address.get(key) != null && String.valueOf(address.get(key)) != '') {
                String value = String.valueOf(address.get(key));
                // Clean up the value
                return value.trim();
            }
        }
        return null;
    }
    
    /**
     * Helper method to build enhanced full address
     */
    private static String buildEnhancedFullAddress(Map<String, Object> address, String areaName, String cityName, String stateName, String countryName) {
        List<String> addressParts = new List<String>();
        
        // Add house number and road
        if (address.containsKey('house_number') && address.get('house_number') != null) {
            addressParts.add(String.valueOf(address.get('house_number')));
        }
        
        if (address.containsKey('road') && address.get('road') != null) {
            addressParts.add(String.valueOf(address.get('road')));
        }
        
        // Add area/neighbourhood
        if (areaName != null && areaName != 'Unknown Area') {
            addressParts.add(areaName);
        }
        
        // Add city
        if (cityName != null && cityName != 'Unknown Location') {
            addressParts.add(cityName);
        }
        
        // Add state
        if (stateName != null && stateName != 'Unknown State') {
            addressParts.add(stateName);
        }
        
        // Add postal code if available
        if (address.containsKey('postcode') && address.get('postcode') != null) {
            addressParts.add(String.valueOf(address.get('postcode')));
        }
        
        // Add country
        if (countryName != null && countryName != 'Unknown Country') {
            addressParts.add(countryName);
        }
        
        return addressParts.size() > 0 ? String.join(addressParts, ', ') : 'Address not available';
    }
}