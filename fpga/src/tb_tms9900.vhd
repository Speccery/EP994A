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
--USE ieee.numeric_std.ALL;
 
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
         stuck : OUT  std_logic
        );
    END COMPONENT;
    

   --Inputs
   signal clk : std_logic := '0';
   signal reset : std_logic := '0';
   signal data_in : std_logic_vector(15 downto 0) := (others => '0');
   signal ready : std_logic := '0';

 	--Outputs
   signal addr : std_logic_vector(15 downto 0);
   signal data_out : std_logic_vector(15 downto 0);
   signal rd : std_logic;
   signal wr : std_logic;
   signal iaq : std_logic;
   signal as : std_logic;
	signal test_out : STD_LOGIC_VECTOR (15 downto 0);
   signal stuck : std_logic;

   -- Clock period definitions
   constant clk_period : time := 10 ns;
 
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
          stuck => stuck
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
   begin		
      -- hold reset state for 100 ns.
		reset <= '1';
      wait for 100 ns;	
		reset <= '0';
      -- wait for clk_period*20;
      -- insert stimulus here 
		
		for i in 0 to 199 loop
			wait for clk_period/2;
			
			if rd='1' then
				case addr is
					when x"0000" =>
						data_in <= x"1234";
					when x"0002" =>
						data_in <= x"5678";
					when x"5678" =>
						data_in <= x"1000";	-- NOP, ie branch next
					when x"567A" =>
						data_in <= x"02E0";
					when x"567C" =>
						data_in <= x"ABCD";
					when x"567E" =>
						data_in <= x"10FC";	-- Branch backwards a bit
					when others =>
						data_in <= x"DEAD";
				end case;
			else
				data_in <= (others => 'Z');
			end if;
		end loop;
		

      wait;
   end process;

END;
