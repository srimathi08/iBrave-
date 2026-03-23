public class TriggerExecutionGuard {

    private static Set<String> executedKeys = new Set<String>();

    public static Boolean canExecute(String key) {
        if (executedKeys.contains(key)) {
            return false;
        }
        executedKeys.add(key);
        return true;
    }

    @TestVisible
    static void reset() {
        executedKeys.clear();
    }
}