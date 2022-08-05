#!/usr/bin/python

import socket
import os
import sys
import atexit
import time
import math

f=None
s=None

if len(sys.argv) > 1:
    outfile = sys.argv[1]
else:
    outfile="/opt/neeskay/data/compassraw.cur.csv"
    sumfile="/opt/neeskay/data/compass.cur.csv"

print "outfile=",outfile
print "sumfile=",sumfile

def main():
    global s,f
    s=socket.socket()

    recount = -1
    dateime = None

    s.connect(('192.168.148.56',4001))
    f=s.makefile("r")

    recount = -1
    totaln = 0
    totale = 0
    totalws = 0
    maxws = 0
    thistime = time.localtime()
    lasttime = thistime
    while True:
        dataline =  f.readline().rstrip('\0\r\n').split(",")
        thistime = time.localtime()
        print dataline
        if thistime.tm_sec != lasttime.tm_sec:
            lasttime = thistime
            # if we have data, write them
            if recount > 0:
                with open(sumfile+".tmp","w") as sumf:
                    avgwd = math.atan2(totale/recount,totaln/recount)/math.pi*180.
                    if (avgwd < 0): avgwd += 360
                    sumrec = [ time.strftime("%Y-%m-%d %H:%M:%S", thistime), str(recount), str(totalws/recount), str(maxws),str(avgwd) ]
                    print sumrec
                    print >>sumf, ",".join(sumrec)
                with open(sumfile+".log","a") as sumlog:
                    print >>sumlog, ",".join(sumrec)
                os.rename(sumfile+".tmp",sumfile)
            # always try to close the outfile even if we didn't have records
            try:
                outf.close()
            except:
                pass
            # always try renaming
            try:
                os.rename(outfile+".tmp",outfile)
            except:
                pass
            # establish new output file
            outf=open(outfile+".tmp","w")
            outlog=open(outfile+".log","a")
            # reset parameters
            recount = 0
            totaln = 0
            totale = 0
            totalws = 0
            maxws = 0
        elif recount == -1:
            pass
        elif dataline[0] == "$GPHDT":
            dataout = [ time.strftime("%Y-%m-%d %H:%M:%S", thistime) ] + dataline[1:]
            print dataout
            print >>outf, ",".join(dataout)
            print >>outlog, ",".join(dataout)
            thisws = 1
            thisdir = float(dataline[1])
            thisn = math.cos(thisdir*math.pi/180.)*thisws
            thise = math.sin(thisdir*math.pi/180.)*thisws
            totaln += thisn
            totale += thise
            if (thisws > maxws): maxws = thisws
            totalws += thisws
            recount = recount + 1
                


@atexit.register
def cleanup():
    global f,s
    try:
        f.close()
        s.close()
        out.close()
        print "files closed."
    except:
        print "files were not open."
        pass





try:
    main()
except KeyboardInterrupt:
    print "--keyboard interrupt--"
    sys.exit(0)
