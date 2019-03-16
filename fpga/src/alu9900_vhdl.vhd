-- ALU9900.vhd
-- EP 2019-02-07
-- copied existing VHDL version of the ALU

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

use IEEE.STD_LOGIC_UNSIGNED.ALL;
-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
use IEEE.NUMERIC_STD.ALL;

entity alu9900_vhdl is
	port ( 
		arg1 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		arg2 : IN STD_LOGIC_VECTOR(15 DOWNTO 0);
		ope  : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
		compare : IN STD_LOGIC;
		alu_result: OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		alu_logical_gt 	: OUT STD_LOGIC;
		alu_arithmetic_gt : OUT STD_LOGIC;
		alu_flag_zero     : OUT STD_LOGIC;
		alu_flag_carry    : OUT STD_LOGIC;
		alu_flag_overflow : OUT STD_LOGIC;
		alu_flag_parity	: OUT STD_LOGIC;
		alu_flag_parity_source : OUT STD_LOGIC
	);
end alu9900_vhdl;

architecture behavioural of alu9900_vhdl is
	signal alu_out: STD_LOGIC_VECTOR(16 downto 0);
--	localparam load1=4'h0, load2=4'h1, add =4'h2, sub =4'h3, 
--				  abs  =4'h4, aor  =4'h5, aand=4'h6, axor=4'h7,
--				  andn =4'h8, coc  =4'h9, czc =4'ha, swpb=4'hb,
--				  sla  =4'hc, sra  =4'hd, src =4'he, srl =4'hf;		
	constant alu_load1 : std_logic_vector(3 downto 0) := x"0";
	constant alu_load2 : std_logic_vector(3 downto 0) := x"1";
	constant alu_add   : std_logic_vector(3 downto 0) := x"2";
	constant alu_sub   : std_logic_vector(3 downto 0) := x"3";
	constant alu_abs   : std_logic_vector(3 downto 0) := x"4";
	constant alu_or    : std_logic_vector(3 downto 0) := x"5";
	constant alu_and   : std_logic_vector(3 downto 0) := x"6";
	constant alu_xor   : std_logic_vector(3 downto 0) := x"7";
	constant alu_and_not : std_logic_vector(3 downto 0) := x"8";
	constant alu_coc   : std_logic_vector(3 downto 0) := x"9";
	constant alu_czc   : std_logic_vector(3 downto 0) := x"a";
	constant alu_swpb2 : std_logic_vector(3 downto 0) := x"b";
	constant alu_sla   : std_logic_vector(3 downto 0) := x"c";
	constant alu_sra   : std_logic_vector(3 downto 0) := x"d";
	constant alu_src   : std_logic_vector(3 downto 0) := x"e";
	constant alu_srl   : std_logic_vector(3 downto 0) := x"f";	
begin
	process(arg1, arg2, ope)
	begin
		-- arg1 is DA, arg2 is SA when ALU used for instruction execute
		case ope is
			when alu_load1 =>		alu_out <= '0' & arg1;
			when alu_load2 =>		alu_out <= '0' & arg2;
			when alu_add =>		alu_out <= std_logic_vector(unsigned('0' & arg1) + unsigned('0' & arg2));
			when alu_or =>			alu_out <= '0' & arg1 or '0' & arg2;
			when alu_and =>		alu_out <= '0' & arg1 and '0' & arg2;
			when alu_sub =>		alu_out <= std_logic_vector(unsigned('0' & arg1) - unsigned('0' & arg2));
			when alu_and_not =>	alu_out <= '0' & arg1 and not ('0' & arg2);
			when alu_xor =>		alu_out <= '0' & arg1 xor '0' & arg2;
			when alu_coc => -- compare ones corresponding
										alu_out <= ('0' & arg1 xor ('0' & arg2)) and ('0' & arg1);
			when alu_czc => -- compare zeros corresponding
										alu_out <= ('0' & arg1 xor not ('0' & arg2)) and ('0' & arg1);
			when alu_swpb2 =>		alu_out <= '0' & arg2(7 downto 0) & arg2(15 downto 8); -- swap bytes of arg2
			when alu_abs => -- compute abs value of arg2
				if arg2(15) = '0' then
					alu_out <= '0' & arg2;
				else
					-- same as alu sub (arg1 must be zero; this is set elsewhere)
					alu_out <= std_logic_vector(unsigned(arg1(15) & arg1) - unsigned(arg2(15) & arg2));
				end if;
			when alu_sla =>		alu_out <= arg2 & '0';
			when alu_sra =>		alu_out <= arg2(0) & arg2(15) & arg2(15 downto 1);
			when alu_src =>		alu_out <= arg2(0) & arg2(0) & arg2(15 downto 1);
			when others => 	   alu_out <= arg2(0) & '0' & arg2(15 downto 1);
			-- when alu_srl =>		alu_out <= arg2(0) & '0' & arg2(15 downto 1);
		end case;			
	end process;
	alu_result <= alu_out(15 downto 0);
	
	-- ST0 ST1 ST2 ST3 ST4 ST5
	-- L>  A>  =   C   O   P
	-- ST0 - when looking at data sheet arg1 is (DA) and arg2 is (SA), sub is (DA)-(SA). 
	alu_logical_gt 	<= '1' when compare='1' and ((arg2(15)='1' and arg1(15)='0') or (arg1(15)=arg2(15) and alu_out(15)= '1')) else 
								'1' when compare='0' and alu_out(15 downto 0) /= x"0000" else
								'0';
	-- ST1
	alu_arithmetic_gt <= '1' when compare='1' and ((arg2(15)='0' and arg1(15)='1') or (arg1(15)=arg2(15) and alu_out(15)= '1')) else 
								'1' when compare='0' and alu_out(15)='0' and alu_out(15 downto 0) /= x"0000" else
								'0';
	-- ST2
	alu_flag_zero 		<= '1' when alu_out(15 downto 0) = x"0000" else '0';
	-- ST3 carry
	alu_flag_carry    <= alu_out(16) when ope /= alu_sub else not alu_out(16);	-- for sub carry out is inverted
	-- ST4 overflow
	alu_flag_overflow <= 
		'1' when (compare='1' or ope = alu_sub or ope = alu_abs)			                   and arg1(15) /= arg2(15) and alu_out(15) /= arg1(15) else 
		'1' when (ope /= alu_sla and not (compare='1' or ope = alu_sub or ope = alu_abs)) and arg1(15) =  arg2(15) and alu_out(15) /= arg1(15) else 
		'1' when ope = alu_sla and alu_out(15) /= arg2(15) else -- sla condition: if MSB changes during shift
		'0';
	-- ST5 parity
	alu_flag_parity <= alu_out(15) xor alu_out(14) xor alu_out(13) xor alu_out(12) xor 
				       alu_out(11) xor alu_out(10) xor alu_out(9)  xor alu_out(8);
		-- source parity used with CB and MOVB instructions
	alu_flag_parity_source <= arg2(15) xor arg2(14) xor arg2(13) xor arg2(12) xor 
				       arg2(11) xor arg2(10) xor arg2(9)  xor arg2(8);

end behavioural;