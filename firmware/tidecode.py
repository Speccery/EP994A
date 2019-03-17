#!/usr/bin/python
# tidecode.py
# EP 2018-02-23
# A small program to understand the structure of TI files.
import sys

def get16(f):
  """read 16 bits from the file f"""
  r=ord(f.read(1))
  r=(ord(f.read(1)) << 8) | r
  return r


def print_header(filename):
	src = open(filename, "rb")
	try:
		id = src.read(8)
		length_sectors = get16(src)
		filetype = ord(src.read(1))
		records_per_sector = ord(src.read(1))
		bytes_in_last_sector = ord(src.read(1))
		record_length = ord(src.read(1))
		num_records = get16(src)
		
		
	finally:
		src.close()
		if ord(id[0]) != 7 or id[1:8] != "TIFILES":
			print "Not in TIFILES format"
			print ord(id[0]) , id[1:8]
		else:
			print "{0:8s} length_sectors={1:d} filetype={2:d}".format(str(id), length_sectors, filetype)
			print "records_per_sector={0:d} bytes_in_last_sector={1:d}".format(records_per_sector, bytes_in_last_sector)
			print "record_length={0:d} num_recods={1:d}".format(record_length, num_records)
			f7 = [ "Fixed", "Variable" ]
			f1 = [ "Disp", "Internal" ]
			f0 = [ "Data", "Program" ]
			print f7[ (filetype & 0x80) >> 7], f1[(filetype & 2) >> 1], f0[filetype & 1]
	
		# k = ' x"%04x"' % val
	
	
if __name__=='__main__':
	print "Processing " + sys.argv[1]
	print_header(sys.argv[1])
	