----------------------------------------------------------------------------------
-- gromext.vhd
--
-- GROM memory implementation code.
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
-- Description: 	Implementation of GROM for external memory.
--						Basically here we map GROM accesses to external RAM addresses.
--						Since we're not using internal block RAM, we can use 8K
--						for each of the GROMs.
--						This is the address space layout for 20 bit addresses:
--						1 1 1 1 1 1 1 1 1 1
--                9 8 7 6 5 4 3 2 1 0 9 8 7 6 5 4 3 2 1 0
--										  |<--- in grom addr  --->|
--								  |<->|	3 bit GROM chip select (0,1,2 are console in all bases)
--						|<--->|			4 bit base select
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity gromext is
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
end gromext;

architecture Behavioral of gromext is
  signal offset		: std_logic_vector(12 downto 0);
  signal grom_sel		: std_logic_vector(2 downto 0);	-- top 3 bits of GROM address
  signal rom_addr		: std_logic_vector(15 downto 0);
  signal grom_base	: std_logic_vector(3 downto 0);
  signal read_addr	: std_logic_vector(15 downto 0);
  signal read_addr_refresh : std_logic;
  signal old_rd		: std_logic;
begin

--	selected <= '1' when unsigned(grom_base) = x"0" else '0';	
	selected <= '1'; -- Our GROMs cover all the bases currently.
	addr <= grom_base & grom_sel & offset;
	dout <= read_addr(15 downto 8);
	
	process(clk, reset)
	begin 
		if reset = '1' then
			grom_sel <= "000";
			read_addr_refresh <= '0';
		elsif rising_edge(clk) then
			-- we handle only two scenarios:
			-- 	write to GROM address counter
			--		read from GROM data
		
			if we = '1' and mode(0) = '1' then
				-- write to address counter
				offset(7 downto 0) <= din;
				offset(12 downto 8) <= offset(4 downto 0);
				grom_sel 	<= offset(7 downto 5);
				grom_base 	<= mode(4 downto 1);
				read_addr_refresh <= '1';
			end if;
			
			old_rd <= rd;
			if old_rd = '1' and rd = '0' then
				if mode(0)='0' then
					offset <= offset + 1;
					read_addr_refresh <= '1';
				else
					-- address byte read just finished
					read_addr(15 downto 8) <= read_addr(7 downto 0);
				end if;
			end if;
			
			if read_addr_refresh='1' then
				read_addr <= grom_sel & (offset+1);
				read_addr_refresh <= '0';
			end if;
			
		end if;
	end process;
	
end Behavioral;

