#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct password {
    char str1[8];
    char str2[8];
    int pass;
} password_t;

int main(int argc, char *argv[]) {
    password_t check_password;
    strncpy(check_password.str1, "fuzzball", 8);

    check_password.pass = 0;

    printf("Enter the password:\n");
    gets(check_password.str2);
    printf("Pass is %d\n", check_password.pass);

    if (strncmp(check_password.str1, check_password.str2, 8) == 0)
        check_password.pass = 1;
    
    if (check_password.pass == 1)
        printf("Password is correct! \n");
    else
        printf("Incorrect password %s %s \n", check_password.str1,
               check_password.str2);
}