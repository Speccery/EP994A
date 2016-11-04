----------------------------------------------------------------------------------
-- tms9919.vhd
--
-- Implementation of the TMS9919 sound chip.
-- The module is not 100% compatible with the orignal design.
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
-----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx primitives in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity tms9919 is
    Port ( clk 		: in  STD_LOGIC;	-- 100MHz clock
           reset 		: in  STD_LOGIC;	-- reset active high
           we 			: in  STD_LOGIC;	-- high for one clock for a write to sound chip
           data_in 	: in  STD_LOGIC_VECTOR (7 downto 0);	-- data bus in
           dac_out 	: out  STD_LOGIC_VECTOR (7 downto 0));	-- output to audio DAC
end tms9919;

architecture tms9919_Behavioral of tms9919 is
	signal latch_high		: std_logic_vector(6 downto 0);	-- written when MSB (bit 7) is set
	signal tone1_div_val : std_logic_vector(9 downto 0);	-- divider value
	signal tone1_att		: std_logic_vector(3 downto 0);	-- attenuator value
	signal tone2_div_val : std_logic_vector(9 downto 0);	-- divider value
	signal tone2_att		: std_logic_vector(3 downto 0);	-- attenuator value
	signal tone3_div_val : std_logic_vector(9 downto 0);	-- divider value
	signal tone3_att		: std_logic_vector(3 downto 0);	-- attenuator value
	signal noise_div_val : std_logic_vector(3 downto 0);	-- Noise generator divisor
	signal noise_att		: std_logic_vector(3 downto 0);	-- attenuator value
	
	signal tone1_counter : std_logic_vector(9 downto 0);
	signal tone2_counter : std_logic_vector(9 downto 0);
	signal tone3_counter : std_logic_vector(9 downto 0);
	signal noise_counter : std_logic_vector(10 downto 0);
	signal master_divider : integer;
	
	signal tone1_out	: std_logic;
	signal tone2_out	: std_logic;
	signal tone3_out	: std_logic;
	signal noise_out	: std_logic;
	signal bump_noise : std_logic;
	signal noise_lfsr : std_logic_vector(15 downto 0);
	
	signal add_value	: std_logic_vector(3 downto 0);
	signal add_flag   : std_logic;
	
	
	type tone_proc_type is (
		chan0, chan1, chan2, noise, prepare, output
		);
	signal tone_proc : tone_proc_type;
	signal acc	: std_logic_vector(7 downto 0);

	function volume_lookup( 
		att : std_logic_vector(3 downto 0)) 
		return std_logic_vector is 
	begin
		case to_bitvector(att) is
			when x"0" => return "00111100";		-- this is not good for now
			when x"1" => return "00110000";	
			when x"2" => return "00100010";
			when x"3" => return "00010011";
			when x"4" => return "00001111";
			when x"5" => return "00001111";
			when x"6" => return "00001111";
			when x"7" => return "00001111";
			when x"8" => return "00001100";
			when x"9" => return "00001000";
			when x"A" => return "00000110";
			when x"B" => return "00000100";
			when x"C" => return "00000011";
			when x"D" => return "00000010";
			when x"E" => return "00000001";	-- minimum change
			when x"F" => return "00000000";	-- no change
		end case;
	end;
	

begin

	process(clk, reset)
	variable k : std_logic;
	begin
		if reset = '1' then
			latch_high <= (others => '0');
			tone1_att <= "1111";	-- off
			tone2_att <= "1111";	-- off
			tone3_att <= "1111";	-- off
			noise_att <= "1111";	-- off
			master_divider <= 0;
			add_value <= (others => '0');
			add_flag <= '0';
		elsif rising_edge(clk) then
			if we='1' then
				-- data write 
				if data_in(7) = '1' then
					latch_high <= data_in(6 downto 0);	-- store for later re-use
					case data_in(6 downto 4) is 
						when "000" => tone1_div_val(3 downto 0) <= data_in(3 downto 0);
						when "001" => tone1_att 					 <= data_in(3 downto 0);
						when "010" => tone2_div_val(3 downto 0) <= data_in(3 downto 0);
						when "011" => tone2_att 					 <= data_in(3 downto 0);
						when "100" => tone3_div_val(3 downto 0) <= data_in(3 downto 0);
						when "101" => tone3_att 					 <= data_in(3 downto 0);
						when "110" => noise_div_val 				 <= data_in(3 downto 0);
							noise_lfsr <= x"0001"; -- initialize noise generator
						when "111" => noise_att 					 <= data_in(3 downto 0);
						when others =>
					end case;
				else 
					-- Write with MSB set to zero. Use latched register value.
					case latch_high(6 downto 4) is 
						when "000" =>	tone1_div_val(9 downto 4) <= data_in(5 downto 0);
						when "010" =>	tone2_div_val(9 downto 4) <= data_in(5 downto 0);
						when "100" =>	tone3_div_val(9 downto 4) <= data_in(5 downto 0);
						when others =>
					end case;
				end if;
			end if;
			
			-- Ok. Now handle the actual sound generators.
			-- The input freuency on the TI-99/4A is 3.58MHz which is divided by 32, this is 111875Hz.
			-- Our clock is 100MHz. As the first approximation we will divide 100MHz by 894.
			-- That gives a clock of 111857Hz which is good enough.
			-- After checking that actually yields half of the desired frequency. So let's go with 447.
			master_divider <= master_divider + 1;
			if master_divider >= 446 then
				master_divider <= 0;
				tone1_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(tone1_counter)) - 1, tone1_counter'length));
				tone2_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(tone2_counter)) - 1, tone2_counter'length));
				tone3_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(tone3_counter)) - 1, tone3_counter'length));
				noise_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(noise_counter)) - 1, noise_counter'length));
				
				if unsigned(tone1_counter) = 0 then
					tone1_out <= not tone1_out;
					tone1_counter <= tone1_div_val;
				end if;
				if unsigned(tone2_counter) = 0 then
					tone2_out <= not tone2_out;
					tone2_counter <= tone2_div_val;
				end if;
				bump_noise <= '0';
				if unsigned(tone3_counter) = 0 then
					tone3_out <= not tone3_out;
					tone3_counter <= tone3_div_val;
					if noise_div_val(1 downto 0) = "11" then
						bump_noise <= '1';
					end if;
				end if;
				
				if noise_counter(8 downto 0) = "000000000" then 
					case noise_div_val(1 downto 0) is
						when "00" => bump_noise <= '1';	-- 512 
						when "01" =>
							if noise_counter(9)='0' then -- 1024
								bump_noise <= '1';
							end if;
						when "10" =>
							if noise_counter(10 downto 9)="00" then -- 2048
								bump_noise <= '1';
							end if;
						when others =>
					end case;
				end if;
				
				if bump_noise='1' then
					if noise_div_val(2)='1' then
						-- white noise
						k := noise_lfsr(14) xor noise_lfsr(13);
					else
						k := noise_lfsr(14);	-- just feedback 
					end if;
					noise_lfsr <= noise_lfsr(14 downto 0) & k;
					if noise_lfsr(14) = '1' then 
						noise_out <= not noise_out;
					end if;
				end if;
				
			end if;

			if add_flag='1' then 
				acc <= std_logic_vector(to_unsigned(
					to_integer(unsigned(acc)) + to_integer(unsigned(volume_lookup(add_value))), 
					acc'length));
			else
				acc <= std_logic_vector(to_unsigned(
					to_integer(unsigned(acc)) - to_integer(unsigned(volume_lookup(add_value))), 
					acc'length));
			end if;
			
			-- Ok now combine the tone_out values
			case tone_proc is
				when chan0 =>
					add_value <= tone1_att;
					add_flag <= tone1_out;
					tone_proc <= chan1;
				when chan1 =>
					add_value <= tone2_att;
					add_flag <= tone2_out;
					tone_proc <= chan2;
				when chan2 =>
					add_value <= tone3_att;
					add_flag <= tone3_out;
					tone_proc <= noise;
				when noise =>
					add_value <= noise_att;
					add_flag <= noise_out;
					tone_proc <= prepare;
				when prepare =>
					-- During this step the acc gets updated with noise value
					add_value <= "1111";	-- silence, this stage is just a wait state to pick up noise
					tone_proc <= output;
				when others =>		-- output stage
					dac_out <= acc;
					add_value <= "1111";	-- no change
					acc <= x"80";
					tone_proc <= chan0;
			end case;
			
		end if;
	end process;

end tms9919_Behavioral;

