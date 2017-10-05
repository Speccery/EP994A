----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Erik Piehl
-- 
-- Create Date:    22:27:32 08/18/2016 
-- Design Name: 
-- Module Name:    pager612 - Behavioral 
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
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity pager612 is
    Port ( clk 			: in  STD_LOGIC;
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
end pager612;

architecture Behavioral of pager612 is
	type abank is array (natural range 0 to 15) of std_logic_vector(15 downto 0);
	signal regs   : abank;
begin
	process(clk)
	begin
		if rising_edge(clk) then
			if access_regs = '1' and write_enable = '1' then
				-- write to paging register
				regs(to_integer(unsigned(abus_low(3 downto 0)))) <= dbus_in;
			end if;
		end if;
	end process;

	translated_addr <= 
		regs(to_integer(unsigned(abus_high(15 downto 12)))) when mapen = '1' and access_regs = '0' else
		x"000" & abus_high(15 downto 12);	-- mapping off
	
	dbus_out <= regs(to_integer(unsigned(abus_low(3 downto 0)))) when page_reg_read = '1' and access_regs = '1' else
		-- mapen & write_enable & page_reg_read & access_regs & x"E" & mapen & write_enable & page_reg_read & access_regs & x"F";
		x"BEEF";
end Behavioral;

