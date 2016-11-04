library IEEE;
use  IEEE.STD_LOGIC_1164.all;
use  IEEE.STD_LOGIC_ARITH.all;
use  IEEE.STD_LOGIC_UNSIGNED.all;

ENTITY VGA_SYNC IS
	PORT(	clk, ena					: IN STD_LOGIC; 
			video_on, horiz_sync_out, vert_sync_out	: OUT	STD_LOGIC;
			pixel_row, pixel_column: OUT STD_LOGIC_VECTOR(9 DOWNTO 0));
END VGA_SYNC;

ARCHITECTURE a OF VGA_SYNC IS
	SIGNAL horiz_sync, vert_sync : STD_LOGIC;
	SIGNAL video_onx, video_on_v, video_on_h : STD_LOGIC;
	SIGNAL h_count, v_count :STD_LOGIC_VECTOR(9 DOWNTO 0);
	signal vbuf : std_logic;
BEGIN

	video_on <= video_onx;
	-- video_onx is high only when RGB data is displayed
	video_onx <= video_on_H AND video_on_V;


--Generate Horizontal and Vertical Timing Signals for Video Signal
-- H_count counts pixels (640 + extra time for sync signals)
-- 
--  Horiz_sync  ------------------------------------__________--------
--  H_count       0                640             659       755    799
--
	do_hcount:  process(clk, ena)
	begin
		if(rising_edge(clk) and ena='1') then 
			IF (h_count = 799) THEN
				h_count <= "0000000000";
        if v_count = 524 then
          v_count <= "0000000000";
        else
          v_count <= v_count + 1;
        end if;
			ELSE
				h_count <= h_count + 1;
			END IF;
		end if;
	end process;

--Generate Horizontal Sync Signal using H_count
	do_hsync: process(clk, ena)
	begin
		if (rising_edge(clk) and ena='1') then
			IF (h_count <= 755) AND (h_count >= 659) THEN
				horiz_sync <= '0';
			ELSE
				horiz_sync <= '1';
			END IF;
		end if;
	end process;

--V_count counts rows of pixels (480 + extra time for sync signals)
--  
--  Vert_sync      -----------------------------------------------_______------------
--  V_count         0                                      480    493-494          524
--

	
	

-- Generate Vertical Sync Signal using V_count
	do_vs: process(clk, ena)
	begin
		if (rising_edge(clk) and ena='1') then
			IF (v_count <= 494) AND (v_count >= 493) THEN
					vert_sync <= '0';
			ELSE
				vert_sync <= '1';
			END IF;
		end if;
	end process;

-- Generate Video on Screen Signals for Pixel Data
	do_video_on: process(clk, ena)
	begin
		if (rising_edge(clk) and ena='1') then
			pixel_column <= h_count;
			IF (h_count <= 639) THEN
					video_on_h <= '1';
					--pixel_column <= h_count;
			ELSE
					video_on_h <= '0';
			END IF;
		
			pixel_row <= v_count;
			IF (v_count <= 479) THEN
					video_on_v <= '1';
					-- pixel_row <= v_count;
			ELSE
					video_on_v <= '0';
			END IF;
		end if;
	end process;

	horiz_sync_out <= horiz_sync;
	vert_sync_out <= vert_sync;

END a;
