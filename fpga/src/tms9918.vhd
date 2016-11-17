----------------------------------------------------------------------------------
-- tms9918.vhd
--
-- This module is an implementation of the TI TMS9918 Video Processor chip.
-- The module is not 100% compatible with the orignal design.
-- There are some missing features, but also some extensions.
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

entity tms9918 is
    Port ( clk 		: in  STD_LOGIC;
           reset 		: in  STD_LOGIC;
           mode 		: in 	STD_LOGIC; -- 1 for registers, 0 for memory
			  addr		: in  STD_LOGIC_VECTOR(7 downto 0); -- extension, 8 bit address in
           data_in 	: in  STD_LOGIC_VECTOR (7 downto 0);
           data_out 	: out  STD_LOGIC_VECTOR (15 downto 0);	-- extended to 16-bits (top 8 correspond to 8-bit interface)
           wr 			: in  STD_LOGIC;	-- high for 1 clock cycle to write
           rd 			: in  STD_LOGIC;	-- can be high multiple cycles. high-to-low transition increments addr for data reads
           vga_vsync : out  STD_LOGIC;
           vga_hsync : out  STD_LOGIC;
			  debug1		: out STD_LOGIC;
			  debug2		: out STD_LOGIC;
			  int_out   : out STD_LOGIC;	-- interrupt out, high means interrupt pending
           vga_red 	: out  STD_LOGIC_VECTOR (2 downto 0);
           vga_green : out  STD_LOGIC_VECTOR (2 downto 0);
           vga_blue 	: out  STD_LOGIC_VECTOR (1 downto 0));
end tms9918;


architecture Behavioral of tms9918 is

	-- CPU side of VRAM and VDP
	signal state 		: std_logic;
	signal hold_reg	: std_logic_vector(7 downto 0);
	signal vram_addr	: std_logic_vector(13 downto 0);
	signal reg0			: std_logic_vector(7 downto 0);
	signal reg1			: std_logic_vector(7 downto 0) := x"00";	-- init with zero, interrupts disabled
	signal reg2			: std_logic_vector(7 downto 0);
	signal reg3			: std_logic_vector(7 downto 0);
	signal reg4			: std_logic_vector(7 downto 0);
	signal reg5			: std_logic_vector(7 downto 0);
	signal reg6			: std_logic_vector(7 downto 0);
	signal reg7			: std_logic_vector(7 downto 0);
	signal stat_reg   : std_logic_vector(7 downto 0) := x"00";
	signal mem_rd_bus : std_logic_vector(7 downto 0);
	signal vram_write	: std_logic;
	signal bump_rq		: std_logic;
	signal vdp_rd_prev: std_logic;
	signal vdp_mode_prev: std_logic;
	signal vdp_addr_prev: std_logic_vector(1 downto 0);
	-- video refresh circuit
--	signal vga_addr	: std_logic_vector(13 downto 0);
--	signal vga_out		: std_logic_vector(7 downto 0);	-- VRAM read bus for refresh
	signal clk25MHz	: std_logic;		-- 25MHz 25/75 clock
	signal clkdiv		: std_logic_vector(1 downto 0);
	
	signal Hsync		: std_logic;
	signal Vsync		: std_logic;
	signal VGARow		: std_logic_vector(9 downto 0);
	signal VGACol		: std_logic_vector(9 downto 0);
	signal vga_shift  : std_logic_vector(7 downto 0);
	signal video_on	: std_logic;	
	signal clk12_5MHz	: std_logic;		-- 12.5 MHz 50/50 clock
	
	-- linebuffer based VGA implementation
	signal vga_line_buf_out : std_logic_vector(7 downto 0); -- linebuf to VGA data out
	signal vga_line_buf_in	: std_logic_vector(7 downto 0); -- write bus to linebuffer
	signal vram_out_data		: std_logic_vector(7 downto 0); -- vram hardware read bus
	signal vram_out_addr		: std_logic_vector(13 downto 0);	-- vram hardware addr bus
	signal line_buf_addra	: std_logic_vector(10 downto 0);
	signal line_buf_addrb	: std_logic_vector(10 downto 0);
	signal vga_bank			: std_logic;
	signal vga_line_buf_addr : std_logic_vector(8 downto 0);
	signal vga_line_buf_wr	: std_logic;	-- write strobe
	signal xpos 				: integer;
	signal ypos					: std_logic_vector(7 downto 0);
	signal pixel_write		: std_logic;
	signal pixel_toggler		: std_logic;
	type refresh_state_type is (
		wait_frame,	
		wait_line, 
		process_line,
		process_sprites,
		
		sprites_addr,
		sprite_read_vert, sprite_read_horiz,sprite_read_char,
		sprite_read_color,
		sprite_read_pattern0, sprite_read_pattern1,
		sprite_write_pattern0, sprite_write_pattern1, sprite_write_pattern_last,
		sprite_next
		);
	signal refresh_state : refresh_state_type := wait_frame;	
	type pixel_type is (
		setup_read_char,
		read_char0,
		read_char1,
		read_pattern,
		read_color,
		write_pixels,
		write_pixel_last
		);
	signal process_pixel : pixel_type;
	
	signal char_addr			: std_logic_vector(13 downto 0);
	signal char_addr_reload	: std_logic_vector(13 downto 0);
	signal char_code			: std_logic_vector(7 downto 0);
	signal char_pattern		: std_logic_vector(7 downto 0);
	signal color0				: std_logic_vector(3 downto 0);
	signal color1				: std_logic_vector(3 downto 0);
	signal pixel_count		: integer;

	-- display start and in VGA scanlines
	constant disp_start 		: integer := 16;
	constant disp_rendr     : integer := disp_start - 2;
	constant disp_start2		: integer := disp_start + 2;
	constant disp_rendr_slv : std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(disp_rendr,10));	
	--
	constant slv_511	: std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(511,10));
	constant slv_760	: std_logic_vector(9 downto 0) := std_logic_vector(to_unsigned(760,10));
	
	signal 	blanking : std_logic;
	
	-- sprite generator variables
	signal sprite_counter	: std_logic_vector(4 downto 0);
	signal sprite_y			: std_logic_vector(8 downto 0);	-- attr table byte 0, with an extra bit
	signal sprite_x			: std_logic_vector(7 downto 0);	-- attr table byte 1
	signal sprite_name		: std_logic_vector(7 downto 0);	-- attr table byte 2	(partially signed, from -31 bleed to screen)
	signal sprite_color		: std_logic_vector(7 downto 0);	-- attr table byte 3 (early,0,0,0,color:4)
	signal sprite_line 		: std_logic_vector(8 downto 0);
	signal sprite_pixels		: std_logic_vector(15 downto 0);
	signal sprite_write_count : std_logic_vector(3 downto 0);
	
	--https://www.msx.org/forum/semi-msx-talk/emulation/question-about-msx1-palette?page=2
	--1:0, 0, 0
	--2:0, 241, 20
	--3:68, 249, 86
	--4:85, 79, 255
	--5:128, 111, 255
	--6:250, 80, 51
	--7:12, 255, 255
	--8:255, 81, 52
	--9:255, 115, 86
	--A:226, 210, 4
	--B:242, 217, 71
	--C:4, 212, 19
	--D:231, 80, 229
	--E:208, 208, 208
	--F:255, 255, 255
	function palette_lookup( 
		color : std_logic_vector(3 downto 0)) 
		return std_logic_vector is 
	begin
		case to_bitvector(color) is
			when x"0" => return x"00";	-- transparent i.e. black
			when x"1" => return x"00";	-- black
			when x"2" => return "00011100";	-- medium green
			when x"3" => return "00111101";	-- light green
			when x"4" => return "01001011";	-- dark blue
			when x"5" => return "10010011";	-- light blue
			when x"6" => return "11101001";	-- dark red
			when x"7" => return "00011111";	-- cyan
			when x"8" => return "11101001";	-- medium red
			when x"9" => return "11110010";	-- light red
			when x"A" => return "11111000";	-- dark yellow
			when x"B" => return "11111010";	-- light yellow
			when x"C" => return "00011000";	-- dark green
			when x"D" => return "11110111";	-- magenta
			when x"E" => return "10010010";	-- gray
			when x"F" => return "11111111";	-- white
		end case;
	end;
	
begin

	data_out <= 
		mem_rd_bus & x"00" when mode = '0' and addr(7 downto 6)="00" else 
		stat_reg   & x"00" when mode = '1' and addr(7 downto 6)="00" else 
		-- extended registers below. address has bit 7 set (actually bit 8 on CPU side).
		reg0 		  & x"00" 								when addr = x"40" else
		reg1		  & x"00" 								when addr = x"41" else
		"00" & reg2(3 downto 0) & "0000000000" 	when addr = x"42" else	-- pattern memory address base
		"00" & reg3 & "000000" 						 	when addr = x"43" else	-- color table
		"00" & reg4(2 downto 0) & "00000000000" 	when addr = x"44" else -- chare code address base
		"00" & reg5(6 downto 0) & "0000000"			when addr = x"45" else -- sprite attribute table
		"00" & reg6(2 downto 0) & "00000000000"   when addr = x"46" else -- sprite pattern table
		reg7 & x"00"										when addr = x"47" else -- a couple of colors 47
		"00" & vram_addr;
		
	
	debug1 <= vga_bank;
	debug2 <= '1' when refresh_state = wait_line else '0';
	-- stat_reg(7): interrupt pending
	-- reg1(5): Interrupt enable, i.e. mask bit
	int_out <= '1' when stat_reg(7)='1' and reg1(5)='1' else '0'; 

	process(clk,reset)
	variable	k : integer;
	variable spry  : unsigned(8 downto 0);
	variable yline : unsigned(8 downto 0);
	variable	t : std_logic_vector(7 downto 0);	
	variable border : std_logic_vector(7 downto 0);	
	begin 
		if reset = '1' then
			state <= '0';
			bump_rq <= '0';
			refresh_state <= wait_frame;
			stat_reg <= x"00";
		elsif rising_edge(clk) then
		
			-- Divide 100MHz clk by 4 to issue pulses in clk25Mhz. 
			-- It is high once per 4 clock cycles.
			k := to_integer(unsigned(clkdiv)) + 1;
			clkdiv <= std_logic_vector(to_unsigned(k, clkdiv'length));
			clk25MHz <= '0';
			if clkdiv = "11" then
				clk25MHz <= '1';
			end if;
			
			if clk25MHz = '1' then
				clk12_5MHz <= not clk12_5MHz;
			end if;
		
			if wr = '1' and mode = '1' and addr(7 downto 6)="00" then
				-- write cycles to registers etc.
				if state = '0' then
					hold_reg <= data_in;	-- hold on to the first byte
					state <= '1';
				else 
					case data_in(7 downto 6) is
						when "00" =>	-- read from vram setup
							vram_addr <= data_in(5 downto 0) & hold_reg;
						when "01" =>	-- write to vram setup
							vram_addr <= data_in(5 downto 0) & hold_reg;
						when "10" =>	-- write to VDP register
							case data_in(2 downto 0) is
								when "000" => reg0 <= hold_reg;
								when "001" => reg1 <= hold_reg;
								when "010" => reg2 <= hold_reg;
								when "011" => reg3 <= hold_reg;
								when "100" => reg4 <= hold_reg;
								when "101" => reg5 <= hold_reg;
								when "110" => reg6 <= hold_reg;
								when others => reg7 <= hold_reg;
							end case;
						when others => 	-- do nothing
					end case;
					state <= '0';
				end if;
			end if;
			
			if (wr = '1' or rd = '1') and mode = '0' and addr(7 downto 6)="00" then
				state <= '0';
			end if;
			
			bump_rq <= '0';
			vram_write <= '0';
			if mode='0' and wr='1' and addr(7 downto 6)="00" then
				vram_write <= '1';
				bump_rq <= '1';
			end if;
			
			vdp_rd_prev <= rd;
			vdp_mode_prev <= mode;
			vdp_addr_prev <= addr(7 downto 6);
			if vdp_rd_prev='1' and rd='0' and vdp_mode_prev='0' and vdp_addr_prev="00" then
				-- read became inactive on data, bump the address
				bump_rq <= '1';
			end if;

			if vdp_rd_prev='1' and rd='0' and vdp_mode_prev='1' and vdp_addr_prev="00" then
				-- read became inactive on status register, clear interrupt request
				stat_reg(7) <= '0';
			end if;
			
			if bump_rq='1' then
				vram_addr <= std_logic_vector(to_unsigned(1+to_integer(unsigned(vram_addr)), vram_addr'length));
			end if;
			
			-- VGA processing
			vga_hsync 	<= Hsync;
			vga_vsync 	<= Vsync;
	
			-- read from linebuffer
			if clk25MHz = '1' then
				if video_on = '1' and reg1(6)='1' then
					if VGACol <= slv_511 and blanking = '0' then
						vga_red 		<= vga_line_buf_out(7 downto 5);
						vga_green 	<= vga_line_buf_out(4 downto 2);
						vga_blue 	<= vga_line_buf_out(1 downto 0);
					else
						border	:= palette_lookup(reg7(3 downto 0));
						vga_red 		<= border(7 downto 5);
						vga_green 	<= border(4 downto 2);
						vga_blue 	<= border(1 downto 0);
					end if;
				else 
					vga_red 		<= (others => '0');
					vga_green 	<= (others => '0');
					vga_blue 	<= (others => '0');
				end if;				
			end if;
			
			-- Handle reading from vram and writing to line buffer.
			if clkdiv(0) = '0' then
				case refresh_state is
					when wait_frame =>
						pixel_write <= '0';
						blanking <= '1';
						if VGARow = disp_rendr_slv and VGACol = x"00" & "00" then -- start rendering
							refresh_state <= process_line;
							vga_bank <= '0';
							xpos <= 0;
							process_pixel <= setup_read_char;
							char_addr 			<= reg2(3 downto 0) & "0000000000";	-- char memory base address
							char_addr_reload 	<= reg2(3 downto 0) & "0000000000";	
							vga_line_buf_addr <= (others => '1');	-- init to -1, so that first add rolls over to 0
							ypos <= (others => '0');
						end if;
					when process_line =>
						-- here we read all the data for one scanline and write it to linebuffer.
						case process_pixel is
							when setup_read_char => 
								vram_out_addr <= char_addr;
								char_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(char_addr)) + 1, char_addr'length));
								process_pixel <= read_char0;
							when read_char0 =>
								-- now vram_out_data is the character code. Fetch from there the pattern.
								char_code <= vram_out_data;	-- save for later
								process_pixel <= read_char1;
							when read_char1 =>
								if reg0(1)='0' then
									-- Graphics mode 1 (actually anything else than graphics mode 2)
									vram_out_addr <= reg4(2 downto 0) & char_code & ypos(2 downto 0); -- VGARow(3 downto 1);
								else
									-- Graphics mode 2. 768 unique characters are possible.
									vram_out_addr <= reg4(2) & char_addr(9 downto 8) & char_code & ypos(2 downto 0);
								end if;
								process_pixel <= read_pattern;
							when read_pattern =>
								-- store pattern, and work out the address of the color byte
								char_pattern <= vram_out_data;
								if reg0(1)='0' then
									-- Graphics mode 1
									vram_out_addr <= reg3 & '0' & char_code(7 downto 3);
								else
									-- Graphics mode 2
									vram_out_addr <= reg3(7) & char_addr(9 downto 8) & char_code & ypos(2 downto 0);
								end if;
								process_pixel <= read_color;
							when read_color =>
								-- read color data. After this step it would actually be possible to concurrently
								-- start reading the next char etc while pixels are written to the line buffer.
								-- in text mode color 1 comes from register 7
								if reg1(4)='1' then 
									color1 <= reg7(7 downto 4);				-- text mode, ignore VRAM data
								else
									color1 <= vram_out_data(7 downto 4);	-- GM1, GM2
								end if;
								if vram_out_data(3 downto 0) = "0000" or reg1(4)='1' then
									-- transparent, user border color; or text mode
									color0 <= reg7(3 downto 0);
								else
									color0 <= vram_out_data(3 downto 0);
								end if;
								process_pixel <= write_pixels;
								if reg1(4)='1' then 
									pixel_count <= 2;	-- text mode, character cells are 6 pixels wide
								else
									pixel_count <= 0;
								end if;
								pixel_toggler <= '0';
							when write_pixels =>
								-- write 8 pixels. Write each individual pixel twice to make them wide.
								if char_pattern(7) = '1' then
									vga_line_buf_in <= palette_lookup(color1);	-- (x"2"); -- (color1);
								else
									vga_line_buf_in <= palette_lookup(color0);	-- (x"E"); -- (color0);
								end if;
								
								vga_line_buf_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(vga_line_buf_addr)) + 1, vga_line_buf_addr'length));
								pixel_toggler <= not pixel_toggler;
								pixel_write <= '1';							
								if pixel_toggler = '1' then 
									char_pattern <= char_pattern(6 downto 0) & '0';
									pixel_count <= pixel_count + 1;
									if pixel_count = 7 then
										process_pixel <= write_pixel_last;	-- loop back this state machine
									end if;
								end if;
							when write_pixel_last =>
								pixel_write <= '0';	-- turn off writes to linebuffer
								process_pixel <= setup_read_char;	-- loop back this state machine
								xpos <= xpos + 1;
								if (xpos = 31 and reg1(4)='0') or (xpos=39 and reg1(4)='1') then
									xpos <= 0;					
									refresh_state <= process_sprites;
								end if;
						end case;
						
					when process_sprites =>
						sprite_counter <= (others => '1');	-- start from the highest numbered sprite
						refresh_state <= sprites_addr;
					when sprites_addr =>
						vram_out_addr <= reg5(6 downto 0) & sprite_counter & "00";
						refresh_state <= sprite_read_vert;
					when sprite_read_vert =>
						if vram_out_data = x"D0" then
							-- vertical count D0 (208) stop immediately processing
							refresh_state <= wait_line;
						end if;
						if vram_out_data(7 downto 5) = "111" then
							sprite_y <= '0' & vram_out_data;
						else
							sprite_y <= '1' & vram_out_data;
						end if;
						vram_out_addr <= reg5(6 downto 0) & sprite_counter & "01";
						refresh_state <= sprite_read_horiz;
					when sprite_read_horiz =>
						-- sprite_line <= unsigned("1" & ypos) - unsigned("0" & sprite_y);
						sprite_line <= std_logic_vector(to_unsigned(
							to_integer(unsigned('1' & ypos)) - to_integer(unsigned(sprite_y)) - 1, 
							sprite_line'length));
						sprite_x <= vram_out_data;
						vram_out_addr <= reg5(6 downto 0) & sprite_counter & "10";
						refresh_state <= sprite_read_char;
					when sprite_read_char =>
						if (reg1(1)='1' and sprite_line(8 downto 4) = "00000") 		-- 16x16
							or (reg1(1)='0' and sprite_line(8 downto 3) = "000000")	-- 8x8
						then
							sprite_name <=  vram_out_data;
							vram_out_addr <= reg5(6 downto 0) & sprite_counter & "11";
							refresh_state <= sprite_read_color;
						else
							-- sprite does not belong to this scanline. Either the offset is negative or beyound 15 ("1111")
							refresh_state <= sprite_next;
						end if;
					when sprite_read_color =>
						sprite_color <= vram_out_data;
						if reg1(1) = '1' then
							-- 16x16 sprite
							vram_out_addr <= reg6(2 downto 0) & sprite_name(7 downto 2) & '0' & sprite_line(3 downto 0);
						else
							-- 8x8 sprite
							vram_out_addr <= reg6(2 downto 0) & sprite_name(7 downto 0) & sprite_line(2 downto 0);
						end if;
						refresh_state <= sprite_read_pattern0;
					when sprite_read_pattern0 =>
						if sprite_color(3 downto 0) = "0000" then
							refresh_state <= sprite_next;	-- this sprite is transparent, go draw next
						else
							sprite_pixels(15 downto 8) <= vram_out_data;
							vram_out_addr <= reg6(2 downto 0) & sprite_name(7 downto 2) & '1' & sprite_line(3 downto 0);
							refresh_state <= sprite_read_pattern1;
						end if;
					when sprite_read_pattern1 =>
						sprite_pixels(7 downto 0) <= vram_out_data;
						sprite_write_count <=  reg1(1) & "111";	-- 8x8: "0111", 16x16: "1111"
						refresh_state <= sprite_write_pattern0;
					when sprite_write_pattern0 =>	-- write in two steps since pixels take 2 clock cycles
						if sprite_color(7)='1' then 
							-- early clock bit set. Now we need to figure out our address.
							if unsigned(sprite_x) >= 32 then
								-- just force bit 5 to zero to substract 32. This is bogus but we don't care
								vga_line_buf_addr <= sprite_x(7 downto 6) & '0' & sprite_x(4 downto 0) & '0';
								-- enable write strobe if we have a pixel
								if sprite_pixels(15) = '1' then 
									pixel_write <= '1';
								else
									pixel_write <= '0';
								end if;
							end if;
						else
							-- setup address normally
							vga_line_buf_addr <= sprite_x & '0';
							-- enable write strobe if we have a pixel 
							if sprite_pixels(15) = '1' then 
								pixel_write <= '1';
							else
								pixel_write <= '0';
							end if;
						end if;
						-- set data whether we write it or not.
						vga_line_buf_in <= palette_lookup(sprite_color(3 downto 0));
						refresh_state <= sprite_write_pattern1;
					when sprite_write_pattern1 =>
						vga_line_buf_addr(0) <= '1';	-- keep data and write flag change only address
						sprite_pixels <= sprite_pixels(14 downto 0) & '0';
						sprite_x <= std_logic_vector(to_unsigned(to_integer(unsigned(sprite_x)) + 1, sprite_x'length));
						sprite_write_count <= std_logic_vector(to_unsigned(to_integer(unsigned(sprite_write_count)) - 1, sprite_write_count'length));
						if sprite_write_count = "0000" or sprite_x=x"ff" then
							-- if out of pixels or rightmost pixel of the screen written (FF=255) go to next sprite
							refresh_state <= sprite_write_pattern_last;
						else 
							refresh_state <= sprite_write_pattern0;
						end if;
					when sprite_write_pattern_last =>
						pixel_write <= '0';
						refresh_state <= sprite_next;
					when sprite_next =>
						sprite_counter <= std_logic_vector(to_unsigned(to_integer(unsigned(sprite_counter)) - 1, sprite_counter'length));
						if sprite_counter = "00000" then
							-- if we were already at sprite zero we are done.
							refresh_state <= wait_line;
						else
							-- other wise look at next sprite
							refresh_state <= sprites_addr;
						end if;
						
					when wait_line =>
						if VGARow = std_logic_vector(to_unsigned(to_integer(unsigned(ypos & '0')) + disp_start2,10)) and VGACol=slv_760 then	
							-- we arrived at next line boundary, process it
							vga_bank <= not vga_bank;
							refresh_state <= process_line;
							vga_line_buf_addr <= (others => '0');
							blanking <= '0';
							if ypos(2 downto 0) /= "111" then
								char_addr <= char_addr_reload;	-- reload char ptr to beginning of line
							else
								char_addr_reload <= char_addr;
							end if;
							ypos <= std_logic_vector(to_unsigned(to_integer(unsigned(ypos)) + 1, ypos'length));
							if ypos = std_logic_vector(to_unsigned(192, ypos'length)) then
								blanking <= '1';
								refresh_state <= wait_frame;
								stat_reg(7) <= '1';			-- make VDP interrupt pending
							end if;
						end if;
				end case;
			end if;

		end if;	-- rising_edge
	end process;

	line_buf_addra <= '0' & not vga_bank & vga_line_buf_addr;
	line_buf_addrb <= '0' & vga_bank & VGACol(8 downto 0);
	
	LINEBUFFER: RAMB16_S9_S9 -- Port A: write from VRAM, port B: output to VGA
		port map (
			DOA => open,      -- Port A 8-bit Data Output
			DOB => vga_line_buf_out,      -- Port B 8-bit Data Output
--			DOPA => DOPA,    -- Port A 1-bit Parity Output
--			DOPB => DOPB,    -- Port B 1-bit Parity Output
			ADDRA => line_buf_addra,  -- Port A 11-bit Address Input
			ADDRB => line_buf_addrb,  -- Port B 11-bit Address Input
			CLKA => CLK,     -- Port A Clock
			CLKB => CLK ,    -- Port B Clock
			DIA => vga_line_buf_in,      -- Port A 8-bit Data Input
			DIB => (others => '0'),      -- Port B 8-bit Data Input
			DIPA => "0",     -- Port A 1-bit parity Input
			DIPB => "0",     -- Port-B 1-bit parity Input
			ENA => '1',      -- Port A RAM Enable Input
			ENB => '1',      -- PortB RAM Enable Input
			SSRA => '0',     -- Port A Synchronous Set/Reset Input
			SSRB => '0', 	  -- Port B Synchronous Set/Reset Input
			WEA => pixel_write, -- Port A Write Enable Input
			WEB => '0'       -- Port B Write Enable Input		
		);


	VRAM: 
		for I in 0 to 7 generate
		begin
		  u_sprite_ram : RAMB16_S1_S1
			 port map (
				-- CPU port
				DOA   => mem_rd_bus(I downto I),
				DIA   => data_in(I downto I),
				ADDRA => vram_addr,
				WEA   => vram_write,
				ENA   => '1',
				SSRA  => '0',
				CLKA  => CLK,
				-- read side
				DOB   => vram_out_data(I downto I), -- vga_out(I downto I),
				DIB   => "0",
				ADDRB => vram_out_addr, -- vga_addr,
				WEB   => '0',
				ENB   => '1',
				SSRB  => '0',
				CLKB  => CLK
				);
		end generate;
		
 	vgadriver: entity work.VGA_SYNC
		port map(
		clk				=> clk,
		ena				=> clk25MHz,
		video_on			=> video_on,
		horiz_sync_out => Hsync,
		vert_sync_out  => Vsync,
		pixel_row      => VGARow,
		pixel_column   => VGACol
		);		

end Behavioral;




					-- debugging code 
--					case VGARow is
--						when "0010000000" =>
--							vga_red 		<= "111";
--							vga_green 	<= "000";
--							vga_blue 	<= "00";
--						when "0010000010" =>
--							if refresh_state = wait_frame then 
--								vga_red 		<= "000";
--								vga_green 	<= "000";
--								vga_blue 	<= "11";
--							else
--								vga_red 		<= (others => '0');
--								vga_green 	<= (others => '0');
--								vga_blue 	<= (others => '0');
--							end if;
--						when others =>
--							vga_red 		<= vga_line_buf_out(7 downto 5);
--							vga_green 	<= vga_line_buf_out(4 downto 2);
--							vga_blue 	<= vga_line_buf_out(1 downto 0);
--					end case;
--					
--					if VGARow(9 downto 4) = "001100" then
--						t := palette_lookup(VGARow(3 downto 0));
--						vga_red 		<= t(7 downto 5);
--						vga_green 	<= t(4 downto 2);
--						vga_blue 	<= t(1 downto 0);
--					end if;
--					
--					-- show processing time per line
--					if VGARow(9 downto 4) = "001110" then
--						if refresh_state = process_line then
--							case process_pixel is 
--								when setup_read_char =>
--									vga_red <= "000"; vga_green <= "010"; vga_blue <= "00";
--								when read_char0 =>
--									vga_red <= "000"; vga_green <= "100"; vga_blue <= "01";
--								when read_char1 =>
--									vga_red <= "000"; vga_green <= "100"; vga_blue <= "01";
--								when read_pattern =>
--									vga_red <= "000"; vga_green <= "111"; vga_blue <= "10";
--								when read_color =>
--									vga_red <= "000"; vga_green <= "111"; vga_blue <= "11";
--								when write_pixels =>
--									vga_red <= "111"; vga_green <= "000"; vga_blue <= "00";
--								when write_pixel_last =>
--									vga_red <= "111"; vga_green <= "111"; vga_blue <= "11";
--							end case;
--						else
--							vga_red <= "000"; vga_green <= "000"; vga_blue <= "00";
--						end if;
--					end if;
--					
--					-- show pattern data somehow
--					if VGARow(9 downto 4) = "001111" then
--						if char_pattern(7)='1' then
--							vga_green <= "111";
--						else
--							vga_green <= "000";
--						end if;
--					end if;
