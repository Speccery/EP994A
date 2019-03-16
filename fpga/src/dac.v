// EP 2019-02-04 dac.v converted from dac.vhd
// My very first conversion of VHDL to Verilog. Interesting!
// Delta-sigma DAC
// This DAC requires an external RC low-pass filter:
//
//   dac_o 0---XXXXX---+---0 analog audio
//              3k3    |
//                    === 4n7
//                     |
//                    GND



module dac #(
	parameter msbi_g = 7
	)(
		input clk_i,
		input res_n_i,
		input [msbi_g:0] dac_i,
		output dac_o
	);

	reg [msbi_g+2:0] sig_in_d, sig_in_q;
	reg dac_o_q, dac_o_d;
	
	assign dac_o = dac_o_q;
	
	always @(*) begin
		sig_in_d = sig_in_q + { sig_in_q[msbi_g+2], sig_in_q[msbi_g+2], dac_i };
		dac_o_d = sig_in_q[msbi_g+2];
	end 
	
	always @(posedge clk_i) begin
		if (res_n_i == 1'b0) begin
			sig_in_q <= 2**(msbi_g+1);
			dac_o_q  <= 1'b0;
		end else begin
			sig_in_q <= sig_in_d;
			dac_o_q  <= dac_o_d;
		end
	end
endmodule
	
