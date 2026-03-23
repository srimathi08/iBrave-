public class CreateHandler {

    public static ChatResponse handle(String objectApiName, String userMessage) {

        // 1️⃣ Get schema-safe fields
        List<FieldResolver.FieldInfo> fieldSchema =FieldResolver.resolve(objectApiName, userMessage);

        if (fieldSchema.isEmpty()) {
            System.debug('No creatable fields');
            return new ChatResponse(false, 'No creatable fields found.');
        }

        // 2️⃣ AI field extraction (LABEL → VALUE)
        Map<String, Object> aiFields =FieldMappingAI.getMap(userMessage, fieldSchema);

        if (aiFields == null || aiFields.isEmpty()) {
            return new ChatResponse(false, 'No field values detected.');
        }

        // 3️⃣ Resolve LABEL → API NAME
        Map<String, Object> resolvedFields =
            SchemaAwareFieldResolver.resolve(
                objectApiName,
                aiFields
            );
        
        if (resolvedFields.isEmpty()) {
            return new ChatResponse(false, 'No valid fields resolved.');
        }

        // 4️⃣ Check OBJECT CREATE permission
        Schema.DescribeSObjectResult objDescribe =
            Schema.getGlobalDescribe()
                  .get(objectApiName)
                  .getDescribe();

        if (!objDescribe.isCreateable()) {
            throw new SecurityException(
                'No create permission for ' + objDescribe.getLabel()
            );
        }

        // 5️⃣ Create dynamic SObject
        SObject record =
            Schema.getGlobalDescribe()
                  .get(objectApiName)
                  .newSObject();
			
       Map<String, Schema.SObjectField> fieldMap =
            objDescribe.fields.getMap(); 
        
        // ❗ putAll is NOT supported on SObject
        for (String fieldApi : resolvedFields.keySet()) {
            //record.put(fieldApi, resolvedFields.get(fieldApi));
            if (!fieldMap.containsKey(fieldApi)) {
                continue;
            }

            Schema.DescribeFieldResult fieldDesc =
                fieldMap.get(fieldApi).getDescribe();

            Object value = resolvedFields.get(fieldApi);
		     // 🔗 REFERENCE FIELD (Lookup / Master-Detail)
            if (fieldDesc.getType() == Schema.DisplayType.REFERENCE) {
		
                Id parentId =
                    RelationshipResolver.resolveOrCreate(
                        fieldDesc,
                        value
                    );

                if (parentId != null) {
                    record.put(fieldApi, parentId);
                }

            }
            // 🔹 NORMAL FIELD
            else {
                record.put(fieldApi, value);
            }
           
        }

        // 6️⃣ Enforce FIELD-LEVEL SECURITY (FINAL GATE)
        record =
            Security.stripInaccessible(
                AccessType.CREATABLE,
                new List<SObject>{ record }
            ).getRecords()[0];

        // 7️⃣ Insert
        insert record;

        ChatResponse res = new ChatResponse(
            true,
            '🎉 ' + objectApiName + ' created successfully!'
        );
        res.data = new Map<String, Object>{
            'id' => record.Id,
            'object' => objectApiName,
            'fields' => resolvedFields
        };
        return res;
        
    }
}