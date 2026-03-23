public class RelationshipResolver {

    public static Id resolveOrCreate(
        Schema.DescribeFieldResult fieldDesc,
        Object rawValue
    ) {
        if (rawValue == null) return null;

        String value = String.valueOf(rawValue).trim();
        if (value.length() == 15 || value.length() == 18) {
            return (Id) value;
        }

        Schema.SObjectType parentType =
            fieldDesc.getReferenceTo()[0];
        Schema.DescribeSObjectResult d =
            parentType.getDescribe();

        // 1️⃣ External ID
        for (Schema.SObjectField f :
             d.fields.getMap().values()) {

            Schema.DescribeFieldResult fd = f.getDescribe();
            if (fd.isExternalId() && fd.isUnique()) {
                return querySingle(
                    d.getName(),
                    fd.getName(),
                    value
                );
            }
        }

        // 2️⃣ Email
        if (d.fields.getMap().containsKey('Email')) {
            return querySingle(
                d.getName(),
                'Email',
                value
            );
        }

        // 3️⃣ Name
        if (d.fields.getMap().containsKey('Name')) {
            return querySingle(
                d.getName(),
                'Name',
                value
            );
        }

        return null;
    }

    private static Id querySingle(
        String objectName,
        String field,
        String value
    ) {
        String soql =
            'SELECT Id FROM ' + objectName +
            ' WHERE ' + field + ' = :value LIMIT 2';

        List<SObject> res = Database.query(soql);

        if (res.size() == 1) return res[0].Id;
        if (res.size() > 1)
            throw new AuraHandledException(
                'Multiple matches found for ' + value
            );

        return null;
    }
}