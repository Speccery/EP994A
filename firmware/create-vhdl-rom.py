# create-vhdl-rom.py
# EP 2017-04-15

src = open("test9900_0000.bin", "rb")
dst = open("../fpga/src/testrom.vhd", "wt")
count = 0
try:

  prefix = """\
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
           addr : in  STD_LOGIC_VECTOR (11 downto 0);
           data_out : out  STD_LOGIC_VECTOR (15 downto 0));
end testrom;

architecture Behavioral of testrom is
	constant romLast : integer := 4095;
	type pgmRomArray is array(0 to romLast) of STD_LOGIC_VECTOR (15 downto 0);
	constant pgmRom : pgmRomArray := (  
"""

  postfix="""\
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
  """

  dst.write(prefix)
  byte1 = src.read(1)
  byte2 = src.read(1)
  first = True
  while byte1: # != b"":
    val = ord(byte1)*256+ord(byte2)
    if first:
      k = ' x"%04x"' % val
      first = False
    else:
      k = ',x"%04x"' % val
    dst.write("           " + k + '\n')
    count = count+1
    byte1 = src.read(1)
    byte2 = src.read(1)
finally:
  src.close()
  while count < 4096:
    dst.write("           " + ',x"0000"' + '\n')
    count = count+1
  dst.write(postfix)
  dst.close()
  