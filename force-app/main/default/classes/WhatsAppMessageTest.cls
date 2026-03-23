@isTest
public class WhatsAppMessageTest {

    @isTest
    static void testDeserializeAndSerialize() {
        // Sample WhatsApp webhook JSON
        String jsonString = '{' +
            '"entry": [' +
            '  {' +
            '    "id": "109524531871388",' +
            '    "changes": [' +
            '      {' +
            '        "field": "messages",' +
            '        "value": {' +
            '          "messaging_product": "whatsapp",' +
            '          "metadata": {' +
            '            "display_phone_number": "15550610026",' +
            '            "phone_number_id": "105666505595426"' +
            '          },' +
            '          "contacts": [' +
            '            {' +
            '              "wa_id": "918925262167",' +
            '              "profile": {"name": "Test User"}' +
            '            }' +
            '          ],' +
            '          "messages": [' +
            '            {' +
            '              "from_x": "918925262167",' +
            '              "id": "wamid.TEST123",' +
            '              "timestamp": "1750749574",' +
            '              "typex": "document",' +
            '              "document": {' +
            '                "filename": "Resume.pdf",' +
            '                "mime_type": "application/pdf",' +
            '                "sha256": "ABC123",' +
            '                "id": "684333427759355"' +
            '              },' +
            '              "text": {"body": "job or candidate"},' +
            '              "image": {' +
            '                "filename": "Resume.jpeg",' +
            '                "mime_type": "application/jpeg",' +
            '                "sha256": "XYZ456",' +
            '                "id": "111222333"' +
            '              }' +
            '            }' +
            '          ]' +
            '        }' +
            '      }' +
            '    ]' +
            '  }' +
            ']' +
        '}';

        // Act: Deserialize into your WhatsAppMessage Apex class
        WhatsAppMessage messageObj = (WhatsAppMessage) JSON.deserialize(jsonString, WhatsAppMessage.class);

        // Assert: verify key fields were mapped correctly
        System.assertNotEquals(null, messageObj, 'Deserialization should produce an object');
        System.assertEquals('109524531871388', messageObj.entry[0].id);
        System.assertEquals('messages', messageObj.entry[0].changes[0].field);
        System.assertEquals('whatsapp', messageObj.entry[0].changes[0].value.messaging_product);
        System.assertEquals('15550610026', messageObj.entry[0].changes[0].value.metadata.display_phone_number);
        System.assertEquals('918925262167', messageObj.entry[0].changes[0].value.contacts[0].wa_id);
        System.assertEquals('Test User', messageObj.entry[0].changes[0].value.contacts[0].profile.name);

        WhatsAppMessage.messages msg = messageObj.entry[0].changes[0].value.messages[0];
        System.assertEquals('918925262167', msg.from_x);
        System.assertEquals('wamid.TEST123', msg.id);
        System.assertEquals('document', msg.typex);
        System.assertEquals('Resume.pdf', msg.document.filename);
        System.assertEquals('application/jpeg', msg.image.mime_type);
        System.assertEquals('job or candidate', msg.text.body);

        // Act: Serialize back to JSON
        String backToJson = JSON.serialize(messageObj);
        System.assert(backToJson.contains('Resume.pdf'), 'Serialized JSON should contain document filename');
        System.assert(backToJson.contains('job or candidate'), 'Serialized JSON should contain text body');
    }
}