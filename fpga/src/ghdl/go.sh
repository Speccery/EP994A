# go.sh

 ghdl -a --std=08  tms9900.vhd ghdl_tb_tms9900.vhd testrom.vhd scratchpad.vhd epcache.vhd
 ghdl -e --std=08  tb_tms9900   # this is probably not necessary
 ghdl -r --std=08  tb_tms9900 --stop-time=500us 
 
