public class AmountToWordsUtil {

    private static final String[] units = new String[]{
        '', 'One','Two','Three','Four','Five','Six','Seven','Eight','Nine',
        'Ten','Eleven','Twelve','Thirteen','Fourteen','Fifteen','Sixteen',
        'Seventeen','Eighteen','Nineteen'
    };

    private static final String[] tens = new String[]{
        '','','Twenty','Thirty','Forty','Fifty','Sixty','Seventy','Eighty','Ninety'
    };

    public static String convertAmount(Long amount){

        if(amount == null || amount == 0){
            return 'Zero Only';
        }

        return convert(amount).trim() + ' Only';
    }

    private static String convert(Long n){

        String word='';

        if(n >= 10000000){
            word += convert(n/10000000) + ' Crore ';
            n = Math.mod(n,10000000);
        }

        if(n >= 100000){
            word += convert(n/100000) + ' Lakh ';
            n = Math.mod(n,100000);
        }

        if(n >= 1000){
            word += convert(n/1000) + ' Thousand ';
            n = Math.mod(n,1000);
        }

        if(n >= 100){
            word += convert(n/100) + ' Hundred ';
            n = Math.mod(n,100);
        }

        if(n > 0){

            if(n < 20){
                word += units[(Integer)n];
            }
            else{

                word += tens[(Integer)(n/10)];

                if(Math.mod(n,10) > 0){
                    word += ' ' + units[(Integer)Math.mod(n,10)];
                }
            }
        }

        return word;
    }
}