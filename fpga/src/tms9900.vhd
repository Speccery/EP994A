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
	signal wr_dat : std_logic_vector(15 downto 0);	-- data written to memory
	signal reg_t : std_logic_vector(15 downto 0);	-- temporary register
		
	type cpu_state_type is (
		do_pc_read,
		do_blwp, do_blwp1, do_blwp2,
		do_fetch, do_decode,
		do_branch,
		do_stuck,
		do_read,
		do_read0, do_read1, do_read2, do_read3,
		do_write,
		do_write0, do_write1, do_write2, do_write3,
		do_ir_imm, do_lwpi_limi,
		do_load_imm, do_load_imm2, do_load_imm3, do_load_imm4, do_load_imm5
	);
	signal cpu_state : cpu_state_type;
	signal cpu_state_next : cpu_state_type;
	
	signal arg1 : std_logic_vector(15 downto 0);
	signal arg2 : std_logic_vector(15 downto 0);
	signal alu_result :  std_logic_vector(15 downto 0);
	
	type alu_operation_type is (
		alu_load2, alu_add, alu_or, alu_and, alu_compare
	);
	signal ope : alu_operation_type;
	signal alu_flag_zero     : std_logic;
	signal alu_flag_overflow : std_logic;
	signal alu_logical_gt 	 : std_logic;
	signal alu_arithmetic_gt : std_logic;
begin
	
	process(arg1, arg2, ope)
	begin
		case ope is
			when alu_load2 =>
				alu_result <= arg2;
			when alu_add =>
				alu_result <= std_logic_vector(
					to_unsigned(to_integer(unsigned(arg1)) + to_integer(unsigned(arg2)), alu_result'length)
					);
			when alu_or =>
				alu_result <= arg1 or arg2;
			when alu_and =>
				alu_result <= arg1 and arg2;
			when alu_compare =>
				alu_result <= std_logic_vector(
					to_unsigned(to_integer(unsigned(arg1)) - to_integer(unsigned(arg2)), alu_result'length)
					);
		end case;			
	end process;
	-- ST0 ST1 ST2 ST3 ST4 ST5
	-- L>  A>  =   C   O   P
	-- ST0
	alu_logical_gt 	<= '1' when (arg1(15)='0' and arg2(15)='1') or (arg1(15)=arg2(15) and alu_result(15)= '1') else '0';
	-- ST1
	alu_arithmetic_gt <= '1' when (arg1(15)='1' and arg2(15)='0') or (arg1(15)=arg2(15) and alu_result(15)= '1') else '0';
	-- ST2
	alu_flag_zero 		<= '1' when alu_result = x"0000" else '0';
	-- ST3 carry
	-- ST4 overflow
	alu_flag_overflow <= '1' when arg1(15)=arg2(15) and alu_result(15) /= arg1(15) else '0';
	
	

	process(clk, reset) is
	variable offset : std_logic_vector(15 downto 0);
	variable take_branch : boolean;
	begin
		if reset = '1' then
			st <= (others => '0');
			pc <= (others => '0');
			stuck <= '0';
			cpu_state <= do_blwp;		-- do blwp from pc (zero)
			rd <= '0';
			wr <= '0';
		else
			if rising_edge(clk) then
			
				-- CPU state changes
				case cpu_state is
				------------------------
				-- memory opperations --
				------------------------
					when do_pc_read =>
						addr <= pc;
						pc <= std_logic_vector(to_unsigned(2+to_integer(unsigned(pc)), pc'length));	-- increment pc always
						as <= '1';
						rd <= '1';
						cpu_state <= do_read0;
					when do_read =>		-- start memory read cycle
						as <= '1';
						rd <= '1';
						addr <= ea;
						cpu_state <= do_read0;
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
					when do_write =>
						as <= '1';
						wr <= '1';
						addr <= ea;
						data_out <= wr_dat;
						cpu_state <= do_write0;
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
					when do_blwp =>						-- read from pc new W, from pc+2 new PC
						cpu_state <= do_pc_read;
						cpu_state_next <= do_blwp1;
					when do_blwp1 =>
						w <= rd_dat;						-- first read done, put it to workspace pointer
						cpu_state <= do_pc_read;		-- do second read
						cpu_state_next <= do_blwp2;	-- continue from here
					when do_blwp2 =>
						pc <= rd_dat;						-- 2nd read done, put it to program counter
						cpu_state <= do_fetch;			-- go to instruction fetch
					when do_fetch =>
						iaq <= '1';
						cpu_state <= do_pc_read;
						cpu_state_next <= do_decode;
						test_out <= x"0000";
					when do_decode =>
						ir <= rd_dat;						-- read done, store to instruction register
						iaq <= '0';
						-- Next analyze what we got
						if rd_dat(15 downto 12) = "0001" then
							cpu_state <= do_branch;
						else 
							if rd_dat(15 downto 4) = x"020" or rd_dat(15 downto 4) = x"022" or   -- LI, AI
								rd_dat(15 downto 4) = x"024" or rd_dat(15 downto 4) = x"026" or 	-- ANDI, ORI
								rd_dat(15 downto 4) = x"028"													-- CI
							then -- ANDI, ORI 
								cpu_state <= do_load_imm;	-- LI or AI
							elsif rd_dat(15 downto 9) = "0000001" and rd_dat(4 downto 0) = "00000" then
								cpu_state <= do_ir_imm;
							else
								cpu_state <= do_stuck;		-- unknown instruction, let's get stuck
							end if;
						end if;
					when do_branch =>
						-- do branching, we need to sign extend ir(7 downto 0) and add it to PC and continue.
						cpu_state <= do_fetch; -- may be overwritten with do_stuck
						take_branch := False;
						case ir(11 downto 8) is
						when "0000" => take_branch := True;	-- JMP
						when "0001" => if ST(14)='0' and ST(13)='0' then take_branch := True; end if; -- JLT
						when "0010" => if ST(15)='0' or  ST(13)='1' then take_branch := True; end if; -- JLE
						when "0011" => if                ST(13)='1' then take_branch := True; end if; -- JEQ
						when "0100" => if ST(15)='1' or  ST(13)='1' then take_branch := True; end if; -- JHE
						when "0101" => if                ST(14)='1' then take_branch := True; end if; -- JGT
						when "0110" => if                ST(13)='0' then take_branch := True; end if; -- JNE
						when "0111" => if                ST(12)='0' then take_branch := True; end if; -- JNC
						when "1000" => if                ST(12)='1' then take_branch := True; end if; -- JOC (on carry)
						when "1001" => if                ST(11)='0' then take_branch := True; end if; -- JNO (no overflow)
						when "1010" => if ST(15)='0' and ST(13)='0' then take_branch := True; end if; -- JL
						when "1011" => if ST(15)='1' and ST(13)='0' then take_branch := True; end if; -- JH
						when "1100" => if                ST(10)='1' then take_branch := True; end if; -- JOP (odd parity)
						when others => cpu_state <= do_stuck;
						end case;
						if take_branch then
							offset := ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7) & ir(7 downto 0) & '0';
							pc <= std_logic_vector(to_unsigned(to_integer(unsigned(offset)) + to_integer(unsigned(pc)), pc'length));
						end if;
					when do_ir_imm =>
						test_out <= x"EE00";
						if ir(8 downto 5) = "0111" or ir(8 downto 5) = "1000" then	-- 4 LSBs don't care
							cpu_state <= do_pc_read;
							cpu_state_next <= do_lwpi_limi;
						else
							cpu_state <= do_stuck;
						end if;
					when do_lwpi_limi =>	
						cpu_state <= do_fetch;
						if ir(8 downto 5) = "0111" then
							w <= rd_dat;	-- LWPI
						else
							st(3 downto 0) <= rd_dat(3 downto 0);	-- LIMI
						end if;
						
					when do_load_imm =>	-- LI, AI, ANDI, ORI, CI instruction here
						test_out <= x"0001";
						cpu_state <= do_pc_read;		-- read immediate value from instruction stream
						cpu_state_next <= do_load_imm2;
					when do_load_imm2 =>
						test_out <= x"0002";
						reg_t <= rd_dat;	-- store the immediate to temp
						arg1 <= w;
						arg2 <= x"00" & "000" & ir(3 downto 0) & '0';
						ope <= alu_add;	-- calculate workspace address
						cpu_state <= do_load_imm3;
					when do_load_imm3 =>	-- read from workspace register
						test_out <= x"0003";
						ea <= alu_result; 
						cpu_state <= do_read;	
						cpu_state_next <= do_load_imm4;
					when do_load_imm4 =>	-- do actual operation
						test_out <= x"0004";
						arg1 <= rd_dat;	-- contents of workspace register
						arg2 <= reg_t;		-- temporary holds the immediate addess
						case ir(7 downto 4) is
							when x"0" => ope <= alu_load2;
							when x"2" => ope <= alu_add;
							when x"4" => ope <= alu_and;
							when x"6" => ope <= alu_or;
							when x"8" => ope <= alu_compare;
							when others => cpu_state <= do_stuck;
						end case;
						cpu_state <= do_load_imm5;
					when do_load_imm5 =>		-- write to workspace the result of ALU, ea still points to register
						test_out <= x"0005";
						-- let's write flags 0-2 for all instructions
						st(15) <= alu_logical_gt;
						st(14) <= alu_arithmetic_gt;
						st(13) <= alu_flag_zero;
						if ope = alu_add then
							-- carry to ST3
							st(11) <= alu_flag_overflow;
						end if;
						
						if ope /= alu_compare then
							wr_dat <= alu_result;	
							cpu_state <= do_write;
							cpu_state_next <= do_fetch;
						else
							-- compare, skip result write altogether
							cpu_state <= do_fetch;
						end if;
					when do_stuck =>
						stuck <= '1';
				end case;
				
			
			end if; -- rising_edge
		end if;	
	end process;


end Behavioral;

