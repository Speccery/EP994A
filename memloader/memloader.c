//------------------------------------------------------------------
// memloader.c
// Erik Piehl (C) 2016-09-01 .. 2016-11-13
// epiehl@gmail.com
//------------------------------------------------------------------
// 2016-11-12, 2016-11-13:
//    Refactoring, added Visual Studio 2015 project files.
//    Added disk support, in keyboard emulation mode the code polls
//    TMS99105 and processes file requests.
//------------------------------------------------------------------
// Serial port access from cygwin, to communicate with Pepino FPGA.
// Compile with "gcc -g -o memloader memloader.c"
//
// Initial versio nof serial port code was loosely based on code 
// from LPC21ISP, although there is very little code
// now leftover from that project.
//------------------------------------------------------------------

#define _CRT_SECURE_NO_WARNINGS

#include <stdio.h>
#include <windows.h>
#include <io.h>

#include "fpga-mem.h"
#include "diskio.h"

// For now COM port is stupidly hardcoded, but then again changes are one "make" command away!
char serial_port[10] = "COM4";
char opt_verbose = 0;

HANDLE hCom = INVALID_HANDLE_VALUE;
int bit_rate = 230400;
int write_delay = 0;
unsigned serial_timeout_count=0;
int debug_level = 3;

struct fpga_context {
	unsigned addr;
} fc;

// A few prototypes
void DumpString(int level, const void *b, size_t size, const char *prefix_string);
void DebugPrintf(int level, const char *fmt, ...);

void OpenSerialPort(void)
{
    DCB    dcb;
    COMMTIMEOUTS commtimeouts;

#ifdef _MSC_VER
    /* Torsten Lang 2013-05-06 Switch to higher timer resolution (we want to use 1ms timeouts in the serial device driver!) */
    (void)timeBeginPeriod(1UL);
#endif // _MSC_VER

    hCom = CreateFile(serial_port, GENERIC_READ | GENERIC_WRITE,0,NULL,
		OPEN_EXISTING,FILE_ATTRIBUTE_NORMAL,NULL);

    if (hCom == INVALID_HANDLE_VALUE)
    {
        DebugPrintf(1, "Can't open COM-Port %s ! - Error: %ld\n", serial_port, GetLastError());
        exit(2);
    }

    if (opt_verbose)
      DebugPrintf(3, "COM-Port %s opened...\n", serial_port);

	ZeroMemory(&dcb, sizeof(DCB));
	dcb.DCBlength = sizeof(DCB);
    GetCommState(hCom, &dcb);
    dcb.BaudRate    = bit_rate;
    dcb.ByteSize    = 8;
    dcb.StopBits    = ONESTOPBIT;
    dcb.Parity      = NOPARITY;
    dcb.fDtrControl = DTR_CONTROL_DISABLE;
    dcb.fOutX	 	= FALSE;
    dcb.fInX  		= FALSE;
    dcb.fNull       = FALSE;
    dcb.fRtsControl = RTS_CONTROL_DISABLE;

    // added by Herbert Demmel - iF CTS line has the wrong state, we would never send anything!
    dcb.fOutxCtsFlow = FALSE;
    dcb.fOutxDsrFlow = FALSE;

    if (SetCommState(hCom, &dcb) == 0)
    {
        DebugPrintf(1, "Can't set baudrate %s ! - Error: %ld", bit_rate, GetLastError());
        exit(3);
    } else {
		DebugPrintf(4, "Did set bitrate to %d\n", bit_rate);
	}

   /*
    *  Peter Hayward 02 July 2008
    *
    *  The following call is only needed if the WaitCommEvent
    *  or possibly the GetCommMask functions are used.  They are
    *  *not* in this implimentation.  However, under Windows XP SP2
    *  on my laptop the use of this call causes XP to freeze (crash) while
    *  this program is running, e.g. in section 5/6/7 ... of a largish
    *  download.  Removing this *unnecessary* call fixed the problem.
    *  At the same time I've added a call to SetupComm to request
    *  (not necessarity honoured) the operating system to provide
    *  large I/O buffers for high speed I/O without handshaking.
    *
    *   SetCommMask(IspEnvironment->hCom,EV_RXCHAR | EV_TXEMPTY);
    */
    SetupComm(hCom, 32000, 32000);

    SetCommMask(hCom, EV_RXCHAR | EV_TXEMPTY);

    // Torsten Lang 2013-05-06: ReadFile may hang indefinitely with MAXDWORD/0/1/0/0 on FTDI devices!!!
    commtimeouts.ReadIntervalTimeout         = MAXDWORD;
    commtimeouts.ReadTotalTimeoutMultiplier  = MAXDWORD;
    commtimeouts.ReadTotalTimeoutConstant    =    1;
    commtimeouts.WriteTotalTimeoutMultiplier =    0;
    commtimeouts.WriteTotalTimeoutConstant   =    0;
    SetCommTimeouts(hCom, &commtimeouts);
}

static void CloseSerialPort()
{
	CloseHandle(hCom);
#ifdef _MSC_VER
    /* Torsten Lang 2013-05-06 Switch back timer resolution */
    (void)timeEndPeriod(1UL);
#endif // _MSC_VER
}
void ControlXonXoffSerialPort( unsigned char XonXoff)
{
    DCB dcb;

    GetCommState(hCom, &dcb);

    if(XonXoff) {
        dcb.fOutX = TRUE;
        dcb.fInX  = TRUE;
    } else {
        dcb.fOutX = FALSE;
        dcb.fInX  = FALSE;
    }

    if (SetCommState(hCom, &dcb) == 0) {
        DebugPrintf(1, "Can't set XonXoff ! - Error: %ld", GetLastError());
        exit(3);
    }
}

/***************************** SendComPortBlock *************************/
/**  Sends a block of bytes out the opened com port.
\param [in] s block to send.
\param [in] n size of the block.
*/
void SendComPortBlock(const void *s, size_t n)
{
  DWORD written;
  if(!WriteFile(hCom, s, n, &written, NULL)) {
    DebugPrintf(0, "SendComPortBlock: Error WriteFile failed.\n");
  } else {
    if (written != n) {
      DebugPrintf(0, "Error: SendComPort %d/%d", written, n);
    }
  }
}

void SendComPortString(const char *s) {
  SendComPortBlock(s, strlen(s));
}

/***************************** SerialTimeoutTick ************************/
/**  Performs a timer tick.  In this simple case all we do is count down
with protection against underflow and wrapping at the low end.
*/
void SerialTimeoutTick()
{
    if (serial_timeout_count <= 1) {
        serial_timeout_count = 0;
    } else {
        serial_timeout_count--;
    }
}


/***************************** ReceiveComPortBlock **********************/
/**  Receives a buffer from the open com port. Returns all the characters
ready (waits for up to 'n' milliseconds before accepting that no more
characters are ready) or when the buffer is full. 'n' is system dependant,
see SerialTimeout routines.
\param [out] answer buffer to hold the bytes read from the serial port.
\param [in] max_size the size of buffer pointed to by answer.
\param [out] real_size pointer to a long that returns the amout of the
buffer that is actually used.
*/
void ReceiveComPortBlock(void *answer, unsigned long max_size, DWORD *num_read) 
{
  ReadFile(hCom, answer, max_size, num_read, NULL);
  if (*num_read == 0) {
    SerialTimeoutTick();
  }
}


/***************************** SerialTimeoutSet *************************/
/**  Sets (or resets) the timeout to the timout period requested.  Starts
counting to this period.  This timeout support is a little odd in that the
timeout specifies the accumulated deadtime waiting to read not the total
time waiting to read. They should be close enought to the same for this
use. Used by the serial input routines, the actual counting takes place in
ReceiveComPortBlock.
\param [in] timeout_milliseconds the time in milliseconds to use for
timeout.  Note that just because it is set in milliseconds doesn't mean
that the granularity is that fine.  In many cases (particularly Linux) it
will be coarser.
*/
void SerialTimeoutSet(unsigned timeout_milliseconds)
{
#if 1
	serial_timeout_count = timeout_milliseconds + GetTickCount();
#else
#ifdef _MSC_VER
    serial_timeout_count = timeGetTime() + timeout_milliseconds;
#else
    serial_timeout_count = timeout_milliseconds;
#endif // _MSC_VER
#endif
}

/***************************** SerialTimeoutCheck ***********************/
/**  Check to see if the serial timeout timer has run down.
\retval 1 if timer has run out.
\retval 0 if timer still has time left.
*/
int SerialTimeoutCheck()
{
#if 1
	if (GetTickCount() > serial_timeout_count)
		return 1;
#else
#ifdef _MSC_VER
    if ((signed long)(serial_timeout_count - timeGetTime()) < 0) {
        return 1;
    }
#else
    if (serial_timeout_count == 0) {
        return 1;
    }
#endif // _MSC_VER
#endif
    return 0;
}

/***************************** ClearSerialPortBuffers********************/
/**  Empty the serial port buffers.  Cleans things to a known state.
*/
void ClearSerialPortBuffers() {
    PurgeComm(hCom, PURGE_TXABORT | PURGE_RXABORT | PURGE_TXCLEAR | PURGE_RXCLEAR);
}

/***************************** DebugPrintf ******************************/
/**  Prints a debug string depending the current debug level. The higher
the debug level the more detail that will be printed.  Each print
has an associated level, the higher the level the more detailed the
debugging information being sent.
\param [in] level the debug level of the print statement, if the level
is less than or equal to the current debug level it will be printed.
\param [in] fmt a standard printf style format string.
\param [in] ... the usual printf parameters.
*/
void DebugPrintf(int level, const char *fmt, ...)
{
    va_list ap;

    if (level <= debug_level)
    {
        char pTemp[2000];
        va_start(ap, fmt);
        //vprintf(fmt, ap);
        vsprintf(pTemp, fmt, ap);
        printf(pTemp);
        va_end(ap);
        fflush(stdout);
    }
}


/***************************** ReceiveComPortBlockComplete **************/
/**  Receives a fixed block from the open com port. Returns when the
block is completely filled or the timeout period has passed
\param [out] block buffer to hold the bytes read from the serial port.
\param [in] size the size of the buffer pointed to by block.
\param [in] timeOut the maximum amount of time to wait before guvung up on
completing the read.
\return 0 if successful, non-zero otherwise.
*/
int ReceiveComPortBlockComplete(void *block, size_t size, unsigned timeout)
{
    DWORD realsize = 0, read;
    char *result;
	int loops = 0;
  unsigned int u;
  unsigned char *up;
	unsigned now = GetTickCount();

    result = (char*) block;

    SerialTimeoutSet(timeout);

    do
    {
        ReceiveComPortBlock(result + realsize, size - realsize, &read);

        realsize += read;
		loops++;
		
		if (realsize < size)
			Sleep(1);

    } while ((realsize < size) && (SerialTimeoutCheck() == 0));

    // sprintf(tmp_string, "Answer(Length=%ld): ", realsize);
    // DumpString(3, result, realsize, tmp_string);
	DebugPrintf(4, "Answer(length=%ld, loops=%d, %dms): ", realsize, loops, GetTickCount() - now);
  up = block;
	for(u=0; u<realsize; u++) {
		DebugPrintf(4, "%02X ", up[u]);
	}
	DebugPrintf(4, "\n");

    if (realsize != size)
    {
        return 1;
    }
    return 0;
}


/***************************** Ascii2Hex ********************************/
/**  Converts a hex character to its equivalent number value. In case of an
error rather abruptly terminates the program.
\param [in] c the hex digit to convert.
\return the value of the hex digit.
*/
static unsigned char Ascii2Hex(unsigned char c)
{
    if (c >= '0' && c <= '9')
    {
        return (unsigned char)(c - '0');
    }

    if (c >= 'A' && c <= 'F')
    {
        return (unsigned char)(c - 'A' + 10);
    }

    if (c >= 'a' && c <= 'f')
    {
        return (unsigned char)(c - 'a' + 10);
    }

    DebugPrintf(1, "Wrong Hex-Nibble %c (%02X)\n", c, c);
    exit(1);

    return 0;  // this "return" will never be reached, but some compilers give a warning if it is not present
}

/***************************** DumpString ******************************/
/**  Prints an area of memory to stdout. Converts non-printables to hex.
\param [in] level the debug level of the block to be dumped.  If this is
less than or equal to the current debug level than the dump will happen
otherwise this just returns.
\param [in] b pointer to an area of memory.
\param [in] size the length of the memory block to print.
\param [in] prefix string is a pointer to a prefix string.
*/
void DumpString(int level, const void *b, size_t size, const char *prefix_string)
{
    size_t i;
    const char * s = (const char*) b;
    unsigned char c;

    DebugPrintf(level, prefix_string);

    DebugPrintf(level, "'");
    for (i = 0; i < size; i++)
    {
        c = s[i];
        if (c >= 0x20 && c <= 0x7e) /*isprint?*/
        {
            DebugPrintf(level, "%c", c);
        }
        else
        {
            DebugPrintf(level, "(%02X)", c);
        }
    }
    DebugPrintf(level, "'\n");
}

int RxByte(unsigned timeout) {
	char buf[1] = { 0 };
	DWORD bytes_read = 0;
	DWORD now = GetTickCount();
	DWORD last;
	do {
		if(!ReadFile(hCom, buf, 1, &bytes_read, NULL)) {
			printf("ReadFile failed\n");
		}
		if (bytes_read == 0)
			Sleep(1);
		last = GetTickCount();
	} while(bytes_read == 0 && last < now + timeout );
	if(bytes_read == 0) {
		DebugPrintf(3, "RxByte did timeout while waiting for byte (%dms).\n", last-now);
	}
	return buf[0];
}

int try_sync() {
	char buf[16];
	unsigned long realsize;
	DebugPrintf(4, ".");
	SendComPortString(".");
	memset(buf,0,sizeof(buf));
	// ReceiveComPort(buf, sizeof(buf)-1, &realsize, 1,100);
	buf[0] = RxByte(100); realsize = 1;
	DebugPrintf(4, "try_sync: Got %d bytes\n", realsize);
	if (realsize > 0 && buf[0] == '.')
		return 1;
	return 0;
}

void setup_hw_address(unsigned addr) {
	unsigned char buf[16] = { "A_B_C_D_" };
	buf[1] = addr;
	buf[3] = addr >> 8;
	buf[5] = addr >> 16;
	buf[7] = addr >> 24;
	SendComPortBlock(buf, 8);
	fc.addr = addr;
}

unsigned read_hw_address(int *ok) {
	unsigned char buf[8] = { "EFGH" };
	*ok = 0;
	DebugPrintf(4, "read_hw_address: %s\n", buf);
#if 0
	SendComPortBlock(buf, 4);
	int res = ReceiveComPortBlockComplete(buf, 4, 200);
	if(res == 0) {	// 0 = success
		*ok = 1;
		return buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
	}
	DebugPrintf(3, "read_hw_address: problemo\n");
	return ~0;
#else	
	SendComPortString("E");
	buf[0] = RxByte(200);
	SendComPortString("F");
	buf[1] = RxByte(200);
	SendComPortString("G");
	buf[2] = RxByte(200);
	SendComPortString("H");
	buf[3] = RxByte(200);
	*ok = 1;
	return buf[0] | (buf[1] << 8) | (buf[2] << 16) | (buf[3] << 24);
#endif
}

void check_sync(void) {
	if(!try_sync())
		DebugPrintf(2, "Sync failed\n");
}

void check_addressing() {
	unsigned test_data[] = { 0, 1, 0xFF00, 0xFF00FF00, 0x12345678, 0x87654321, 0x101, 0x7F0000 };
	int ok;
	int i;
  unsigned k;
	for(i=0; i<sizeof(test_data)/sizeof(test_data[0]); i++) {
		setup_hw_address(test_data[i]);
		k = read_hw_address(&ok);
		if (k != test_data[i]) {
			printf("Error: check_addressing failed %i %0X!=%0X\n", i, test_data[i], k);
			exit(1);
		}
	}
	// Check increment command
	SendComPortString("+++++++");
	k = read_hw_address(&ok);
	if (k != test_data[i-1]+7) {
		printf("Autoincrement test failed.\n");
		exit(1);
	}
	DebugPrintf(2, "Addressing test passed %0X\n", k);
}

void check_writes_reads() {
	unsigned base_addr = 0;
	int ok;
	char *s = "This is our test string to be written to actual memory!";
	int len = strlen(s)+1;
  int i;
  unsigned read_addr;
	char response[256];
	setup_hw_address(base_addr);
	for(i=0; i<len; i++) {
		char buf[4] = { "!_+" };
		buf[1] = s[i];
		SendComPortBlock(buf, 3);
	}
	// verify autoincrement address
	read_addr = read_hw_address(&ok);
	if(read_addr != len+base_addr) {
		printf("Error: check_writes_reads() failed %0X\n", read_addr);
		exit(2);
	}
	DebugPrintf(2, "Memory writes done.\n");
	// verify reading
	setup_hw_address(base_addr);
	ZeroMemory(response, sizeof(response));
	SendComPortString("@");
	for(i=0; i<len; i++) {
		response[i] = RxByte(100);
		SendComPortString("+@");
	}
	response[len] = RxByte(100);
	DebugPrintf(2,"Memory reads done.\n");
	for(i=0; i<len; i++) {
		if(response[i])
			DebugPrintf(2, "%c", response[i]);
		if(response[i] != s[i]) {
			printf("\nError: memory compare failed %X!=%X at %d\n", s[i], response[i], i);
			exit(3);
		}
	}
	DebugPrintf(2,"\nMemory check ok.\n");	
}

void SetRepeatCounter16(int len) {
    unsigned char cmd[3] = { 'T', 0, 0 };
    cmd[1] = len & 0xFF;
    cmd[2] = len >> 8;
    SendComPortBlock(cmd, 3);
}

unsigned GetRepeatCounter() {
  unsigned char buf[2];
  unsigned k;
  // Send read command
  SendComPortString("P");
  // Receive our bytes
  ReceiveComPortBlockComplete(buf, 2, 200);
  k = buf[0] | (buf[1] << 8);
    return k;
}

 void check_repeat_counter() {
   // check reads and writes to repeat counter register.
	unsigned test_data[] = { 0, 1, 0xF0, 0xFFFF, 0x55AA, 0xAA55 };
	int i;
  unsigned k;
	for(i=0; i<sizeof(test_data)/sizeof(test_data[0]); i++) {
    SetRepeatCounter16(test_data[i]);
    k = GetRepeatCounter();
		if (k != test_data[i]) {
			printf("Error: check_counter failed %i wrote %0X!= read %0X\n", i, test_data[i], k);
			exit(1);
		}
	}
    DebugPrintf(2, "Repeat counter test ok\n");
 }

int RunTests()
{
	int ok;
    DebugPrintf(2, "memloader\n");

    OpenSerialPort(); 
    ClearSerialPortBuffers();
	check_sync();
    SendComPortString("M0");  // Disable autoincrement for this
	printf("\tread_hw_addr=0x%08X\n", read_hw_address(&ok));
	setup_hw_address(0x55555555);
	printf("\tread_hw_addr=0x%08X\n", read_hw_address(&ok));
	setup_hw_address(0);
	printf("\tread_hw_addr=0x%08X\n", read_hw_address(&ok));
	setup_hw_address(0x101);
	printf("\tread_hw_addr=0x%08X\n", read_hw_address(&ok));
	check_sync();	
	check_addressing();
	check_sync();
	check_writes_reads();
	check_sync();
  check_repeat_counter();
	check_sync();
    CloseSerialPort();
    return 0;
}


void ReadMemoryBlock(unsigned char *dest, unsigned address, int len) {
  setup_hw_address(address);
  // Enable autoincrement mode and configure length
  SendComPortString("M3");
  SetRepeatCounter16(len);
  // Send read command and read our stuff
  SendComPortString("@");
  ReceiveComPortBlockComplete(dest, len, 2000);
}

int WriteMemoryBlock(unsigned char *source, unsigned address, int len) {
  int chunk = len > 1024 ? 1024 : len;
  setup_hw_address(address);
  // Enable autoincrement mode and configure length
  SendComPortString("M3");
  SetRepeatCounter16(chunk);
  // Send write command and write our stuff
  SendComPortString("!");
  SendComPortBlock(source, chunk);
  check_sync();
  return chunk;
}

int cmd_keys()
{
  char keybuf[8];
  printf("Sending keyboard state codes to TI994A\n");
  OpenSerialPort();
  ClearSerialPortBuffers();
  while (1) {
    // VK_LEFT, VK_SHIFT
    memset(keybuf, 0xff, sizeof(keybuf));
    if (GetAsyncKeyState(VK_LSHIFT) & 0x8000) {
      keybuf[0] &= ~0x20;
    }
    if (GetAsyncKeyState(VK_RSHIFT) & 0x8000) {
      keybuf[0] &= ~0x20;
    }

    if (GetAsyncKeyState(VK_LCONTROL) & 0x8000) {
      keybuf[0] &= ~0x40;
    }
    if ((GetAsyncKeyState(VK_RCONTROL) & 0x8000) || (GetAsyncKeyState(VK_RMENU) & 0x8000)) {
      // printf("FCTN "); // VK_RMENU is actually right alt (alt gr on scandinavian keyboard)
      keybuf[0] &= ~0x10;   // FCTN
    }
    if (GetAsyncKeyState(VK_RETURN) & 0x8000) {
      keybuf[0] &= ~0x04;
    }
    if (GetAsyncKeyState(VK_SPACE) & 0x8000) {
      keybuf[0] &= ~0x02;
    }
    if (GetAsyncKeyState(187) & 0x8000) {
      keybuf[0] &= ~0x01;   // = +
    }
    if (GetAsyncKeyState(188) & 0x8000) {
      keybuf[2] &= ~0x01;   // ,
    }
    if (GetAsyncKeyState(190) & 0x8000) {
      keybuf[1] &= ~0x01;   // .
    }
    if (GetAsyncKeyState(192) & 0x8000) {
      keybuf[5] &= ~0x02;   // ; ö
    }
    if (GetAsyncKeyState(221) & 0x8000) {
      keybuf[5] &= ~0x01;   // / å
    }

    if (GetAsyncKeyState('0') & 0x8000) { keybuf[5] &= ~0x08; }
    if (GetAsyncKeyState('1') & 0x8000) { keybuf[5] &= ~0x10; }
    if (GetAsyncKeyState('2') & 0x8000) { keybuf[1] &= ~0x10; }
    if (GetAsyncKeyState('3') & 0x8000) { keybuf[2] &= ~0x10; }
    if (GetAsyncKeyState('4') & 0x8000) { keybuf[3] &= ~0x10; }
    if (GetAsyncKeyState('5') & 0x8000) { keybuf[4] &= ~0x10; }
    if (GetAsyncKeyState('6') & 0x8000) { keybuf[4] &= ~0x08; }
    if (GetAsyncKeyState('7') & 0x8000) { keybuf[3] &= ~0x08; }
    if (GetAsyncKeyState('8') & 0x8000) { keybuf[2] &= ~0x08; }
    if (GetAsyncKeyState('9') & 0x8000) { keybuf[1] &= ~0x08; }

    if (GetAsyncKeyState('A') & 0x8000) { keybuf[5] &= ~0x20; }
    if (GetAsyncKeyState('B') & 0x8000) { keybuf[4] &= ~0x80; }
    if (GetAsyncKeyState('C') & 0x8000) { keybuf[2] &= ~0x80; }
    if (GetAsyncKeyState('D') & 0x8000) { keybuf[2] &= ~0x20; }
    if (GetAsyncKeyState('E') & 0x8000) { keybuf[2] &= ~0x40; }

    if (GetAsyncKeyState('F') & 0x8000) { keybuf[3] &= ~0x20; }
    if (GetAsyncKeyState('G') & 0x8000) { keybuf[4] &= ~0x20; }
    if (GetAsyncKeyState('H') & 0x8000) { keybuf[4] &= ~0x02; }
    if (GetAsyncKeyState('I') & 0x8000) { keybuf[2] &= ~0x04; }
    if (GetAsyncKeyState('J') & 0x8000) { keybuf[3] &= ~0x02; }
    if (GetAsyncKeyState('K') & 0x8000) { keybuf[2] &= ~0x02; }
    if (GetAsyncKeyState('L') & 0x8000) { keybuf[1] &= ~0x02; }
    if (GetAsyncKeyState('M') & 0x8000) { keybuf[3] &= ~0x01; }
    if (GetAsyncKeyState('N') & 0x8000) { keybuf[4] &= ~0x01; }

    if (GetAsyncKeyState('O') & 0x8000) { keybuf[1] &= ~0x04; }
    if (GetAsyncKeyState('P') & 0x8000) { keybuf[5] &= ~0x04; }
    if (GetAsyncKeyState('Q') & 0x8000) { keybuf[5] &= ~0x40; }
    if (GetAsyncKeyState('R') & 0x8000) { keybuf[3] &= ~0x40; }
    if (GetAsyncKeyState('S') & 0x8000) { keybuf[1] &= ~0x20; }
    if (GetAsyncKeyState('T') & 0x8000) { keybuf[4] &= ~0x40; }
    if (GetAsyncKeyState('U') & 0x8000) { keybuf[3] &= ~0x04; }
    if (GetAsyncKeyState('V') & 0x8000) { keybuf[3] &= ~0x80; }
    if (GetAsyncKeyState('W') & 0x8000) { keybuf[1] &= ~0x40; }
    if (GetAsyncKeyState('X') & 0x8000) { keybuf[1] &= ~0x80; }
    if (GetAsyncKeyState('Y') & 0x8000) { keybuf[4] &= ~0x04; }
    if (GetAsyncKeyState('Z') & 0x8000) { keybuf[5] &= ~0x80; }

    if ((GetAsyncKeyState(VK_LEFT) & 0x8000) || (GetAsyncKeyState(VK_BACK) & 0x8000)) {
      // VK_BACK = backspace
      keybuf[0] &= ~0x10;   // FCTN
      keybuf[1] &= ~0x20; // S
      keybuf[6] &= ~2;      // Joystick 1 left
    }
    if (GetAsyncKeyState(VK_RIGHT) & 0x8000) {
      keybuf[0] &= ~0x10;   // FCTN
      keybuf[2] &= ~0x20;   // D
      keybuf[6] &= ~4;       // Joystick 1 right
    }
    if (GetAsyncKeyState(VK_UP) & 0x8000) {
      keybuf[6] &= ~0x10;       // Joystick 1 up
      printf("UP");
    }
    if (GetAsyncKeyState(VK_DOWN) & 0x8000) {
      keybuf[6] &= ~8;       // Joystick 1 down
      printf("DOWN");
    }
    if (GetAsyncKeyState(VK_NUMPAD0) & 0x8000) {
      keybuf[6] &= ~1;       // Joystick 1 fire
      printf("FIRE");
    }
    if (GetAsyncKeyState(VK_DELETE) & 0x8000) {
      keybuf[0] &= ~0x10;   // FCTN
      keybuf[5] &= ~0x10;   // 1
    }
    if (GetAsyncKeyState(VK_INSERT) & 0x8000) {
      keybuf[0] &= ~0x10;   // FCTN
      keybuf[1] &= ~0x10;   // 2
    }
    if (GetAsyncKeyState(VK_ESCAPE) & 0x8000) {
      keybuf[0] &= ~0x10;   // FCTN
      keybuf[1] &= ~0x08;   // 9  - BACK button on the TI
    }


    if (GetAsyncKeyState(VK_END) & 0x8000) {
      printf("Ending...\n");
      // Clear all input from buffer
      FlushConsoleInputBuffer(GetStdHandle(STD_INPUT_HANDLE));
      // while (!feof(stdin))
      //  getc(stdin);  // read spurious input
      break;
    }

#if 0          
    for (int i = 0; i<255; i++) {
      if (GetAsyncKeyState(i) & 0x8000) {
        printf("%d ", i);
        fflush(stdout);
      }
    }
#endif 

    WriteMemoryBlock(keybuf, 0x100000, 8);

    DoDiskProcess();
  }
  CloseSerialPort();
  return 0;
}

int cmd_singlestep(int k, int argc, char *argv[]) {
  // write to 0x100009 the value of 3 to single step.
  // read from 0x100010 8 bytes of cpu_debug_out bus.
  char step = 3;
  struct {
    unsigned short ir;
    unsigned short pc_ir;
    unsigned short pc;
    unsigned short st;
    unsigned short wr_addr;
    unsigned short wr_data;
    unsigned short alu_arg_dst;
    unsigned short alu_arg_src;
  } cpu_debug_bus;
  OpenSerialPort();
  ClearSerialPortBuffers();
  int count = 1;
  sscanf(argv[k], "%d", &count);
  int i;
  FILE *f = fopen("cputrace.txt", "wt");
  if (f)
    fprintf(f, "line:pc  :addr:data:st  :ir  :adst:asrc\n");
  for (i = 0; i < count; i++) {
    WriteMemoryBlock(&step, 0x100009, 1);
    ReadMemoryBlock(&cpu_debug_bus, 0x100010, 16);
    printf("IR=%04X PC=%04X ST=%04X WA=%04X WD=%04X ALU_DST=%04X ALU_SRC=%04X\n", cpu_debug_bus.ir, cpu_debug_bus.pc, cpu_debug_bus.st, 
      cpu_debug_bus.wr_addr, cpu_debug_bus.wr_data, cpu_debug_bus.alu_arg_dst, cpu_debug_bus.alu_arg_src);
    if (f)
      fprintf(f, "%4d:%04X:%04X:%04X:%04X:%04X:%04X:%04X\n",
        i, cpu_debug_bus.pc, cpu_debug_bus.wr_addr, cpu_debug_bus.wr_data, cpu_debug_bus.st,
        cpu_debug_bus.ir, cpu_debug_bus.alu_arg_dst, cpu_debug_bus.alu_arg_src);
  }
  CloseSerialPort();
  if (f) {
    fclose(f);
    f = NULL;
  }
  return 0;
}

int cmd_regs() {
  int ok;
  ////////////////////////////////////////////////////////////////////
  // Show register status
  ////////////////////////////////////////////////////////////////////
  OpenSerialPort();
  ClearSerialPortBuffers();
  printf("Address: 0x%X\n", read_hw_address(&ok));
  printf("Repeat count: 0x%X\n", GetRepeatCounter());
  SendComPortString("V");
  printf("Version: %c\n", RxByte(200));
  SendComPortString("N");
  printf("Mode: %c\n", RxByte(200));
  SendComPortString("X");
  printf("Ack clocks: %c\n", RxByte(200));
  CloseSerialPort();
  return 0;
}

int cmd_read(int k, int argc, char *argv[]) {
  ////////////////////////////////////////////////////////////////////
  // Read from memory, write to file
  ////////////////////////////////////////////////////////////////////
  unsigned addr = 0;
  unsigned len = 0;
  FILE *f = NULL;
  if (sscanf(argv[k], "%X", &addr) != 1) {
    printf("Unable to decode hex address: %s\n", argv[2]);
    return 10;
  }
  if (sscanf(argv[k+1], "%X", &len) != 1) {
    printf("Unable to decode hex count: %s\n", argv[3]);
    return 10;
  }
  f = fopen(argv[k+2], "wb");
  if (f == NULL) {
    printf("Unable to open destination file: %s\n", argv[4]);
    return 10;
  }
  printf("Reading from 0x%X to %s, count 0x%X\n", addr, argv[4], len);
  OpenSerialPort();
  ClearSerialPortBuffers();
  if (!try_sync()) {
    printf("Unable to sync with hardware.\n");
    CloseSerialPort();
    fclose(f);
    return 11;
  }
  // Now just go and read the stuff.
  {
    unsigned char buf[2048];
    int block_size = sizeof(buf);
    int i = 0;
    int chunk;
    int wrote;
    while (i < len) {
      if ((i & 0xFFF) == 0)
        printf("%d \n", i);
      chunk = block_size;
      if (len - i < chunk)
        chunk = len - i;
      ReadMemoryBlock(buf, addr + i, chunk);
      wrote = fwrite(buf, 1, chunk, f);
      if (wrote != chunk) {
        printf("Error: file write %d != %d\n", wrote, chunk);
      }
      i += chunk;
    }
  }
  fclose(f);
  CloseSerialPort();
  return 0;
}

int cmd_write(int k, int argc, char *argv[]) {
  ////////////////////////////////////////////////////////////////////
  // Read from file, write to memory
  ////////////////////////////////////////////////////////////////////
  // format: memloader <hex-address> <filename>
  unsigned addr = 0;
  int ok;
  FILE *f;
  if (sscanf(argv[k], "%X", &addr) != 1) {
    printf("Unable to decode hex address: %s\n", argv[k]);
    return 10;
  }
  /*
  if (addr & 0xF) {
  printf("Address needs to be aligned at a 16-byte boundary: %s\n", argv[1]);
  return 10;
  }
  */
  f = fopen(argv[k+1], "rb"); 
  if (f == NULL) {
    printf("Unable to open source file: %s\n", argv[2]);
    return 10;
  }
  OpenSerialPort();
  ClearSerialPortBuffers();
  if (!try_sync()) {
    printf("Unable to sync with hardware.\n");
    CloseSerialPort();
    fclose(f);
    return 11;
  }
  setup_hw_address(addr);
  unsigned r;
  if ((r = read_hw_address(&ok)) != addr) {
    printf("Error: address readback returned: %0X\n", r);
    CloseSerialPort();
    fclose(f);
    return 11;
  }
#define BUFSIZE (1024*1024)
  unsigned char *buf = malloc(BUFSIZE);
  unsigned char *p = buf;
  if (!buf) {
    printf("Malloc failed.\n");
    return 12;
  }

  // Modes: M0 - no autoincrement, no repeat
  //        M1 - address autoincrement after write or read, no repeat
  //        M3 - address autoincrement after write or read, repeat operation based on repeat counter
  int autoincrement = 3;
  if (autoincrement) {
    if (opt_verbose)
      printf("Enable autoincrement addressing mode.\n");
    if (autoincrement == 3) {
      if (opt_verbose)
        printf("Enable hardware repeat counter.\n");
      SendComPortString("M3");
    }
    else
      SendComPortString("M1");

  }
  else {
    SendComPortString("M0");
  }
  printf("Loading file %s to address 0x%05X\n", argv[k + 1], addr);
  DWORD now = GetTickCount();
  unsigned wr_addr = addr;

  if (autoincrement == 3) {
    while (p < buf + BUFSIZE) {
      size_t did_read = fread(p, 1, 8192, f);
      if (!did_read)
        break;
      do {
        int wrote = WriteMemoryBlock(p, wr_addr, did_read);
        p += wrote;
        wr_addr += wrote;
        did_read -= wrote;
      } while (did_read > 0);
      if (opt_verbose) {
        printf("%d \r", p - buf);
        fflush(stdout);
      }
    }
    if (opt_verbose)
      printf("\n");
  }
  else {
    setup_hw_address(wr_addr);

    while (p < buf + BUFSIZE) {
      unsigned char buf2[256];
      unsigned char *p2 = buf2;
      size_t did_read = fread(p, 1, 32, f);
      if (!did_read)
        break;
      for (int i = 0; i<did_read; i++) {
        if ((wr_addr & 0x1FF) == 0) {
          setup_hw_address(wr_addr);
          // printf("--addr: 0x%X p-buf=0x%X\n", wr_addr, p-buf);
          check_sync();
        }
        *p2++ = '!';     // store
        *p2++ = *p++; // data byte
        if (!autoincrement)
          *p2++ = '+';     // inc address
        wr_addr++;
      }
      SendComPortBlock(buf2, p2 - buf2);
    }
  }
  fclose(f);
  f = NULL;
  now = GetTickCount() - now;
  if (opt_verbose)
    printf("Wrote %d bytes in %d ms, %dbps\n", p - buf, now, 8 * (p - buf) * 1000 / (now ? now : 1));
  // verify address counter
  check_sync();
  check_sync();
  r = read_hw_address(&ok);
  // Check address, but only lowest 16-bits due to autoincrement being limited to low 16 bits.
  if ((r & 0xFFFF) != ((addr + p - buf) & 0xFFFF)) {
    printf("Error: address counter %X not %X\n", r, addr + p - buf);
  }
  if (opt_verbose)
    printf("Verying written data:\n");
  // Next perform verify operation.
  int fail = 0;
  int block_size = 32;
  autoincrement = 3;    // Test block reading!

  now = GetTickCount();
  int len = p - buf;
  int i = 0;
  setup_hw_address(addr);

  if (autoincrement == 3) {
    // Fetch the return data
    unsigned char minibuf[2048];
    block_size = sizeof(minibuf);

    while (i < len) {
      if (opt_verbose && (i & 0xFFF) == 0) {
        printf("%d \r", i);
        fflush(stdout);
      }
      int chunk = block_size;
      if (len - i < chunk)
        chunk = len - i;
      ReadMemoryBlock(minibuf, addr + i, chunk);
      // Verify the received data.
      for (int j = 0; j<chunk; j++) {
        if (buf[i + j] != minibuf[j]) {
          printf("Verify mismatch: offset %d, %02X != %02X\n", i + j, buf[j + i], minibuf[j]);
          if (++fail == 10) {
            printf("Error: too many failures, stopping.\n");
            return 20;
          }
        }
      }
      i += chunk;
    }

  }
  else {
    char command[512];
    for (i = 0; i<block_size; i++) {
      if (autoincrement)
        command[i] = '@';
      else {
        command[2 * i] = '@';
        command[2 * i + 1] = '+';
      }
    }
    command[i] = 0;

    while (i < len) {
      if ((i & 0xFFF) == 0)
        printf("%d \n", i);
      if ((i & 0xF) == 0)
        setup_hw_address(addr + i);
      if (i + block_size < len) {
        SendComPortString(command);
        // Fetch the return data
        unsigned char minibuf[512];
        ReceiveComPortBlockComplete(minibuf, block_size, 200);
        for (int j = 0; j<block_size; j++) {
          if (buf[i + j] != minibuf[j]) {
            printf("Verify mismatch: offset %d, %02X != %02X\n", i + j, buf[j + i], minibuf[j]);
            if (++fail == 10) {
              printf("Error: too many failures, stopping.\n");
              return 20;
            }
          }
        }
        i += block_size;
      }
      else {
        // byte mode, issue 1 read
        if (autoincrement)
          SendComPortString("@");
        else
          SendComPortString("@+");
        unsigned c = RxByte(100);
        if (c != buf[i]) {
          printf("Verify mismatch: offset %d, %02X != %02X\n", i, buf[i], c);
          if (++fail == 10) {
            printf("Error: too many failures, stopping.\n");
            return 20;
          }
        }
        i++;
      }
    }
  }
  now = GetTickCount() - now;
  if (opt_verbose)
    printf("Verified %d bytes in %d ms, %dbps (block_size %d)\n", p - buf, now, 8 * (p - buf) * 1000 / (now ? now : 1), block_size);
  CloseSerialPort();
  return 0;
}

/***************************** main *************************************/
/**  main. Everything starts from here.
\param [in] argc the number of arguments.
\param [in] argv an array of pointers to the arguments.
*/

int main(int argc, char *argv[])
{
	fc.addr = 0;
  if (argc == 1) {
    printf("Usage: memloader [opts] <hex-address> <filename>    to load a file to RAM.\n");
    printf("       memloader [opts] -r <hex-address> <count> <filename> to read from addess and write to file.\n");
    printf("       memloader [opts] -s     Show current register status.\n");
    printf("       memloader [opts] -t     Run hardware test.\n");
    printf("       memloader [opts] -k     Keyboard polling mode.\n");
    printf("       memloader [opts] -S <count>  Single step, show registers.\n");
    printf("Options (opts) are:\n");
    printf("\t-v verbose mode\n");
    printf("\t-1 Set com port 1 (number can be between 1 and 9)\n");
    return 0;
  }

  enum { c_write, c_read, c_regs, c_test, c_keys, c_fileunittest, c_singlestep } cmd;
  cmd = c_write;

  int i;
  for (i = 1; i < argc; i++) {
    if (argv[i][0] == '-') {
      switch (argv[i][1]) {
      case 'v':
        opt_verbose = 1;
        break;
      case 'r':
        cmd = c_read;
        break;
      case 's':
        cmd = c_regs;
        break;
      case 't':
        cmd = c_test;
        break;
      case 'k':
        cmd = c_keys;
        break;
	    case 'u':
		    cmd = c_fileunittest;
		    break;
      case 'S':
        cmd = c_singlestep;
        break;
      case '1': case '2': case '3': case '4': case '5': 
      case '6': case '7': case '8': case '9': 
        serial_port[3] = argv[i][1];
        if (argv[i][2] >= '0' && argv[i][2] <= '9') {
          serial_port[4] = argv[i][2];
          serial_port[5] = 0;
        }

        break;
      default:
        printf("Unknown option: %s\n", argv[i]);
        return 5;
      }
    }
    else {
      break;  // no more options / commands
    }
  }

  switch (cmd) {
  case c_test:
    printf("Running hardare test\n");
    return RunTests();
  case c_regs:
    return cmd_regs();
  case c_keys:
    return cmd_keys();
  case c_read:
    return cmd_read(i, argc, argv);
  case c_write:
    cmd_write(i, argc, argv);
    break;  // return from below
  case c_singlestep:
    cmd_singlestep(i, argc, argv);
    break;
  case c_fileunittest:
	  {
		int h = open_tifile("DSK1/SCORE", 123, NULL, 0);
		printf("buffer_tifile(%d) returned %d\n", h, buffer_tifile(h));
		dump_records(h);
    // simulate reading
    printf("Testing reading:\n");
    int r;
    do {
      r = read_record(h, NULL);
    } while(r == ERR_NOERROR);
    printf("Stopped, last read returned %d", r);
    // close file
    close_tifile(h);
	  }
	break;
  }
 
  return 0;
}


