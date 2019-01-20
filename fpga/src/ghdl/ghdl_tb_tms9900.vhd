--------------------------------------------------------------------------------
-- Company: 
-- Engineer:
--
-- Create Date:   15:24:49 04/02/2017
-- Design Name:   
-- Module Name:   C:/Users/Erik Piehl/Dropbox/Omat/trunk/EP994A/fpga/src/tb_tms9900.vhd
-- Project Name:  ep994a
-- Target Device:  
-- Tool versions:  
-- Description:   
-- 
-- VHDL Test Bench Created by ISE for module: tms9900
-- 
-- Dependencies:
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
--
-- Notes: 
-- This testbench has been automatically generated using types std_logic and
-- std_logic_vector for the ports of the unit under test.  Xilinx recommends
-- that these types always be used for the top-level I/O of a design in order
-- to guarantee that the testbench will bind correctly to the post-implementation 
-- simulation model.
--------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
USE ieee.numeric_std.ALL;

library std;
USE STD.TEXTIO.ALL;
USE ieee.std_logic_textio.ALL;	-- needed for xilinx ise "hwrite"
-- EP GHDL USE IEEE.STD_LOGIC_TEXTIO.ALL;
 
ENTITY tb_tms9900 IS
END tb_tms9900;
 
ARCHITECTURE behavior OF tb_tms9900 IS 
	 
	 COMPONENT TESTROM
	 PORT (
		clk : IN  std_logic;
      addr : in  STD_LOGIC_VECTOR (11 downto 0);
      data_out : out  STD_LOGIC_VECTOR (15 downto 0));
	 END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal data_in : std_logic_vector(15 downto 0) := (others => '0');
   signal ready : std_logic := '0';
	signal cruin : std_logic := '0';
	signal int_req	: STD_LOGIC := '0';		-- interrupt request, active high
	signal ic03    : STD_LOGIC_VECTOR(3 downto 0) := "0001";	-- interrupt priority for the request, 0001 is the highest (0000 is reset)
	signal int_ack : STD_LOGIC;

 	--Outputs
   signal addr : std_logic_vector(15 downto 0);
   signal data_out : std_logic_vector(15 downto 0);
   signal rd : std_logic;
   signal wr : std_logic;
   signal iaq : std_logic;
   signal as : std_logic;
	signal cpu_debug_out : STD_LOGIC_VECTOR (95 downto 0);
--	signal test_out : STD_LOGIC_VECTOR (15 downto 0);
--	signal alu_debug_out : STD_LOGIC_VECTOR (15 downto 0);
--	signal alu_debug_oper : STD_LOGIC_VECTOR (3 downto 0);
	signal alu_debug_arg1 : STD_LOGIC_VECTOR (15 downto 0);
	signal alu_debug_arg2 : STD_LOGIC_VECTOR (15 downto 0);
	signal mult_debug_out : STD_LOGIC_VECTOR (35 downto 0);
	signal cruout : std_logic;
	signal cruclk : std_logic;
   signal stuck : std_logic;
	signal hold : std_logic := '0';
	signal holda : std_logic;
	signal rd_now : std_logic;
	
	signal cpu_st : std_logic_vector(15 downto 0);

   -- Clock period definitions
   constant clk_period : time := 10 ns;

	signal rom_data : STD_LOGIC_VECTOR (15 downto 0);
	
	-- RAM block to 8300
	type ramArray is array (0 to 127) of STD_LOGIC_VECTOR (15 downto 0);
	signal scratchpad : ramArray;
	signal ramIndex : integer range 0 to 15 := 0;
	signal write_detect : std_logic_vector(1 downto 0);
	signal read_detect : std_logic_vector(1 downto 0);	-- used for all reads during debugging
	
	signal prev_cruclk : std_logic;
	
--	constant cru_test_data : std_logic_vector(15 downto 0) := x"A379";
	signal cru_test_data : std_logic_vector(15 downto 0) := x"A379";
	signal opcode_read : boolean := false;

-- read detect to only print opcode fetches once
	signal read_history : std_logic_vector(2 downto 0);
-- counter for clocks per instruction
	signal ins_clocks : integer := 0;
	signal last_clocks : integer := 0;
	signal write_act_clocks : integer := 0; -- counts clocks with write active
	signal read_act_clocks : integer := 0; -- counts clocks with write active
	signal last_read_act_clocks : integer := 0;
	signal last_write_act_clocks : integer := 0;
	
	signal memory_reads : integer := 0;
	signal memory_reads_hit : integer := 0; -- calculate cache hits

	-- cache signals
	signal cache_data_in  : std_logic_vector(15 downto 0);
	signal cache_data_out : std_logic_vector(15 downto 0);
	signal cpu_data_in    : std_logic_vector(15 downto 0);
	signal cacheable 		 : std_logic := '1';	-- 1 means cache is enabled
	signal cache_hit      : std_logic;
	signal cache_miss     : std_logic;
	signal cache_update   : std_logic := '0';
	signal cache_reset_done : std_logic;
	signal cache_addr_in  : std_logic_vector(19 downto 0);
	signal cpu_reset      : std_logic;
	signal wr_force		 : std_logic;	-- force a write to the cache from CPU
	signal cache_wr		 : std_logic;
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: entity work.tms9900 PORT MAP (
          clk => clk,
          reset => cpu_reset,
          addr_out => addr,
          data_in => data_in,
          data_out => data_out,
          rd => rd,
          wr => wr,
			 rd_now => rd_now,
			 wr_force => wr_force,
			 cache_hit => cache_hit,
          -- ready => ready,
          iaq => iaq,
          as => as,
--			 test_out => test_out,
--			 alu_debug_out => alu_debug_out,
--			 alu_debug_oper => alu_debug_oper,
			 alu_debug_arg1 => alu_debug_arg1,
			 alu_debug_arg2 => alu_debug_arg2,
			 mult_debug_out => mult_debug_out,
			 cpu_debug_out => cpu_debug_out,
			 int_req => int_req,
			 ic03 => ic03,
			 int_ack => int_ack,
			 cruin => cruin,
			 cruout => cruout,
			 cruclk => cruclk,
			 hold => hold,
			 holda => holda,
			 waits => "00000000", -- "111111", -- "000000",
          stuck => stuck
        );
		  
	ROM: TESTROM PORT MAP(
		clk => clk,
		addr => addr(12 downto 1),
		data_out => rom_data
		);

	cache_addr_in <= "0000" & addr;
	cpu_reset <= not cache_reset_done or reset;

	cache: entity work.epcache PORT MAP ( 
		clk => clk,
		reset => reset,
		reset_done => cache_reset_done, 
	   cacheable => cacheable,
	   update => cache_update,
		data_in =>  cache_data_in, -- data_out,
		data_out => cache_data_out, 
		addr_in => cache_addr_in,
		hit => cache_hit,
		-- hit_async => cache_hit,
		miss => cache_miss,
		rd => rd,
		wr => cache_wr
	);
	
	-------------------------
	-- control cache stuff --
	-------------------------
	-- feed write data to cache during writes, otherwise whatever CPU is reading.
	cache_data_in 	<= data_out when wr='1' or wr_force='1' else data_in; 	
	cpu_data_in 	<= cache_data_out when cache_hit='1' and rd='1' else data_in;
	cache_update	<= '1' when cacheable='1' and rd_now='1' and cache_miss='1' else '0';
	cache_wr 		<= wr or wr_force;

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
		ins_clocks <= ins_clocks + 1;
		if rd='1' then 
			read_act_clocks <= read_act_clocks + 1;
		end if;
		if wr='1' then 
			write_act_clocks <= write_act_clocks + 1;
		end if;
   end process;
	
   -- Stimulus process
   stim_proc: process
	variable addr_int : integer range 0 to 32767 := 0;
	variable my_line : line;	-- from textio
	variable myindex : natural range 0 to 15;	

	procedure show_instruction(
			constant cycle : in integer;
			signal iaq   : in std_logic;
			signal dat   : in std_logic_vector(15 downto 0) ) is 
	begin
		if iaq = '1' then
			-- Instruction display, CPU is performing an instruction fetch cycle
			write(my_line, cycle, right, 6);
			write(my_line, ins_clocks - last_clocks, right, 6);
			write(my_line, read_act_clocks - last_read_act_clocks, right, 3);
			write(my_line, write_act_clocks - last_write_act_clocks, right, 3);
			last_clocks <= ins_clocks;
			write(my_line, STRING'(" instruction at "));
			hwrite(my_line, addr);
			write(my_line, STRING'(" opcode "));
			hwrite(my_line, dat); -- data_in);
			write(my_line, STRING'(" reads "));
			write(my_line, memory_reads);
			write(my_line, STRING'(" cache hits "));
			write(my_line, memory_reads_hit);
			writeline(OUTPUT, my_line);
			last_write_act_clocks <= write_act_clocks;
			last_read_act_clocks <= read_act_clocks;
		end if;	
	end;

   begin		
		write(my_line, STRING'("Simulation started"));
		writeline(output, my_line);

		write(my_line, STRING'("Reset on"));
		writeline(output, my_line);
      -- hold reset state for 100 ns.
		reset <= '1';
        wait for 100 ns;	
		reset <= '0';

		while cache_reset_done = '0' loop
			wait for clk_period/2;
		end loop;

		write(my_line, STRING'("Cache reset done at cycle "));
		write(my_line, ins_clocks);
		writeline(output, my_line);
		
		write(my_line, STRING'("Reset off"));
		writeline(output, my_line);
      -- wait for clk_period*20;
      -- insert stimulus here 
		
		for i in 0 to 29999 loop
			wait for clk_period/2;
			
			if clk='1' then
				-- print cache status
--				write(my_line, STRING'("cache addr "));
--				hwrite(my_line, cache_addr_in);
--				write(my_line, STRING'(" data "));
--				hwrite(my_line, cache_data_out);
--				write(my_line, STRING'(" hit "));
--				write(my_line, cache_hit, right, 2);
--				write(my_line, STRING'(" miss "));
--				write(my_line, cache_miss, right, 2);
--				writeline(output, my_line);
			end if;

			-- Test hold logic
			if i = 2000 then 
				hold <= '1';
			elsif i = 2200 then
				hold <= '0';
			end if;
			
			-- test interrupt behaviour
			if i = 2400 then
				int_req <= '1';
			elsif i = 2500 then
				int_req <= '0';
			end if;
			
			-- read CPU status
			cpu_st <= cpu_debug_out(63 downto 48);
			
			read_history <= read_history(1 downto 0) & rd;
			if rd='1' then
			
				if read_history = "011" then 
					memory_reads <= memory_reads+1;
					if cache_hit = '1' then 
						memory_reads_hit <= memory_reads_hit + 1;
					end if;
				end if;
			
				addr_int := to_integer( unsigned( addr(15 downto 1) ));	-- word address
				if addr_int >= 0 and addr_int <= 4095 then 
					data_in <= rom_data;
					if read_history = "011" and iaq='1' then
						opcode_read <= true;
					end if;
				elsif addr_int >= 16768 and addr_int < 16896 then	-- scratch pad memory range in words
					-- we're in the scratchpad
					data_in <= scratchpad( addr_int - 16768 );
				else
					data_in <= x"DEAD";
				end if;
			else
				data_in <= (others => 'Z');
			end if;

			if 	opcode_read then				
				show_instruction( cycle => i, 
						iaq => iaq,
						dat => data_in);
				opcode_read <= false;
			end if;
			
			write_detect <= write_detect(0) & wr;
			read_detect <= read_detect(0) & rd_now;
			if rd = '1' and read_detect = "01" then
				write(my_line, STRING'("cycle "));
				write(my_line, i);
				write(my_line, STRING'(" read from "));
				hwrite(my_line, addr);
				write(my_line, STRING'(" data "));
				hwrite(my_line, data_in);
				writeline(OUTPUT, my_line);			
			elsif wr = '1' then
				addr_int := to_integer( unsigned( addr(15 downto 1) ));	-- word address
				if addr_int >= 16768 and addr_int < 16896 then	-- scratch pad memory range in words
					-- we're in the scratchpad
					scratchpad( addr_int - 16768 ) <= data_out;
				end if;
				if write_detect = "01" then 
					write(my_line, STRING'("cycle "));
					write(my_line, i);
					write(my_line, STRING'(" write to "));
					-- write(my_line, to_hstring(addr)); -- to_signed(addr, 16)));
					hwrite(my_line, addr);
					-- If in 8300..831F assume it is a register, print its name
					if addr_int >= 16768 and addr_int < 16784 then
						write(my_line, STRING'(" R"));
						write(my_line, addr_int - 16768);
						write(my_line, STRING'(" "));
					else
						write(my_line, STRING'("    "));
					end if;
					write(my_line, STRING'(" data "));
					hwrite(my_line, data_out);
					write(my_line, STRING'("               "));
					write(my_line, data_out);
					writeline(OUTPUT, my_line);
				end if;
			end if;
			
			-- Support CRU interface somehow
			myindex := to_integer(unsigned(addr(4 downto 1)));
			cruin <= cru_test_data(myindex);
			
			prev_cruclk <= cruclk;
			if prev_cruclk='0' and cruclk='1' then 
				-- rising edge
				cru_test_data(myindex) <= cruout;
			end if;
			
			if stuck='1' then
				write(my_line, STRING'("CPU GOT STUCK"));
				writeline(OUTPUT, my_line);
				exit;
			end if;
			
		end loop;
		

      wait;
   end process;

END;
