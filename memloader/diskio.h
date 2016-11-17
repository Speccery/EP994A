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

#pragma pack(pop)

int DoDiskProcess();
