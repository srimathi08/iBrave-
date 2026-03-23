public class FieldResolver {
	public class FieldInfo {
        public String apiName;
        public String label;
        public String type;
        public List<String> values;
        public String controllingField;
        public Map<String, List<String>> dependentValues;
    }

    public static List<FieldInfo> resolve(String objectApiName,String userMessage){
		Schema.SObjectType objType =Schema.getGlobalDescribe().get(objectApiName);
        Schema.DescribeSObjectResult d = objType.getDescribe();
         Map<String, Schema.SObjectField> fieldMap =d.fields.getMap();
          List<FieldInfo> result = new List<FieldInfo>();
		List<String> fieldList = new List<String>();
		 for (String fieldName : fieldMap.keySet()) {
		 Schema.DescribeFieldResult field = fieldMap.get(fieldName).getDescribe();
            
		  if (field.isAccessible() && field.isCreateable() && !field.isCalculated() && !field.isAutoNumber() ) {
         	 FieldInfo info = new FieldInfo();
            info.apiName = field.getName();
            info.label   = field.getLabel();
            info.type    = String.valueOf(field.getType());

            // PICKLIST
            if (field.getType() == Schema.DisplayType.PICKLIST ||
                field.getType() == Schema.DisplayType.MULTIPICKLIST) {

                info.values = new List<String>();
                for (Schema.PicklistEntry p : field.getPicklistValues()) {
                    if (p.isActive()) {
                        info.values.add(p.getValue());
                    }
                }
            }

            result.add(info);
             
          }      
		}
							
		return result; 
    }	
}