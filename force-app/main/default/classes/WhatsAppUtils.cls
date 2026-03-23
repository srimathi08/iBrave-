/**
 * @class WhatsAppUtils
 * @desc 
 *   Utility class for integrating with the WhatsApp Business Cloud API (Meta/Facebook).
 *   Handles:
 *   - Sending WhatsApp text messages via HTTP POST
 *   - Downloading media (images or documents) using media ID from webhook payload
 * 
 *   Requires:
 *   - WhatsApp access token stored in `System.Label.WHATSAPPACCESSTOKEN`
 * 
 * @author Afrose Ahamed
 */

public class WhatsAppUtils {
    @future(callout=true)
    public static void sendTextMessage(String messageContent, String toPhone){
        HttpRequest httpReq =new HttpRequest();
        httpReq.setEndPoint('https://graph.facebook.com/v22.0/105666505595426/messages');
        httpReq.setMethod('POST');
        httpReq.setHeader('Content-Type','application/json');
        httpReq.setHeader('Authorization', 'Bearer '+System.label.WHATSAPPACCESSTOKEN);
        /*
        String json=		'{'+
		'    "messaging_product": "whatsapp",    '+
		'    "recipient_type": "individual",'+
		'    "to": "'+toPhone+'",'+
		'    "type": "text",'+
		'    "text": {'+
		'        "preview_url": false,'+
		'        "body": "'+messageContent+'"'+
		'    }'+
		'}';*/
        
        Map<String, Object> payload = new Map<String, Object>{
        'messaging_product' => 'whatsapp',
        'recipient_type' => 'individual',
        'to' => toPhone,
        'type' => 'text',
        'text' => new Map<String, Object>{
            'preview_url' => false,
            'body' => messageContent
        }
    };

    String json = JSON.serialize(payload); // safe encoding

        
        httpReq.setBody(json);
        Http http =new Http();
        try{
        HttpResponse response=http.send(httpreq);
        System.debug('Whats sent request response'+response.getBody());    
        }catch(System.calloutException ex){
            system.debug('CalloutException'+ex.getMessage());
        }catch(exception e){
            system.debug('Exception'+e.getMessage());
        }
    }
    
    public static blob getMedia(string mediaid){
        System.debug('mediaid'+mediaid);
        http httpObj=new Http();
HttpRequest request =new HttpRequest();
request.setEndpoint('https://graph.facebook.com/v22.0/'+mediaid);
request.setMethod('GET');
request.setHeader('Authorization','Bearer '+System.label.WHATSAPPACCESSTOKEN);
Httpresponse response =httpObj.send(request);
System.debug(response.getBody());

Map<String, Object> result = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
String downloadUrl = (String)result.get('url');        
System.debug('Download Url'+downloadUrl);        
Http http = new Http();
HttpRequest requestmedia = new HttpRequest();
requestmedia.setEndpoint(downloadUrl);
requestmedia.setMethod('GET');
requestmedia.setHeader('Authorization', 'Bearer '+System.label.WHATSAPPACCESSTOKEN);
HttpResponse responsemedia = http.send(requestmedia);
System.debug('Download Image Response: ' + responsemedia);
System.debug('Response Body: ' + responsemedia.getBodyAsBlob());        
        return responsemedia.getBodyAsBlob();
    } 
}