----------------------------------------------------------------------------------
-- ep994a.vhd
--
-- Toplevel module. The design is intended for the Saanlima electronics Pepino
-- FPGA board. The extension pins on that board are connected to an external
-- board (prototype board as of 2016-10-30) housing a TMS99105 microprocessor,
-- it's clock oscillator and a 74LVC245 buffer chip. See schematics for details.
--
-- This file is part of the ep994a design, a TI-99/4A clone 
-- designed by Erik Piehl in October 2016.
-- Erik Piehl, Kauniainen, Finland, speccery@gmail.com
--
-- This is copyrighted software.
-- Please see the file LICENSE for license terms. 
--
-- NO WARRANTY, THE SOURCE CODE IS PROVIDED "AS IS".
-- THE SOURCE IS PROVIDED WITHOUT ANY GUARANTEE THAT IT WILL WORK 
-- FOR ANY PARTICULAR USE. IN NO EVENT IS THE AUTHOR LIABLE FOR ANY 
-- DIRECT OR INDIRECT DAMAGE CAUSED BY THE USE OF THE SOFTWARE.
--
-- Synthesized with Xilinx ISE 14.7.
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
library UNISIM;
use UNISIM.VComponents.all;

--0000..1FFF     Console ROM
--2000..3FFF     (8K, part of 32K RAM expansion)
--4000..5FFF     (Peripheral cards ROM)
--6000..7FFF     Cartridge ROM (module port)
--8000..83FF     Scratchpad RAM (256 bytes, mirrored (partially decoded) across 8000..83FF)
--8400..87FF     Sound chip write
--8800..8BFF     VDP Read (8800 read, 8802 status)
--8C00..8FFF     VDP Write (8C00 write, 8C02 set address)
--9800..9BFF     GROM Read (9800 read, 9802 read addr+1)
--9C00..9FFF     GROM Write (9C00 write data, 9C02 write address)
--A000..FFFF     (24K, part of 32K RAM expansion)
----------------------------------------------------------------------------------
-- CRU map of the TI-99/4A
--0000..0FFE	  Internal use
--1000..10FE	  Unassigned
--1100..11FE	  Disk controller card
--1200..12FE	  Modems
--1300..13FE     RS232 (primary)
--1400..14FE     Unassigned
--1500..15FE     RS232 (secondary)
--1600..16FE     Unassigned
--...
----------------------------------------------------------------------------------
entity ep994a is
    Port ( clock : in  STD_LOGIC;
           rxd : in  STD_LOGIC;
           txd : out  STD_LOGIC;
           led : out  STD_LOGIC_VECTOR (7 downto 0);

			  SWITCH		: in std_logic;
			  
			  -- I/O interfaces
--			  INDATA		: inout std_logic_vector(15 downto 0);	-- TMS99105 multiplexed A/D bus

			  --------------------------------------
			  -- The connection information below is the Pepino FPGA buffer board.
			  -- There were two iterations in my circuit: 
			  -- 	1st I used the board as is, just using the extension connectors
			  --	2nd I cut a few traces and soldered a couple of wires, to free up two I/O pins.
			  --		 This was done by having the LVC16245 buffer chip be operated as a single 16-bit wide
			  --		 buffer instead of two 8 bit buffers.
			  --
			  -- LVC16245 control signals. low = input. Pin numbers for the nRF24L01 connector.
			  -- 			FPGA	label	J7		label		FPGA	
			  ------------------------------------------
			  --				A14	IRQ 	8  7	MISO		C10
			  --	CH1_EN	D8		MOSI 	6  5	SCK		D9		CH1_DIR
			  --	CH2_EN	F9		SS		4  3	NE			C8		CH2_DIR
			  --	   				3V3	2	1	GND
			  --
			  -- two traces on PCB cut: J7-5 (CH1_DIR) and J7-4 (CH2_EN)
			  --------------------------------------
			  
--			  CH1_DIR	: out std_logic;	-- FPGA pin D9 - CUT
--			  CH2_DIR	: out std_logic;	-- FPGA pin C8 
--			  CH1_EN		: out std_logic;	-- FPGA pin D8 
--			  CH2_EN		: out std_logic;	-- FPGA pin F9 - CUT
--			  
--			  -- TMS99105 control signals
--			  ALATCH		: in std_logic;		
			  MEM_n_ext	: in std_logic;		
--			  RD_n		: in std_logic;
			  WE_n_ext	: in std_logic;

			  ----------------------------------------------
			  -- Signals for the PCB
--			  ALATCH    : in std_logic;	-- CPU address latch input
--			  RD_n      : in std_logic;	-- CPU read signal
--			  BUS_OE_n  : out std_logic;	-- when low, 16-bit bus drivers active
--			  BUSDIR 	: out std_logic;	-- direction of 16-bit bus. High=TMS99105 driving the bus
--			  CTRL_RD_n : out std_logic;	-- when IO1N..IO8N contains bus control signals from CPU
--			  CTRL_CP   : out std_logic;  -- rising edge clocks IO1P..IO8P to control latch
			  
			  -- VGA output
			  VGA_HSYNC	: out std_logic;
			  VGA_VSYNC	: out std_logic;
			  VGA_RED	: out std_logic_vector(2 downto 0);
			  VGA_BLUE	: out std_logic_vector(1 downto 0);
			  VGA_GREEN	: out std_logic_vector(2 downto 0);
			  
			  -- DEBUG (PS2 KBD port)
			  DEBUG1		: out std_logic;
			  DEBUG2		: out std_logic;
--			  INTERRUPT	: out std_logic;	-- interrupt to the CPU
--			  CPU_RESET		: out std_logic;
			  
			  -- AUDIO
			  AUDIO_L	: out std_logic;
			  AUDIO_R	: out std_logic;
			  
			  -- SRAM
			  SRAM_DAT	: inout std_logic_vector(31 downto 0);
			  SRAM_ADR	: out std_logic_vector(18 downto 0);
			  SRAM_CE0	: out std_logic;
			  SRAM_CE1	: out std_logic;
			  SRAM_WE	: out std_logic;
			  SRAM_OE	: out std_logic;
			  SRAM_BE	: out std_logic_vector(3 downto 0)
			);
end ep994a;

architecture Behavioral of ep994a is

	 component serloader port (
		  clk 		: in  STD_LOGIC;
		  rst 		: in  STD_LOGIC;
		  tx				: out STD_LOGIC;
		  rx				: in STD_LOGIC;
		  mem_addr 	: out  STD_LOGIC_VECTOR (31 downto 0);
		  mem_data_out : out  STD_LOGIC_VECTOR (7 downto 0);
		  mem_data_in : in  STD_LOGIC_VECTOR (7 downto 0);
		  mem_read_rq : out  STD_LOGIC;
		  mem_read_ack : in  STD_LOGIC;
		  mem_write_rq : out  STD_LOGIC;
		  mem_write_ack : in  STD_LOGIC
		);
	 end component;
 
	
	signal funky_reset 		: std_logic_vector(15 downto 0) := (others => '0');
	signal real_reset			: std_logic;
	signal real_reset_n		: std_logic;
	signal mem_data_out 		: std_logic_vector(7 downto 0);
	signal mem_data_in 		: std_logic_vector(7 downto 0);
	signal mem_addr			: std_logic_vector(31 downto 0);
	signal mem_read_rq		: std_logic;
	signal mem_read_ack		: std_logic;
	signal mem_write_rq		: std_logic;
	signal mem_write_ack		: std_logic;
	-- SRAM memory controller state machine
	type mem_state_type is (
		idle, 
		wr0, wr1, wr2,
		rd0, rd1, rd2,
		grace,
		cpu_wr0, cpu_wr1, cpu_wr2,
		cpu_rd0, cpu_rd1, cpu_rd2
		);
	signal mem_state : mem_state_type := idle;	
	signal mem_drive_bus : std_logic := '0';
	
	type ctrl_state_type is (
		idle, control_write, control_read, ack_end
		);
	signal ctrl_state : ctrl_state_type := idle;
	
	signal debug_sram_ce0 : std_logic;
	signal debug_sram_we  : std_logic;
	signal debug_sram_oe  : std_logic;
	signal sram_addr_bus  : std_logic_vector(18 downto 0); 
	signal sram_16bit_read_bus : std_logic_vector(15 downto 0);	-- choose between (31..16) and (15..0) during reads.
	
	signal clk_ref_ibuf 		: std_logic;
	signal clk 					: std_logic;				-- output primary clock
	signal clk0					: std_logic;
	signal clkfx				: std_logic;
	signal clkfb				: std_logic;
	signal locked_internal	: std_logic;
	signal status_internal  : std_logic_vector(7 downto 0);
	
	-- TMS99105 control signals
	signal cpu_addr			: std_logic_vector(15 downto 0);
	signal cpu_data_out		: std_logic_vector(15 downto 0);	-- data to CPU
	signal cpu_data_in		: std_logic_vector(15 downto 0);	-- data from CPU
--	signal alatch_sampler	: std_logic_vector(15 downto 0);
	signal wr_sampler			: std_logic_vector(3 downto 0);
	signal rd_sampler			: std_logic_vector(3 downto 0);
	signal cruclk_sampler   : std_logic_vector(3 downto 0);
	signal cpu_access			: std_logic;		-- when '1' CPU owns the SRAM memory bus	
	signal outreg				: std_logic_vector(15 downto 0);
	signal mem_to_cpu   		: std_logic_vector(15 downto 0);
	
	-- VDP read and write signals
	signal vdp_wr 				: std_logic;
	signal vdp_rd 				: std_logic;
	signal vga_vsync_int		: std_logic;
	signal vga_hsync_int		: std_logic;
	signal vdp_debug1			: std_logic;
	signal vdp_debug2			: std_logic;
	signal vdp_data_out		: std_logic_vector(15 downto 0);
	signal vdp_interrupt		: std_logic;
	
	-- GROM signals
	signal grom_data_out		: std_logic_vector(7 downto 0);
	signal grom_rd_inc		: std_logic;
	signal grom_we				: std_logic;
	signal grom_ram_addr		: std_logic_vector(19 downto 0);
	signal grom_selected		: std_logic;
	signal grom_rd				: std_logic;
	
	-- Keyboard control
	signal cru9901			: std_logic_vector(31 downto 0) := x"00000000";	-- 32 write bits to 9901, when cru9901(0)='0'
	signal cru9901_timer	: std_logic_vector(15 downto 0) := x"0000";	-- 15 write bits of 9901 when cru9901(0)='1' (bit 0 not used here)
	
	type keyboard_array is array (7 downto 0, 7 downto 0) of std_logic;
	signal keyboard : keyboard_array;
	
	signal cru_read_bit		: std_logic;
	
	-- Reset control
	signal cpu_reset_ctrl	: std_logic_vector(7 downto 0);	-- 8 control signals, bit 0 = reset
	signal cpu_single_step  : std_logic_vector(7 downto 0) := x"00";	-- single stepping. bit 0=1 single step mode, bit 1=1 advance one instruction	
	
	-- Module port banking
	signal basic_rom_bank : std_logic_vector(3 downto 1) := "000";	-- latch ROM selection, 64K ROM support
	signal cartridge_cs	 : std_logic;	-- 0x6000..0x7FFF
	
	-- audio subsystem
	signal dac_data		: std_logic_vector(7 downto 0);	-- data from TMS9919 to DAC input
	signal dac_out_bit	: std_logic;		-- output to pin
	signal tms9919_we		: std_logic;		-- write enable pulse for the audio "chip"
	
	-- disk subsystem
	signal cru1100			: std_logic;		-- disk controller CRU select
	
	-- SAMS memory extension
	signal sams_regs			: std_logic_vector(7 downto 0);
	signal pager_data_in		: std_logic_vector(15 downto 0);
	signal pager_data_out   : std_logic_vector(15 downto 0);
	signal translated_addr  : std_logic_vector(15 downto 0);
	signal paging_enable    : std_logic := '0';
	signal paging_registers : std_logic;
	signal paging_wr_enable : std_logic;
	signal page_reg_read		: std_logic;
	signal paging_enable_cs : std_logic;	-- access to some registers to enable paging etc.
	signal paging_regs_visible : std_logic;	-- when 1 page registers can be accessed
	-- signal pager_extended   : std_logic;
	
	-- TMS99105 Shield control latch signals (written to control latch during control cycle)
	signal conl_led1  : std_logic;	-- IO8P - indata[7]
	signal conl_led2  : std_logic;	-- IO7P - indata[6]
	signal conl_app_n : std_logic;
	signal conl_ready : std_logic;
	signal conl_hold  : std_logic;
	signal conl_nmi   : std_logic;
	signal conl_int   : std_logic;	-- IO2P - indata[1]
	signal conl_reset : std_logic;	-- IO1P - indata[0]
	-- TMS99105 Shield control signal buffer read signals (read during control control cycle)
	signal WE_n			: std_logic;	-- IO1N - indata[8]
	signal MEM_n		: std_logic;	-- IO2N - indata[9]
	signal BST1			: std_logic;	-- IO6N - indata[13]
	signal BST2			: std_logic;	-- IO7N - indata[14]
	signal BST3			: std_logic;	-- IO8N - indata[15]
--	signal bus_oe_n_internal : std_logic;
	-- when to write to places
	signal go_write   : std_logic;
	signal cpu_mem_write_pending : std_logic;
	-- counter of alatch pulses to produce a sign of life of the CPU
	signal alatch_counter : std_logic_vector(19 downto 0);
	
	signal go_cruclk : std_logic;	-- CRUCLK write pulses from the soft TMS9900 core

-------------------------------------------------------------------------------	
-- SRAM debug signals with FPGA CPU
	signal sram_debug : std_logic_vector(63 downto 0);
	signal sram_capture : boolean := False;

-------------------------------------------------------------------------------	
-- Signals from FPGA CPU
-------------------------------------------------------------------------------	
	signal RD_n   : std_logic;
	signal cpu_rd : std_logic;
	signal cpu_wr : std_logic;	
	signal cpu_ready : std_logic;
	signal cpu_iaq : std_logic;
	signal cpu_as : std_logic;
	
	signal cpu_cruin : std_logic;
	signal cpu_cruout : std_logic;
	signal cpu_cruclk : std_logic;
	signal cpu_stuck : std_logic;
	
	signal cpu_hold : std_logic;
	signal cpu_holda : std_logic;
	
	signal cpu_reset : std_logic;
	signal cpu_debug_out : STD_LOGIC_VECTOR (63 downto 0);
	
	signal cpu_int_req : std_logic;
	signal cpu_ic03    : std_logic_vector(3 downto 0) := "0001";
	signal cpu_int_ack : std_logic;
	
-------------------------------------------------------------------------------	
    COMPONENT tms9900
    PORT(
         clk : IN  std_logic;
         reset : IN  std_logic;
         addr : OUT  std_logic_vector(15 downto 0);
         data_in : IN  std_logic_vector(15 downto 0);
         data_out : OUT  std_logic_vector(15 downto 0);
         rd : OUT  std_logic;
         wr : OUT  std_logic;
         ready : IN  std_logic;
         iaq : OUT  std_logic;
         as : OUT  std_logic;
--			test_out : OUT  std_logic_vector(15 downto 0);
--			alu_debug_out : OUT  std_logic_vector(15 downto 0);
--			alu_debug_oper : out STD_LOGIC_VECTOR(3 downto 0);
--			alu_debug_arg1 : OUT  std_logic_vector(15 downto 0);
--			alu_debug_arg2 : OUT  std_logic_vector(15 downto 0);
			int_req	: in STD_LOGIC;		-- interrupt request, active high
			ic03     : in STD_LOGIC_VECTOR(3 downto 0);	-- interrupt priority for the request, 0001 is the highest (0000 is reset)
			int_ack	: out STD_LOGIC;		-- does not exist on the TMS9900, when high CPU vectors to interrupt
			cpu_debug_out : out STD_LOGIC_VECTOR (63 downto 0);	
			cruin		: in STD_LOGIC;
			cruout   : out STD_LOGIC;
			cruclk   : out STD_LOGIC;
			hold     : in STD_LOGIC;
			holda    : out STD_LOGIC;
         stuck : OUT  std_logic
        );
    END COMPONENT;
-------------------------------------------------------------------------------	
	component pager612
		port (  clk 			: in  STD_LOGIC;
				  abus_high		: in  STD_LOGIC_VECTOR (15 downto 12);
				  abus_low  	: in  STD_LOGIC_VECTOR (3 downto 0);
				  dbus_in 		: in  STD_LOGIC_VECTOR (15 downto 0);
				  dbus_out 		: out  STD_LOGIC_VECTOR (15 downto 0);
				  mapen 			: in  STD_LOGIC;	-- 1 = enable mapping
				  write_enable : in  STD_LOGIC;		-- 0 = write to register when sel_regs = 1
				  page_reg_read : in  STD_LOGIC;		-- 0 = read from register when sel_regs = 1
				  translated_addr : out  STD_LOGIC_VECTOR (15 downto 0);
				  access_regs  : in  STD_LOGIC -- 1 = read/write registers	
		);
	end component;
-------------------------------------------------------------------------------
	component gromext is
    Port ( din 	: in  STD_LOGIC_VECTOR (7 downto 0);	-- data in, write bus for addresses
	        dout 	: out  STD_LOGIC_VECTOR (7 downto 0);	-- data out, read bus
           clk 	: in  STD_LOGIC;
           we 		: in  STD_LOGIC;								-- write enable, 1 cycle long
           rd		: in  STD_LOGIC;								-- read signal, may be up for multiple cycles
			  selected : out STD_LOGIC;							-- high when this GROM is enabled during READ
																			-- when high, databus should be driven
           mode 	: in  STD_LOGIC_VECTOR(4 downto 0);		-- A5..A1 (4 bits for GROM base select, 1 bit for register select)
			  reset  : in  STD_LOGIC;
			  addr	: out STD_LOGIC_VECTOR(19 downto 0)		-- 1 megabyte GROM address out
			  );
	end component;
-------------------------------------------------------------------------------
begin
  
 clkin1_buf : IBUFG
  port map
   (O => clk_ref_ibuf,
    I => clock);
  
  
  dcm_sp_inst: DCM_SP
  generic map
   (CLKDV_DIVIDE          => 2.000,
    CLKFX_DIVIDE          => 16,			-- try to multiply by 2 overall to get to 100MHz
    CLKFX_MULTIPLY        => 32,
    CLKIN_DIVIDE_BY_2     => FALSE,
    CLKIN_PERIOD          => 20.00,
    CLKOUT_PHASE_SHIFT    => "NONE",
    CLK_FEEDBACK          => "1X",
    DESKEW_ADJUST         => "SYSTEM_SYNCHRONOUS",
    PHASE_SHIFT           => 0,
    STARTUP_WAIT          => FALSE)
  port map
   -- Input clock
   (CLKIN                 => clk_ref_ibuf,
    CLKFB                 => clkfb,
    -- Output clocks
    CLK0                  => clk0,
    CLK90                 => open,
    CLK180                => open,
    CLK270                => open,
    CLK2X                 => open,
    CLK2X180              => open,
    CLKFX                 => clkfx,
    CLKFX180              => open,
    CLKDV                 => open,
   -- Ports for dynamic phase shift
    PSCLK                 => '0',
    PSEN                  => '0',
    PSINCDEC              => '0',
    PSDONE                => open,
   -- Other control and status signals
    LOCKED                => locked_internal,
    STATUS                => status_internal,
    RST                   => '0',
   -- Unused pin, tie low
    DSSEN                 => '0');

	-- Output buffering
	-------------------------------------
	clkf_buf    : BUFG   port map (O => clkfb, I => clk0);
	clkout1_buf : BUFG   port map (O => clk,   I => clkfx);
	-------------------------------------
	-------------------------------------

	-- Use all 32 bits of RAM, we use CE0 and CE1 to control what chip is active.
	-- The byte enables are driven the same way for both chips.
	SRAM_BE 		<= "0000" when cpu_access = '1' else	-- TMS99105 is always 16-bit, use CE 
						"1010" when mem_addr(0) = '1' else	-- lowest byte
						"0101";										-- second lowest byte
	SRAM_ADR 	<= '0' & sram_addr_bus(18 downto 1);	-- sram_addr_bus(0) selects between the two chips
	SRAM_DAT		<= -- broadcast on all byte lanes when memory controller is writing
						mem_data_out & mem_data_out & mem_data_out & mem_data_out when cpu_access='0' and mem_drive_bus='1' else
						-- broadcast on 16-bit wide lanes when CPU is writing
						cpu_data_in & cpu_data_in when cpu_access='1' and MEM_n='0' and WE_n = '0' else
						(others => 'Z');
						
	sram_16bit_read_bus <= SRAM_DAT(15 downto 0) when sram_addr_bus(0)='0' else SRAM_DAT(31 downto 16);
						
	SRAM_CE0	<=		(debug_sram_ce0 or sram_addr_bus(0))       when cpu_access = '0' else (MEM_n or sram_addr_bus(0));
	SRAM_CE1	<= 	(debug_sram_ce0 or (not sram_addr_bus(0))) when cpu_access = '0' else (MEM_n or (not sram_addr_bus(0)));
	SRAM_WE	<=		debug_sram_we;  -- when cpu_access = '0' else WE_n; 
	SRAM_OE	<=		debug_sram_oe; -- when cpu_access = '0' else RD_n; 	
	
	-------------------------------------
	-- CPU reset out. If either cpu_reset_ctrl(0) or funky_reset(MSB) is zero, put CPU to reset.
	real_reset <= funky_reset(funky_reset'length-1);
	real_reset_n <= not real_reset;
	-- CPU_RESET <= cpu_reset_ctrl(0) and real_reset;
	conl_reset <= cpu_reset_ctrl(0) and real_reset;
	
	cpu_access <= not cpu_holda;	-- CPU owns the bus except when in hold
	
	-------------------------------------
	-- vdp interrupt
	-- INTERRUPT <=  not vdp_interrupt when cru9901(2)='1' else '1';	-- TMS9901 interrupt mask bit
	conl_int <= not vdp_interrupt when cru9901(2)='1' else '1';	-- TMS9901 interrupt mask bit
	-- cartridge memory select
  	cartridge_cs 	<= '1' when MEM_n = '0' and cpu_addr(15 downto 13) = "011" else '0'; -- cartridge_cs >6000..>7FFF
	
	process(clk, switch)
	variable ki : integer range 0 to 7;
	begin
		if rising_edge(clk) then 	-- our 100 MHz clock
			-- reset generation
			if switch = '1' then
				funky_reset <= (others => '0');	-- button on the FPGA board pressed
			else
				funky_reset <= funky_reset(funky_reset'length-2 downto 0) & '1';
			end if;
			-- reset processing
			if funky_reset(funky_reset'length-1) = '0' then
				-- reset activity here
				mem_state <= idle;
				ctrl_state <= idle;
				mem_drive_bus <= '0';
				debug_sram_ce0 <= '1';
				debug_sram_WE <= '1';
				debug_sram_oe <= '1';
				mem_read_ack <= '0';
				mem_write_ack <= '0';
				cru9901 <= x"00000000";
				cru1100 <= '0';
				sams_regs <= (others => '0');
				
				conl_app_n  <= '1';
				conl_ready  <= '1';
				conl_hold 	<= '1';
				conl_nmi 	<= '1';
				
				alatch_counter <= (others => '0');
				
				cpu_mem_write_pending <= '0';
				sram_capture <= True;
				
				cpu_single_step <= x"00";
			else
				-- processing of normal clocks here. We run at 100MHz.
				---------------------------------------------------------
				-- SRAM map (1 mega byte, 0..FFFFF, 20 bit address space)
				---------------------------------------------------------
				--	00000..7FFFF - SAMS RAM 512K
				-- 80000..8FFFF - GROM mapped to this area, 64K (was at 30000)
				-- 90000..AFFFF - Cartridge module port, paged, 64K (was at 70000)
				-- B0000..B7FFF - DSR area, 32K reserved	(was at 60000)
				-- B8000..B8FFF - Scratchpad 	(was at 68000)
				-- BA000..BCFFF - Boot ROM remapped (was at 0)   
				---------------------------------------------------------
				-- The SAMS control bits are set to zero on reset.
				-- sams_regs(0) CRU 1E00: when set, paging registers appear at DSR space >4000..
				-- sams_regs(1) CRU 1E02: when set, paging is enabled
				-- sams_regs(2) CRU 1E04: unused
				-- sams_regs(3) CRU 1E06: unused
				-- The memory paging CRU register control bits can be used
				-- to remove devices from the CPU's address space, revealing the
				-- underlying pageable RAM:
				-- sams_regs(4) CRU 1E08: when set, ROM is out and pageable RAM instead is available
				-- sams_regs(5) CRU 1E0A: when set, cartridge is out and pageable RAM instead is available
				--								  Also writes to cartridge area do not change the cartridge page during this time.
				-- sams_regs(6) CRU 1E0C: when set I/O devices are out and pageable RAM instead is available
				-- sams_regs(7) CRU 1E0E: unused
				-- Also, when disk DSR ROM are not mapped (CRU >1100=0) or SAMS page registers visible (>1E00=0)
				--	the pageable RAM "under" the DSR space is available.
				-- Thus the entire 64K is pageable.
				---------------------------------------------------------
				
				-- Drive SRAM addresses outputs synchronously 
				if cpu_access = '1' then
					if cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' then
						sram_addr_bus <= x"8" & grom_ram_addr(15 downto 1);	-- 0x80000 GROM
					elsif cartridge_cs='1' and sams_regs(5)='0' then
						-- Handle paging of module port at 0x6000 unless sams_regs(5) is set (1E0A)
						sram_addr_bus <= x"9" & basic_rom_bank & cpu_addr(12 downto 1);	-- mapped to 0x90000
					elsif cru1100='1' and cpu_addr(15 downto 13) = "010" then	
						-- DSR's for disk system
						sram_addr_bus <= x"B" & "000" & cpu_addr(12 downto 1);	-- mapped to 0xB0000
					elsif cpu_addr(15 downto 13) = "000" and sams_regs(4) = '0' then
						-- ROM at the bottom of address space not paged unless sams_regs(4) is set (1E08)
						sram_addr_bus <= x"B" & "101" & cpu_addr(12 downto 1);	-- mapped to 0xBA000
					elsif cpu_addr(15 downto 10) = "100000" then
						-- now that paging is introduced we need to move scratchpad (1k here)
						-- out of harm's way. Scartchpad at B8000 to keep it safe from paging.
						sram_addr_bus <= x"B8" & "00" & cpu_addr(9 downto 1);
					else
						-- regular RAM access
						-- Bottom 512K is CPU SAMS RAM for now, so we have 19 bit memory addresses for RAM
						sram_addr_bus <= "0" & translated_addr(6 downto 0) & cpu_addr(11 downto 1);
					end if;
				end if;
				
				if MEM_n = '0' and go_write = '1' 
					and cpu_addr(15 downto 12) /= x"9"			-- 9XXX addresses don't go to RAM
					and cpu_addr(15 downto 11) /= x"8" & '1'	-- 8800-8FFF don't go to RAM
					and cartridge_cs='0' 							-- writes to cartridge region do not go to RAM
					then
						cpu_mem_write_pending <= '1';
				end if;
				
				if cpu_single_step(1 downto 0)="11" and cpu_holda = '0' then
					-- CPU single step is desired, and CPU is out of hold despite cpu_singe_step(0) being '1'.
					-- This must mean that the CPU is started to execute an instruction, so zero out bit 1
					-- which controls the stepping.
					cpu_single_step(1) <= '0';	
				end if;

				-- memory controller state machine
				case mem_state is
					when idle =>
						mem_drive_bus <= '0';
						debug_sram_ce0 <= '1';
						debug_sram_WE <= '1';
						debug_sram_oe <= '1';
						mem_read_ack <= '0';
						mem_write_ack <= '0';
--						cpu_access <= '1';		
						DEBUG2 <= '0';						
						if mem_write_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							-- normal memory write
							sram_addr_bus <= mem_addr(19 downto 1);	-- setup address
--							cpu_access <= '0';
							mem_state <= wr0;
							mem_drive_bus <= '1';	-- only writes drive the bus
						elsif mem_read_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							sram_addr_bus <= mem_addr(19 downto 1);	-- setup address
--							cpu_access <= '0';
							mem_state <= rd0;
							mem_drive_bus <= '0';
						elsif MEM_n = '0' and rd_sampler(1 downto 0) = "10" then
							-- init CPU read cycle
--							cpu_access <= '1';	
							mem_state <= cpu_rd0;
							debug_sram_ce0 <= '0';	-- init read cycle
							debug_sram_oe <= '0';
							mem_drive_bus <= '0';
						elsif cpu_mem_write_pending = '1' then
							-- init CPU write cycle
--							cpu_access <= '1';
							mem_state <= cpu_wr1;	-- EPEP jump directly to state 1!!!
							debug_sram_ce0 <= '0';	-- initiate write cycle
							debug_sram_WE <= '0';	
							mem_drive_bus <= '1';	-- only writes drive the bus
							DEBUG2 <= '1';
							cpu_mem_write_pending <= '0';
						end if;
					when wr0 => 
						debug_sram_ce0 <= '0';	-- issue write strobes
						debug_sram_WE <= '0';	
						mem_state <= wr1;	
					when wr1 => mem_state <= wr2;	-- waste time
					when wr2 =>							-- terminate memory write cycle
						debug_sram_WE <= '1';
						debug_sram_ce0 <= '1';
						mem_drive_bus <= '0';
						mem_state <= grace;
						mem_write_ack <= '1';
						
					-- states to handle read cycles
					when rd0 => 
						debug_sram_ce0 <= '0';	-- init read cycle
						debug_sram_oe <= '0';
						mem_state <= rd1;
					when rd1 => mem_state <= rd2;	-- waste some time
					when rd2 => 
						if mem_addr(0) = '1' then
							mem_data_in <= sram_16bit_read_bus(7 downto 0);
						else
							mem_data_in <= sram_16bit_read_bus(15 downto 8);
						end if;
						debug_sram_ce0 <= '1';
						debug_sram_oe <= '1';
						mem_state <= grace;	
						mem_read_ack <= '1';
					when grace =>						-- one cycle grace period before going idle.
						mem_state <= idle;			-- thus one cycle when mem_write_rq is not sampled after write.
						mem_read_ack <= '0';
						mem_write_ack <= '0';
						
					-- CPU read cycle
					when cpu_rd0 => mem_state <= cpu_rd1;
					when cpu_rd1 => 
						mem_state <= cpu_rd2;
						mem_to_cpu <= sram_16bit_read_bus(15 downto 0);
						if sram_capture then
							sram_capture <= False;
							sram_debug <= cpu_addr & "00000000000" & cpu_access & sram_addr_bus & '0' & sram_16bit_read_bus(15 downto 0);
						end if;
					when cpu_rd2 =>
						debug_sram_ce0 <= '1';
						debug_sram_oe <= '1';
						mem_state <= grace;
						
					-- CPU write cycle
					when cpu_wr0 => mem_state <= cpu_wr1;
					when cpu_wr1 => mem_state <= cpu_wr2;
					when cpu_wr2 =>
						mem_state <= grace;
						debug_sram_WE <= '1';
						debug_sram_ce0 <= '1';
						mem_drive_bus <= '0';
						mem_state <= grace;
				end case;
				
				-- Handle control state transfer is a separate
				-- state machine in order not to disturb the TMS99105.
				case ctrl_state is 
					when idle =>
						if mem_read_rq = '1' and mem_addr(20)='1' then
							if mem_addr(4 downto 3) = "00" then
								-- read keyboard matrix (just for debugging)
								ki := to_integer(unsigned(mem_addr(2 downto 0)));
								mem_data_in(0) <= keyboard(ki, 0);
								mem_data_in(1) <= keyboard(ki, 1);
								mem_data_in(2) <= keyboard(ki, 2);
								mem_data_in(3) <= keyboard(ki, 3);
								mem_data_in(4) <= keyboard(ki, 4);
								mem_data_in(5) <= keyboard(ki, 5);
								mem_data_in(6) <= keyboard(ki, 6);
								mem_data_in(7) <= keyboard(ki, 7);
							else
								case mem_addr(4 downto 0) is
									when "01000" => mem_data_in <= cpu_reset_ctrl;
									when "01001" => mem_data_in <= cpu_single_step;
									when "10000" => mem_data_in <= cpu_debug_out(7 downto 0);
									when "10001" => mem_data_in <= cpu_debug_out(15 downto 8);
									when "10010" => mem_data_in <= cpu_debug_out(23 downto 16);
									when "10011" => mem_data_in <= cpu_debug_out(31 downto 24);
									when "10100" => mem_data_in <= cpu_debug_out(39 downto 32);
									when "10101" => mem_data_in <= cpu_debug_out(47 downto 40);									
									when "10110" => mem_data_in <= cpu_debug_out(55 downto 48);
									when "10111" => mem_data_in <= cpu_debug_out(63 downto 56);
									when "11000" => mem_data_in <= sram_debug(7 downto 0);
									when "11001" => mem_data_in <= sram_debug(15 downto 8);
									when "11010" => mem_data_in <= sram_debug(23 downto 16);
									when "11011" => mem_data_in <= sram_debug(31 downto 24);
									when "11100" => mem_data_in <= sram_debug(39 downto 32);
									when "11101" => mem_data_in <= sram_debug(47 downto 40);									
									when "11110" => mem_data_in <= sram_debug(55 downto 48);
									when "11111" => mem_data_in <= sram_debug(63 downto 56);									
									when others =>
										mem_data_in <= x"AA";
								end case;
							end if;
							ctrl_state <= control_read;
						elsif mem_write_rq = '1' and mem_addr(20)='1' then 
							ctrl_state <= control_write;
						end if;
					when control_read =>
						mem_read_ack <= '1';
						ctrl_state <= ack_end;
					when ack_end =>
						mem_read_ack <= '0';
						mem_write_ack <= '0';
						ctrl_state <= idle;
					when control_write =>
						if mem_addr(3) = '0' then 
							ki := to_integer(unsigned(mem_addr(2 downto 0)));
							keyboard(ki, 0) <= mem_data_out(0);
							keyboard(ki, 1) <= mem_data_out(1);
							keyboard(ki, 2) <= mem_data_out(2);
							keyboard(ki, 3) <= mem_data_out(3);
							keyboard(ki, 4) <= mem_data_out(4);
							keyboard(ki, 5) <= mem_data_out(5);
							keyboard(ki, 6) <= mem_data_out(6);
							keyboard(ki, 7) <= mem_data_out(7);
						else
							-- CPU reset control register
							if mem_addr(2 downto 0) = "000" then 
								cpu_reset_ctrl <= mem_data_out;
							elsif mem_addr(2 downto 0) = "001" then 
								cpu_single_step <= mem_data_out;
							end if;
						end if;
						mem_write_ack <= '1';
						ctrl_state <= ack_end;
				end case;
				
				if cpu_reset_ctrl(1)='0' then
					basic_rom_bank <= "000";	-- Reset ROM bank selection
				end if;
				
				
				-- CPU signal samplers
				if cpu_as='1' then
					alatch_counter <= std_logic_vector(to_unsigned(1+to_integer(unsigned(alatch_counter)), alatch_counter'length));
				end if;
				wr_sampler <= wr_sampler(wr_sampler'length-2 downto 0) & WE_n;
				rd_sampler <= rd_sampler(rd_sampler'length-2 downto 0) & RD_n;
				cruclk_sampler <= cruclk_sampler(cruclk_sampler'length-2 downto 0) & cpu_cruclk;
				vdp_wr <= '0';
				vdp_rd <= '0';
				grom_we <= '0';
				tms9919_we <= '0';
				paging_wr_enable <= '0';
				if sams_regs(6)='0' then	-- if sams_regs(6) is set I/O is out and paged RAM is there instead
					if go_write = '1' and MEM_n='0' then
						if cpu_addr(15 downto 8) = x"80" then
							outreg <= cpu_data_in;			-- write to >80XX is sampled in the output register
						elsif cpu_addr(15 downto 8) = x"8C" then
							vdp_wr <= '1';
						elsif cpu_addr(15 downto 8) = x"9C" then
							grom_we <= '1';			-- GROM writes
						elsif cartridge_cs='1' and sams_regs(5)='0' then
							basic_rom_bank <= cpu_addr(3 downto 1);	-- capture ROM bank select
						elsif cpu_addr(15 downto 8) = x"84" then	
							tms9919_we <= '1';		-- Audio chip write
						elsif paging_registers = '1' then 
							paging_wr_enable <= '1';
						end if;
					end if;	
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and cpu_addr(15 downto 8)=x"88" then
						vdp_rd <= '1';
					end if;
					grom_rd <= '0';
					if MEM_n='0' and rd_sampler(1 downto 0)="00" and cpu_addr(15 downto 8) = x"98" then
						grom_rd <= '1';
					end if;
				end if;
				
				-- CRU cycle to TMS9901
				if MEM_n='1' and cpu_addr(15 downto 8)=x"00" and go_cruclk = '1' then

					if cru9901(0) = '1' and cpu_addr(5)='0' and cpu_addr(4 downto 1) /= "0000" then
						-- write to timer bits (not bit 0)
						cru9901_timer(to_integer(unsigned(cpu_addr(4 downto 1)))) <= cpu_cruout;
					else
						-- write to main register
						cru9901(to_integer(unsigned(cpu_addr(5 downto 1)))) <= cpu_cruout;
					end if;

				end if;
				
				-- CRU write cycle to disk control system
				if MEM_n='1' and cpu_addr(15 downto 1)= x"110" & "000" and go_cruclk = '1' then
					cru1100 <= cpu_cruout;
				end if;
				-- SAMS register writes
				if MEM_n='1' and cpu_addr(15 downto 4) = x"1E0" and go_cruclk = '1' then
					sams_regs(to_integer(unsigned(cpu_addr(3 downto 1)))) <= cpu_cruout;
				end if;				
				
				-- Precompute cru_read_bit in case this cycle is a CRU read 
				cru_read_bit <= '1';
--				if cru9901(20 downto 18)="101" and cpu_addr(15 downto 1) & '0' = x"000E" then
--					-- key "1" CRU is connected to switch
--					cru_read_bit <= '1';
--					if switch = '1' or keyboard(5, 4)='0' then
--						cru_read_bit <= '0';
--					end if;
--				els
				if cpu_addr(15 downto 1) & '0' >= 6 and cpu_addr(15 downto 1) & '0' < 22 then
					-- 6 = 0110
					--	8 = 1000
					-- A = 1010 
					ki := to_integer(unsigned(cpu_addr(3 downto 1))) - 3; -- row select on address
					cru_read_bit <= keyboard(to_integer(unsigned(cru9901(20 downto 18))), ki); -- column select on multiplexor select
				elsif cpu_addr(15 downto 1) & '0' >= 6 and cpu_addr(15 downto 1) & '0' < 22 then
					-- 6 = 0110
					--	8 = 1000
					-- A = 1010 
					ki := to_integer(unsigned(cpu_addr(3 downto 1))) - 3; -- row select on address
					cru_read_bit <= keyboard(to_integer(unsigned(cru9901(20 downto 18))), ki); -- column select on multiplexor select
				elsif cpu_addr(15 downto 1) & '0' = x"0004" then
					cru_read_bit <= not vdp_interrupt; -- VDP interrupt status (read with TB 2 instruction)
				elsif cpu_addr(15 downto 1) & '0' = x"0000" then
					cru_read_bit <= cru9901(0);
				elsif cpu_addr(15 downto 5) = "00000000001" then
					-- TMS9901 bits 16..31, addresses 20..3E
					cru_read_bit <= cru9901(to_integer(unsigned('1' & cpu_addr(4 downto 1))));
				elsif cpu_addr(15 downto 1) & '0' = x"1100" then
					cru_read_bit <= cru1100;
				elsif cpu_addr(15 downto 4) = x"1E0" then
					cru_read_bit <= sams_regs(to_integer(unsigned(cpu_addr(3 downto 1))));
				end if;
			end if;
		end if;	-- rising_edge
	end process;
	
		
	command_processor : serloader port map (
		clk 		=> clk,
		rst 		=> real_reset_n,
		tx			=> txd,
		rx			=> rxd,
		mem_addr 		=> mem_addr,
		mem_data_out 	=> mem_data_out,
		mem_data_in		=> mem_data_in,
		mem_read_rq 	=> mem_read_rq,
		mem_read_ack 	=> mem_read_ack,
		mem_write_rq 	=> mem_write_rq,
		mem_write_ack	=> mem_write_ack	
		);
		
	-- led <= outreg(15 downto 8);
	led(0) <= cpu_reset;
	led(1) <= cpu_hold;
	led(2) <= cpu_holda;
	led(3) <= cpu_rd;
	led(4) <= cpu_stuck;
	led(5) <= cpu_wr;
	led(6) <= '1';
	led(7) <= alatch_counter(19);
	
	
	cpu_hold <= '1' when mem_read_rq='1' or mem_write_rq='1' or (cpu_single_step(0)='1' and cpu_single_step(1)='0') else '0'; -- issue DMA request

	-- TMS99105 CPU interface.
--	BUSDIR <= RD_n;	-- Bus buffers towards TMS99105 only during read cycle
--	bus_oe_n_internal <= '1' when alatch_sampler(2) = '1' and alatch_sampler(5) = '0' else '0'; -- only four clock cycles during which indata buffers are disabled
--	BUS_OE_n <= bus_oe_n_internal;
--	CTRL_RD_n <= not bus_oe_n_internal;	-- Control bits readable when addr/data buffers are off
--	CTRL_CP <= '1' when alatch_sampler(4) = '1' and alatch_sampler(6) = '0' else '0';	-- issue clock pulse	
	-- FPGA drivers follow RD_n except during control signal operations (CTRL_RD_n = '0')
--	INDATA <= "ZZZZZZZZ" & conl_led1 & conl_led2 & conl_app_n & conl_ready & conl_hold & conl_nmi & conl_int & conl_reset when bus_oe_n_internal='1'
--		else "ZZZZZZZZZZZZZZZZ" when RD_n = '1'
--		else cpu_data_out;
		
	DEBUG1 <= go_write;
--	WE_n <= WE_n_ext;
	
	go_write <= '1' when wr_sampler = "1000" else '0'; -- wr_sampler = "1110" else '0';
	go_cruclk <= '1' when cruclk_sampler(1 downto 0) = "01" else '0';


	-- Here drive the two shield board LEDs to include a little status information:
	-- LED1: Disk access
	-- LED2: ALATCH counter indication (i.e. CPU is alive)
	conl_led1 <= cru1100;
	conl_led2 <= alatch_counter(19);
	
	
--	-- Control LVC16245 direction and output enables.
--	-- ALATCH, MEN_n, RD_n, WE_n are control signals that we always receive from the CPU.
--	-- The LVC16245 is in input mode, i.e. driving from CPU to FPGA, always except when #RD is low.
--	CH1_DIR <= 'Z'; -- trace cut not RD_n;		-- CH1_DIR='0' means input, '1' means output i.e. serving CPU reads.
--	CH2_DIR <= not RD_n;
--	INDATA <= "ZZZZZZZZZZZZZZZZ" when RD_n = '1' else cpu_data_out;	-- FPGA drivers follow RD_n
--	-- Enable signals for the LVC16245
--	CH1_EN <= '0';
--	CH2_EN <= 'Z'; -- TRACE CUT '0'; 
	
	cpu_data_out <= 
		vdp_data_out         			when sams_regs(6)='0' and cpu_addr(15 downto 10) = "100010" else	-- 10001000..10001011 (8800..8BFF)
		grom_data_out & x"00" 			when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='1' else	-- GROM address read
		pager_data_out(7 downto 0) & pager_data_out(7 downto 0) when paging_registers = '1' else	-- replicate pager values on both hi and lo bytes
		sram_16bit_read_bus(15 downto 8) & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='0' and grom_selected='1' else
		sram_16bit_read_bus(7 downto 0)  & x"00" when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_ram_addr(0)='1' and grom_selected='1' else
	   x"FF00"                       when sams_regs(6)='0' and cpu_addr(15 downto 8) = x"98" and cpu_addr(1)='0' and grom_selected='0' else
		-- CRU space signal reads
		cru_read_bit & "000" & x"000"	when MEM_n='1' else
		x"FFF0"								when MEM_n='1' else -- other CRU
		-- line below commented, paged memory repeated in the address range as opposed to returning zeros outside valid range
		--	x"0000"							when translated_addr(15 downto 6) /= "0000000000" else -- paged memory limited to 256K for now
		sram_16bit_read_bus(15 downto 0);		-- data to CPU
	
 	vdp: entity work.tms9918
		port map(
		clk 		=> clk,		
		reset 	=> real_reset_n,	
		mode 		=> cpu_addr(1),
		addr		=> cpu_addr(8 downto 1),
		data_in 	=> cpu_data_out(15 downto 8),
		data_out => vdp_data_out,
		wr 		=> vdp_wr,	
		rd 		=> vdp_rd,
		vga_vsync	 => vga_vsync_int,
		vga_hsync	 => vga_hsync_int,
		debug1		=> vdp_debug1,
		debug2		=> vdp_debug2,
		vga_red 		 => VGA_RED,
		vga_green	 => VGA_GREEN,
		vga_blue		 => VGA_BLUE,
		int_out	=> vdp_interrupt
		);			
		
	VGA_VSYNC <= vga_vsync_int;
	VGA_HSYNC <= vga_hsync_int;
	
	-- GROM implementation - GROM's are mapped to external RAM
	extbasgrom : entity work.gromext port map (
			clk 		=> clk,
			din 		=> cpu_data_out(15 downto 8),
			dout		=> grom_data_out,
			we 		=> grom_we,
			rd 		=> grom_rd,
			selected => grom_selected,	-- output from GROM available, i.e. GROM address is ours
			mode 		=> cpu_addr(5 downto 1),
			reset 	=> real_reset_n,
			addr 		=> grom_ram_addr
		);

	-- sound chip implementation
	TMS9919_CHIP: entity work.tms9919 port map (
			clk 		=> clk,
			reset		=> real_reset_n,
			data_in 	=> cpu_data_out(15 downto 8),
			we			=> tms9919_we,
			dac_out	=> dac_data
		);
		
	MY_DAC : entity work.dac port map (
			clk_i   	=> clk,
         res_n_i 	=> funky_reset(funky_reset'length-1),
         dac_i   	=> dac_data,
         dac_o   	=> dac_out_bit
		);
		
	AUDIO_L <= dac_out_bit;
	AUDIO_R <= dac_out_bit;
	
	-- memory paging unit implementation
	paging_regs_visible 	<= sams_regs(0);			-- 1E00 in CRU space
	paging_enable 			<= sams_regs(1);			-- 1E02 in CRU space
	
	-- the pager registers can be accessed at >4000 to >5FFF when paging_regs_visible is set
	paging_registers <= '1' when paging_regs_visible = '1' and MEM_n = '0' and cpu_addr(15 downto 13) = "010" else '0';
	page_reg_read <= '1' when paging_registers = '1' and RD_n='0' else '0';	

	pager_data_in <= x"00" & cpu_data_out(15 downto 8);	-- my own extended mode not supported here

	pager : pager612 port map (
		clk		 => clk,
		abus_high => cpu_addr(15 downto 12),
		abus_low  => cpu_addr(4 downto 1),
		dbus_in   => pager_data_in,
		dbus_out  => pager_data_out,
		mapen 	 => paging_enable,				-- ok
		write_enable	 => paging_wr_enable,	-- ok
		page_reg_read   => page_reg_read,
		translated_addr => translated_addr,		-- ok
		access_regs     => paging_registers		-- ok
		);	
		
	MEM_n <= not (cpu_rd or cpu_wr);
	WE_n <= not cpu_wr;
	RD_n <= not cpu_rd;
	cpu_cruin <= cru_read_bit;
	cpu_reset <= not (cpu_reset_ctrl(0) and real_reset);
	cpu_int_req <= not conl_int;
	
	cpu : tms9900 PORT MAP (
          clk => clk,
          reset => cpu_reset,
          addr => cpu_addr,
          data_in => cpu_data_out,
          data_out => cpu_data_in,
          rd => cpu_rd,
          wr => cpu_wr,
          ready => cpu_ready,
          iaq => cpu_iaq,
          as => cpu_as,
--			 test_out => test_out,
--			 alu_debug_out => alu_debug_out,
--			 alu_debug_oper => alu_debug_oper,
--			 alu_debug_arg1 => alu_debug_arg1,
--			 alu_debug_arg2 => alu_debug_arg2,
			 int_req => cpu_int_req,
			 ic03 => cpu_ic03,
			 int_ack => cpu_int_ack,
		    cpu_debug_out => cpu_debug_out,
			 cruin => cpu_cruin,
			 cruout => cpu_cruout,
			 cruclk => cpu_cruclk,
			 hold => cpu_hold,
			 holda => cpu_holda,
          stuck => cpu_stuck
        );
		
end Behavioral;

