----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Erik Piehl
-- 
-- Create Date:    10:34:14 01/07/2018 
-- Design Name: 
-- Module Name:    spi_slave - Behavioral 
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
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity spi_slave is
    Port ( clk : in  STD_LOGIC;
			  rst: in STD_LOGIC;
			  
           cs_n 		: in  STD_LOGIC;
			  spi_clk 	: in  STD_LOGIC;			  
           mosi 		: in  STD_LOGIC;
           miso 		: out  STD_LOGIC;
			  spi_rq 	: out STD_LOGIC;	-- debug for now - data was wll received or sent
			  
           rx_data : out  STD_LOGIC_VECTOR (7 downto 0);
			  rx_ready : out STD_LOGIC;
			  
           tx_data : in  STD_LOGIC_VECTOR (7 downto 0);
			  tx_busy : out STD_LOGIC;
			  tx_new_data : in STD_LOGIC	-- launch transmission of new data
		);
end spi_slave;

architecture spi_slave_Behavioral of spi_slave is
-------------------------------------------------------------------------------	
-- Signals for LPC1343 SPI controller receiver
-------------------------------------------------------------------------------	
	signal lastCS : std_logic_vector(7 downto 0) := x"00";
	signal spi_tx_shifter : std_logic_vector(7 downto 0);
	signal spi_bitcount : integer range 0 to 7;
	signal spi_ready : boolean := false;
	signal spi_test_count : integer range 0 to 255 := 0;
	signal spi_clk_sampler : std_logic_vector(2 downto 0) := "000";
	signal spi_rx_bit : std_logic;	
	signal wait_clock : boolean := false;
	signal transmitter_busy : std_logic;
begin
	spi_rq <= '1' when spi_ready else '0' ; -- indicates data well received / sent
	miso <= spi_tx_shifter(7) when cs_n='0' else 'Z';
	tx_busy <= transmitter_busy;
	process(clk)
	begin
		if rising_edge(clk) then
			if rst = '1' then
				lastCS <= x"FF";
				spi_ready <= false;
				spi_test_count <= 0;
				spi_clk_sampler <= "000";
				wait_clock <= false;
				transmitter_busy <= '1';
				spi_tx_shifter <= x"FF";
			else
				spi_clk_sampler <= spi_clk_sampler(1 downto 0) & spi_clk;
				lastCS <= lastCS(6 downto 0) & cs_n;
				rx_ready <= '0';
				if lastCS(7 downto 5) = "111" and lastCS(1 downto 0) = "00" and cs_n='0' and not wait_clock then 
					-- falling edge of CS
						spi_bitcount <= 0;
						spi_ready <= false;
						-- spi_test_count <= spi_test_count + 1;
						-- spi_tx_shifter <= std_logic_vector(to_unsigned(spi_test_count,8));
						wait_clock <= true;
				end if;
				if spi_clk_sampler = "011" and lastCS(0) = '0' and cs_n='0' then 
					-- rising edge of clock, receive shift
					spi_rx_bit <= mosi;
					spi_ready <= false;
					wait_clock <= false;
				end if;
				if spi_clk_sampler = "110"  and lastCS(0) = '0' and cs_n='0' then 
					-- falling edge of clock, transmit shift
					spi_tx_shifter <= spi_tx_shifter(6 downto 0) & spi_rx_bit;
					spi_bitcount <= spi_bitcount + 1;
					if spi_bitcount = 7 then
						spi_bitcount <= 0;
						spi_ready <= true;
						
						rx_data <= spi_tx_shifter(6 downto 0) & spi_rx_bit;
						rx_ready <= '1';	-- a single clock cycle pulse
						
						transmitter_busy <= '0';	-- ready transmit a byte (if there are subsequent clocks)
					end if;
				end if;
				
				if transmitter_busy = '0' and tx_new_data = '1' then
					transmitter_busy <= '1';
					spi_tx_shifter <= tx_data;
				end if;
				
			end if; -- reset
		end if;	-- rising_edge
	end process;

end spi_slave_Behavioral;

