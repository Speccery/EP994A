#!/usr/bin/python
f1=open("cpu9900log-new.txt")
f2=open("cputrace.txt")

# ignore header lines
f1.readline()
f2.readline()
f2.readline()		# one extra line here

# lines that have been checked and where the differences do not matter
exclusions=[6,8,9]

k=1

while True:
	classic=f1.readline().split(':')
	fpga=f2.readline().split(':')
	ac=int(classic[2],16)
	dc=int(classic[3],16)	
	af=int(fpga[2],16)
	df=int(fpga[3],16)
	pc=int(classic[1],16)
	if ac != af or dc != df:
		if k not in exclusions:
			# print hex(ac),hex(af), " ", hex(dc),hex(df)
			print "{0:4d} pc {1:04x} addr {2:04x} {3:04x} data {4:04x} {5:04x}".format(k, pc,ac, af, dc,df)
	k=k+1
	if k >= 200:
		break

f1.close()
f2.close()

