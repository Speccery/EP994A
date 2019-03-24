/***************************************************************************************************
*  flash.v
*
*  flash program loader for PlusToo
*
*  Copyright (c) 2015, Magnus Karlsson
*  All rights reserved.
*
*  Modified by Erik Piehl 2017-12-31 for us with the TI-99/4A FPGA clone.
*  For this project I need to load 256K not 128K from Flash to RAM.
*
*  Erik Piehl 2019-03-16
*  Further extensively modified to support loading of individual memory words
*  based on their address, rather than using this as a state machine to just load a large block
*  of data in one go. This enables direct execution of code from the serial Flash ROM.
*
*  Original notice from Magnus Karlsson:
*  Redistribution and use in source and binary forms, with or without modification, are permitted
*  provided that the following conditions are met:
*
*  1. Redistributions of source code must retain the above copyright notice, this list of conditions
*     and the following disclaimer.
*  2. Redistributions in binary form must reproduce the above copyright notice, this list of
*     conditions and the following disclaimer in the documentation and/or other materials provided
*     with the distribution.
*
*  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR
*  IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND
*  FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
*  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
*  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
*  DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
*  WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
*  WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*
***************************************************************************************************/

module flashword (
  input clk,
  input clk8_enable,
  input n_reset,
  input [23:0] memoryAddr,
  input readRq,
  output wordReady_o,
  output reg idle_o,		// idle_o is high when the system is idle
  output [15:0] dataOut,
  output reg loading,
  output reg spi_sclk,
  output reg spi_ss,
  output spi_mosi,
  input spi_miso
);

  reg next_loading;
  reg next_spi_sclk;
  reg next_spi_ss;
  reg next_spi_mosi;
  reg [2:0] spi_state, next_spi_state;
  reg [31:0] dout, next_dout;
  reg [4:0] bitcnt, next_bitcnt;
  reg [15:0] din, next_din;
  reg [15:0] word, next_word;
  reg [22:0] addr, next_addr;	// word aligned
  reg wordready, next_wordready;
  

  always @(posedge clk or negedge n_reset) begin
    if (!n_reset) begin
      spi_state <= 3'd0;
      loading <= 1'b0;
      spi_sclk <= 1'b0;
      spi_ss <= 1'b1;
      dout <= 32'h00000000;
      bitcnt <= 5'd0;
      din <= 16'h0000;
      word <= 16'h0000;
      addr <= 23'd0;
      wordready <= 1'b0;
    end else begin
		if (clk8_enable == 1'b1) begin 
			spi_state <= next_spi_state;
			loading <= next_loading;
			spi_sclk <= next_spi_sclk;
			spi_ss <= next_spi_ss;
			dout <= next_dout;
			bitcnt <= next_bitcnt;
			din <= next_din;
			word <= next_word;
			addr <= next_addr;
			wordready <= next_wordready;
			idle_o = (spi_state == 3'd0) ? 1'b1 : 1'b0;
		end // if (clk8_enable
    end // if (!n_reset)
  end

  always @ (*) begin
    next_spi_state = spi_state;
    next_loading = loading;
    next_spi_sclk = spi_sclk;
    next_spi_ss = spi_ss;
    next_dout = dout;
    next_bitcnt = bitcnt;
    next_din = din;
    next_word = word;
    next_addr = addr;
    next_wordready = wordready;
    
    case (spi_state)
      3'd0: begin
		  // Erik waiting for read request to start
		  if (readRq == 1'b1) begin
			  next_loading = 1'b1;
			  next_spi_sclk = 1'b0;
			  next_spi_ss = 1'b1;
			  next_wordready = 1'b0;
			  next_spi_state = 3'd1;
			  next_bitcnt = 5'd0;
			  next_addr = memoryAddr[23:1]; // Addresses must be word aligned
			end
      end
      3'd1: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 3'd2;
      end
      3'd2: begin
        next_spi_sclk = 1'b0;
        next_spi_ss = 1'b0;
		  next_dout = { 8'h03, next_addr, 1'b0 };	// Read command and address
        next_bitcnt = 5'd0;
        next_spi_state = 3'd3;
      end
      3'd3: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 3'd4;
      end
      3'd4: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd31) begin
          next_bitcnt = 3'd0;
          next_spi_state = 3'd5;
        end else begin
          next_dout = {dout[30:0], 1'b0};	// shift out the read command
          next_spi_state = 3'd3;
        end
      end
      3'd5: begin
        next_spi_sclk = 1'b1;
        next_wordready = 1'b0;
        next_din = {din[14:0], spi_miso};	// capture but from the flash
        next_spi_state = 3'd6;
      end
      3'd6: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd15) begin
          next_wordready = 1'b1;
          next_word = din;
          next_addr = addr + 1'b1;
          next_spi_state = 3'd7;
        end else begin
          next_spi_state = 3'd5;
        end
      end
      3'd7: begin
        next_spi_ss = 1'b1;
        next_wordready = 1'b0;
        next_loading = 1'b0;
		  // Loop back to beginning
        next_spi_state = 3'd0;
      end
      default:
        next_spi_state = 3'd0;
    endcase
  end

  assign spi_mosi = dout[31];
  assign wordReady_o = wordready;
  assign dataOut = word;
  
endmodule
