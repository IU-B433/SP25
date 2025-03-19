#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void secret_function() {
    printf(
        "\n*************************\nProgram failed "
        "successfully!\n************************\n\n");
}

int get_from_user() {
    char input_number[8];
    printf("We are now in the get_from_user function ... \n");
    printf("Enter your group number: ");
    gets(input_number);
    return atoi(input_number);
}

int main(int argc, char **argv[]) {
    printf("We are now in the main function ... \n");
    int group_number = get_from_user(group_number);
    printf("Your group number is %d\n", group_number);

    return 0;
}