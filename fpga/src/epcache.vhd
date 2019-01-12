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

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity epcache is
    Port ( clk 		 : in  STD_LOGIC;
           reset 		 : in  STD_LOGIC;
			  reset_done : out STD_LOGIC;
			  cacheable  : in  STD_LOGIC;
			  update     : in  STD_LOGIC;		-- on cache miss write to cache when miss='1' during reads
           data_in 	 : in  STD_LOGIC_VECTOR (15 downto 0);
           data_out   : out  STD_LOGIC_VECTOR (15 downto 0);
           addr_in    : in  STD_LOGIC_VECTOR (19 downto 0);
           hit        : out  STD_LOGIC;
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
begin

	data_out <= dataword(15 downto 0);
	hit  <= '1' when rd='1' and reset_done='1' and tag = addr_in(19 downto maxSizeBit) and cacheable='1' else '0';
	miss <= '1' when rd='1' and reset_done='1' and tag /= addr_in(19 downto maxSizeBit) and cacheable='1' else '0';

	process(clk, reset)
	variable cache_line : integer range 0 to cacheLast;
	variable tag : std_logic_vector(addressSize-maxSizeBit-1 downto 0);
	begin 
		if reset='1' then
			in_reset <= '1';
			reset_done <= '0';
			reset_count <= 0 ;
			hit <= '0';
			miss <= '0';
			-- state <= '0';
		elsif rising_edge(clk) then
			cache_line := to_integer( unsigned( addr_in(maxSizeBit-1 downto 0) ));
			tag := dataword(16+addressSize-MaxSizeBit downto 16);
			
			if in_reset = '1' then
				-- process cache clearing. During this time we miss every access.
				cache(reset_count) <= (others => '0');
				reset_count <= reset_count + 1;
				if reset_count = cacheLast then
					in_reset <= '0';
				end if;
			else
				-- normal operation of the cache
				reset_done <= '1';
				if rd='1' and cacheable='1' then 
					dataword <= cache(cache_line);
					state <= '1';
				elsif (wr='1' or update='1') and cacheable='1' then
					cache(cache_line) <= tag & data_in;	-- update the contents of the cache on writes
				end if;
			end if;
		end if;
	end process;

end Behavioral;

