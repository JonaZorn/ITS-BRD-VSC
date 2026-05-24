import java.util.Arrays;

public class PrimzahlenTest {
    public static void main(String[] args) {

        int[] primzahlen = new int[]{2,3,5,7};
        int[] zahlen = Primzahlen.erstelleZahlen(11);

        for(int j = primzahlen.length-1; j > 0; j--){
            for(int i = 0; i <= zahlen.length-1; i++){
                if(zahlen[i] != 0 && Primzahlen.testeVielfaches(zahlen[i], primzahlen[j])){
                    zahlen[i] = 0;
                }
            } 
        }
        System.out.println(Arrays.toString(zahlen));
    }
}