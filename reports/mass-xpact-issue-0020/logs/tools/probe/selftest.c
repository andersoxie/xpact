#include <stdio.h>
int main(void) { volatile int *p = 0; printf("before\n"); fflush(stdout); return *p; }
