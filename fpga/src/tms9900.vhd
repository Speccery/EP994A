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

-- simulation begin
USE STD.TEXTIO.ALL;
USE IEEE.STD_LOGIC_TEXTIO.ALL;
-- simulation end


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
	alu_debug_out  : out STD_LOGIC_VECTOR (15 downto 0); -- ALU debug bus
	alu_debug_oper : out STD_LOGIC_VECTOR(3 downto 0);
	alu_debug_arg1 :  out STD_LOGIC_VECTOR (15 downto 0);
	alu_debug_arg2 :  out STD_LOGIC_VECTOR (15 downto 0);	
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
	signal source_op : std_logic_vector(15 downto 0); -- storage of source operand
	signal read_byte_aligner : std_logic_vector(15 downto 0); -- align bytes to words for reads
		
	type cpu_state_type is (
		do_pc_read, do_alu_read,
		do_fetch, do_decode,
		do_branch,
		do_stuck,
		do_read,
		do_read0, do_read1, do_read2, do_read3,
		do_write,
		do_write0, do_write1, do_write2, do_write3,
		do_ir_imm, do_lwpi_limi,
		do_load_imm, do_load_imm2, do_load_imm3, do_load_imm4, do_load_imm5,
		do_read_operand0, do_read_operand1, do_read_operand2, do_read_operand3, do_read_operand4, do_read_operand5,
		do_write_operand0, do_write_operand1, do_write_operand2, do_write_operand3, do_write_operand4,
		do_alu_write,
		do_dual_op, do_dual_op1, do_dual_op2, do_dual_op3,
		do_source_address0, do_source_address1, do_source_address2, do_source_address3, do_source_address4, do_source_address5, do_source_address6,
		do_branch_b_bl, do_single_op_read, do_single_op_writeback,
		do_rtwp0, do_rtwp1, do_rtwp2, do_rtwp3,
		do_shifts0, do_shifts1, do_shifts2, do_shifts3, do_shifts4,
		do_blwp0, do_blwp1, do_blwp2, do_blwp3 
	);
	signal cpu_state : cpu_state_type;
	signal cpu_state_next : cpu_state_type;
	signal cpu_state_operand_return : cpu_state_type;
	
	signal arg1 : std_logic_vector(15 downto 0);
	signal arg2 : std_logic_vector(15 downto 0);
	signal alu_out : std_logic_vector(16 downto 0);
	signal alu_result :  std_logic_vector(15 downto 0);
	signal shift_count : std_logic_vector(4 downto 0);
	
	type alu_operation_type is (
		alu_load2, alu_add, alu_or, alu_and, alu_sub, alu_and_not, alu_xor, alu_swpb2, alu_abs,
		alu_sla, alu_sra, alu_src, alu_srl
	);
	signal ope : alu_operation_type;
	signal alu_flag_zero     : std_logic;
	signal alu_flag_overflow : std_logic;
	signal alu_logical_gt 	 : std_logic;
	signal alu_arithmetic_gt : std_logic;
	signal alu_flag_carry    : std_logic;
	
	-- operand_mode controls fetching of operands, i.e. addressing modes
	-- operand_mode(5:4) is the mode R, *R, @ADDR, @ADDR(R), *R+
	-- operand_mode(3:0) is the register number
	signal operand_mode		 : std_logic_vector(5 downto 0);
	signal operand_word		 : boolean;	-- if false, we have a byte (matters for autoinc)
begin
	
	process(arg1, arg2, ope)
	variable t : std_logic_vector(15 downto 0);
	begin
		-- arg1 is DA, arg2 is SA when ALU used for instruction execute
		case ope is
			when alu_load2 =>
				alu_out <= '0' & arg2;
				alu_debug_oper <= x"1";
			when alu_add =>
				alu_out <= std_logic_vector(unsigned('0' & arg1) + unsigned('0' & arg2));
				alu_debug_oper <= x"2";
			when alu_or =>
				alu_out <= '0' & arg1 or '0' & arg2;
				alu_debug_oper <= x"3";
			when alu_and =>
				alu_out <= '0' & arg1 and '0' & arg2;
				alu_debug_oper <= x"4";
			when alu_sub =>
				t := std_logic_vector(unsigned(arg1) - unsigned(arg2));
				alu_out <= t(15) & t;
				alu_debug_oper <= x"5";
			when alu_and_not =>
				alu_out <= '0' & arg1 and not '0' & arg2;
				alu_debug_oper <= x"6";
			when alu_xor =>
				alu_out <= '0' & arg1 xor '0' & arg2;
				alu_debug_oper <= x"7";
			when alu_swpb2 =>
				alu_out <= '0' & arg2(7 downto 0) & arg2(15 downto 8); -- swap bytes of arg2
				alu_debug_oper <= x"8";
			when alu_abs => -- compute abs value of arg2
				alu_debug_oper <= x"9";
				if arg2(15) = '0' then
					alu_out <= '0' & arg2;
				else
					-- same as alu sub (arg1 must be zero; this is set elsewhere)
					alu_out <= std_logic_vector(unsigned(arg1(15) & arg1) - unsigned(arg2(15) & arg2));
				end if;
			when alu_sla =>
				alu_debug_oper <= x"A";
				alu_out <= arg2 & '0';
			when alu_sra =>
				alu_debug_oper <= x"B";
				alu_out <= arg2(0) & arg2(15) & arg2(15 downto 1);
			when alu_src =>
				alu_debug_oper <= x"C";
				alu_out <= arg2(0) & arg2(0) & arg2(15 downto 1);
			when alu_srl =>
				alu_debug_oper <= x"D";
				alu_out <= arg2(0) & '0' & arg2(15 downto 1);
		end case;			
	end process;
	alu_result <= alu_out(15 downto 0);
	alu_debug_out <= alu_out(15 downto 0);
	alu_debug_arg1 <= arg1;
	alu_debug_arg2 <= arg2;
	
	-- ST0 ST1 ST2 ST3 ST4 ST5
	-- L>  A>  =   C   O   P
	-- ST0
	alu_logical_gt 	<= '1' when (arg1(15)='0' and arg2(15)='1') or (arg1(15)=arg2(15) and alu_result(15)= '1') else '0';
	-- ST1
	alu_arithmetic_gt <= '1' when (arg1(15)='1' and arg2(15)='0') or (arg1(15)=arg2(15) and alu_result(15)= '1') else '0';
	-- ST2
	alu_flag_zero 		<= '1' when alu_result = x"0000" else '0';
	-- ST3 carry
	alu_flag_carry    <= alu_out(16);
	-- ST4 overflow
	alu_flag_overflow <= '1' when arg1(15)=arg2(15) and alu_result(15) /= arg1(15) else '0';

	-- Byte aligner
	process(ea, rd_dat, operand_mode, operand_word)
	begin
		-- We have a byte operation. If the data came from register,
		-- we don't need to do anything. If it came from memory,
		-- we will zero extend and possibly shift.
		if operand_word or operand_mode(5 downto 4) = "00" then
			read_byte_aligner <= rd_dat;
		else
			-- Not register operand. Need to check that EA is still valid.
			-- BUGBUG: EA is not always valid here! For autoinc / etc.
			if ea(0) = '0' then
				read_byte_aligner <= rd_dat(15 downto 8) & x"00";
			else
				read_byte_aligner <= rd_dat(7 downto 0) & x"00";
			end if;
		end if;
	end process;

	process(clk, reset) is
	variable offset : std_logic_vector(15 downto 0);
	variable take_branch : boolean;
	-- simulation begin
	variable my_line : line;	-- from textio
	-- simulation end
	begin
		if reset = '1' then
			st <= (others => '0');
			pc <= (others => '0');
			stuck <= '0';
			rd <= '0';
			wr <= '0';
			-- Prepare for BLWP from 0
			ea   <= x"0000";
			arg1 <= x"0002";
			arg2 <= x"0000";
			ope <= alu_add;
			cpu_state <= do_read;		-- read from 0, i.e the workspace pointer
			cpu_state_next <= do_blwp0;		-- do blwp from pc (zero)
		else
			if rising_edge(clk) then
			
				-- CPU state changes
				case cpu_state is
				------------------------
				-- memory opperations --
				------------------------
					when do_pc_read =>
						addr <= pc;
						pc <= std_logic_vector(unsigned(pc) + to_unsigned(2,16));
						as <= '1';
						rd <= '1';
						cpu_state <= do_read0;
					when do_read =>		-- start memory read cycle
						as <= '1';
						rd <= '1';
						addr <= ea;
						cpu_state <= do_read0;
					when do_alu_read =>
						as <= '1';
						rd <= '1';
						addr <= alu_result;
						cpu_state <= do_read0;
					when do_read0 => cpu_state <= do_read1; as <= '0';
					when do_read1 => cpu_state <= do_read2;
					when do_read2 => cpu_state <= do_read3;
					when do_read3 => 
						-- if ready='1' then 
							cpu_state <= cpu_state_next;
							rd <= '0';
							rd_dat <= data_in;
						-- end if;
					-- write cycles --
					when do_write =>
						as <= '1';
						wr <= '1';
						addr <= ea;
						data_out <= wr_dat;
						cpu_state <= do_write0;
					when do_alu_write =>
						as <= '1';
						wr <= '1';
						addr <= alu_result;
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
					when do_fetch =>		-- instruction opcode fetch
						iaq <= '1';
						cpu_state <= do_pc_read;
						cpu_state_next <= do_decode;
						test_out <= x"0000";
					-------------------------------------------------------------------------------
					-- do_decode
					-------------------------------------------------------------------------------
					when do_decode =>
						operand_word <= True;			-- By default 16-bit operations.
						ir <= rd_dat;						-- read done, store to instruction register
						iaq <= '0';
						-- Next analyze what we got
						-- check for dual operand instructions with full addressing modes
						if rd_dat(15 downto 13) = "101" or -- A, AB
						   rd_dat(15 downto 13) = "100" or -- C, CB
							rd_dat(15 downto 13) = "011" or -- S, SB
							rd_dat(15 downto 13) = "111" or -- SOC, SOCB
							rd_dat(15 downto 13) = "010" or -- SZC, SZCB
							rd_dat(15 downto 13) = "110" then -- MOV, MOVB
							-- found dual operand instruction. Get source operand.
							operand_mode <= rd_dat(5 downto 0);	-- ir not set at this point yet
							if rd_dat(12) = '1' then
								operand_word <= False;	-- byte operation
							else
								operand_word <= True;
							end if;
							cpu_state <= do_read_operand0;
							cpu_state_operand_return <= do_dual_op;
						elsif rd_dat(15 downto 12) = "0001" then
								cpu_state <= do_branch; 
						elsif rd_dat(15 downto 10) = "000010" then -- SLA, SRA, SRC, SRL
							-- Do all the shifts SLA(10) SRA(00) SRC(11) SRL(01), OPCODE:6 INS:2 C:4 W:4
							shift_count <= '0' & rd_dat(7 downto 4);
							arg1 <= w;
							arg2 <= x"00" & "000" & rd_dat(3 downto 0) & '0';
							ope <= alu_add;	-- calculate workspace address
							cpu_state <= do_shifts0;
						elsif rd_dat = x"0380" then	-- RTWP
							arg1 <= w;
							arg2 <= x"00" & "000" & x"D" & '0';	-- calculate of register 13 (WP)
							ope <= alu_add;	
							cpu_state <= do_rtwp0;
							
						elsif rd_dat(15 downto 4) = x"020" or rd_dat(15 downto 4) = x"022" or   -- LI, AI
									rd_dat(15 downto 4) = x"024" or rd_dat(15 downto 4) = x"026" or 	-- ANDI, ORI
									rd_dat(15 downto 4) = x"028"													-- CI
								then -- ANDI, ORI 
									cpu_state <= do_load_imm;	-- LI or AI
						elsif rd_dat(15 downto 9) = "0000001" and rd_dat(4 downto 0) = "00000" then
									cpu_state <= do_ir_imm;
						elsif rd_dat(15 downto 10) = "000001" then 
							-- Single operand instructions: BL, B, etc.
							operand_word <= True;
							operand_mode <= rd_dat(5 downto 0);
							cpu_state <= do_source_address0;
							cpu_state_operand_return <= do_branch_b_bl;
						else
							cpu_state <= do_stuck;		-- unknown instruction, let's get stuck
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
							pc <= std_logic_vector(unsigned(offset) + unsigned(pc));
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
							when x"8" => ope <= alu_sub;
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
							st(12) <= alu_flag_carry;
							st(11) <= alu_flag_overflow;
						end if;
						
						if ope /= alu_sub then
							wr_dat <= alu_result;	
							cpu_state <= do_write;
							cpu_state_next <= do_fetch;
						else
							-- compare, skip result write altogether
							cpu_state <= do_fetch;
						end if;
					
					-------------------------------------------------------------
					-- Dual operand instructions
					-------------------------------------------------------------					
					when do_dual_op =>
						source_op <= read_byte_aligner;
						-- calculate address of destination operand
						cpu_state <= do_source_address0;
						cpu_state_operand_return <= do_dual_op1;
						operand_mode <= ir(11 downto  6);
					when do_dual_op1 =>
						-- Now ALU output has address of destination (side effects done), and source_op
						-- has the source operand.
						-- Read destination operand, except if we have MOV in that case optimized
						ea <= alu_result;	-- Save destination address
						if ir(15 downto 13) = "110" and operand_word then
							-- We have MOV, skip reading of dest operand. We still need to
							-- move along as we need to set flags.
							test_out <= x"DD00";
							cpu_state <= do_dual_op2;
						else
							-- we have any of the other ones expect MOV
							cpu_state <= do_read;
							cpu_state_next <= do_dual_op2;
							test_out <= x"DD10";
						end if;
					when do_dual_op2 =>
						-- perform the actual operation
						test_out <= x"DD02";
						-- Handle processing of byte operations for rd_dat.
						arg1 <= read_byte_aligner;
						arg2 <= source_op;
						cpu_state <= do_dual_op3;
						case ir(15 downto 13) is
							when "101" => ope <= alu_add;
							when "100" => ope <= alu_sub;
							when "011" => ope <= alu_sub;
							when "111" => ope <= alu_or;
							when "010" => ope <= alu_and_not;
							when "110" => ope <= alu_load2;
							when others =>	cpu_state <= do_stuck;
						end case;
					when do_dual_op3 =>
						-- Store flags.
						st(15) <= alu_logical_gt;
						st(14) <= alu_arithmetic_gt;
						st(13) <= alu_flag_zero;
						if ir(15 downto 13) = "101" or ir(15 downto 13) = "011" then
							-- add and sub set two more flags
							st(12) <= alu_flag_carry;
							st(11) <= alu_flag_overflow;
						end if;						
						-- Store the result except with compare instruction.
						if ir(15 downto 13) = "100" then
							cpu_state <= do_fetch;	-- compare, we are already done
							test_out <= x"DD03";
						else
							-- writeback result
							test_out <= x"DD13";
							if operand_word then
								wr_dat <= alu_result;
							else
								-- simulation debug start
								write(my_line, STRING'("do_dual_op3 byte arg1 "));
								hwrite(my_line, arg1);
								write(my_line, STRING'(" arg2 "));
								hwrite(my_line, arg2);
								write(my_line, STRING'(" alu_result "));
								hwrite(my_line, alu_result);
								write(my_line, STRING'(" rd_dat "));
								hwrite(my_line, rd_dat);

								-- simulation debug end
								-- Byte operation.
								if operand_mode(5 downto 4) = "00" or ea(0)='0' then
									-- Register operation or write to high byte. Always impacts high byte.
									wr_dat <= alu_result(15 downto 8) & rd_dat(7 downto 0);
									write(my_line, STRING'(" HIGH "));
								else
									-- Memory operation going to low byte. High byte not impacted.
									wr_dat <= rd_dat(15 downto 8) & alu_result(15 downto 8); 
									write(my_line, STRING'(" LOW "));
								end if;
								
								writeline(OUTPUT, my_line);	-- simulation
							end if;
							cpu_state_next <= do_fetch;
							cpu_state <= do_write;
						end if;
						
					-------------------------------------------------------------
					-- Single operand instructions
					-------------------------------------------------------------					
					when do_branch_b_bl =>
						-- when we enter here source address is at the ALU output
						case ir(9 downto 6) is 
							when "0001" => -- B instruction
								pc <= alu_result;	-- the source address is our PC destination
								cpu_state <= do_fetch;
							when "1010" => -- BL instruction.Store old PC to R11 before returning.
								pc <= alu_result;	-- the source address is our PC destination
								wr_dat <= pc;		-- capture old PC before to write data
								arg1 <= w;
								arg2 <= x"0016";	-- 2*11 = 22 = 0x16, offset to R11
								ope <= alu_add;
								cpu_state <= do_alu_write;
								cpu_state_next <= do_fetch;
							when "0011" => -- CLR instruction
								wr_dat <= x"0000";
								cpu_state <= do_alu_write;
								cpu_state_next <= do_fetch;
							when "1100" => -- SETO instruction
								wr_dat <= x"FFFF";
								cpu_state <= do_alu_write;
								cpu_state_next <= do_fetch;
							when "0101" => -- INV instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"FFFF";
								ope <= alu_xor;
							when "0100" => -- NEG instruction
								test_out <= x"EEFF";
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"0000";
								ope <= alu_sub;
							when "1101" => -- ABS instruction
								test_out <= x"AABB";
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"0000";
								ope <= alu_abs;
							when "1011" =>  -- SWPB instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"0000";
								ope <= alu_swpb2;
							when "0110" => -- INC instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"0001";
								ope <= alu_add;
							when "0111" => -- INCT instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"0002";
								ope <= alu_add;
							when "1000" => -- DEC instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"FFFF";	-- add -1 to create DEC
								ope <= alu_add;
							when "1001" => -- DECT instruction
								ea <= alu_result;	-- save address SA
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
								arg1 <= x"FFFE";	-- add -2 to create DEC
								ope <= alu_add;
							when "0010" => -- X instruction...
								cpu_state_next <= do_single_op_read;
								cpu_state <= do_read;
							when "0000" => -- BLWP instruction
								-- alu_result points to new WP
								ea <= alu_result;
								arg1 <= x"0002";			-- calculate address of PC
								arg2 <= alu_result;
								ope <= alu_add;
								cpu_state <= do_read;	-- read new WP
								cpu_state_next <= do_blwp0;
							when others =>
								cpu_state <= do_stuck;
						end case;
					when do_single_op_read =>
						if ir(9 downto 6) /= "0010" then -- if not X instruction
							arg2 <= rd_dat;	-- feed the data that was read to ALU
							cpu_state <= do_single_op_writeback;
						else -- Here we process the X instruction...
							ir <= rd_dat;
							cpu_state <= do_decode;	-- off we go to do something... BUGBUG: this may not work as flags will be impacted.
						end if;
					when do_single_op_writeback =>
						-- setup flags
						if ope /= alu_swpb2 then 
							-- set flags for INV, NEG, ABS, INC, INCT, DEC, DECT
							st(15) <= alu_logical_gt;
							st(14) <= alu_arithmetic_gt;
							st(13) <= alu_flag_zero;
							if ope = alu_add or ope = alu_sub or ope = alu_abs then
								st(12) <= alu_flag_carry;
								st(11) <= alu_flag_overflow;
							end if;
						end if;
						-- write the result
						wr_dat <= alu_result;
						cpu_state <= do_write;	-- ea still holds our address; return via write
						cpu_state_next <= do_fetch;

					-------------------------------------------------------------
					-- BLWP
					-- (SA) -> WP, (SA+2) -> PC
					-- R13 -> old_WP, R14 -> old_PC, R15 -> ST
					-------------------------------------------------------------					
					when do_blwp0 =>
						-- here rd_dat is our new WP, alu_result is addr of new PC
						ea 	<= alu_result;
						reg_t <= rd_dat;	-- store new WP to temp register
						arg1 	<= rd_dat;
						arg2 	<= x"00" & "000" & x"D" & '0';	-- calculate new addr 13 (WP)
						ope 	<= alu_add;
						cpu_state <= do_read;
						cpu_state_next <= do_blwp1;
					when do_blwp1 =>
						-- now rd_dat is new PC, reg_t new WP, alu_result addr of new R13
						wr_dat <= w;
						ea     <= alu_result;
						arg1   <= x"0002";
						arg2   <= alu_result;		-- prepare for PC write, i.e. point to new R14
						cpu_state 		<= do_write; -- write old WP
						cpu_state_next <= do_blwp2;
					when do_blwp2 =>
						wr_dat <= pc;
						ea     <= alu_result;
						arg2   <= alu_result;		-- prepare for ST write, i.e. point to new R15
						cpu_state 		<= do_write; -- write old PC
						cpu_state_next <= do_blwp3;
					when do_blwp3 =>
						wr_dat <= st;
						ea     <= alu_result;
						arg2   <= alu_result;
						cpu_state 		<= do_write; -- write old ST
						cpu_state_next <= do_fetch;
						-- now do the context switch
						pc <= rd_dat;
						w 	<= reg_t;
					
					-------------------------------------------------------------
					-- RTWP
					-- R13 -> WP, R14 -> PC, R15 -> ST
					-------------------------------------------------------------					
					when do_rtwp0 =>
						-- Here start first read cycle (from R13) and calculate also addr of R14
						ea <= alu_result;		-- Addr of R13
						arg1 <= x"0002";
						arg2 <= alu_result;
						ope <= alu_add;
						cpu_state <= do_read;
						cpu_state_next <= do_rtwp1;
					when do_rtwp1 =>
						w <= rd_dat;			-- W from previous R13
						ea <= alu_result;		-- addr of previous R14
						arg2 <= alu_result;	-- start calculation of R15
						cpu_state <= do_read;
						cpu_state_next <= do_rtwp2;
					when do_rtwp2 =>
						pc <= rd_dat;			-- PC from previous R14
						ea <= alu_result;		-- addr of previous R15
						cpu_state <= do_read;
						cpu_state_next <= do_rtwp3;
					when do_rtwp3 =>
						st <= rd_dat;			-- ST from previous R15
						cpu_state <= do_fetch;
						
					-------------------------------------------------------------
					-- All shift instructions
					-------------------------------------------------------------					
					when do_shifts0 =>
						ea <= alu_result;	-- address of our working register
						if shift_count = "00000" then 
							-- we need to read WR0 to get shift count
							arg1 <= w;
							arg2 <= x"0000";
							ope <= alu_add;
							cpu_state <= do_alu_read;
							cpu_state_next <= do_shifts1;
						else
							-- shift count is ready, it came from the instruction already.
							cpu_state <= do_read;			-- read the register.
							cpu_state_next <= do_shifts2;
						end if;
					when do_shifts1 =>
						-- rd_dat is now contents of WR0. Setup shift count and read the operand.
						if rd_dat(3 downto 0) = x"0" then
							shift_count <= '1' & rd_dat(3 downto 0);
						else
							shift_count <= '0' & rd_dat(3 downto 0);
						end if;
						cpu_state <= do_read;
						cpu_state_next <= do_shifts2;
					when do_shifts2 => 
						-- shift count is now ready. rd_dat is our operand.
						arg2 <= rd_dat;
						case ir(9 downto 8) is 
							when "00" =>
								ope <= alu_sra;
							when "01" =>
								ope <= alu_srl;
							when "10" =>
								ope <= alu_sla;
							when "11" =>
								ope <= alu_src;
							when others =>
						end case;
						cpu_state <= do_shifts3;
					when do_shifts3 => 	-- we stay here doing the shifting
						arg2 <= alu_result;
						shift_count <= std_logic_vector(unsigned(shift_count) - to_unsigned(1, 5));
						if shift_count = "00001" then 
							ope <= alu_load2;				-- pass through the previous result
							cpu_state <= do_shifts4;	-- done with shifting altogether
						else 
							cpu_state <= do_shifts3;	-- more shifting to be done
						end if;
					when do_shifts4 =>
						-- Store the result of shifting, and return to next instruction.
						wr_dat <= alu_result;
						cpu_state <= do_write;
						cpu_state_next <= do_fetch;
					
					-------------------------------------------------------------
					-- subprogram to calculate source operand address SA
					-- This does not include reading the source operand, the address is
					-- left at ALU output register alu_result
					-------------------------------------------------------------					
					when do_source_address0 =>
						arg1 <= w;
						arg2 <= x"00" & "000" & operand_mode(3 downto 0) & '0';
						ope <= alu_add;	-- calculate workspace address
						case operand_mode(5 downto 4) is
							when "00" => -- workspace register
								cpu_state <= cpu_state_operand_return;	-- return the workspace register address
							when "01" => -- workspace register indirect
								cpu_state <= do_alu_read;
								cpu_state_next <= do_source_address1;
							when "10" => -- symbolic or indexed mode
								cpu_state <= do_pc_read;
								if operand_mode(3 downto 0) = "0000" then
									cpu_state_next <= do_source_address1;	-- symbolic
								else
									cpu_state_next <= do_source_address2;	-- indexed
								end if;
							when "11" => -- workspace register indirect with autoincrement
								cpu_state <= do_alu_read;
								cpu_state_next <= do_source_address4;
							when others =>
								cpu_state <= do_stuck;
						end case;
					when do_source_address1 =>
						-- Make the result visible in alu output, i.e. the contents of the memory read.
						-- This is either workspace register contents in case of *Rx or the immediate operand in case of @LABEL
						arg2 <= rd_dat;
						ope  <= alu_load2;
						cpu_state <= cpu_state_operand_return;
					when do_source_address2 =>
						-- Indexed. rd_dat is the immediate parameter. alu_result is still the address of register Rx.
						-- We need to read the register and add it to rd_dat.
						reg_t <= rd_dat;
						cpu_state <= do_alu_read;
						cpu_state_next <= do_source_address3;
					when do_source_address3 =>
						arg1 <= rd_dat;	-- contents of Rx
						arg2 <= reg_t;		-- @TABLE
						ope <= alu_add;
						cpu_state <= cpu_state_operand_return;
					when do_source_address4 =>	-- autoincrement
						reg_t <= rd_dat;	-- save the value of Rx, this is our return value
						arg1 <= rd_dat;
						if operand_word then
							arg2 <= x"0002";	
						else
							arg2 <= x"0001";	
						end if;
						ope <= alu_add;
						ea <= alu_result;	-- save address of register before alu op destroys it					
						cpu_state <= do_source_address5;
					when do_source_address5 =>
						-- writeback the autoincremented value
						wr_dat <= alu_result;
						cpu_state <= do_write;
						cpu_state_next <= do_source_address6;
					when do_source_address6 =>
						-- end of the autoincrement stuff, now put source address to ALU output
						arg2 <= reg_t;
						ope <= alu_load2;
						cpu_state <= cpu_state_operand_return;
					
					-------------------------------------------------------------
					-- subprogram to do operand fetching, data returned in rd_dat.
					-- operand address is left to EA (when appropriate)
					when do_read_operand0 =>
						-- read workspace register. Goes to waste if symbolic mode.
						arg1 <= w;
						arg2 <= x"00" & "000" & operand_mode(3 downto 0) & '0';
						ope <= alu_add;	-- calculate workspace address
						cpu_state <= do_alu_read;	-- read from addr of ALU output
						cpu_state_next <= do_read_operand1;
						test_out <= x"EE00";
					when do_read_operand1 =>
						test_out <= x"EE01";
						case operand_mode(5 downto 4) is
						when "00" =>
							-- workspace register, we are done.
							cpu_state <= cpu_state_operand_return;
						when "01" =>
							-- workspace register indirect
							ea <= rd_dat;
							cpu_state <= do_read;
							-- return via operand read
							cpu_state_next <= cpu_state_operand_return;
						when "10" =>
							-- read immediate operand for symbolic or indexed mode
							reg_t <= rd_dat;	-- save register value for later
							cpu_state <= do_pc_read;
							cpu_state_next <= do_read_operand2;
						when "11" =>
							-- workspace register indirect auto-increment
							reg_t <= rd_dat;		-- register value, to be left to EA
							ea <= alu_result;		-- address of register
							arg1 <= rd_dat;
							if operand_word then
								arg2 <= x"0002";	
							else
								arg2 <= x"0001";	
							end if;
							ope <= alu_add;		-- add for autoincrement
							cpu_state <= do_read_operand3;
						when others =>
							cpu_state <= do_stuck;	-- get stuck, should never happen
						end case;
					when do_read_operand2 =>
						-- indirect or indexed mode here
						test_out <= x"EE02";
						if operand_mode(3 downto 0) = "0000" then
							-- symbolic, read from rd_dat
							ea <= rd_dat;
							cpu_state <= do_read;
							-- return after read
							cpu_state_next <= cpu_state_operand_return;
						else
							-- indexed, need to compute the address
							-- We need to return via an extra state (not with do_alu_read) since
							-- EA needs to be setup.
							arg1 <= rd_dat;
							arg2 <= reg_t;
							ope <= alu_add;
							cpu_state <= do_read_operand5;
						end if;
					when do_read_operand3 =>
						test_out <= x"EE03";
						-- write back our result to the register
						wr_dat <= alu_result;
						cpu_state <= do_write;
						cpu_state_next <= do_read_operand4;
					when do_read_operand4 =>
						-- Now we need to read the actual value. And return in EA where it came from.
						ea <= reg_t;
						cpu_state <= do_read;
						cpu_state_next <= cpu_state_operand_return;
					when do_read_operand5 =>
						ea <= alu_result;
						cpu_state <= do_read;
						cpu_state_next <= cpu_state_operand_return; 	-- return via read
						
						
					-- subprogram to do operand writing, data to write in wr_dat
					when do_write_operand0 =>
						-- read workspace register. Goes to waste if symbolic mode.
						test_out <= x"AA00";
						arg1 <= w;
						arg2 <= x"00" & "000" & operand_mode(3 downto 0) & '0';
						ope <= alu_add;	-- calculate workspace address
						if operand_mode(5 downto 4) = "00" then
							-- write to workspace register directly, then done!
							cpu_state <= do_alu_write;
							cpu_state_next <= cpu_state_operand_return;
						else
							-- we have an indirect write, so need to first read the workspace register
							cpu_state <= do_alu_read;	-- read from addr of ALU output
							cpu_state_next <= do_write_operand1;
						end if;
					when do_write_operand1 =>
						test_out <= x"AA01";
						case operand_mode(5 downto 4) is
						when "01" =>
							-- workspace register indirect
							ea <= rd_dat;
							cpu_state <= do_write;
							-- return via operand write
							cpu_state_next <= cpu_state_operand_return;
						when "10" =>
							-- read immediate operand for symbolic or indexed mode
							reg_t <= rd_dat;	-- save register value for later
							cpu_state <= do_pc_read;
							cpu_state_next <= do_write_operand2;
						when "11" =>
							-- workspace register indirect auto-increment
							ea <= rd_dat;
							reg_t <= rd_dat;
							cpu_state <= do_write;
							cpu_state_next <= do_write_operand3;
						when others =>
							cpu_state <= do_stuck;	-- get stuck, should never happen
						end case;
					when do_write_operand2 =>
						-- indirect or indexed mode here
						if operand_mode(3 downto 0) = "0000" then
							-- symbolic, write to address rd_dat
							test_out <= x"AA02";
							ea <= rd_dat;
							cpu_state <= do_write;
							-- return after write
							cpu_state_next <= cpu_state_operand_return;
						else
							-- indexed, need to compute the address
							test_out <= x"AA12";
							arg1 <= rd_dat;
							arg2 <= reg_t;
							ope <= alu_add;
							cpu_state <= do_alu_write;
							-- return after read
							cpu_state_next <= cpu_state_operand_return;
						end if;
					when do_write_operand3 =>
						-- need to autoincrement our register. rd_dat contains still our read data.
						test_out <= x"AA03";
						arg1 <= reg_t;		-- register value
						if operand_word then
							arg2 <= x"0002";	-- word operation, inc by 2
						else
							arg2 <= x"0001";
						end if;
						ope <= alu_add;
						ea <= alu_result;	-- save address of register before alu op destroys it
						cpu_state <= do_write_operand4;
					when do_write_operand4 =>
						-- writeback of autoincremented register
						test_out <= x"AA04";
						wr_dat <= alu_result;
						cpu_state <= do_write;
						cpu_state_next <= cpu_state_operand_return;
						
						
					when do_stuck =>
						stuck <= '1';
				end case;
				
			
			end if; -- rising_edge
		end if;	
	end process;


end Behavioral;

