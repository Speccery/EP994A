// alu9900.v
// EP 2019-02-07
// Conversion of VHDL ALU code to verilog.
// I put this into a separate module to test how to port VHDL code to verilog
// in a little smaller units.
// This module is purely combinatorial logic.
module alu9900(
	input [15:0] arg1, 
	input [15:0] arg2, 
	input [3:0] ope, 
	input compare,	// for compare, set this to 1 and ope to sub.
	output [15:0] alu_result,
	output alu_logical_gt,
	output alu_arithmetic_gt,
	output alu_flag_zero,
	output alu_flag_carry,
	output alu_flag_overflow,
	output alu_flag_parity,
	output alu_flag_parity_source
	);
	localparam load1=4'h0, load2=4'h1, add =4'h2, sub =4'h3, 
				  abs  =4'h4, aor  =4'h5, aand=4'h6, axor=4'h7,
				  andn =4'h8, coc  =4'h9, czc =4'ha, swpb=4'hb,
				  sla  =4'hc, sra  =4'hd, src =4'he, srl =4'hf;
				   
	wire [16:0] alu_out;
	
	// arg1 is DA, arg2 is SA when ALU used for instruction execute
	assign alu_out = 
		(ope == load1) ? { 1'b0, arg1 } :
		(ope == load2) ? { 1'b0, arg2 } :
		(ope == add)   ? { 1'b0, arg1 } + { 1'b0, arg2 } :
		(ope == sub)   ? { 1'b0, arg1 } - { 1'b0, arg2 } :
		(ope == aor)   ? { 1'b0, arg1 | arg2 } :
		(ope == aand)  ? { 1'b0, arg1 & arg2 } :
		(ope == axor)  ? { 1'b0, arg1 ^ arg2 } :
		(ope == andn)  ? { 1'b0, arg1 & ~arg2 } :
		(ope == coc)   ? { 1'b0, (arg1 ^ arg2) & arg1 } :  // compare ones corresponding
		(ope == czc)   ? { 1'b0, (arg1 ^ ~arg2) & arg1 }: // compare zeros corresponding
		(ope == swpb)  ? { 1'b0, arg2[7:0], arg2[15:8] }: // swap bytes of arg2
		(ope == abs)   ? (arg2[15] ? { 1'b0, arg1 } - { 1'b0, arg2 } : { 1'b0, arg2 }) :
		(ope == sla)   ? { arg2, 1'b0 } :
		(ope == sra)   ? { arg2[0], arg2[15], arg2[15:1] } :
		(ope == src)   ? { arg2[0], arg2[0],  arg2[15:1] } :
		{ arg2[0], 1'b0,     arg2[15:1] }; // srl
	
	assign alu_result = alu_out[15:0];
	// ST0 ST1 ST2 ST3 ST4 ST5
	// L>  A>  =   C   O   P
	// ST0 - when looking at data sheet arg1 is (DA) and arg2 is (SA), sub is (DA)-(SA). 
	assign alu_logical_gt = compare ? (arg2[15] && !arg1[15]) || (arg1[15]==arg2[15] && alu_result[15]) 
											  : alu_result != 16'd0;

	// ST1
	assign alu_arithmetic_gt = compare ? (!arg2[15] && arg1[15]) || (arg1[15]==arg2[15] && alu_result[15])
											  : alu_result[15]==1'b0 && alu_result != 16'd0;
	// ST2
	assign alu_flag_zero = !(|alu_result);
	// ST3
	assign alu_flag_carry = (ope == sub) ? !alu_out[16] : alu_out[16]; // for sub carry out is inverted
	// ST4 overflow
	assign alu_flag_overflow = (ope == sla) ? alu_result[15] != arg2[15] : // sla condition: if MSB changes during shift
										(compare || ope==sub || ope==abs) ? (arg1[15] != arg2[15] && alu_result[15] != arg1[15]) : 
																					   (arg1[15] == arg2[15] && alu_result[15] != arg1[15]);
	// ST5 parity
	assign alu_flag_parity = ^alu_result[15:8];
	// source parity used with CB and MOVB instructions
	assign alu_flag_parity_source = ^arg2[15:8];
	
endmodule
