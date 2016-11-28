#pragma once
// diskio.h

#pragma pack(push, 1)

struct ti_pab {
	unsigned char   opcode;
	unsigned char   flags;
	unsigned short  addr;
	unsigned char   record_length;
	unsigned char   count;
	union {
		unsigned short  record_number;
		unsigned short  byte_count;
	};
	unsigned char   screen_offset;
	unsigned char   name_length;
	unsigned char   name[1];
};

#define SCRATCHPAD          0xB8000 // Scratchpad base address
#define CMD_ADDR			      0xB800C
#define DSR_PABSTA          0xB8004  // TMS99105 stores PAB start address here.
#define DISK_BUFFER_ADDR_TI	0x8100  // Address in TMS99105 terms
#define DISK_BUFFER_ADDR_PC 0xB8100 // Address from PC

struct dsr_cmd {
	unsigned short arg1, arg2, arg3;
	unsigned short cmd;
};

struct tifiles_header {
	char id[8];
	// Names in the following from classic99 / diskclass.h
	unsigned short	LengthSectors;
	unsigned char	FileType;
	unsigned char	RecordsPerSector;
	unsigned char	BytesInLastSector;
	unsigned char	RecordLength;
	unsigned short	NumberRecords;		// note: even for variable, we translate the value on output

	char crap[0x70];	// Pad the length to 128, but we couldn't care less about this
};

// The following definitions are from classic99/diskclass.h for naming consistency
// but basically they are from 99-4A_Console_Peripheral_Expansion_System_Technical_Data.pdf

// The following is from diskclass.h / classic99 and defines the bits in the FileType byte above
// Filetype enums for TIFILES (same for V9T9?) - these go into FileInfo::FileType and come from the file
#define TIFILES_VARIABLE	0x80		// else Fixed
#define TIFILES_PROTECTED	0x08		// else not protected
#define TIFILES_INTERNAL	0x02		// else Display
#define TIFILES_PROGRAM		0x01		// else Data
// others undefined - for the mask, ignore protection bit
#define TIFILES_MASK	(TIFILES_VARIABLE|TIFILES_INTERNAL|TIFILES_PROGRAM)

// 
// return bits for the STATUS command (saved in Screen Offset byte)
#define STATUS_NOSUCHFILE	0x80
#define STATUS_PROTECTED	0x40
#define STATUS_INTERNAL		0x10
#define STATUS_PROGRAM		0x08
#define STATUS_VARIABLE		0x04
#define STATUS_DISKFULL		0x02
#define STATUS_EOF			0x01

// File operation codes
#define OP_OPEN			0
#define OP_CLOSE		1
#define OP_READ			2
#define OP_WRITE		3
#define OP_RESTORE		4
#define OP_LOAD			5
#define OP_SAVE			6
#define OP_DELETE		7
#define OP_SCRATCH		8
#define OP_STATUS		9

// PAB error codes
#define ERR_NOERROR			0			// This also means the DSR was not found!
#define ERR_BADBAME			0			// thus the duplicate definition
#define ERR_WRITEPROTECT	1
#define ERR_BADATTRIBUTE	2
#define ERR_ILLEGALOPERATION 3
#define ERR_BUFFERFULL		4
#define ERR_READPASTEOF		5
#define ERR_DEVICEERROR		6
#define ERR_FILEERROR		7

// Modes for opening files. These are bits in tipab.flags
// Bit 0 is sequential / relative:
#define PAB_REL 1   // when flags.0 = 0 sequential, flags.0=1 relative (supports seeking)
// Bits 2 & 1 of tipab.flags give the mode
enum filemode_t { filemode_update = 0, filemode_output = 1, filemode_input = 2, filemode_append = 3 };
// FILEMODE_UPDATE 0   // supports both reading and writing.
// FILEMODE_OUTPUT 1   // supports only writing.
// FILEMODE_INPUT  2   // supports only reading.
// FILEMODE_APPEND 3   // supports writing to the end of the file.



#pragma pack(pop)

int DoDiskProcess();

int open_tifile(const char *name, unsigned short pab_addr, struct ti_pab *pab, int writeback);
int buffer_tifile(int i);
int dump_records(int i);
int swap_word_bytes(unsigned short *k);
int read_record(int index, const struct ti_pab *pab);
int close_tifile(int i);
