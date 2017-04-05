----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 		Erik Piehl
-- 
-- Create Date:    09:53:30 04/02/2017 
-- Design Name: 	 TMS9900 CPU Core
-- Module Name:    tms9900 - Behavioral 
-- Project Name: 
-- Target Devices: XC6SLX9
-- Tool versions:  ISE 14.7
-- Description: 	 Toplevel of the CPU core implementation
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
library UNISIM;
use UNISIM.VComponents.all;

entity tms9900 is Port ( 
	clk 		: in  STD_LOGIC;		-- input clock
	reset 	: in  STD_LOGIC;		-- reset, active high
	addr 		: out  STD_LOGIC_VECTOR (15 downto 0);
	data_in 	: in  STD_LOGIC_VECTOR (15 downto 0);
	data_out : out  STD_LOGIC_VECTOR (15 downto 0);
	rd 		: out  STD_LOGIC;		
	wr 		: out  STD_LOGIC;
	ready 	: in  STD_LOGIC;		-- memory read input, a high terminates a memory cycle
	iaq 		: out  STD_LOGIC;
	as 		: out  STD_LOGIC;		-- address strobe, when high new address is valid, starts a memory cycle
	test_out : out STD_LOGIC_VECTOR (15 downto 0);
	stuck	 	: out  STD_LOGIC		-- when high the CPU is stuck
	);
end tms9900;

architecture Behavioral of tms9900 is
	-- CPU architecture registers
	signal pc : std_logic_vector(15 downto 0);
	signal w  : std_logic_vector(15 downto 0);
	signal st : std_logic_vector(15 downto 0);
	
	signal ea : std_logic_vector(15 downto 0);	-- effective address
	signal ir : std_logic_vector(15 downto 0);	-- instruction register
	signal rd_dat : std_logic_vector(15 downto 0);	-- data read from memory
		
	type cpu_state_type is (
		do_blwp, do_blwp1, do_blwp2,
		do_fetch, do_decode,
		do_branch,
		do_stuck,
		do_read,
		do_read0, do_read1, do_read2, do_read3,
		do_write0, do_write1, do_write2, do_write3,
		do_ir_imm, do_lwpi_limi
	);
	signal cpu_state : cpu_state_type;
	signal cpu_state_next : cpu_state_type;
	
begin

	test_out <= w;

	process(clk, reset) is
	variable offset : std_logic_vector(15 downto 0);
	begin
		if reset = '1' then
			st <= (others => '0');
			ea <= (others => '0');
			stuck <= '0';
			cpu_state <= do_blwp;		-- do blwp from ea (zero)
			rd <= '0';
			wr <= '0';
		else
			if rising_edge(clk) then
			
				data_out <= w;	-- testing

			
				-- CPU state changes
				case cpu_state is
				------------------------
				-- memory opperations --
				------------------------
					when do_read =>		-- start memory read cycle
						as <= '1';
						rd <= '1';
						addr <= ea;
						cpu_state <= do_read0;
						ea <= std_logic_vector(to_unsigned(2+to_integer(unsigned(ea)), ea'length));	-- increment ea always
					when do_read0 => cpu_state <= do_read1; as <= '0';
					when do_read1 => cpu_state <= do_read2;
					when do_read2 => cpu_state <= do_read3;
					when do_read3 => 
						-- if ready='1' then 
							cpu_state <= cpu_state_next;
							rd_dat <= data_in;
							rd <= '0';
						-- end if;
					-- write cycles --
					when do_write0 => cpu_state <= do_write1; as <= '0';
					when do_write1 => cpu_state <= do_write2;
					when do_write2 => cpu_state <= do_write3;
					when do_write3 => 
						-- if ready='1' then
							cpu_state <= cpu_state_next;
							wr <= '0';
						-- end if;
					----------------
					-- operations --
					----------------
					when do_blwp =>			-- read from ea new W, from ea+2 new PC
						cpu_state <= do_read;
						cpu_state_next <= do_blwp1;
					when do_blwp1 =>
						w <= rd_dat;						-- first read done, put it to workspace pointer
						cpu_state <= do_read;			-- do second read
						cpu_state_next <= do_blwp2;	-- continue from here
					when do_blwp2 =>
						pc <= rd_dat;						-- 2nd read done, put it to program counter
						cpu_state <= do_fetch;			-- go to instruction fetch
					when do_fetch =>
						ea <= pc;							-- fetch from 
						iaq <= '1';
						cpu_state <= do_read;
						cpu_state_next <= do_decode;
					when do_decode =>
						pc <= ea;							-- capture incremented pc
						ir <= rd_dat;						-- read done, store to instruction register
						iaq <= '0';
						-- Next analyze what we got
						if rd_dat(15 downto 8) = "00010000" then
							cpu_state <= do_branch;
						else 
							if rd_dat(15 downto 9) = "0000001" then
								cpu_state <= do_ir_imm;
							else
								cpu_state <= do_stuck;		-- unknown instruction, let's get stuck
							end if;
						end if;
					when do_branch =>
						-- do branching, we need to sign extend ir(7 downto 0) and add it to PC and continue.
						offset := ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7 downto 0) & '0';
						pc <= std_logic_vector(to_unsigned(to_integer(unsigned(offset)) + to_integer(unsigned(pc)), pc'length));
						cpu_state <= do_fetch;
					when do_ir_imm =>
						if ir(8 downto 5) = "0111" or ir(8 downto 5) = "1000" then	-- 4 LSBs don't care
							cpu_state <= do_read;
							cpu_state_next <= do_lwpi_limi;
						else
							cpu_state <= do_stuck;
						end if;
					when do_lwpi_limi =>	
						pc <= ea;
						cpu_state <= do_fetch;
						if ir(8 downto 5) = "0111" then
							w <= rd_dat;	-- LWPI
						else
							st(3 downto 0) <= rd_dat(3 downto 0);	-- LIMI
						end if;
					when do_stuck =>
						stuck <= '1';
				end case;
				
			
			end if; -- rising_edge
		end if;	
	end process;


end Behavioral;

