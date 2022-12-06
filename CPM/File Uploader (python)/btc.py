#!/usr/bin/env python3
import sys
import os
import time
import glob

__version__ = '0.2'

def show_help():
	print( '== Binary to CP/M Converter %s ==' % __version__ )
	print( '                  by Meurisse D.')
	print( 'USAGE:')
	print( '  ./btc.py -u <user> <filename>  -o <output> -d <device> -h -t' )
	print( '' )
	print( '-u <user>   : 0 .. 9. CP/M user identification. REQUIRED ')
	print( '<filename>  : the source file to transform in HEX' )
	print( '-o <output> : output filename where the HEX will be stored. OPTIONAL.')
	print( '-d <device> : serial device where the HEX must be sent. OPTIONAL.')
	print( '-h          : display this help.')
	print( '-t          : Text only. force \r or \n to \r\n')

	print( '' )
	print( 'If none of -o or -d is defined then the stdout is used!' )
	print( 'If <filename> contains a * wildcard then several files are sent! (-o is ignored in such case).' )
	print( '')

def get_args( argv ):
	""" Process argv and extract: output, source, device, user parameters """
	r = { 'output' : None, 'source' : None, 'device' : None, 'user' : None, 'forcern' : False } # -o, unamed, -d, -u, -t
	used = [] # list of used entries in argv
	used.append(0) # item #0 is the script name
	unamed = [] # unamed parameters
	# Locate the named parameter
	for i in range( len(argv) ):
		if argv[i] == '-u':
			sUser = argv[i+1]
			try:
				r['user']=int(sUser)
			except:
				raise Exception('"%s" is an invalid user value (0..9 allowed)' % sUser )
			used.append(i)
			used.append(i+1)
		elif argv[i] == '-o':
			r['output'] = argv[i+1]
			used.append(i)
			used.append(i+1)
		elif argv[i] == '-d':
			r['device'] = argv[i+1]
			used.append(i)
			used.append(i+1)
		elif argv[i] == '-t':
			r['forcern'] = True
			used.append(i)

	# Locate the unamed parameter
	for i in range( len(argv) ):
		if i in used:
			continue
		else:
			unamed.append( argv[i] )
	# First unamed is the source file
	if len(unamed) > 0:
		r['source'] = unamed[0]


	# Sanity check
	if r['user']==None:
		raise Exception('CP/M user value (0..9) missing')
	if not( 0 <= r['user'] <= 9 ):
		raise Exception('Invalid value "%i" for CP/M user (0..9 allowed)' % r['user'])

	if r['source']==None:
		raise Exception('source filename is missing')

	return r


def encode_hex( filename, **kwargs ):
	""" return a list of string with formatted data generated from filename """
	user = kwargs['user']
	forcern = kwargs['forcern'] # True/False : transform \r or \r in text to \r\n
	#print('forcern: %s' % forcern)
	_r = []
	with open( filename, "rb" ) as source:
		_r.append( "A:DOWNLOAD %s\r\n" % os.path.basename(filename) ) # just keep the filename
		_r.append( "U%i\r\n" % user )
		_r.append( ":" ) # start of download
		_l   = 0
		_sum = 0
		_catch_r = False # we catch a \r
		abyte = source.read(1)
		while len(abyte)>0:
			if forcern: # only applies for text file
				if (abyte[0] == 10) and not(_catch_r):
					_r.append( '%02X' % 13 )
					_l += 1
					_sum += 13
					_r.append( '%02X' % abyte[0] )
					_l += 1
					_sum += abyte[0]
					_catch_r = False
					abyte = source.read(1)
					continue
				if (abyte[0] == 13):
					_r.append( '%02X' % abyte[0] )
					_l += 1
					_sum += abyte[0]
					_catch_r = True
					abyte = source.read(1)
					continue
				if _catch_r and (abyte[0] != 10):
					_r.append( '%02X' % 10 )
					_l += 1
					_sum += 10
					_r.append( '%02X' % abyte[0] )
					_l += 1
					_sum += abyte[0]
					_catch_r = False
					abyte = source.read(1)
					continue

			# for binary file & other use-case
			_r.append( '%02X' % abyte[0] )
			_l += 1
			_sum += abyte[0]
			abyte = source.read(1)

		_r.append( ">" )
		_r.append( '%02X' %  (_l%0x100) )
		_r.append( '%02X' %  (_sum%0x100) )
		_r.append( '\r\n' )
	return _r


def write_hex( data, output_filename ):
	""" Write the data into an ascii file """
	with open( output_filename, "wb" ) as destin:
		for item in data:
			destin.write( item.encode('ASCII') )

def write_stream( data, stream ):
	""" Write the data to a stream """
	for item in data:
		stream.write( item )

def send_hex( data, device, prefix='' ):
	""" Write the data to a serial/com device. prefix is used to display a text prefix in the progression """
	import serial
	ser = serial.Serial(device, 115200, timeout=0 )
	_count = 0
	_max = len(data)
	_progress = 0
	for item in data:
		for c in item:
			ser.write(c.encode('ASCII'))
			time.sleep(0.001) # wait one ms.
			_count += 1
		_progress += 1
		if '\r\n' in item: # This may be a command.... wait it to start
			time.sleep(1.5)

		if _count>20:
			sys.stdout.write( '\r%s - progress: %4.1f %%' % (prefix, _progress*100.0/_max) )
			_data = ser.read(10)
			time.sleep(0.001) # wait one ms.
			_count = 0
			# Do not print the dots while sending a file
			# if len(_data)>0:
			#	print( _data.decode('ASCII') )
	sys.stdout.write( '\r%s - progress: %4.1f %%' % (prefix, 100) )
	print() # Going to the line
	_r = False
	if len(_data)>0: # check if OK has been received with progress messages
		_r = ( 'OK'.encode('ASCII') in _data)
		# print( _data )
	if not(_r):
		time.sleep(1)
		_data = ser.read(10)
		# print( _data )
		_r = ( 'OK'.encode('ASCII') in _data)
	if not(_r): # make a second try
		time.sleep(2) # wait the software to respond
		_data = ser.read(10)
		# print(  _data )
		_r = ('OK'.encode('ASCII') in _data)

	ser.close()
	return _r

def btc_single_file( args ):
	data = encode_hex( filename=args['source'], **args )
	if args['output'] != None:
		write_hex( data, args['output'] )
	if args['device'] != None:
		sent = send_hex( data, args['device'], os.path.basename(args['source']) ) # data, serial_device, prefix_text
		if sent:
			print( 'File %s succesfully sent!' % os.path.basename(args['source']) )
	if (args['output']==None) and (args['device']==None):
		write_stream( data, sys.stdout )

def btc_multiple_files( args ):
	source = filename=args['source']
	files = glob.glob( source )
	print( "Files: %s" % ', '.join([ os.path.basename(f) for f in files]) )
	# data = encode_hex( filename, **args )
	_file_count = 0
	_file_max = len( files )
	for filename in files:
		_file_count += 1
		data = encode_hex( filename=filename, **args )
		basename = os.path.basename( filename )
		prefix = '%3i/%i  %15s ' % (_file_count,_file_max, basename )
		if args['device'] != None:
			sent = send_hex( data, args['device'], prefix ) # data, serial_device, prefix_text
			if sent:
				pass #print( 'File %s succesfully sent!' % basename )
			else:
				raise Exception( 'OK not received for file %i/%i  %s' % (_file_count,_file_max,basename) )
		if args['device']==None:
			write_stream( data, sys.stdout )




if __name__ == '__main__':
	if (len( sys.argv )==1) or ('-h' in sys.argv):
		show_help()
		exit(1)

	args = get_args( sys.argv ) # gets 'output', 'source', 'device', 'user'
	#print( 'Number of arguments: %i' % len(sys.argv) )
	#print( 'Argument List: %s' % sys.argv )
	#print( 'Decoded args: %s' % args )

	# Check if pySerial is installed
	if args['device'] != None:
		try:
			import serial
		except Exception as e:
			raise Exception("Cannot send to %s because pySerial is not installed!" % args['device'])

	print( args['source'] )
	if '*' in args['source']: # send multiple files
		btc_multiple_files( args )
	else:
		btc_single_file( args )
