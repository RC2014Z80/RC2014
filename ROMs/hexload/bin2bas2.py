
mem = 0xF800

with open("hexload.bin", "rb") as f:
    byte = f.read(1)
    while byte != "":
        print "poke "+str( mem-65536 )+","+str( ord(byte) )
        mem = mem+1
        byte = f.read(1)

print "poke "+str(0x8048-65536) + "," + str(0xC3)
print "poke "+str(0x8048-65536+1) + "," + str(0x00)
print "poke "+str(0x8048-65536+2) + "," + str(0xF8)
