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

module flash (
  input clk8,
  input n_reset,
  input bad_load,
  input load_disk,
  input [3:0] disk,
  input dioBusControl,
  output reg romLoaded,
  output reg diskLoaded,
  output [15:0] memoryDataOut,
  output [19:0] memoryAddr,
  output n_ramWE,
  output reg loading,
  output reg spi_sclk,
  output reg spi_ss,
  output spi_mosi,
  input spi_miso
);

  reg next_loading;
  reg next_romLoaded;
  reg next_diskLoaded;
  reg next_spi_sclk;
  reg next_spi_ss;
  reg next_spi_mosi;
  reg [3:0] spi_state, next_spi_state;
  reg [31:0] dout, next_dout;
  reg [4:0] bitcnt, next_bitcnt;
  reg [18:0] wordcnt, next_wordcnt;
  reg [15:0] din, next_din;
  reg [15:0] word, next_word;
  reg [18:0] addr, next_addr;
  reg wordready, next_wordready;
  reg load_disk_sync;
  

  always @(posedge clk8 or negedge n_reset) begin
    if (!n_reset) begin
      spi_state <= 4'd0;
      loading <= 1'b1;
      spi_sclk <= 1'b0;
      spi_ss <= 1'b1;
      dout <= 32'h00000000;
      bitcnt <= 5'd0;
      wordcnt <= 19'd0;
      din <= 16'h0000;
      word <= 16'h0000;
      addr <= 19'd0;
      wordready <= 1'b0;
      romLoaded <= 1'b0;
      diskLoaded <= 1'b0;
      load_disk_sync <= 1'b0;
    end else begin
      spi_state <= next_spi_state;
      loading <= next_loading;
      spi_sclk <= next_spi_sclk;
      spi_ss <= next_spi_ss;
      dout <= next_dout;
      bitcnt <= next_bitcnt;
      wordcnt <= next_wordcnt;
      din <= next_din;
      word <= next_word;
      addr <= next_addr;
      wordready <= next_wordready;
      romLoaded <= next_romLoaded;
      diskLoaded <= next_diskLoaded;
      load_disk_sync <= load_disk;
    end
  end

  always @ (*) begin
    next_spi_state = spi_state;
    next_loading = loading;
    next_spi_sclk = spi_sclk;
    next_spi_ss = spi_ss;
    next_dout = dout;
    next_bitcnt = bitcnt;
    next_wordcnt = wordcnt;
    next_din = din;
    next_word = word;
    next_addr = addr;
    next_wordready = (wordready & dioBusControl) ? 1'b0 : wordready;
    next_romLoaded = romLoaded;
    next_diskLoaded = 1'b0;
    
    case (spi_state)
      4'd0: begin
        next_loading = 1'b1;
        next_spi_sclk = 1'b0;
        next_spi_ss = 1'b1;
        next_wordcnt = 19'd0;
        next_wordready = 1'b0;
        next_spi_state = 4'd1;
      end
      4'd1: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 4'd2;
      end
      4'd2: begin
        next_spi_sclk = 1'b0;
        next_spi_ss = 1'b0;
        next_dout = 32'h03160000; // READ command, addr = $160000
        next_bitcnt = 5'd0;
        next_spi_state = 4'd3;
      end
      4'd3: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 4'd4;
      end
      4'd4: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd31) begin
          next_bitcnt = 3'd0;
          next_spi_state = 4'd5;
        end else begin
          next_dout = {dout[30:0], 1'b0};
          next_spi_state = 4'd3;
        end
      end
      4'd5: begin
        next_spi_sclk = 1'b1;
        next_wordready = 1'b0;
        next_din = {din[14:0], spi_miso};
        next_spi_state = 4'd6;
      end
      4'd6: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd15) begin
          next_wordready = 1'b1;
          next_word = din;
          next_addr = wordcnt;
          next_wordcnt = wordcnt + 1'b1;
			 // EP read 256K of ROM
			 if (wordcnt == 19'd131071) begin
            next_spi_state = 4'd7;
          end else begin
            next_bitcnt = 5'd0;
            next_spi_state = 4'd5;
          end
        end else begin
          next_spi_state = 4'd5;
        end
      end
      4'd7: begin
        next_spi_ss = 1'b1;
        next_wordready = 1'b0;
        next_loading = 1'b0;
        if (bad_load)
          next_spi_state = 4'd0;
        else begin
          next_romLoaded = 1'b1;
          next_spi_state = 4'd8;
        end
      end
      4'd8: begin
        next_loading = 1'b0;
        next_spi_sclk = 1'b0;
        next_spi_ss = 1'b1;
        next_wordcnt = 19'd131071;  // offset by ROM size
        if (load_disk_sync) begin
          next_loading = 1'b1;
          next_spi_state = 4'd9;
        end
      end
      4'd9: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 4'd10;
      end
      4'd10: begin
        next_spi_sclk = 1'b0;
        next_spi_ss = 1'b0;
        next_dout = {8'h03, 24'h180000 + {disk, 20'd0}};
        next_bitcnt = 5'd0;
        next_spi_state = 4'd11;
      end
      4'd11: begin
        next_spi_sclk = 1'b1;
        next_spi_state = 4'd12;
      end
      4'd12: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd31) begin
          next_bitcnt = 3'd0;
          next_spi_state = 4'd13;
        end else begin
          next_dout = {dout[30:0], 1'b0};
          next_spi_state = 4'd11;
        end
      end
      4'd13: begin
        next_spi_sclk = 1'b1;
        next_din = {din[14:0], spi_miso};
        next_spi_state = 4'd14;
      end
      4'd14: begin
        next_spi_sclk = 1'b0;
        next_bitcnt = bitcnt + 1'b1;
        if (bitcnt == 5'd15) begin
          next_wordready = 1'b1;
          next_word = din;
          next_addr = wordcnt;
          next_wordcnt = wordcnt + 1'b1;
          // read 800K (FLOPPY)
          if (wordcnt == 19'd475135) begin
            next_diskLoaded = 1'b1;
            next_spi_state = 4'd15;
          end else begin
            next_bitcnt = 5'd0;
            next_spi_state = 4'd13;
          end
        end else begin
          next_spi_state = 4'd13;
        end
      end
      4'd15: begin
        next_spi_ss = 1'b1;
        next_loading = 1'b0;
        if (!load_disk_sync)
          next_spi_state = 4'd8;
      end
      default:
        next_spi_state = 4'd0;
    endcase
  end

  assign spi_mosi = dout[31];
  
  assign memoryAddr = {addr, 1'b0};
  assign memoryDataOut = word;
  assign n_ramWE = ~wordready;

endmodule
