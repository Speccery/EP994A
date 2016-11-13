// diskio.c
// Started by Erik Piehl Nov 2016

// Define the following for cygwin compatibility
#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <string.h>
#include <ctype.h>

#include "diskio.h"
#include "fpga-mem.h"

const char *get_name(struct ti_pab *p) {
	static char name[80];
	int i;
	for (i = 0; i<sizeof(name) && i<p->name_length; i++)
		name[i] = p->name[i];
	name[i] = '\0';
	return name;
}

void print_pab(struct ti_pab *p) {
	char name[80];
	char *op = "Unkown";
	fprintf(stderr, "\n");
	switch (p->opcode) {
	case 0: op = "Open"; break;
	case 1: op = "Close"; break;
	case 2: op = "Read"; break;
	case 3: op = "Write"; break;
	case 4: op = "Restore"; break;
	case 5: op = "Load"; break;
	case 6: op = "Save"; break;
	case 7: op = "Delete"; break;
	case 8: op = "Scratch"; break;
	case 9: op = "Status"; break;
	}
	char flags[128];
	strcpy(flags, "[");
	strcat(flags, p->flags & 1 ? "REL " : "SEQ ");
	char *mode[] = { "Update ", "Output ", "Input ", "Append " };
	strcat(flags, mode[(p->flags >> 1) & 3]);
	strcat(flags, p->flags & 8 ? "INTE " : "DISP ");
	strcat(flags, p->flags & 16 ? "VAR" : "FIX");
	strcat(flags, "]");
	strcpy(name, get_name(p));
	fprintf(stderr, "%s %s err=%d addr=%04X rec=%d cnt=%d n=%d offs=%d %s\n",
		op, flags, p->flags >> 5, p->addr, p->record_length, p->count,
		p->record_number, p->screen_offset, name);
}

int swap_word_bytes(unsigned short *k) {
	unsigned short t = *k;
	t = (t >> 8) | (t << 8);
	*k = t;
	return t;
}



void issue_cmd(const struct dsr_cmd *p) {
	struct dsr_cmd mycmd;
	memcpy(&mycmd, p, sizeof(mycmd));
	swap_word_bytes(&mycmd.arg1);
	swap_word_bytes(&mycmd.arg2);
	swap_word_bytes(&mycmd.arg3);
	swap_word_bytes(&mycmd.cmd);
	WriteMemoryBlock((char *)&mycmd, CMD_ADDR, 8);
}

int wait_cmd_complete(const char *msg) {
	int timeout = 10;
	struct dsr_cmd mycmd;
	while (timeout > 0) {
		ReadMemoryBlock((char *)&mycmd, CMD_ADDR, 8);
		if (mycmd.cmd == 0)
			return 1; // Done
		timeout--;
	}
	fprintf(stderr, "Error: wait_cmd_complete(%s) timeout\n", msg);
	return 0;
}

void generate_filename(char *destname, const char *name) {
	char tmp[256];
	char *fname = NULL;
	int first_dot = 1;
	int i;
	for (i = 0; i<sizeof(tmp) - 2 && name[i]; i++) {
		tmp[i] = toupper(name[i]);
		if (tmp[i] == '.' && first_dot) {
			first_dot = 0;
			tmp[i] = '\0';
			tmp[i + 1] = '\0';
			fname = tmp + i + 1;
		}
	}
	tmp[i] = '\0';
	if (fname == NULL)
		fname = "temp";
	if (!strcmp(tmp, "DSK1")) {
		sprintf(destname, "dsk1/%s", fname);
	}
	else if (!strcmp(tmp, "DSK2")) {
		sprintf(destname, "dsk2/%s", fname);
	}
	else {
		sprintf(destname, "dsk3/%s", fname);
	}
}

void DoSave(const char *name, const struct ti_pab *pab) {
	char filename[256];
	struct dsr_cmd k;
	generate_filename(filename, name);
	FILE *f = fopen(filename, "wb");
	if (f == NULL) {
		// Failure, return error.
		fprintf(stderr, "Error: DoSave was unable to open %s\n", filename);
		k.arg1 = 0x7000;
		k.arg2 = k.arg3 = 0;
		k.cmd = 3;
		issue_cmd(&k);
		return;
	}
	// Ok so we were able to open the file. Now ask the TMS99105 to copy 
	// to us the data we need to save, max 256 at a time.
	// We ask the TMS99105 to give us the data at memory address >8100
	int len = pab->byte_count;
	int vdp_addr = pab->addr;
	while (len > 0) {
		int chunk = len;
		if (chunk > 256)
			chunk = 256;
		k.cmd = 1;
		k.arg1 = vdp_addr;
		k.arg2 = DISK_BUFFER_ADDR_TI;
		k.arg3 = chunk;
		issue_cmd(&k);
		// Wait for the TMS99105 to do the job 
		if (!wait_cmd_complete("chunk read")) {
			return;
		}
		// Ok we did get our chunk, let's read it to PC memory and write it to disk
		unsigned char buf[256];
		ReadMemoryBlock(buf, DISK_BUFFER_ADDR_PC, chunk);
		fwrite(buf, 1, chunk, f);
		len -= chunk;
		vdp_addr += chunk;
	}
	// We are done with saving!
	fclose(f);
	// Exit the DSR
	k.arg1 = k.arg2 = k.arg3 = 0;
	k.cmd = 3;
	issue_cmd(&k);
	printf("Saved %d bytes\n", pab->byte_count);
} 

void DoLoad(const char *name, const struct ti_pab *pab) {
	char filename[256];
	struct dsr_cmd k;
	generate_filename(filename, name);
	FILE *f = fopen(filename, "rb");
	if (f == NULL) {
		// Failure, return error.
		fprintf(stderr, "Error: DoLoad was unable to open %s\n", filename);
		k.arg1 = 0x7000;
		k.arg2 = k.arg3 = 0;
		k.cmd = 3;
		issue_cmd(&k);
		return;
	}
  // LOAD data in PAB:
  // 2 & 3 = Start address of memory dump area
  // 6,7 Number of bytes available
  unsigned vdp_addr = pab->addr;
  unsigned pab_count = pab->byte_count; // max size
  int chunk = 0;
  int length = 0;
  do {
    unsigned char buf[256];
    chunk = fread(buf, 1, sizeof(buf), f);
    // Huge hack: if we have TIFILES header, just skip it.
    if (length == 0 && strncmp(buf, "\x07TIFILES", 8) == 0) {
      // We have TIFILES header, let's skip it.
      memcpy(buf, buf + 128, chunk - 128);
      chunk -= 128;
      printf("Skipping TIFILES header\n");
    }
    else if (length == 0 && strncmp(buf, "AMSTEST4", 8) == 0) {
      // This is V9T9 format apparently - again skip 128 bytes
      memcpy(buf, buf + 128, chunk - 128);
      chunk -= 128;
      printf("Skipping V9T9 header for AMSTEST4\n");
    }

    // Check that chunk does not bring us over the available space
    if (length + chunk > pab_count)
      chunk = pab_count - length;
    if (chunk > 0) {
      WriteMemoryBlock(buf, DISK_BUFFER_ADDR_PC, chunk);
      k.cmd = 2;  // Write to VDP memory
      k.arg1 = DISK_BUFFER_ADDR_TI;  // CPU memory address
      k.arg2 = vdp_addr;
      k.arg3 = chunk;
      issue_cmd(&k);
    }
    length += chunk;
    vdp_addr += chunk;
  } while (chunk > 0 && length < pab_count);
  // We are done with saving!
  fclose(f);
  // Exit the DSR
  k.arg1 = k.arg2 = k.arg3 = 0;
  k.cmd = 3;
  issue_cmd(&k);
  printf("Loaded %d bytes\n", length);
}

int DoDiskProcess() {
	char cmd_buf[64];
	ReadMemoryBlock(cmd_buf, SCRATCHPAD, sizeof(cmd_buf));
	if (!(cmd_buf[10] == 0 && cmd_buf[11] == 1))
		return 0; // Nothing to be done
				  // We have a command from the CPU. PAB is at offset 32.
	struct ti_pab *p = (struct ti_pab *)&cmd_buf[32];
	swap_word_bytes(&p->addr);
	swap_word_bytes(&p->record_number);
	print_pab(p);
	if (p->opcode == OP_SAVE) {
		// Save operation, the TI wants to save a program to our disk.
		// DEBUG: Save sprite table
		if (0) {
			struct dsr_cmd k;
			k.cmd = 1;  // read VDP RAM
			k.arg1 = 0x300; // From sprite attribute table
			k.arg2 = DISK_BUFFER_ADDR_TI;
			k.arg3 = 256;
			issue_cmd(&k);
			// Wait for the TMS99105 to do the job 
			if (!wait_cmd_complete("sprite read")) {
				fprintf(stderr, "debug code error\n");
			}
			char sprites[256];
			ReadMemoryBlock(sprites, DISK_BUFFER_ADDR_PC, 256);
			FILE *f = fopen("sprites.bin", "wb");
			if (f) {
				fwrite(sprites, 1, 256, f);
				fclose(f);
			}
		}
		DoSave(get_name(p), p);
	}
	else if (p->opcode == OP_LOAD) {
		DoLoad(get_name(p), p);
  }
  else if (p->opcode == OP_OPEN) {
    // This is not implemented, let's return an error (file not found)
    fprintf(stderr, "Error: OP_OPEN was unable to open %s\n", get_name(p));
    struct dsr_cmd k;
    k.arg1 = 0x7000;
    k.arg2 = k.arg3 = 0;
    k.cmd = 3;
    issue_cmd(&k);
  }
	return 0;
}
