/**
 * @class WhatsAppMessage
 * @desc 
 *   Wrapper class used to deserialize incoming JSON payloads from WhatsApp Business API webhook.
 *   Represents the structure of messages received including document, image, and text types.
 * 
 * @structure 
 *   Matches the standard payload format from Meta's WhatsApp Cloud API for webhook events.
 * 
 * @author Afrose Ahamed
 */
public class WhatsAppMessage {

	public entry[] entry;
	public class entry {
		public String id;	//109524531871388
		public changes[] changes;
	} 
	 public class changes {
		public value value;
		public String field;	//messages
	}
	 public class value {
		public String messaging_product;	//whatsapp
		public metadata metadata;
		public contacts[] contacts;
		public messages[] messages;
	}
	 public class metadata {
		public String display_phone_number;	//15550610026
		public String phone_number_id;	//105666505595426
	}
	public class contacts {
		public profile profile;
		public String wa_id;	//918925262167
	}
	public class profile {
		public String name;	//.
	}
	public class messages {
		public String from_x;	//918925262167
		public String id;	//wamid.HBgMOTE4OTI1MjYyMTY3FQIAEhggMDI3NzREMDI2MjhGM0VCRjI0NThBNzhCRTU0MjZCRDEA
		public String timestamp;	//1750749574
		public String typex;	//document
		public document document;
        public text text;
        public image image;
        public audio audio;
	}
	public class document {
		public String filename;	//Resume.pdf
		public String mime_type;	//application/pdf
		public String sha256;	//1BTggu64UoXdVfqZFUVTE9Fgwbhnfq6AuJa11IcYu4A=
		public String id;	//684333427759355
	}
    
   public class image {
		public String filename;	//Resume.jpeg
		public String mime_type;	//application/jpeg
		public String sha256;	//1BTggu64UoXdVfqZFUVTE9Fgwbhnfq6AuJa11IcYu4A=
		public String id;	//684333427759355
	} 
  public class audio {
		public String filename;	
		public String mime_type;	
		public String sha256;	
		public String id;
	}  
    public class text {
        public String body; //job or candidate
    }
    
	
}