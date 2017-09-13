#!/usr/bin/python
#f1=open("cpu9900log-new.txt")
f1=open("cpu9900log.txt")
f2=open("cputrace.txt")
# lines that have been checked and where the differences do not matter
# exclusions=[6,8,9]
exclusions=[1,2,4]


# ignore header lines
f1.readline()
f2.readline()
f2.readline()		# one extra line here


k=1
instr=0

print "Classic99 address written first, followed by FPGA address."
print "Similarly for data, Classic99 result first."
while True:
	classic=f1.readline().split(':')
	fpga=f2.readline().split(':')
	ac=int(classic[2],16)
	dc=int(classic[3],16)	
	af=int(fpga[2],16)
	df=int(fpga[3],16)
	pc=int(classic[1],16)
	instr = instr + 1
	# also compare flags
	fc=int(classic[4], 16) & 0xFE0F	# Mask unused flag bits
	ff=int(fpga[4], 16) & 0xFE0F
		
	if ac != af or dc != df or fc != ff:
		# For byte writes to VDP, we do not care about the low byte differences.
		if ac==af and (ac & 0xFFFC) == 0x8C00 and (dc & 0xFF00) == (df & 0xFF00):
			# print "VDP low byte different {0:04x} {1:04x}".format(dc,df)
			continue
		
		if k not in exclusions:
			# print hex(ac),hex(af), " ", hex(dc),hex(df)
			print "{0:4d} {1:4d} pc {2:04x} addr {3:04x} {4:04x} data {5:04x} {6:04x} flags {7:04x} {8:04x}".format(instr, k, pc,ac, af, dc,df, fc,ff)
	k=k+1
	if k >= 32000:
		break

f1.close()
f2.close()

