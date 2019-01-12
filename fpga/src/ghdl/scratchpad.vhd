----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 	Erik Piehl
-- 
-- Create Date:    22:18:02 09/25/2017 
-- Design Name: 
-- Module Name:    scartchpad - Behavioral 
-- Project Name: 
-- Target Devices: 
-- Tool versions: 
-- Description: 
--
-- Dependencies: 
--
-- Revision: 
-- Revision 0.01 - File Created
-- Additional Comments: 
--
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Library UNISIM;
-- use UNISIM.vcomponents.all;

-- Library UNIMACRO;
-- use UNIMACRO.vcomponents.all;

entity scratchpad is
    Port ( addr : in  STD_LOGIC_VECTOR (7 downto 1);
           din  : in  STD_LOGIC_VECTOR (15 downto 0);
           dout : out  STD_LOGIC_VECTOR (15 downto 0);
           clk  : in  STD_LOGIC;
           wr   : in  STD_LOGIC);
end scratchpad;

architecture Behavioral of scratchpad is
--	signal we : std_logic_vector(1 downto 0);
--	signal dip : std_logic_vector(1 downto 0);
	signal ram_addr : std_logic_vector(9 downto 0);
	type ramArray is array (0 to 127) of STD_LOGIC_VECTOR (15 downto 0);
	signal scratchpad_mem : ramArray;

begin
--	dip <= "00";
	ram_addr <= "000" & addr;

	process(clk)
	begin
		if (rising_edge(clk)) then
			if wr='1' then 
			scratchpad_mem(to_integer(unsigned(addr))) <= din;
			end if;
			dout <= scratchpad_mem(to_integer(unsigned(addr)));
		end if;
	-- small_ram : RAMB16_S18 port map(
	-- 	do => dout,
	-- 	dop => open,
	-- 	addr => ram_addr,
	-- 	clk => clk,
	-- 	di => din,
	-- 	dip => "00",
	-- 	en => '1',
	-- 	ssr => '0', 
	-- 	we => wr);
	end process;

end Behavioral;

