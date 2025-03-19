#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int main(int argc, char *argv[]) {
    char str1[6] = "hello";
    char str2[6];

    gets(str2);

    /* hint: strncmp(str1,str2,c) compares first "c" characters of
      strings str1 and str2 */

    if (strncmp(str1, str2, 6) == 0) {
        printf("Both strings are equal to %s \n", str1);
    } else
        printf("Strings are not equal \n");
}