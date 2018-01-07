----------------------------------------------------------------------------------
-- serloader.vhd
--
-- State machine for commands received over a serial port.
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
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity serloader is
    Port ( clk 			: in  STD_LOGIC;
           rst 			: in  STD_LOGIC;
			  tx				: out STD_LOGIC;
			  rx				: in STD_LOGIC;
			  -- SPI interface begin
			  spi_cs_n		: in STD_LOGIC;
			  spi_clk		: in STD_LOGIC;
			  spi_mosi		: in STD_LOGIC;
			  spi_miso     : out STD_LOGIC;
			  spi_rq			: out STD_LOGIC;	-- spi request - currently used for debugging.
			  -- SPI interface end
           mem_addr 		: out  STD_LOGIC_VECTOR (31 downto 0);
           mem_data_out : out  STD_LOGIC_VECTOR (7 downto 0);
           mem_data_in 	: in  STD_LOGIC_VECTOR (7 downto 0);
           mem_read_rq 	: out  STD_LOGIC;
           mem_read_ack : in  STD_LOGIC;
           mem_write_rq : out  STD_LOGIC;
           mem_write_ack : in  STD_LOGIC);
end serloader;

architecture serloader_Behavioral of serloader is
	type state_type is (
		idle, 
		set_mode, do_auto_inc, set_count_0, set_count_1,
		rd_count_1, rd_count_2,
		wr_a0, wr_a1, wr_a2, wr_a3,
		wr_dat0, wr_dat1, wr_dat2, wr_dat_inc,
		rd_dat0, rd_dat1, rd_dat2, rd_dat_inc
		);
	signal state : state_type;
	signal return_state : state_type;		-- return state after autoincrement operation
	signal ab0, ab1, ab2, ab3 : std_logic_vector(7 downto 0);
	signal rx_byte_latch : std_logic_vector(7 downto 0);
	signal rx_byte_ready : std_logic;
	signal tx_data_latch : std_logic_vector(7 downto 0);
	signal wr_data_latch : std_logic_vector(7 downto 0);
	signal mychar 			: integer;
	signal mode				: std_logic_vector(1 downto 0);		-- repeat mode, autoincrement mode
	signal rpt_count 		: std_logic_vector(15 downto 0);

	-- uart routing
	signal rx_data 	: STD_LOGIC_VECTOR (7 downto 0);	-- data from serial port
   signal rx_new_data: STD_LOGIC;
	signal tx_data 	: STD_LOGIC_VECTOR (7 downto 0);	-- data to serial port
	signal tx_now		: STD_LOGIC;							-- transmit tx_data NOW
	signal tx_busy		: STD_LOGIC;							-- transmitter is busy

	-- SPI routing
	signal spi_rx_data 	: STD_LOGIC_VECTOR (7 downto 0);	-- data from serial port
   signal spi_rx_ready  : STD_LOGIC;
	signal spi_tx_data 	: STD_LOGIC_VECTOR (7 downto 0);	-- data to serial port
	signal spi_tx_now		: STD_LOGIC;							-- transmit tx_data NOW
	signal spi_tx_busy		: STD_LOGIC;							-- transmitter is busy

	
	signal cnt_minus1 : std_logic_vector(15 downto 0);
	signal ack_w_high : integer;
	signal mem_write_rq_state : std_logic;
	signal prev_ack	: std_logic;	-- debugging signal
	
	component serial_tx port (
		clk 	: in std_logic;
		rst 	: in std_logic;
		tx  	: out std_logic;
		block_tx : in std_logic;	-- pause transmission (i.e. other side not ready to handle more right now)
		busy 	: out std_logic;
		data 	: in std_logic_vector(7 downto 0);
		new_data : in std_logic
    );
	end component;
	
	component serial_rx port (
        clk 		: in std_logic;
        rst			: in std_logic;
        rx 			: in std_logic;
        data 		: out std_logic_vector(7 downto 0);
        new_data	: out std_logic
    );	
	 end component;	
-------------------------------------------------------------------------------
-- my own SPI receiver
	component spi_slave is
    Port ( clk 		: in  STD_LOGIC;
			  rst			: in STD_LOGIC;
			  
           cs_n 		: in  STD_LOGIC;
			  spi_clk 	: in  STD_LOGIC;			  
           mosi 		: in  STD_LOGIC;
           miso 		: out  STD_LOGIC;
			  spi_rq 	: out STD_LOGIC;	-- debug for now - data was wll received or sent
			  
           rx_data 	: out  STD_LOGIC_VECTOR (7 downto 0);
			  rx_ready 	: out STD_LOGIC;
			  
           tx_data 	: in  STD_LOGIC_VECTOR (7 downto 0);
			  tx_busy 	: out STD_LOGIC;
			  tx_new_data : in STD_LOGIC	-- launch transmission of new data
		);
	end component;
-------------------------------------------------------------------------------
begin
	
	tx_data <= tx_data_latch;
	mem_addr <= ab3 & ab2 & ab1 & ab0;
	mem_data_out <= wr_data_latch;
	mychar <= to_integer(unsigned(rx_byte_latch));
	mem_write_rq <= mem_write_rq_state;
	
	
	cnt_minus1 <= std_logic_vector(to_unsigned(to_integer(unsigned(rpt_count)) - 1, cnt_minus1'length));

	process(clk, rst)
	variable k : integer;
	variable kbits : std_logic_vector(31 downto 0);
	variable k16 : std_logic_vector(15 downto 0);
	variable cnt : integer;
	variable cnt16 : std_logic_vector(15 downto 0);
	begin
		if rst = '1' then
			state <= idle;
			ab0 <= (others => '0');
			ab1 <= (others => '0');
			ab2 <= (others => '0');
			ab3 <= (others => '0');
			mem_read_rq <= '0';
			mem_write_rq_state <= '0';
			rx_byte_ready <= '0';
			mode <= "00";
			ack_w_high <= 0;
		elsif rising_edge(clk) then
		
			tx_now <= '0';	-- assume nothing is sent, this may change below
		
			if rx_new_data = '1' then
				-- we got a byte from serial port. Latch it. 
				-- The state machine will eat it later.
				rx_byte_latch <= rx_data;
				rx_byte_ready <= '1';
			end if;
			
			-- for how many cycles is the memory requst high *after* getting the ack?
			prev_ack <= mem_write_ack;
			if prev_ack = '0' and mem_write_ack = '1' then 
				ack_w_high <= 0;
			elsif mem_write_rq_state = '1' then
				ack_w_high <= ack_w_high + 1;
			end if;
			
			if rx_byte_ready = '1' then
				case state is
					when idle =>
						case mychar is
							when 46 =>	-- .
								if tx_busy = '0' then
									tx_data_latch <= std_logic_vector(to_unsigned(46,8));			-- echo back .
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 65 => 	state <= wr_a0;	-- A
								rx_byte_ready <= '0';		-- char consumed
							when 66 => 	state <= wr_a1;	-- B
								rx_byte_ready <= '0';		-- char consumed
							when 67 => 	state <= wr_a2;	-- C
								rx_byte_ready <= '0';		-- char consumed
							when 68 => 	state <= wr_a3;	-- D
								rx_byte_ready <= '0';		-- char consumed
							when 69 =>							-- E
								if tx_busy = '0' then
									tx_data_latch <= ab0;
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 70 =>							-- F
								if tx_busy = '0' then
									tx_data_latch <= ab1;
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 71 =>							-- G
								if tx_busy = '0' then
									tx_data_latch <= ab2;
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 72 =>							-- H
								if tx_busy = '0' then
									tx_data_latch <= ab3;
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 33 =>							-- ! write byte
								state <= wr_dat0;
								rx_byte_ready <= '0';		-- char consumed
							when 64 =>							-- @ read byte
								state <= rd_dat0;
								rx_byte_ready <= '0';		-- char consumed
							when 43 =>							-- + increment lowest address byte
								rx_byte_ready <= '0';		-- char consumed
								ab0 <= std_logic_vector(to_unsigned(to_integer(unsigned(ab0)) + 1, ab0'length));
							when 77 =>							-- set mode 'M'
								rx_byte_ready <= '0';
								state <= set_mode;
							when 78 => 							-- read mode 'N'
								if tx_busy = '0' then
									tx_data_latch <= x"3" & "00" & mode;	-- '0', '1', '2' or '3' as ASCII
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 86 =>							-- get version V
								if tx_busy = '0' then
									tx_data_latch <= x"30";	-- '0'
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 84 =>							-- 'T' set 16-bit repeat count
								rx_byte_ready <= '0';
								state <= set_count_0;
							when 80 =>							-- 'P' get repeat count (low, high)
								if tx_busy = '0' then
									tx_data_latch <= rpt_count(7 downto 0);
									tx_now <= '1';
									state <= rd_count_1;
									rx_byte_ready <= '0';	-- Char consumed.
								end if;
							when 81 =>							-- 'Q' get repeat count (high)
								if tx_busy = '0' then
									tx_data_latch <= rpt_count(15 downto 8);
									tx_now <= '1';
									rx_byte_ready <= '0';	-- here we consume the character.
								end if;
							when 88 =>							-- 'X' read ack signal counter
								if tx_busy = '0' then
									tx_data_latch <= x"3" & std_logic_vector(to_unsigned(ack_w_high, 4));
									tx_now <= '1';
									rx_byte_ready <= '0';	-- character consumed
								end if;
							when others => 
								state <= idle;	-- no change
								rx_byte_ready <= '0';	-- consume the character, i.e. throw it away
						end case;	-- end of case mychar
					when set_count_0 =>						-- low byte of repeat count
						rx_byte_ready <= '0';
						rpt_count <= rpt_count(15 downto 8) & rx_byte_latch;
						state <= set_count_1;
					when set_count_1 =>						-- high byte of repeat count
						rx_byte_ready <= '0';
						rpt_count <= rx_byte_latch & rpt_count(7 downto 0);
						state <= idle;
					when set_mode =>
						rx_byte_ready <= '0';				-- capture low 2 bits as mode
						mode <= rx_byte_latch(1 downto 0);							
						state <= idle;
					when wr_a0 =>
						rx_byte_ready <= '0';
						ab0 <= rx_byte_latch;
						state <= idle;
					when wr_a1 =>
						rx_byte_ready <= '0';
						ab1 <= rx_byte_latch;
						state <= idle;
					when wr_a2 =>
						rx_byte_ready <= '0';
						ab2 <= rx_byte_latch;
						state <= idle;
					when wr_a3 =>
						rx_byte_ready <= '0';
						ab3 <= rx_byte_latch;
						state <= idle;
					when wr_dat0 =>
						return_state <= wr_dat0;	-- If there is an autoincrement repeat, come back here.
						rx_byte_ready <= '0';
						wr_data_latch <= rx_byte_latch;
						state <= wr_dat1;
						ack_w_high <= 0;
					when others =>
						-- go back to idle state - also aborts things in progress
						-- Note: keeps rx_byte_ready signal active, idle state will consume it.

						-- EP actually do nothing, because the state machine is handled in two parts
						-- which actually sucks.
						
--						state <= idle;	
--						mem_read_rq <= '0';
--						mem_write_rq <= '0';
				end case;
			end if; -- new_data = 1
			
			-- state transitions which are not driven by data receive but by clock
			-- cycles or other signals i.e memory activity
			case state is
				when wr_dat1 =>
					mem_write_rq_state <= '1';
					state <= wr_dat2;
				when wr_dat2 =>
					if mem_write_ack = '1' then
						mem_write_rq_state <= '0';
						if mode(0) = '1' then 
							state <= do_auto_inc;	-- return to idle via autoinc
						else
							state <= idle;
						end if;
					end if;
				when rd_dat0 =>
					return_state <= rd_dat0;	-- If there is an autoincrement repeat, come back here.
					mem_read_rq <= '1';
					state <= rd_dat1;
				when rd_dat1 =>
					if mem_read_ack = '1' then
						mem_read_rq <= '0';
						state <= rd_dat2;
					end if;
				when rd_dat2 =>
					if tx_busy = '0' then
						tx_data_latch <= -- std_logic_vector(to_unsigned(42,8));	-- return * for now
							 mem_data_in;
						tx_now <= '1';
						if mode(0) = '1' then 
							state <= do_auto_inc;	-- return to idle via autoinc
						else
							state <= idle;
						end if;
					end if;
				when do_auto_inc =>
					-- handle autoincrement.
					k := to_integer(unsigned(ab1 & ab0)) + 1;
					k16 := std_logic_vector(to_unsigned(k, k16'length));
					ab0 <= k16(7 downto 0);
					ab1 <= k16(15 downto 8);
					-- hard coded repeat for reading data
					if mode(1) = '1' then
						rpt_count <= cnt_minus1;
						if rpt_count = x"0001" then
							state <= idle;
						else 
							state <= return_state;	-- go to rd_dat0 or wr_dat0 depending on how we got here.
						end if;
					else
						state <= idle;
					end if;
				when rd_count_1 =>
					state <= rd_count_2;			-- waste 1 clock cycle, not sure how fast tx_busy goes to zero
				when rd_count_2 =>
					if tx_busy = '0' then		-- return high byte of repeat counter
						tx_data_latch <= rpt_count(15 downto 8);
						tx_now <= '1';
						state <= idle;
					end if;
				when others =>
					-- do nothing
			end case;
		end if;
	end process;
	
	uart_tx: serial_tx port map (
		clk => clk,
		rst => rst,
		tx =>  tx,
		block_tx => '0',
		busy => tx_busy,
		data => tx_data,
		new_data => tx_now
		);
		
	uart_receiver : serial_rx port map (
		clk 	=> clk,
		rst 	=> rst,
		rx 	=> rx,
		data 	=> rx_data,
		new_data => rx_new_data
		);
	
	spi_tx_data <= x"00";
	spi_tx_now <= '0';
	spi_receiver : spi_slave PORT MAP
			( clk => clk,
			  rst => rst,
			  
           cs_n 		=> spi_cs_n,
			  spi_clk 	=> spi_clk,
           mosi 		=> spi_mosi,
           miso 		=> spi_miso,
			  spi_rq 	=> spi_rq,
			  
           rx_data 	=> spi_rx_data,
			  rx_ready 	=> spi_rx_ready,
			  
           tx_data 	=> spi_tx_data,
			  tx_busy 	=> spi_tx_busy,
			  tx_new_data => spi_tx_now -- launch transmission of new data
		); 
	
end serloader_Behavioral;

