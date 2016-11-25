// diskio.c
// Started by Erik Piehl Nov 2016

// Define the following for cygwin compatibility
#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <malloc.h>
// #include <varargs.h>
#include <stdarg.h>

#include "diskio.h"
#include "fpga-mem.h"

#if defined (__GNUC__)
// functions corresponding to Visual C++ secure runtime - although these are not secure.
int vsprintf_s(char *buf, size_t bufsize, const char *format, ...)
{
  va_list a;
  va_start(a, format);
  vsprintf(buf, format, a);
  printf(buf);
  va_end(a);
}

char *strcpy_s(char *dest, size_t destsize, const char *src) {
  strcpy(dest, src);
  return dest;
}
#endif

struct tifile {
  FILE          *m_file;
  unsigned char *m_data;	//<! Address of databuffer
  unsigned int   m_size;
  int            m_record;
  enum varfix_t { variable, fixed } m_var;
  struct tifiles_header m_header;
  char          m_name[256];
  unsigned short m_pab;	//<! PAB address in VDP memory
  unsigned char *m_cur_data;
};

struct tifile *files[10] = { 0 };

void issue_cmd(unsigned short cmd, unsigned short arg1, unsigned short arg2, unsigned short arg3);


void debug_write(const char *format, ...) {
	va_list a;
	char buf[128];
	va_start(a, format);
	vsprintf_s(buf, sizeof(buf), format, a);
	printf(buf);
	va_end(a);
}

void free_slot(int i) {
  if (files[i]->m_file != NULL) {
    fclose(files[i]->m_file);
  }
  if (files[i]->m_data != NULL) {
    free(files[i]->m_data);
  }
  free(files[i]);
  files[i] = NULL;
}

int find_tifile_handle(unsigned short vdp_pab_addr) {
  for (int i = 0; i < sizeof(files) / sizeof(files[0]); i++) {
    if (files[i] != NULL && files[i]->m_pab == vdp_pab_addr)
      return i;
  }
  return -1;
}

// returns index to tifiles table, or negative value on error
int open_tifile(const char *name, unsigned short pab_addr, const struct ti_pab *pab, int writeback) {
  int i;
  int found = 0;
  for (i = 0; i < sizeof(files) / sizeof(files[0]); i++) {
    if (files[i] == NULL)
      found = 1;
      break;
  }
  if (!found)
    return -1;  // No free slot available.
  files[i] = malloc(sizeof(struct tifile));
  if (!files[i])
    return -2;
  memset(files[i], 0, sizeof(struct tifile));
  strcpy_s(files[i]->m_name, sizeof(files[i]->m_name), name);
  files[i]->m_file = fopen(files[i]->m_name, "rb");
  if (files[i]->m_file == NULL) {
    free_slot(i);
    return -3;
  }
  int r = fread(&files[i]->m_header, sizeof(struct tifiles_header), 1, files[i]->m_file);
  if (r != 1) {
    free_slot(i);
    return -4;
  }
  // Validate header here
  if (strncmp(files[i]->m_header.id, "\x07TIFILES", 8) != 0) {
	  free_slot(i);
	  return -5;
  }

  files[i]->m_pab = pab_addr;
  unsigned short len = files[i]->m_header.LengthSectors;
  files[i]->m_header.LengthSectors = (len << 8) | (len >> 8); // swap bytes
  // Allocate a large buffer for the file.
  files[i]->m_size = 512 * 1024;
  files[i]->m_data = malloc(files[i]->m_size); // for now allocate 0.5M and assume that's good 
  memset(files[i]->m_data, 0, files[i]->m_size);// quick and dirty.
  files[i]->m_var = files[i]->m_header.FileType & TIFILES_VARIABLE ? variable : fixed;
  files[i]->m_cur_data = files[i]->m_data;
  files[i]->m_record = 0;

  // Write the response to the TI. This time we write back the entire PAB.
  if (writeback) {
    struct ti_pab ret_pab = *pab; // copy original as basis
    ret_pab.record_number = 0;
    ret_pab.record_length = files[i]->m_header.RecordLength;
    // swap endianess on 16-bit fields
    swap_word_bytes(&ret_pab.addr);
    swap_word_bytes(&ret_pab.record_number);
    ret_pab.flags &= 0x1F;  // clear top 3 bits -> OK
    WriteMemoryBlock(&ret_pab, DISK_BUFFER_ADDR_PC, sizeof(ret_pab));
    issue_cmd(2, DISK_BUFFER_ADDR_TI, pab_addr, sizeof(ret_pab));
  }

  return i;
}

int buffer_tifile(int i) {
  // read the file a la classic99, basically we fill files[i]->m_data with what we get from the file.
  // the code below is a direct ripoff from classic99/FiadDisk.cpp - BufferFiadFile
  int idx = 0;							// count up the records read
  int nSector = 256;					// bytes left in this sector
  FILE *fp = files[i]->m_file;
  unsigned char tmpbuf[256];
  fseek(fp, sizeof(struct tifiles_header), SEEK_SET);// skip the header
  unsigned char *pData = files[i]->m_data;

  // we need to let the embedded code decide the terminating rule
  for (;;) {
    if (feof(fp)) {
      debug_write("Premature EOF - truncating read.");
      files[i]->m_header.NumberRecords = idx; // note: this modifies the header we read from disk
      break;
    }

    if (variable == files[i]->m_var) {
      // read a variable record
      int nLen = fgetc(fp);
      if (EOF == nLen) {
        debug_write("Corrupt file - truncating read.");
        files[i]->m_header.NumberRecords = idx;
        break;
      }

      nSector--;
      if (nLen == 0xff) {
        // end of sector indicator, no record read, skip rest of sector
        fread(tmpbuf, 1, nSector, fp);
        nSector = 256;
        files[i]->m_header.NumberRecords--;
        // are we done?
        if (files[i]->m_header.NumberRecords == 0) {
          // yes we are, get the true count
          files[i]->m_header.NumberRecords = idx;
          break;
        }
      }
      else {
        // check for buffer resize
        if ((files[i]->m_data + files[i]->m_size) - pData < (files[i]->m_header.RecordLength + 2) * 10) {
          int nOffset = pData - files[i]->m_data;		// in case the buffer moves
                                                // time to grow the buffer - add another 100 lines
          files[i]->m_size += (100) * (files[i]->m_header.RecordLength + 2);
          files[i]->m_data = (unsigned char*)realloc(files[i]->m_data, files[i]->m_size);
          pData = files[i]->m_data + nOffset;
        }

        // clear buffer
        memset(pData, 0, files[i]->m_header.RecordLength + 2);

        // check again
        if (nSector < nLen) {
          debug_write("Corrupted file - truncating read.");
          files[i]->m_header.NumberRecords = idx;
          break;
        }

        // we got some data, read it in and count off the record
        // verify it (don't get screwed up by a bad file)
        if (nLen > files[i]->m_header.RecordLength) {
          debug_write("Potentially corrupt file - skipping end of record.");

          // store length data
          *(unsigned short*)pData = files[i]->m_header.RecordLength;
          pData += 2;

          fread(pData, 1, files[i]->m_header.RecordLength, fp);
          nSector -= nLen;
          // skip the excess and trim down nLen
          fread(tmpbuf, 1, nLen - files[i]->m_header.RecordLength, fp);
          nLen = files[i]->m_header.RecordLength;
        }
        else {
          // record is okay (normal case)

          // write length data
          *(unsigned short*)pData = nLen;
          pData += 2;

          fread(pData, 1, nLen, fp);
          nSector -= nLen;
        }
        // count off a valid record and update the pointer
        idx++;
        pData += files[i]->m_header.RecordLength;
      }
    }
    else {
      // are we done?
      if (idx >= files[i]->m_header.NumberRecords) {
        break;
      }

      // clear buffer
      memset(pData, 0, files[i]->m_header.RecordLength + 2);

      // read a fixed record
      if (nSector < files[i]->m_header.RecordLength) {
        // not enough room for another record, skip to the next sector
        fread(tmpbuf, 1, nSector, fp);
        nSector = 256;
      }
      else {
        // a little simpler, we just need to read the data
        *(unsigned short*)pData = files[i]->m_header.RecordLength;
        pData += 2;

        fread(pData, 1, files[i]->m_header.RecordLength, fp);
        nSector -= files[i]->m_header.RecordLength;
        idx++;
        pData += files[i]->m_header.RecordLength;
      }
    }
  }

  fclose(fp);
  files[i]->m_file = NULL;
  return 1;
}

void dump_record(int j, unsigned char *pData) {
  unsigned short len = *(unsigned short*)pData;
  pData += 2;
  printf("Record %d [%d]: ", j, len);
  for (int k = 0; k < len; k++) {
    if (pData[k] < 32 || pData[k] > 127)
      putchar('.');
    else
      putchar(pData[k]);
  }
  printf("\n");
}

int dump_records(int i) {
	if (i < 0) {
		debug_write("dump_records, broken id %d\n", i);
		return 0;
	}
	unsigned char *pData = files[i]->m_data;
	for (int j = 0; j < files[i]->m_header.NumberRecords; j++) {
		unsigned short len = *(unsigned short*)pData;
    dump_record(j, pData);
    pData += 2;
		pData += files[i]->m_header.RecordLength;
	}
	return 1;
}

// Return TI-99/4A success code
int read_record(int index, const struct ti_pab *pab) {
  if (index < 0)
    return ERR_FILEERROR;
  struct tifile *f = files[index];
  if (f->m_record >= f->m_header.NumberRecords)
    return ERR_READPASTEOF;
  // Dump the record
  unsigned char *pData = f->m_cur_data;
  dump_record(f->m_record, pData);
  unsigned short len = *(unsigned short*)f->m_cur_data;
  f->m_cur_data += 2;
  // Transfer to TI memory - start
  if (pab != NULL) {
    // Write record to VDP memory via the transfer buffer
    WriteMemoryBlock(f->m_cur_data, DISK_BUFFER_ADDR_PC, len);
    unsigned vdp_addr = pab->addr;
    issue_cmd(2, DISK_BUFFER_ADDR_TI, vdp_addr, len);
    // Update byte 5 of PAB to be record length (low byte of len) 
    vdp_addr = files[index]->m_pab + 5;
    WriteMemoryBlock((unsigned char *)&len, DISK_BUFFER_ADDR_PC, 1);   
    issue_cmd(2, DISK_BUFFER_ADDR_TI, vdp_addr, 1);
  }
  // Transfer to TI memory - end
  f->m_cur_data += f->m_header.RecordLength;  // point to next
  f->m_record++;
  return ERR_NOERROR;
}

int close_tifile(int index) {
  if (index < 0)
    return ERR_FILEERROR;
  free_slot(index);
  return ERR_NOERROR;
}

const char *get_name(struct ti_pab *p) {
	static char name[80];
	int i;
	for (i = 0; i<sizeof(name) && i<p->name_length; i++)
		name[i] = p->name[i];
	name[i] = '\0';
	return name;
}

void print_pab(unsigned short pab_vdp_addr, struct ti_pab *p) {
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
	fprintf(stderr, "%04X: %s %s err=%d addr=%04X rec=%d cnt=%d n=%d offs=%d %s\n",
    pab_vdp_addr, op, flags, p->flags >> 5, p->addr, p->record_length, p->count,
		p->record_number, p->screen_offset, name);
}

int swap_word_bytes(unsigned short *k) {
	unsigned short t = *k;
	t = (t >> 8) | (t << 8);
	*k = t;
	return t;
}

void send_cmd(const struct dsr_cmd *p) {
	struct dsr_cmd mycmd;
	memcpy(&mycmd, p, sizeof(mycmd));
	swap_word_bytes(&mycmd.arg1);
	swap_word_bytes(&mycmd.arg2);
	swap_word_bytes(&mycmd.arg3);
	swap_word_bytes(&mycmd.cmd);
	WriteMemoryBlock((char *)&mycmd, CMD_ADDR, 8);
}

void issue_cmd(unsigned short cmd, unsigned short arg1, unsigned short arg2, unsigned short arg3) {
  struct dsr_cmd k;
  k.cmd = cmd;
  k.arg1 = arg1;
  k.arg2 = arg2;
  k.arg3 = arg3;
  send_cmd(&k);
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
	generate_filename(filename, name);
	FILE *f = fopen(filename, "wb");
	if (f == NULL) {
		// Failure, return error.
		fprintf(stderr, "Error: DoSave was unable to open %s\n", filename);
    issue_cmd(3, 0x7000, 0, 0);
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
    issue_cmd(1, vdp_addr, DISK_BUFFER_ADDR_TI, chunk);
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
  issue_cmd(3, 0, 0, 0);
	printf("Saved %d bytes\n", pab->byte_count);
} 

void DoLoad(const char *name, const struct ti_pab *pab) {
	char filename[256];
	generate_filename(filename, name);
	FILE *f = fopen(filename, "rb");
	if (f == NULL) {
		// Failure, return error.
		fprintf(stderr, "Error: DoLoad was unable to open %s\n", filename);
    issue_cmd(3, 0x7000, 0, 0);
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
      issue_cmd(2, DISK_BUFFER_ADDR_TI, vdp_addr, chunk); // Write to VDP memory
    }
    length += chunk;
    vdp_addr += chunk;
  } while (chunk > 0 && length < pab_count);
  // We are done with saving!
  fclose(f);
  // Exit the DSR
  issue_cmd(3, 0, 0, 0);
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
  unsigned short pabsta = *(unsigned short *)&cmd_buf[DSR_PABSTA - SCRATCHPAD];
  swap_word_bytes(&pabsta);
	print_pab(pabsta, p);
	if (p->opcode == OP_SAVE) {
		// Save operation, the TI wants to save a program to our disk.
		// DEBUG: Save sprite table
		if (0) {
			struct dsr_cmd k;
			k.cmd = 1;  // read VDP RAM
			k.arg1 = 0x300; // From sprite attribute table
			k.arg2 = DISK_BUFFER_ADDR_TI;
			k.arg3 = 256;
      send_cmd(&k);
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
    if (((p->flags >> 1) & 3) != 2) {
      // operation is not input - error
      fprintf(stderr, "Error: OP_OPEN file %s not opened for input.\n", get_name(p));
      issue_cmd(3, 0x7000, 0, 0);
    }
    char filename[256];
    generate_filename(filename, get_name(p));
    int h = open_tifile(filename, pabsta, p, 1);
    if (h < 0) {
      // This is not implemented, let's return an error (file not found)
      fprintf(stderr, "Error: OP_OPEN was unable to open %s\n", get_name(p));
      issue_cmd(3, 0x7000, 0, 0);
    }
    else {
      // Hurray - file opened. Now buffer it.
      printf("Buffer returned: %d\n", buffer_tifile(h));
      issue_cmd(3, 0, 0, 0);  // all ok!
    }
  }
  else if (p->opcode == OP_READ) {
    int h = find_tifile_handle(pabsta);
    int r = read_record(h, p); 
    issue_cmd(3, r << 13, 0, 0);  // return with code
  }
  else if (p->opcode = OP_CLOSE) {
    int h = find_tifile_handle(pabsta);
    int r = close_tifile(h);
    issue_cmd(3, r << 13, 0, 0);  // return with code
  }
	return 0;
}
