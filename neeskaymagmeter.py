#!/usr/bin/env python3
# vim:expandtab:ts=4:sw=4:softtabstop=4:

import socket
import os
import sys
import shutil
import atexit
import time
import datetime
import math
import pymysql

def main():
    with pymysql.connect(host="localhost",user="shipuser",password="arrrrr",db="neeskay") as db:

        if len(sys.argv) > 1:
            sumfile = sys.argv[1]
        else:
            sumfile="/opt/neeskay/data/compass.cur.csv"

        with socket.socket() as s:

            recount = -1
            dateime = None

            s.connect(('192.168.148.56',4001))
            with s.makefile("r") as f:

                recount = -1
                totaln = 0
                totale = 0
                totalws = 0
                thistime = datetime.datetime.utcnow()
                print(thistime)
                lasttime = thistime
                while True:
                    datalin =  f.readline().strip()
                    if datalin[0] != '$' or datalin[-3] != '*': continue
                    dataline = datalin.split(",")
                    thistime = datetime.datetime.utcnow()
                    print(thistime)
                    print(dataline)
                    if thistime.second != lasttime.second:
                        # ==== ONLY RUN FOLLOWING CODE ONCE PER SECOND ====
                        # if we have data, write them
                        if recount > 0:
                            with open(sumfile+".tmp","w") as sumf:
                                avgcd = math.atan2(totale/recount,totaln/recount)/math.pi*180.
                                if (avgcd < 0): avgcd += 360
                                sumrec = [ thistime.strftime("%Y-%m-%d %H:%M:%S"), str(recount), str(avgcd) ]
                                print(sumrec)
                                print(",".join(sumrec), file=sumf)
                            with open(sumfile+".log","a") as sumlog:
                                print(",".join(sumrec), file=sumlog)
                            if os.path.exists(sumfile+".tmp"):
                                shutil.move(sumfile+".tmp",sumfile)

                            # prepare a cursor object using cursor() method
                            cursor = db.cursor()

                            # Prepare SQL query to INSERT a record into the database.
                            sql = f"INSERT INTO compass (recdate, nrecs, avg_degrees) \
                               VALUES ('{sumrec[0]}',{recount},{avgcd});"
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
                    elif recount == -1:
                        pass
                    elif dataline[0] == "$GPHDT":
                        dataout = [ thistime.strftime("%Y-%m-%d %H:%M:%S") ] + dataline[1:]
                        #print(dataout)
                        thisws = 1
                        thisdir = float(dataline[1])
                        thisn = math.cos(thisdir*math.pi/180.)*thisws
                        thise = math.sin(thisdir*math.pi/180.)*thisws
                        totaln += thisn
                        totale += thise
                        totalws += thisws
                        recount = recount + 1

                    lasttime = thistime

@atexit.register
def cleanup():
    print("atexit cleanup.",file=sys.stderr,flush=True)



try:
    main()
except KeyboardInterrupt:
    print("--keyboard interrupt--")
    sys.exit(0)

