--
-- xmemctrl.vhd
--
-- External memory controller for the EP994A design.
-- Erik Piehl (C) 2019-03-14
-- The idea is to package in this module the state machines etc
-- to drive external memory, be that SRAM or SDRAM.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

entity xmemctrl is 
    port (
        clock : in STD_LOGIC;
        reset : in std_logic;   -- active high

		-- SRAM
        SRAM_DAT : inout std_logic_vector(31 downto 0);
        SRAM_ADR : out std_logic_vector(18 downto 0);
        SRAM_CE0 : out std_logic;
        SRAM_CE1 : out std_logic;
        SRAM_WE	 : out std_logic;
        SRAM_OE	 : out std_logic;
        SRAM_BE	 : out std_logic_vector(3 downto 0);

        -- address bus for external memory
		  xaddr_bus  : in std_logic_vector(18 downto 0); 

        -- Flash memory loading (from serial flash)
        flashDataOut    : in std_logic_vector(15 downto 0);
        flashAddrOut    : in std_logic_vector(19 downto 0);
        flashLoading    : in std_logic;
        flashRamWE_n    : in std_logic;

        -- CPU signals
        cpu_holda       : in std_logic;
        MEM_n           : in std_logic;
        WE_n            : in std_logic;
        data_from_cpu   : in std_logic_vector(15 downto 0);
	     read_bus_o      : out std_logic_vector(15 downto 0);	
		  cpu_rd          : in std_logic;
		  cpu_wr_rq       : in std_logic;	-- CPU write request
		  cpu_rd_rq       : in std_logic;	-- CPU read request

        -- memory controller (serloader) signals
        mem_data_out    : in std_logic_vector(7 downto 0);
        mem_data_in     : out std_logic_vector(7 downto 0);
        mem_addr        : in std_logic_vector(31 downto 0);
        mem_read_rq     : in std_logic;
        mem_write_rq    : in std_logic;
        mem_read_ack_o  : out std_logic;
        mem_write_ack_o : out std_logic

    );
end xmemctrl;

architecture behavioral of xmemctrl is
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
	signal ram_cs_n : std_logic;
	signal sram_we_n  : std_logic;
	signal sram_oe_n  : std_logic;
	signal cpu_mem_write_pending : std_logic;
	signal cpu_access : std_logic;		-- when '1' CPU owns the SRAM memory bus	

   signal lastFlashRamWE_n : std_logic;

	signal mem_read_ack		: std_logic;
   signal mem_write_ack    : std_logic;
	signal addr 	 : std_logic_vector(18 downto 0);
	signal read_bus : std_logic_vector(15 downto 0);

begin

	-- Use all 32 bits of RAM, we use CE0 and CE1 to control what chip is active.
	-- The byte enables are driven the same way for both chips.
	SRAM_BE <=  "0000" when cpu_access = '1' or flashLoading = '1' else	-- CPU is always 16-bit, use CE 
			    "1010" when mem_addr(0) = '1' else	-- lowest byte
				"0101";										-- second lowest byte
	SRAM_ADR <= '0' & addr(18 downto 1);	-- addr(0) selects between the two chips
	SRAM_DAT <= -- broadcast 16-bit wide lines when flash loading is active
        flashDataOut & flashDataOut when cpu_access='0' and flashLoading='1' and mem_drive_bus='1' else
        -- broadcast on all byte lanes when memory controller is writing
        mem_data_out & mem_data_out & mem_data_out & mem_data_out when cpu_access='0' and mem_drive_bus='1' else
        -- broadcast on 16-bit wide lanes when CPU is writing
        data_from_cpu & data_from_cpu when cpu_access='1' and MEM_n='0' and WE_n = '0' else
        (others => 'Z');
						
	read_bus <= SRAM_DAT(15 downto 0) when addr(0)='0' else SRAM_DAT(31 downto 16);
	read_bus_o <= read_bus;
						
	SRAM_CE0	<=	(ram_cs_n or addr(0))       when cpu_access = '0' else (MEM_n or addr(0));
	SRAM_CE1	<= (ram_cs_n or (not addr(0))) when cpu_access = '0' else (MEM_n or (not addr(0)));
	SRAM_WE	<=	sram_we_n; 
	SRAM_OE	<=	sram_oe_n; 

	cpu_access <= not cpu_holda;	-- CPU owns the bus except when in hold
    mem_read_ack_o <= mem_read_ack;
    mem_write_ack_o <= mem_write_ack;

    process(clock)
    begin 
        if rising_edge(clock) then
            if reset='1' then 
				mem_state <= idle;
				mem_drive_bus <= '0';
				ram_cs_n <= '1';
				sram_we_n <= '1';
				sram_oe_n <= '1';
				cpu_mem_write_pending <= '0';
		else 
				-- for flash loading, sample the status of flashRamWE_n
				lastFlashRamWE_n <= flashRamWE_n;
				
				if cpu_wr_rq='1' then
					cpu_mem_write_pending <= '1';
				end if;
				
				-- memory controller state machine
				case mem_state is
					when idle =>
						mem_drive_bus <= '0';
						ram_cs_n <= '1';
						sram_we_n <= '1';
						sram_oe_n <= '1';
						mem_read_ack <= '0';
						mem_write_ack <= '0';
						addr <= xaddr_bus;
						if flashLoading = '1' and cpu_holda = '1' and flashRamWE_n='0' and lastFlashRamWE_n='1' then
							-- We are loading from flash memory chip to SRAM.
							-- The total amount is 256K bytes. We perform the following mapping:
							-- 1) First 128K loaded from flash are written from address 0 onwards (i.e. paged module RAM area)
							-- 2) Next 64K are written to 80000 i.e. our 64K GROM area
							-- 3) Last 64K are written to B0000 i.e. our DSR ROM and ROM area.
							-- Note that addresses from flashAddrOut are byte address but LSB set to zero
							if flashAddrOut(17)='0' then
								addr <= "000" & flashAddrOut(16 downto 1);	-- 128K range from 00000
							elsif flashAddrOut(16)='0' then
								addr <= "1000" & flashAddrOut(15 downto 1);	-- 64K range from 80000
							else
								addr <= "1011" & flashAddrOut(15 downto 1);	-- 64K range from B0000
							end if;
							mem_state <= wr0;
							mem_drive_bus <= '1';	-- only writes drive the bus
						elsif mem_write_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							-- normal memory write
							addr <= mem_addr(19 downto 1);	-- setup address
--							cpu_access <= '0';
							mem_state <= wr0;
							mem_drive_bus <= '1';	-- only writes drive the bus
						elsif mem_read_rq = '1' and mem_addr(20)='0' and cpu_holda='1' then
							addr <= mem_addr(19 downto 1);	-- setup address
--							cpu_access <= '0';
							mem_state <= rd0;
							mem_drive_bus <= '0';
						elsif cpu_rd_rq='1' then
							-- init CPU read cycle
--							cpu_access <= '1';	
							mem_state <= cpu_rd0;
							ram_cs_n <= '0';	-- init read cycle
							sram_oe_n <= '0';
							mem_drive_bus <= '0';
						elsif cpu_mem_write_pending = '1' then
							-- init CPU write cycle
--							cpu_access <= '1';
							mem_state <= cpu_wr1;	-- EPEP jump directly to state 1!!!
							ram_cs_n <= '0';	-- initiate write cycle
							sram_we_n <= '0';	
							mem_drive_bus <= '1';	-- only writes drive the bus
							cpu_mem_write_pending <= '0';
						end if;
					when wr0 => 
						ram_cs_n <= '0';	-- issue write strobes
						sram_we_n <= '0';	
						mem_state <= wr1;	
					when wr1 => mem_state <= wr2;	-- waste time
					when wr2 =>							-- terminate memory write cycle
						sram_we_n <= '1';
						ram_cs_n <= '1';
						mem_drive_bus <= '0';
						mem_state <= grace;
						if flashLoading = '0' then
							mem_write_ack <= '1';
						end if;
						
					-- states to handle read cycles
					when rd0 => 
						ram_cs_n <= '0';	-- init read cycle
						sram_oe_n <= '0';
						mem_state <= rd1;
					when rd1 => mem_state <= rd2;	-- waste some time
					when rd2 => 
						if mem_addr(0) = '1' then
							mem_data_in <= read_bus(7 downto 0);
						else
							mem_data_in <= read_bus(15 downto 8);
						end if;
						ram_cs_n <= '1';
						sram_oe_n <= '1';
						mem_state <= grace;	
						mem_read_ack <= '1';
					when grace =>						-- one cycle grace period before going idle.
						mem_state <= idle;			-- thus one cycle when mem_write_rq is not sampled after write.
						mem_read_ack <= '0';
						mem_write_ack <= '0';
						ram_cs_n <= '1';	-- since we can enter here from cache hits, make sure SRAM is deselected
						sram_oe_n <= '1';
						
						
					-- CPU read cycle
					when cpu_rd0 => 
						mem_state <= cpu_rd1;
						if	cpu_rd = '0' then mem_state <= grace; end if;	-- abort if CPU was served by cache
					when cpu_rd1 => 
						mem_state <= cpu_rd2;
						if	cpu_rd = '0' then mem_state <= grace; end if;	-- abort if CPU was served by cache
					when cpu_rd2 =>
						ram_cs_n <= '1';
						sram_oe_n <= '1';
						mem_state <= grace;
						
					-- CPU write cycle
					when cpu_wr0 => mem_state <= cpu_wr1;
					when cpu_wr1 => mem_state <= cpu_wr2;
					when cpu_wr2 =>
						mem_state <= grace;
						sram_we_n <= '1';
						ram_cs_n <= '1';
						mem_drive_bus <= '0';
						mem_state <= grace;
				end case;



            end if;
        end if;
    end process;

end behavioral;