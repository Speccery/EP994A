----------------------------------------------------------------------------------
-- epcache.vhdl
-- A simple direct mapped write through cache for my TMS9900 CPU.
-- The idea is to have two instances of this cache plugged into the TMS9900 core.
-- One for instructions, and one for data.
-- Create Date:    19:00:36 01/09/2019 
-- Creator:			 Erik Piehl
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
library std;
USE ieee.std_logic_textio.ALL;	-- needed for xilinx ise "hwrite"
USE STD.TEXTIO.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity epcache is Port ( 
	clk 	     : in  STD_LOGIC;
   reset 	  : in  STD_LOGIC;
	reset_done : out STD_LOGIC;
	cacheable  : in  STD_LOGIC;
	update     : in  STD_LOGIC;		-- on cache miss write to cache when miss='1' during reads
   data_in    : in  STD_LOGIC_VECTOR (15 downto 0);
   data_out   : out  STD_LOGIC_VECTOR (15 downto 0);
   addr_in    : in  STD_LOGIC_VECTOR (19 downto 0);
   hit        : out  STD_LOGIC;
	hit_async  : out  STD_LOGIC;
   miss       : out  STD_LOGIC;
   rd         : in  STD_LOGIC;
   wr         : in  STD_LOGIC);
end epcache;

architecture Behavioral of epcache is
	constant cacheLast : integer := 511;
	constant maxSizeBit : integer := 9;
	constant addressSize : integer := 20;
	type cacheRamArray is array (0 to cacheLast) of std_logic_vector(35 downto 0);
	signal cache : cacheRamArray;
	signal reset_count : integer range 0 to cacheLast;
	signal in_reset : std_logic := '0';
	signal dataword : std_logic_vector(35 downto 0);
	-- signal state : std_logic := '0';
	signal reset_donei : std_logic;
	signal last_wr : std_logic;	-- help in reducing debug out volume
	signal cache_line : integer range 0 to cacheLast;
begin

	-- addresses are 20 bits: 
	-- 9876543210987654321B, low bit is byte select B, so 19 bit word address
	-- 9876543210IIIIIIIIIB, cache index I runs from 0 to 511
	-- TTTTTTTTTTIIIIIIIIIB, cache tag is 10 bits
	-- The MSB of dataword tells if the data entry is valid.
	
	reset_done <= reset_donei;
	cache_line <= to_integer( unsigned( addr_in(maxSizeBit downto 1) ));
	hit_async <= '1' when cache(cache_line)(addressSize-2-maxsizeBit+16 downto 16) = addr_in(addressSize-1 downto maxSizeBit+1) and cache(cache_line)(35)='1' and rd='1' and cacheable='1' else '0';

	process(clk, reset)
	-- variable cache_line : integer range 0 to cacheLast;
	variable t : line;
	variable tag      : std_logic_vector(addressSize-1 downto maxSizeBit+1);
	variable read_tag : std_logic_vector(addressSize-1 downto maxSizeBit+1);
	begin 
		if reset='1' then
			in_reset <= '1';
			reset_donei <= '0';
			reset_count <= 0 ;
			hit <= '0';
			miss <= '0';
			dataword <= (others => '0');
			-- state <= '0';
		elsif rising_edge(clk) then
			hit        <= '0';
			miss       <= '0';
			last_wr    <= wr;
			
			-- cache_line := to_integer( unsigned( addr_in(maxSizeBit downto 1) ));
			tag        := addr_in(addressSize-1 downto maxSizeBit+1);
			
			if in_reset = '1' then
				-- process cache clearing. During this time we miss every access.
				cache(reset_count) <= (others => '0');
				if reset_count = cacheLast then
					in_reset <= '0';
				else
					reset_count <= reset_count + 1;
				end if;
			else

				reset_donei <= '1';
				if rd='1' and cacheable='0' then
					miss <= '1';
					hit <= '0';
				elsif rd='1' and cacheable='1' and update='0' then 
					dataword <= cache(cache_line); --read from cache
					data_out <= cache(cache_line)(15 downto 0);
					read_tag := cache(cache_line)(addressSize-2-maxsizeBit+16 downto 16);
					
					if addr_in(15 downto 0) = x"8318" then
						write(t, STRING'("epcache debug read: "));
						hwrite(t, addr_in, right, 6);
						write(t, STRING'(" rd="));
						write(t, rd);
						write(t, STRING'(" tag="));
						hwrite(t, "00" & tag , right, 5);
						write(t, STRING'(" read tag="));
						hwrite(t, "00" & read_tag , right, 5);
						write(t, STRING'(" line="));
						write(t, cache_line);
						write(t, STRING'(" cache data="));
						hwrite(t, cache(cache_line), right, 10);
						writeline(output, t);
					end if;
					
					
					if read_tag = tag and cache(cache_line)(35)='1' then 
						hit <= '1';
						miss <= '0';
					else 
						hit <= '0';
						miss <= '1';
					end if;
					
				elsif last_wr='0' and (wr='1' or update='1') and cacheable='1' then
					-- the first below is the "valid cache entry bit"
					cache(cache_line) <= "1000000000" & tag & data_in;	-- update the contents of the cache on writes
					dataword <= "1000000000" & tag & data_in;	-- for simulation: show the update
					
					write(t, STRING'("epcache write: "));
					hwrite(t, addr_in, right, 6);
					write(t, STRING'(" rd="));
					write(t, rd);
					write(t, STRING'(" tag="));
					hwrite(t, "00" & tag , right, 5);
					write(t, STRING'(" line="));
					write(t, cache_line);
					write(t, STRING'(" data="));
					hwrite(t, data_in, right, 5);
					writeline(output, t);
					
				end if;
			end if;
		end if;
	end process;

end Behavioral;

