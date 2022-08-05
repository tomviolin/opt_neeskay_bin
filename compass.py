#!/usr/bin/python3

import socket
import os
import sys
import atexit
import time
import math
import pymysql

db = pymysql.connect("localhost","shipuser","arrrrr","neeskay")

f=None
s=None

if len(sys.argv) > 1:
    sumfile = sys.argv[1]
else:
    sumfile="/opt/neeskay/data/compass.cur.csv"

print("sumfile=",sumfile)

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
        print(dataline)
        if thistime.tm_sec != lasttime.tm_sec:
            # ==== ONLY RUN FOLLOWING CODE ONCE PER SECOND ====
            lasttime = thistime
            # if we have data, write them
            if recount > 0:
                with open(sumfile+".tmp","w") as sumf:
                    avgwd = math.atan2(totale/recount,totaln/recount)/math.pi*180.
                    if (avgwd < 0): avgwd += 360
                    sumrec = [ time.strftime("%Y-%m-%d %H:%M:%S", thistime), str(recount), str(avgwd) ]
                    print(sumrec)
                    print(",".join(sumrec), file=sumf)
                with open(sumfile+".log","a") as sumlog:
                    print(",".join(sumrec), file=sumlog)
                if os.path.exists(sumfile+".tmp"):
                    os.rename(sumfile+".tmp",sumfile)

                # prepare a cursor object using cursor() method
                cursor = db.cursor()

                # Prepare SQL query to INSERT a record into the database.
                sql = f"INSERT INTO compass (recdate, nrecs, avg_degrees) \
                   VALUES ('{sumrec[0]}',{recount},{avgwd});"
                print (sql)
                try:
                   # Execute the SQL command
                   cursor.execute(sql)
                   # Commit your changes in the database
                   db.commit()
                except:
                   # Rollback in case there is any error
                   print("db error.")
                   db.rollback()

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
            #print(dataout)
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
        db.close()
        f.close()
        s.close()
        out.close()
        print("files closed.")
    except:
        print("files were not open.")
        pass





try:
    main()
except KeyboardInterrupt:
    print("--keyboard interrupt--")
    sys.exit(0)
