----------------------------------------------------------------------------------
-- Engineer:	Erik Piehl 
-- 
-- Create Date:    07:01:30 04/15/2017 
-- Design Name: 	 testrom.vhd
-- Module Name:    testrom - Behavioral 
-- Project Name: 	 TMS9900 Test ROM code
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity testrom is
    Port ( clk : in  STD_LOGIC;
           addr : in  STD_LOGIC_VECTOR (6 downto 0);
           data_out : out  STD_LOGIC_VECTOR (15 downto 0));
end testrom;

architecture Behavioral of testrom is
	constant romLast : integer := 63;
	type pgmRomArray is array(0 to romLast) of STD_LOGIC_VECTOR (15 downto 0);
	constant pgmRom : pgmRomArray := (  
            x"8300"
           ,x"0008"
           ,x"beef"
           ,x"beef"
           ,x"0203"
           ,x"8340"
           ,x"0200"
           ,x"1234"
           ,x"0201"
           ,x"0001"
           ,x"c4c0"
           ,x"c0b3"
           ,x"a081"
           ,x"c202"
           ,x"c4c1"
           ,x"a4c1"
           ,x"c820"
           ,x"0004"
           ,x"8344"
           ,x"10f0"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
           ,x"0000"
	);
begin

	process(clk)
	variable addr_int : integer range 0 to romLast := 0;
	begin
		if rising_edge(clk) then
			addr_int := to_integer( unsigned( addr ));	-- word address
			data_out <= pgmRom( addr_int );
		end if;
	end process;

end Behavioral;
  