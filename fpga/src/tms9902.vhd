library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity tms9902 is
port (
   CLK      : in  std_logic;
   nRTS     : out std_logic;
   nDSR     : in  std_logic;
   nCTS     : in  std_logic;
   nINT     : out std_logic;
   nCE      : in  std_logic;
   CRUOUT   : in  std_logic;
   CRUIN    : out std_logic;
   CRUCLK   : in  std_logic;
   XOUT     : out std_logic;
   RIN      : in  std_logic;
   S        : in  std_logic_vector(4 downto 0)
   );
end;

architecture tms9902_arch of tms9902 is

   --
   --  CRU / CONTROLLER
   --
 
   -- flag register
   type flg_type is record
      dscenb : std_logic;
      timenb : std_logic;
      xienb  : std_logic;
      rienb  : std_logic;
      brkon  : std_logic;
      rtson  : std_logic;
      tstmd  : std_logic;
      ldctl  : std_logic;
      ldir   : std_logic;
      lrdr   : std_logic;
      lxdr   : std_logic;
		cruclk : std_logic;
   end record;
   signal flg_q, flg_d : flg_type;
   
   -- control register
   type ctl_type is record
      sbs   : std_logic_vector(2 downto 1);
      penb  : std_logic;
      podd  : std_logic;
      clk4m : std_logic;
      rcl   : std_logic_vector(1 downto 0);
   end record;
   signal ctl_q, ctl_d : ctl_type;
   
   -- control signals from CRU controller
   signal sig_reset   : std_logic; -- device being reset
   signal sig_timenb  : std_logic; -- timenb being written
   signal sig_rienb   : std_logic; -- rienb being written
   signal sig_ldir    : std_logic; -- ldir being reset

   --
   -- INTERVAL TIMER
   --
   
   -- interval register
   signal tmr_q, tmr_d : std_logic_vector(7 downto 0);

   -- interval timer counter
   signal timctr_q, timctr_d : std_logic_vector(13 downto 0);
   
   -- control signal from timer counter
   signal sig_timctr_iszero : std_logic; -- timer counter is zero

   -- interval timer controller
   type timFSM_type is record
      timelp   : std_logic;
      timerr   : std_logic;
   end record;
   signal timFSM_q, timFSM_d : timFSM_type;

   --
   -- TRANSMITTER
   --
   
   -- transmit data rate register
   signal xdr_q, xdr_d : std_logic_vector(10 downto 0);

   -- transmit half-bit timer counter
   signal xhbctr_q, xhbctr_d : std_logic_vector(13 downto 0);
   signal sig_xhbctr_iszero : std_logic;
   
   -- transmit buffer register
   signal xbr_q, xbr_d : std_logic_vector(7 downto 0);
   signal sig_xbr7 : std_logic;

   -- transmit shift register
   signal xsr_q, xsr_d : std_logic_vector(7 downto 0);
   
   -- transmit controller
   type xmtstat is (IDLE, BREAK, START, BITS, PARITY, STOP);
   type xmtFSM_type is record
      xbre   : std_logic;
      xsre   : std_logic;
      xout   : std_logic;
      rts    : std_logic;
      par    : std_logic;
      bitctr : std_logic_vector(4 downto 0);
      state  : xmtstat;
   end record;
   signal xmtFSM_q, xmtFSM_d : xmtFSM_type;   

   -- control signals from the transmit controller
   signal sig_xhb_reset : std_logic;
   signal sig_xsr_load  : std_logic;
   signal sig_xsr_shift : std_logic;

   --
   -- RECEIVER
   --
   
   -- receive data rate register
   signal rdr_q, rdr_d : std_logic_vector(10 downto 0);

   -- receive half-bit timer counter
   signal rhbctr_q, rhbctr_d : std_logic_vector(13 downto 0);
   signal sig_rhbctr_iszero : std_logic;
   
   -- receive buffer register
   signal rbr_q, rbr_d : std_logic_vector(7 downto 0);

   -- receive shift register
   signal rsr_q, rsr_d : std_logic_vector(7 downto 0);
   
   -- receive controller
   type rcvstat is (IDLE, START, START1, BITS, PARITY, STOP);
   type rcvFSM_type is record
      rbrl   : std_logic;
      rsbd   : std_logic;
      rfbd   : std_logic;
      rover  : std_logic;
      rper   : std_logic;
      rfer   : std_logic;
      par    : std_logic;
      bitctr : std_logic_vector(4 downto 0);
      state  : rcvstat;
   end record;
   signal rcvFSM_q, rcvFSM_d : rcvFSM_type;   

   -- control signals from the receive controller
   signal sig_rhb_reset : std_logic;
   signal sig_rbr_load  : std_logic;
   signal sig_rsr_shift : std_logic;

   --
   -- MISCELANEOUS
   --

   signal dscint : std_logic;   -- device status change interrupt pending
   signal rint   : std_logic;   -- receive interrupt pending
   signal xint   : std_logic;   -- transmit interrupt pending
   signal timint : std_logic;   -- timer interrupt pending
   signal intr   : std_logic;   -- any interrupt pending

   signal flag   : std_logic;   -- any register select bit or brkon set
   signal rcverr : std_logic;   -- any error in last received character
   signal rts    : std_logic;   -- copy of xmtFSM_q.rts
   
   -- clock divider and internal clock
   signal bitclk   : std_logic;
   signal clkctr_q : std_logic_vector(1 downto 0) := "00";

   -- 'todo' signals from controllers
   signal dsch : std_logic;
   
begin

   -- hack: assign some values
   dsch <= '0';

   -- clock divider
   clkdiv: process(CLK, clkctr_q, ctl_q)
   variable v : std_logic_vector(1 downto 0);
   begin
      v := clkctr_q;
      if rising_edge(CLK) then
         v := v + 1;
         if ctl_q.clk4m='0' and v="10" then v:="11"; end if;
      end if;
      clkctr_q <= v;
	end process;
   bitclk <= '1' when clkctr_q="00" else '0';
	
   -- define flag register / CRU controller
   --
   flg_reg : process(clk)
   begin
      if rising_edge(clk) then flg_q <= flg_d; end if;
   end process;
   
   flg_cmb : process(clk, flg_q, flg_d, nCE, CRUCLK, CRUOUT, S)
   variable v   : flg_type;
   variable rst, timenb, rienb : std_logic;
   begin
      v := flg_q;
		rst := '0'; timenb := '0'; rienb := '0';
		v.cruclk := CRUCLK;

      if nCE='0' and CRUCLK='1' then
      
         -- handle reset
         if S="11111" then
            v.dscenb := '0';
            v.timenb := '0';
            v.xienb  := '0';
            v.rienb  := '0';
            v.brkon  := '0';
            v.rtson  := '0';
				v.tstmd  := '0';
            v.ldctl  := '1';
            v.ldir   := '1';
            v.lrdr   := '1';
            v.lxdr   := '1';
            rst      := '1';
         else
            case S is

               -- handle int enable flip-flops
               -- (which also reset error flags)
               when "10101" => v.dscenb := CRUOUT;
               when "10100" => v.timenb := CRUOUT;
                               timenb := '1';
               when "10011" => v.xienb  := CRUOUT;
               when "10010" => v.rienb  := CRUOUT;
                               rienb := '1';

               -- handle simple flip-flops
               when "10001" => v.brkon  := CRUOUT;
               when "10000" => v.rtson  := CRUOUT;
               when "01111" => v.tstmd  := CRUOUT;
               when "01110" => v.ldctl  := CRUOUT;
               when "01101" => v.ldir   := CRUOUT;
               when "01100" => v.lrdr   := CRUOUT;
               when "01011" => v.lxdr   := CRUOUT;
               
               when others => null;

            end case;
         end if;
      end if;

		if flg_q.cruclk='1' and v.cruclk='0' then
		   if S="01010" and v.ldctl='0' and v.ldir='0' and v.lrdr='1' then
			   v.lrdr := '0';
			end if;
			if S="00111" then
				if v.ldctl='1' then
				   v.ldctl := '0';
            elsif v.ldir='1' then
				   v.ldir:='0';
				end if;
         end if;
		end if;

		flg_d <= v;
      sig_reset  <= rst;
      sig_timenb <= timenb;
      sig_rienb  <= rienb;
      sig_ldir   <= (flg_q.ldir and not v.ldir);
   end process;

   -- define control register and its CRU interface
   --
   ctl_reg : process(clk)
   begin
      if rising_edge(clk) then ctl_q <= ctl_d; end if;
   end process;

   ctl_cmb : process(ctl_q, nCE, CRUCLK, flg_q, CRUOUT, S)
   variable v : ctl_type;
   begin
      v := ctl_q;
      if nCE='0' and CRUCLK='1' and flg_q.ldctl='1' then
         case S is
            when "00111" => v.sbs(2) := CRUOUT;
            when "00110" => v.sbs(1) := CRUOUT;
            when "00101" => v.penb   := CRUOUT;
            when "00100" => v.podd   := CRUOUT;
            when "00011" => v.clk4m  := CRUOUT;
            --   "00010" is not used
            when "00001" => v.rcl(1) := CRUOUT;
            when "00000" => v.rcl(0) := CRUOUT;
            when others => null;
         end case;
      end if;
      ctl_d <= v;
   end process;

   --
   -- INTERVAL TIMER
   --

   -- define timer interval register and its CRU interface
   --
   tmr_reg : process(clk)
   begin
      if rising_edge(clk) then tmr_q <= tmr_d; end if;
   end process;

   tmr_cmb : process(tmr_q, nCE, CRUCLK, flg_q, CRUOUT, S)
   variable v : std_logic_vector(7 downto 0);
   begin
      v := tmr_q;
      if nCE='0' and CRUCLK='1' and flg_q.ldctl='0' and flg_q.ldir='1' then
         case S is
            when "00111" => v(7) := CRUOUT;
            when "00110" => v(6) := CRUOUT;
            when "00101" => v(5) := CRUOUT;
            when "00100" => v(4) := CRUOUT;
            when "00011" => v(3) := CRUOUT;
            when "00010" => v(2) := CRUOUT;
            when "00001" => v(1) := CRUOUT;
            when "00000" => v(0) := CRUOUT;
            when others => null;
         end case;
      end if;
      tmr_d <= v;
   end process;

   -- define timer counter register
   --
   timctr_reg : process(clk)
   begin
      if rising_edge(clk) then timctr_q <= timctr_d; end if;
   end process;

   timctr_cmb : process(timctr_q, tmr_q, flg_q, bitclk, sig_ldir)
   variable v : std_logic_vector(13 downto 0);
   variable z : std_logic;
   begin
      v := timctr_q;
      if v="00000000000000" then z := '1'; else z := '0'; end if;
      
      if sig_ldir='1' or z='1' then
         v := tmr_q&"000000";
		elsif bitclk='1' then
         if flg_q.tstmd='1' then v := v - 32; else v := v - 1; end if;
      end if;

      timctr_d <= v;
      sig_timctr_iszero <= z;
   end process;

   -- define timer controller register
   --
   timFSM_reg : process(clk)
   begin
      if rising_edge(clk) then timFSM_q <= timFSM_d; end if;
   end process;

   timFSM_cmb : process(timFSM_q, sig_reset, sig_timenb, sig_timctr_iszero)
   variable v  : timFSM_type;
   begin
      v := timFSM_q;
      if sig_reset='1' or sig_timenb='1'then
         v.timelp := '0';
         v.timerr := '0';
      elsif sig_timctr_iszero='1' then
         if v.timelp='1' then v.timerr := '1'; end if;
         v.timelp := '1';
      end if;
      timFSM_d <= v;
   end process;

   
   --
   --   TRANSMITTER
   --

   -- define transmit data rate register
   --
   xdr_reg : process(clk)
   begin
      if rising_edge(clk) then xdr_q <= xdr_d; end if;
   end process;

   xdr_cmb : process(xdr_q, nCE, CRUCLK, flg_q, CRUOUT, S)
   variable v : std_logic_vector(10 downto 0);
   begin
      v := xdr_q;
      if nCE='0' and CRUCLK='1' and flg_q.ldctl='0' and flg_q.ldir='0' and flg_q.lxdr='1' then
         case S is
            when "01010" => v(10) := CRUOUT;
            when "01001" => v(9)  := CRUOUT;
            when "01000" => v(8)  := CRUOUT;
            when "00111" => v(7)  := CRUOUT;
            when "00110" => v(6)  := CRUOUT;
            when "00101" => v(5)  := CRUOUT;
            when "00100" => v(4)  := CRUOUT;
            when "00011" => v(3)  := CRUOUT;
            when "00010" => v(2)  := CRUOUT;
            when "00001" => v(1)  := CRUOUT;
            when "00000" => v(0)  := CRUOUT;
            when others => null;
         end case;
      end if;
      xdr_d <= v;
   end process;

   -- define transmit buffer register
   --
   xbr_reg : process(clk)
   begin
      if rising_edge(clk) then xbr_q <= xbr_d; end if;
   end process;

   xbr_cmb : process(xbr_q, nCE, CRUCLK, flg_q, CRUOUT, S)
   variable v    : std_logic_vector(7 downto 0);
   variable xbr7 : std_logic;
   begin
      v := xbr_q; xbr7 := '0';
      if nCE='0' and CRUCLK='1' and flg_q.ldctl='0' and flg_q.ldir='0'
         and flg_q.lrdr='0' and flg_q.lxdr='0' then
         case S is
            when "00111" => v(7)  := CRUOUT;
            when "00110" => v(6)  := CRUOUT;
            when "00101" => v(5)  := CRUOUT;
            when "00100" => v(4)  := CRUOUT;
            when "00011" => v(3)  := CRUOUT;
            when "00010" => v(2)  := CRUOUT;
            when "00001" => v(1)  := CRUOUT;
            when "00000" => v(0)  := CRUOUT;
            when others => null;
         end case;
         -- writing to bit 7 resets the XBRE flag in the controller.
         if S="00111" then xbr7 := '1'; end if;
      end if;
      xbr_d <= v;
      sig_xbr7 <= xbr7;
   end process;

   -- define transmit shift register
   --
   xsr_reg : process(clk)
   begin
      if rising_edge(clk) then xsr_q <= xsr_d; end if;
   end process;

   xsr_cmb : process(xsr_q, xbr_q, sig_xsr_load, sig_xsr_shift)
   variable v    : std_logic_vector(7 downto 0);
   begin
      v := xsr_q;
      if sig_xsr_load='1' then
         v := xbr_q;
      elsif sig_xsr_shift='1' then
         v := '0'&xsr_q(7 downto 1);
      end if;
      xsr_d <= v;
   end process;

   -- define transmit half-bit counter register
   --
   xhbctr_reg : process(clk)
   begin
      if rising_edge(clk) then xhbctr_q <= xhbctr_d; end if;
   end process;

   xhbctr_cmb : process(xhbctr_q, xdr_q, bitclk, sig_xhb_reset)
   variable v : std_logic_vector(13 downto 0);
   variable z : std_logic;
   begin
      v := xhbctr_q;
      if v="000000000000000" then z := '1'; else z := '0'; end if;
      
      if sig_xhb_reset='1' or z='1' or flg_q.lxdr='1' then -- last 'or clause' for simulation only
         v := xdr_q(10)&"000"&xdr_q(9 downto 0);
      elsif bitclk='1' then
         v := v - 1;
      end if;
      xhbctr_d <= v;
      sig_xhbctr_iszero <= z;
   end process;

   -- define xmt controller register
   --
   xmtFSM_reg : process(clk)
   begin
      if rising_edge(clk) then xmtFSM_q <= xmtFSM_d; end if;
   end process;

   xmtFSM_cmb : process(xmtFSM_q, ctl_q, flg_q, xsr_q, nCTS, sig_reset, sig_xbr7, sig_xhbctr_iszero)
   variable v   : xmtFSM_type;
   variable par : std_logic;
   variable xsr_load, xsr_shift, xhb_reset : std_logic;
   variable xbits : std_logic_vector(4 downto 0);
   variable sbits : std_logic_vector(4 downto 0);   
   begin
      v := xmtFSM_q; xsr_load := '0'; xsr_shift := '0'; xhb_reset := '0';
      
      -- prepare half-bit times for data word and stop bits
      case ctl_q.rcl is
         when "11"   => xbits := "10000";
         when "10"   => xbits := "01110";
         when "01"   => xbits := "01100";
         when others => xbits := "01010";
      end case;
      case ctl_q.sbs is
         when "00"   => sbits := "00011";
         when "01"   => sbits := "00100";
         when others => sbits := "00010";
      end case;

      if sig_xhbctr_iszero='1' then
         v.bitctr := v.bitctr - 1;
      end if;

      if sig_reset='1' then
         v.xout := '1';
         v.rts  := '0';
         v.xsre := '1';
         v.xbre := '1';

      elsif sig_xbr7='1'then
         v.xbre := '0';

      elsif v.state=BREAK then
         v.xout := '0';
         if flg_q.brkon='0' then v.state := IDLE; end if;
         
      elsif v.state=IDLE then
         v.rts := flg_q.rtson;
         if nCTS='0' then
            if v.xbre='1' then
               if flg_q.brkon='1' then v.state := BREAK; end if;
            else
               v.state   := START;
               v.xout    := '0';
               v.bitctr  := "00010";
               xhb_reset := '1';
            end if;
         end if;

      elsif sig_xhbctr_iszero='1' then
         case v.state is

            when START =>
               if v.bitctr=0 then
                  xsr_load := '1';
						v.xsre := '0';
						v.xbre := '1';
						v.state  := BITS;
                  v.bitctr := xbits;
                  v.par  := '0';
               end if;

            when BITS =>
               if v.bitctr(0)='0' then
                  v.par := v.par xor xsr_q(0);
                  xsr_shift := '1';
               end if;
               if v.bitctr=0 then
                  if ctl_q.penb='1' then
							v.xout := v.par xor ctl_q.podd;
							v.state := PARITY;
                     v.bitctr := "00010";
                  else
						   v.xout := '1';
                     v.state := STOP;
                     v.bitctr := sbits;
                  end if;
               end if;
               
            when PARITY =>
               if v.bitctr=0 then
						v.xout := '1';
                  v.state := STOP;
                  v.bitctr := sbits;
               end if; 
            
            when STOP =>
               if v.bitctr=0 then
					   v.xsre := '1';
                  v.state := IDLE;
               end if; 

            when others => v.state := IDLE;

         end case;
      end if;
      xmtFSM_d <= v;
      sig_xhb_reset <= xhb_reset;
      sig_xsr_load  <= xsr_load;
      sig_xsr_shift <= xsr_shift;
   end process;

   --
   -- RECEIVER
   --

   -- define receive data rate register and its CRU interface
   --
   rdr_reg : process(clk)
   begin
      if rising_edge(clk) then rdr_q <= rdr_d; end if;
   end process;

   rdr_cmb : process(rdr_q, nCE, CRUCLK, flg_q, CRUOUT, S)
   variable v : std_logic_vector(10 downto 0);
   begin
      v := rdr_q;
      if nCE='0' and CRUCLK='1' and flg_q.ldctl='0' and flg_q.ldir='0' and flg_q.lrdr='1' then
         case S is
            when "01010" => v(10) := CRUOUT;
            when "01001" => v(9)  := CRUOUT;
            when "01000" => v(8)  := CRUOUT;
            when "00111" => v(7)  := CRUOUT;
            when "00110" => v(6)  := CRUOUT;
            when "00101" => v(5)  := CRUOUT;
            when "00100" => v(4)  := CRUOUT;
            when "00011" => v(3)  := CRUOUT;
            when "00010" => v(2)  := CRUOUT;
            when "00001" => v(1)  := CRUOUT;
            when "00000" => v(0)  := CRUOUT;
            when others => null;
         end case;
      end if;
      rdr_d <= v;
   end process;

   -- define receive buffer register
   --
   rbr_reg : process(clk)
   begin
      if rising_edge(clk) then rbr_q <= rbr_d; end if;
   end process;

   rbr_cmb : process(rbr_q, ctl_q, rsr_q, sig_rbr_load)
   variable v : std_logic_vector(7 downto 0);
   begin
      v := rbr_q;
      if sig_rbr_load='1' then
         case ctl_q.rcl is
            when "11"   => v := rsr_q;
            when "10"   => v :=   "0" & rsr_q(7 downto 1);
            when "01"   => v :=  "00" & rsr_q(7 downto 2); 
            when others => v := "000" & rsr_q(7 downto 3); 
         end case;
      end if;
      rbr_d <= v;
   end process;

   -- define receive shift register
   --
   rsr_reg : process(clk)
   begin
      if rising_edge(clk) then rsr_q <= rsr_d; end if;
   end process;

   rsr_cmb : process(rsr_q, rbr_q, RIN, sig_rsr_shift)
   variable v    : std_logic_vector(7 downto 0);
   begin
      v := rsr_q;
      if sig_rsr_shift='1' then
         v := RIN & rsr_q(7 downto 1);
      end if;
      rsr_d <= v;
   end process;

   -- define receive half-bit counter register
   --
   rhbctr_reg : process(clk)
   begin
      if rising_edge(clk) then rhbctr_q <= rhbctr_d; end if;
   end process;

   rhbctr_cmb : process(rhbctr_q, rdr_q, bitclk, sig_rhb_reset)
   variable v : std_logic_vector(13 downto 0);
   variable z : std_logic;
   begin
      v := rhbctr_q;
      if v="000000000000000" then z := '1'; else z := '0'; end if;
      
      if sig_rhb_reset='1' or z='1' then
         v := rdr_q(10)&"000"&rdr_q(9 downto 0);
      elsif bitclk='1' then
         v := v - 1;
      end if;
      rhbctr_d <= v;
      sig_rhbctr_iszero <= z;
   end process;

   -- define xmt controller register
   --
   rcvFSM_reg : process(clk)
   begin
      if rising_edge(clk) then rcvFSM_q <= rcvFSM_d; end if;
   end process;

   rcvFSM_cmb : process(rcvFSM_q, ctl_q, RIN, sig_reset, sig_rienb, sig_rhbctr_iszero)
   variable v   : rcvFSM_type;
   variable par : std_logic;
   variable rbr_load, rsr_shift, rhb_reset : std_logic;
   variable rbits : std_logic_vector(4 downto 0);
   begin
      v := rcvFSM_q;
		rbr_load := '0'; rsr_shift := '0'; rhb_reset := '0';
      
      -- prepare half-bit times for data word and stop bits
      case ctl_q.rcl is
         when "11"   => rbits := "10000";
         when "10"   => rbits := "01110";
         when "01"   => rbits := "01100";
         when others => rbits := "01010";
      end case;

      if sig_rhbctr_iszero='1' then
         v.bitctr := v.bitctr - 1;
      end if;

      if sig_reset='1' or sig_rienb='1' then
         v.rbrl  := '0';
         v.rover := '0';
         v.rper  := '0';
         v.rfer  := '0';
      end if;
         
      if v.state=IDLE then
         v.rsbd := '0';
         v.rfbd := '0';
         if RIN='1' then
            v.state := START1;
         end if;

      elsif v.state=START1 then
         if RIN='0' then
            v.state := START;
            v.bitctr := "00001";
            rhb_reset := '1';
         end if;
         
      elsif sig_rhbctr_iszero='1' then
         case v.state is

            when START =>
               if v.bitctr=0 then
                  if RIN='1' then
                     v.state := IDLE;
                  else
                     v.state := BITS;
                     v.bitctr := rbits;
                     v.par  := '0';
                     v.rsbd := '1';
                  end if;
               end if;

            when BITS =>
               if v.bitctr(0)='0' then
                  v.par := v.par xor RIN;
						v.rfbd := '1';
                  rsr_shift := '1';
               end if;
               if v.bitctr=0 then
                  v.bitctr := "00010";
                  if ctl_q.penb='1' then
                     v.state  := PARITY;
                  else
                     v.state := STOP;
                  end if;
               end if;

            when PARITY =>
               if v.bitctr=0 then
                  v.par := v.par xor RIN;
                  v.state := STOP;
                  v.bitctr := "00010";
               end if; 
            
            when STOP =>
               if v.bitctr=0 then
						v.rover  := v.rbrl;
						v.rper   := v.par;
						v.rfer   := not RIN;
                  v.rbrl   := '1';
                  rbr_load := '1';
                  v.state  := IDLE;
               end if; 

            when others => v.state := IDLE;

         end case;
      end if;

      rcvFSM_d <= v;
      sig_rhb_reset <= rhb_reset;
      sig_rbr_load  <= rbr_load;
      sig_rsr_shift <= rsr_shift;
   end process;

   --
   --   CRU INPUT
   --

   --    Combinational helper signals (see figure 7 datasheet)
   --
   dscint <= dsch   and flg_q.dscenb;
   rint   <= rcvFSM_q.rbrl   and flg_q.rienb;
   xint   <= xmtFSM_q.xbre   and flg_q.xienb;
   timint <= timFSM_q.timelp and flg_q.timenb;

   intr   <= dscint or rint or xint or timint;
   rcverr <= rcvFSM_q.rfer or rcvFSM_q.rover or rcvFSM_q.rper;
   flag   <= flg_q.ldctl or flg_q.ldir or flg_q.lrdr or flg_q.lxdr or flg_q.brkon;
   rts    <= xmtFSM_q.rts;

   -- the CRUIN signal is essentially a 32-way mux with a tri-state output
   --
   CRUIN <= 
      '1'              when nCE='1' else
      intr             when S="11111" else   -- 31, any interrupt pending
      flag             when S="11110" else   -- 30, 'flag' field
      dsch             when S="11101" else   -- 29, device status change
      not nCTS         when S="11100" else   -- 28, inverse of nCTS input
      not nDSR         when S="11011" else   -- 27, inverse of nDSR input
      not rts          when S="11010" else   -- 26, inverse of nRTS output
      timFSM_q.timelp  when S="11001" else   -- 25, timer elapsed
      timFSM_q.timerr  when S="11000" else   -- 24, timer elapsed more than once
      xmtFSM_q.xsre    when S="10111" else   -- 23, 'xsre', todo
      xmtFSM_q.xbre    when S="10110" else   -- 22, transmit buffer register empty
      rcvFSM_q.rbrl    when S="10101" else   -- 21, receive buffer register loaded
      dscint           when S="10100" else   -- 20, device status change interrupt pending
      timint           when S="10011" else   -- 19, timer interrupt pending
      '0'              when S="10010" else   -- 18, not used (always 0)
      xint             when S="10001" else   -- 17, transmit interrupt pending
      rint             when S="10000" else   -- 16, receive interrupt pending
      RIN              when S="01111" else   -- 15, direct copy of RIN
      rcvFSM_q.rsbd    when S="01110" else   -- 14, 'rsbd', todo
      rcvFSM_q.rfbd    when S="01101" else   -- 13, 'rfbd', todo
      rcvFSM_q.rfer    when S="01100" else   -- 12, 'rfer', todo
      rcvFSM_q.rover   when S="01011" else   -- 11, 'rover', todo
      rcvFSM_q.rper    when S="01010" else   -- 10, 'rper', todo
      rcverr           when S="01001" else   --  9, 'rcverr', todo
      '0'              when S="01000" else   --  8, not used (always 0)
      rbr_q(7)         when S="00111" else   --  7, receive buffer register, bit 7
      rbr_q(6)         when S="00110" else
      rbr_q(5)         when S="00101" else
      rbr_q(4)         when S="00100" else
      rbr_q(3)         when S="00011" else
      rbr_q(2)         when S="00010" else
      rbr_q(1)         when S="00001" else
      rbr_q(0)         when S="00000" else   --  0, receive buffer register, bit 0
      '0';
   
   -- Simple outputs
   --
   nRTS <= not xmtFSM_q.rts;
   nINT <= not intr;
   XOUT <= xsr_q(0) when xmtFSM_q.state=BITS else xmtFSM_q.xout;
   
end;
