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

USE STD.TEXTIO.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
 
ENTITY tb_tms9900 IS
END tb_tms9900;
 
ARCHITECTURE behavior OF tb_tms9900 IS 
 
    -- Component Declaration for the Unit Under Test (UUT)
 
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
			test_out : OUT  std_logic_vector(15 downto 0);
			alu_debug_out : OUT  std_logic_vector(15 downto 0);
			alu_debug_oper : out STD_LOGIC_VECTOR(3 downto 0);
			alu_debug_arg1 : OUT  std_logic_vector(15 downto 0);
			alu_debug_arg2 : OUT  std_logic_vector(15 downto 0);
			cruin		: in STD_LOGIC;
			cruout   : out STD_LOGIC;
			cruclk   : out STD_LOGIC;
         stuck : OUT  std_logic
        );
    END COMPONENT;
	 
	 COMPONENT TESTROM
	 PORT (
		clk : IN  std_logic;
      addr : in  STD_LOGIC_VECTOR (7 downto 0);
      data_out : out  STD_LOGIC_VECTOR (15 downto 0));
	 END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal data_in : std_logic_vector(15 downto 0) := (others => '0');
   signal ready : std_logic := '0';
	signal cruin : std_logic := '0';

 	--Outputs
   signal addr : std_logic_vector(15 downto 0);
   signal data_out : std_logic_vector(15 downto 0);
   signal rd : std_logic;
   signal wr : std_logic;
   signal iaq : std_logic;
   signal as : std_logic;
	signal test_out : STD_LOGIC_VECTOR (15 downto 0);
	signal alu_debug_out : STD_LOGIC_VECTOR (15 downto 0);
	signal alu_debug_oper : STD_LOGIC_VECTOR (3 downto 0);
	signal alu_debug_arg1 : STD_LOGIC_VECTOR (15 downto 0);
	signal alu_debug_arg2 : STD_LOGIC_VECTOR (15 downto 0);
	signal cruout : std_logic;
	signal cruclk : std_logic;
   signal stuck : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;

	signal rom_data : STD_LOGIC_VECTOR (15 downto 0);
	
	-- RAM block to 8300
	type ramArray is array (0 to 127) of STD_LOGIC_VECTOR (15 downto 0);
	signal scratchpad : ramArray;
	signal ramIndex : integer range 0 to 15 := 0;
	signal write_detect : std_logic_vector(1 downto 0);
	
	constant cru_test_data : std_logic_vector(15 downto 0) := x"A079";
 
BEGIN
 
	-- Instantiate the Unit Under Test (UUT)
   uut: tms9900 PORT MAP (
          clk => clk,
          reset => reset,
          addr => addr,
          data_in => data_in,
          data_out => data_out,
          rd => rd,
          wr => wr,
          ready => ready,
          iaq => iaq,
          as => as,
			 test_out => test_out,
			 alu_debug_out => alu_debug_out,
			 alu_debug_oper => alu_debug_oper,
			 alu_debug_arg1 => alu_debug_arg1,
			 alu_debug_arg2 => alu_debug_arg2,
			 cruin => cruin,
			 cruout => cruout,
			 cruclk => cruclk,
          stuck => stuck
        );
		  
	ROM: TESTROM PORT MAP(
		clk => clk,
		addr => addr(8 downto 1),
		data_out => rom_data
		);

   -- Clock process definitions
   clk_process :process
   begin
		clk <= '0';
		wait for clk_period/2;
		clk <= '1';
		wait for clk_period/2;
   end process;
	
   -- Stimulus process
   stim_proc: process
	variable addr_int : integer range 0 to 32767 := 0;
	variable my_line : line;	-- from textio
	variable myindex : natural range 0 to 15;	
   begin		
      -- hold reset state for 100 ns.
		reset <= '1';
      wait for 100 ns;	
		reset <= '0';
      -- wait for clk_period*20;
      -- insert stimulus here 
		
		for i in 0 to 29999 loop
			wait for clk_period/2;
			
			if rd='1' then
				addr_int := to_integer( unsigned( addr(15 downto 1) ));	-- word address
				if addr_int >= 0 and addr_int <= 4095 then
					data_in <= rom_data;
				elsif addr_int >= 16768 and addr_int < 16896 then	-- scratch pad memory range in words
					-- we're in the scratchpad
					data_in <= scratchpad( addr_int - 16768 );
				else
					data_in <= x"DEAD";
				end if;
			else
				data_in <= (others => 'Z');
			end if;
			
			write_detect <= write_detect(0) & wr;
			if wr = '1' then
				addr_int := to_integer( unsigned( addr(15 downto 1) ));	-- word address
				if addr_int >= 16768 and addr_int < 16896 then	-- scratch pad memory range in words
					-- we're in the scratchpad
					scratchpad( addr_int - 16768 ) <= data_out;
				end if;
				if write_detect = "01" then 
					write(my_line, STRING'("write to "));
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
			
			if stuck='1' then
				write(my_line, STRING'("CPU GOT STUCK"));
				writeline(OUTPUT, my_line);
				exit;
			end if;
			
		end loop;
		

      wait;
   end process;

END;
