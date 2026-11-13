/* wselftest.c: checks watch.c. Writes 0x02 then 0x01 at the address in a fresh 32 MB block whose low 24 bits are 38c9be. */
#include <windows.h>
#include <stdio.h>
int main(void) {
  unsigned char *b = VirtualAlloc(NULL, 32u << 20, MEM_COMMIT | MEM_RESERVE, PAGE_READWRITE);
  unsigned long long a = ((unsigned long long)b & ~0xffffffull) | 0x38c9be;
  if (a < (unsigned long long)b) a += 0x1000000;
  Sleep(200);
  *(volatile unsigned char *)a = 2;
  *(volatile unsigned char *)a = 1;
  printf("wrote at %llx\n", a);
  return 0;
}
