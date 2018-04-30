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

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

Library UNISIM;
use UNISIM.vcomponents.all;

Library UNIMACRO;
use UNIMACRO.vcomponents.all;

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
begin
--	dip <= "00";
	ram_addr <= "000" & addr;

	small_ram : RAMB16_S18 port map(
		do => dout,
		dop => open,
		addr => ram_addr,
		clk => clk,
		di => din,
		dip => "00",
		en => '1',
		ssr => '0', 
		we => wr);


--	we <= wr & wr;
-- 
--   BRAM_SINGLE_MACRO_inst : BRAM_SINGLE_MACRO
--   generic map (
--      BRAM_SIZE => "18Kb", -- Target BRAM, "9Kb" or "18Kb" 
--      DEVICE => "SPARTAN6", -- Target Device: "VIRTEX5", "VIRTEX6", "SPARTAN6" 
--      DO_REG => 0, -- Optional output register (0 or 1)
--      INIT => X"000000000",   --  Initial values on output port
--      INIT_FILE => "NONE",
--      WRITE_WIDTH => 16,   -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="18Kb")
--      READ_WIDTH => 16,   -- Valid values are 1-36 (19-36 only valid when BRAM_SIZE="18Kb")
--      SRVAL => X"000000000",   -- Set/Reset value for port output
--      WRITE_MODE => "WRITE_FIRST" -- "WRITE_FIRST", "READ_FIRST" or "NO_CHANGE" 
--	 )
--    port map (
--      DO => dout,      -- Output data, width defined by READ_WIDTH parameter
--      ADDR => "000" & addr,  -- Input address, width defined by read/write port depth
--      CLK => clk,    -- 1-bit input clock
--      DI => din,      -- Input data port, width defined by WRITE_WIDTH parameter
--      EN => en,      -- 1-bit input RAM enable
--      REGCE => '0', -- 1-bit input output register enable
--      RST => '0',    -- 1-bit input reset
--      WE => we       -- Input write enable, width defined by write port depth
--   );

end Behavioral;

