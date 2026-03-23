@isTest
public class AmountToWordsUtilTest {

    @isTest
    static void testConvertAmount() {
        
        // Test Case 1: Basic amount
        Long amount1 = 400000;
        String result1 = AmountToWordsUtil.convertAmount(amount1);
        System.assert(result1.contains('Four Lakh'), 'Expected Four Lakh');

        // Test Case 2: Thousand value
        Long amount2 = 25000;
        String result2 = AmountToWordsUtil.convertAmount(amount2);
        System.assert(result2.contains('Twenty Five Thousand'), 'Expected Twenty Five Thousand');

        // Test Case 3: Crore value
        Long amount3 = 10000000;
        String result3 = AmountToWordsUtil.convertAmount(amount3);
        System.assert(result3.contains('Crore'), 'Expected Crore');

        // Test Case 4: Zero value
        Long amount4 = 0;
        String result4 = AmountToWordsUtil.convertAmount(amount4);
        System.assertEquals('Zero Only', result4);

        // Test Case 5: Null value
        String result5 = AmountToWordsUtil.convertAmount(null);
        System.assertEquals('Zero Only', result5);
    }
}