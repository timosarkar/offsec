#include <ctype.h>
#include <inttypes.h>
#include <sys/stat.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define B_PUSH_RAX ".byte 0x50\n\t" // push rax
#define B_PUSH_RBX ".byte 0x53\n\t" // push rbx
#define B_POP_RAX  ".byte 0x58\n\t" // pop rax
#define B_POP_RBX  ".byte 0x5b\n\t" // pop rbx
#define B_NOP ".byte 0x48,0x87,0xc0\n\t" // REX.W xchg rax,rax
#define H_PUSH     0x50 // push + reg
#define H_POP      0x58 // pop + reg
#define H_NOP_0    0x48 // --------------------
#define H_NOP_1    0x87 // REX.W xchg rax,rax |
#define H_NOP_2    0xC0 // --------------------
#define JUNK_ASM __asm__ __volatile__ (B_PUSH_RBX B_PUSH_RAX B_NOP B_NOP B_POP_RAX B_POP_RBX)
#define JUNKLEN 10

int local_rand () {
  int digit;
  FILE *fp;
  fp = fopen("/dev/urandom", "r");
  fread(&digit, 1, 1, fp);
  fclose(fp);
  return digit;
}


void insert_junk(uint8_t *file_data, uint64_t junk_start) {
  JUNK_ASM;
  /*
   The junk assembly instructions use the following pattern so that they can be identified:
   r1 = random register from RAX, RBX, RCX or RDX
   r2 = a different random register from RAX, RBX, RCX, RDX
   push r1
   push r2
   xchg r1, r2
   xchg r1, r2
   pop r2
   pop r1
  */
  uint8_t reg_1 = (local_rand()%4);
  uint8_t reg_2 = (local_rand()%4);

  while(reg_2 == reg_1) {
    reg_2 = (local_rand()%4);
  }

  uint8_t push_r1 = 0x50 + reg_1;
  uint8_t push_r2 = 0x50 + reg_2;
  uint8_t pop_r1 = 0x58 + reg_1;
  uint8_t pop_r2 = 0x58 + reg_2;
  uint8_t nop[3] = {0x48,0x87,0xC0};
  nop[2] += reg_1;
  nop[2] += (reg_2 * 8);
  file_data[junk_start] = push_r1;
  file_data[junk_start + 1] = push_r2;
  file_data[junk_start + 2] = nop[0];
  file_data[junk_start + 3] = nop[1];
  file_data[junk_start + 4] = nop[2];
  file_data[junk_start + 5] = nop[0];
  file_data[junk_start + 6] = nop[1];
  file_data[junk_start + 7] = nop[2];
  file_data[junk_start + 8] = pop_r2;
  file_data[junk_start + 9] = pop_r1;
}


int32_t load_file(uint8_t **file_data, uint32_t *file_len, const char *filename) {
  JUNK_ASM;

  FILE *fp = fopen(filename, "rb");

  fseek(fp, 0L, SEEK_END);
  if (ftell(fp) < 1) {
    fprintf(stderr, "File %s 0 bytes in length\n", filename);
  } else {
    *file_len = ftell(fp);
  }

  *file_data = malloc(*file_len);

  fseek(fp, 0L, SEEK_SET);
  fread((void*)*file_data, *file_len, 1, fp);
  fclose(fp);
  return EXIT_SUCCESS;
}


void replace_junk(uint8_t *file_data, uint64_t file_len) {
  JUNK_ASM;
  for (uint64_t i = 0; i < file_len; i += 1) {
    if (file_data[i] >= H_PUSH && file_data[i] <= (H_PUSH + 3)) {
      if (file_data[i + 1] >= H_PUSH && file_data[i + 1] <= (H_PUSH + 3)) {
        if (file_data[i + 2 == H_NOP_0]) {
          if (file_data[i + 3] == H_NOP_1) {
            insert_junk(file_data, i);
          }
        }
      }
    }
  }
}

int32_t write_file(uint8_t *file_data, uint32_t file_len, const char *filename) {
  JUNK_ASM;
  FILE *fp;
  int lastoffset = strlen(filename)-1;
  char lastchar = filename[lastoffset];
  char *newfilename = strdup(filename);
  lastchar = '0'+(isdigit(lastchar)?(lastchar-'0'+1)%10:0);
  newfilename[lastoffset] = lastchar;
  fp = fopen(newfilename, "wb");
  fwrite(file_data, file_len, 1, fp);
  fclose(fp);
  free(newfilename);
  return EXIT_SUCCESS;
}

int main(int argc, char* argv[]) {
  JUNK_ASM;
  uint8_t  *file_data = NULL;
  uint32_t file_len;
  load_file(&file_data, &file_len, argv[0]);
  replace_junk(file_data, file_len);
  write_file(file_data, file_len, argv[0]);
  free(file_data);
  return EXIT_SUCCESS;
}
