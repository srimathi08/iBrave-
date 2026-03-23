public class RequiredFieldResolver {

    public static List<String> getMissing(
        String objectApi,
        Map<String,Object> collected
    ) {
        List<String> missing = new List<String>();

        Schema.DescribeSObjectResult d =
            Schema.getGlobalDescribe().get(objectApi).getDescribe();

        for (Schema.SObjectField f : d.fields.getMap().values()) {
            Schema.DescribeFieldResult fd = f.getDescribe();

            if (!fd.isCreateable()) continue;
            if (fd.isNillable()) continue;
            if (fd.isAutoNumber()) continue;
            if (fd.isDefaultedOnCreate()) continue;

            if (!collected.containsKey(fd.getName())) {
                missing.add(fd.getName());
            }
        }
        return missing;
    }
}