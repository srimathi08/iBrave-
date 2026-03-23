public class SchemaAwareFieldResolver {

    public static Map<String, Object> resolve(
        String objectApiName,
        Map<String, Object> aiFields
    ) {
        Map<String, Object> resolved = new Map<String, Object>();

        Schema.DescribeSObjectResult objDescribe =
            Schema.getGlobalDescribe()
                  .get(objectApiName)
                  .getDescribe();

        Map<String, Schema.SObjectField> fieldMap =
            objDescribe.fields.getMap();

        for (String aiLabel : aiFields.keySet()) {

            String aiNorm = normalize(aiLabel);

            for (Schema.SObjectField f : fieldMap.values()) {

                Schema.DescribeFieldResult fd = f.getDescribe();

                // 1️⃣ Non-reference fields (simple)
                if (fd.getType() != Schema.DisplayType.REFERENCE) {

                    if (normalize(fd.getLabel()) == aiNorm ||
                        normalize(fd.getName())  == aiNorm) {

                        resolved.put(fd.getName(), aiFields.get(aiLabel));
                        break;
                    }
                }

                // 2️⃣ 🔗 Reference fields (GENERIC LOGIC)
                else {
                    // Field-level matches
                    if (normalize(fd.getName()) == aiNorm ||
                        normalize(fd.getLabel()) == aiNorm) {

                        resolved.put(fd.getName(), aiFields.get(aiLabel));
                        break;
                    }

                    // Parent object matches
                    for (Schema.SObjectType ref :
                         fd.getReferenceTo()) {

                        Schema.DescribeSObjectResult parentDesc =
                            ref.getDescribe();

                        String parentApi =
                            normalize(parentDesc.getName());

                        String parentLabel =
                            normalize(parentDesc.getLabel());

                        // Match: Project / Invoice / Account
                        if (aiNorm == parentApi ||
                            aiNorm == parentLabel ||
                            aiNorm == parentLabel + 'name' ||
                            aiNorm == parentLabel + 'id') {

                            resolved.put(
                                fd.getName(),
                                aiFields.get(aiLabel)
                            );
                            break;
                        }
                    }
                }
            }
        }

        return resolved;
    }

    private static String normalize(String s) {
        return s == null
            ? ''
            : s.toLowerCase()
                 .replaceAll('__c', '')
                 .replaceAll('[^a-z]', '');
    }
}