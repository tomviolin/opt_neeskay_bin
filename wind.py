#!/usr/bin/env python3

import socket
import os
import sys
import atexit
import time
import datetime
import math
import pymysql

db = pymysql.connect(host="localhost",user="shipuser",password="arrrrr",db="neeskay")

f=None
s=None

if len(sys.argv) > 1:
    sumfile = sys.argv[1]
else:
    sumfile="/opt/neeskay/data/windraw.cur.csv"

gpsfile = "../data/shipdata-current.csv"

print("sumfile=",sumfile)

def main():
    global s,f
    s=socket.socket()

    recount = -1
    dateime = None

    s.connect(('192.168.148.56',4002))
    f=s.makefile("r")

    recount = -1
    totaln = 0
    totale = 0
    totalspd = 0
    maxspd = 0
    thistime = datetime.datetime.utcnow()
    print(thistime)
    lasttime = thistime
    while True:
        print("reading...",flush=True)
        datalin =  f.readline().strip()
        print(datalin,flush=True)
        if datalin[0] != '$' or datalin[-3:] != 'N,A': continue
        dataline = datalin.split(",")
        thistime = datetime.datetime.utcnow()
        print(thistime)
        print(dataline)
        if thistime.second != lasttime.second:
            # ==== ONLY RUN FOLLOWING CODE ONCE PER SECOND ====
            lasttime = thistime
            # if we have data, write them
            if recount > 0:
                gpsdata = open(gpsfile,"r").readline().split(",")
                print(f"Tgpsdata[9])
                with open(sumfile+".tmp","w") as sumf:
                    avgwd = math.atan2(totale/recount,totaln/recount)/math.pi*180.
                    if (avgwd < 0): avgwd += 360
                    avgspd = math.sqrt(totale*totale+totaln*totaln)/recount
                    sumrec = [ thistime.strftime("%Y-%m-%d %H:%M:%S"), str(recount), str(avgwd), str(avgspd) ]
                    print(sumrec)
                    print(",".join(sumrec), file=sumf)
                with open(sumfile+".log","a") as sumlog:
                    print(",".join(sumrec), file=sumlog)
                if os.path.exists(sumfile+".tmp"):
                    os.rename(sumfile+".tmp",sumfile)

                # prepare a cursor object using cursor() method
                cursor = db.cursor()

                # Prepare SQL query to INSERT a record into the database.
                sql = f"INSERT INTO windraw (recdate, nrecs, avg_degrees) \
                   VALUES ('{sumrec[0]}',{recount},{avgwd},{avgspd});"
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
            totalspd = 0
            maxspd = 0
        elif recount == -1:
            pass
        elif dataline[0] == "$WIMWV":
            dataout = [ thistime.strftime("%Y-%m-%d %H:%M:%S") ] + dataline[1:]
            #print(dataout)
            thisdir = float(dataline[1])
            thisspd = float(dataline[3])
            thisn = math.cos(thisdir*math.pi/180.)*thisspd
            thise = math.sin(thisdir*math.pi/180.)*thisspd
            totaln += thisn
            totale += thise
            if (thisspd > maxspd): maxspd = thisspd
            totalspd += thisspd
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
