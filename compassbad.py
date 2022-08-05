#!/usr/bin/python

import socket
import os
import sys
import atexit

f=None
s=None

if len(sys.argv) > 1:
    outfile = sys.argv[1]
else:
    outfile="/opt/neeskay/data/compassraw.cur.csv"
    sumfile="/opt/neeskay/data/compass.cur.csv"

fakeheading=0


def main():
    global s,f,fakeheading
    s=socket.socket()

    recount = -1
    dateime = None

    s.connect(('192.168.148.56',4001))

    milliseconds = 0
    recount = -1
    startheading = 0
    thisheading = 0
    totalheading = 0
    datetime = "000000"
    f=s.makefile("r")
    while True:
        fakeheading = fakeheading + 3.4
        if fakeheading >= 360: fakeheading = fakeheading - 360
        dataline =  f.readline().rstrip('\0\r\n').split(",")
        if dataline[0] == "$GPZDA":
            # if we have records, write them
            if recount > 0:
                with open(sumfile+".tmp","w") as sumf:
                    sumrec = dataline[1:5] + [ str(recount), str(startheading), str(thisheading),str(totalheading/recount) ]
                    for i in xrange(5,8):
                        if float(sumrec[i]) >= 360: sumrec[i] = str(float(sumrec[i]) - 360)
                        if float(sumrec[i]) < 0: sumrec[i] = str(float(sumrec[i]) + 360)
                    print sumrec
                    print >>sumf, ",".join(sumrec)
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

            # reset parameters
            recount = 0
            datetime = dataline[1:5]
            startheading=0
            thisheading=0
            totalheading=0
            milliseconds=0
        elif recount == -1:
            pass
        elif dataline[0] == "$GPHDT":
            dataline[1] = str(fakeheading)
            dataout = datetime + [ str(milliseconds) ] + dataline[1:]

            print dataout
            print >>outf, ",".join(dataout)
            if recount == 0:
                startheading = float(dataline[1])
            thisheading = float(dataline[1])
            if (thisheading-startheading > 180):
                thisheading = thisheading - 360
            if (thisheading-startheading < -180):
                thisheading = thisheading + 360
            totalheading = totalheading + thisheading
            milliseconds = milliseconds + 25
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
