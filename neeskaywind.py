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


def calc_true():
    # === CALCULATE TRUE WIND SPEED/DIRECTION ===

    print("calculating true wind speed/dir",flush=True)
    with db.cursor() as cursor:
        print("DB cursor allocated",flush=True)
        sql = """
            SELECT w.*, c.*, f.*,t.*
            FROM windraw w 
                LEFT JOIN compass c ON c.recdate = w.recdate 
                LEFT JOIN trackingdata_flex f ON f.recdate = w.recdate 
                LEFT JOIN windtrue t on t.recdate = w.recdate
            WHERE w.recdate IS NOT NULL AND 
                c.recdate IS NOT NULL AND 
                f.recdate IS NOT NULL AND
                t.avg_speed_kts_true IS NULL 
            ORDER BY w.recdate desc
            LIMIT 100; """
        print("SQL composed.",flush=True)
        if cursor.execute(sql) > 0:
            print("cursor executed.",flush=True)
            for row in cursor:
                for k in row.keys():
                    print(f" {k} = {row[k]}")
                wind_angle = float(row['avg_degrees'])
                wind_speed = float(row['avg_speed'])
                track_angle = float(row['gpsttmg'])
                track_speed_nmph = float(row['gpssogn'])
                compass_angle = float(row['c.avg_degrees'])
                print (f"wind angle={wind_angle}; windspeed={wind_speed}; track angle={track_angle}; track speed nmph={track_speed_nmph}; compass_angle={compass_angle}")
                rel_angle = wind_angle + compass_angle

                relv_n = math.cos(rel_angle*math.pi/180.0) * wind_speed
                relv_e = math.sin(rel_angle*math.pi/180.0) * wind_speed
                sog_n = math.cos(track_angle*math.pi/180.0) * track_speed_nmph
                sog_e = math.sin(track_angle*math.pi/180.0) * track_speed_nmph

                true_n = relv_n - sog_n
                true_e = relv_e - sog_e

                true_speed_kts = math.sqrt(true_n*true_n + true_e*true_e)
                true_wind_dir = (math.atan2(true_e,true_n)*180.0/math.pi ) % 360.0

                print(f"TRUE spd/dir: {true_speed_kts} / {true_wind_dir}")                        

                # prepare a cursor object using cursor() method
                #ticursor = db.cursor(pymysql.cursors.DictCursor)

                # Prepare SQL query to INSERT a record into the database.
                sql = f"INSERT INTO windtrue (recdate, avg_degrees_true,avg_speed_kts_true) \
                   VALUES ('{row['recdate']}',{true_wind_dir},{true_speed_kts});"
                print (sql)
                try:
                   # Execute the SQL command
                   cursor.execute(sql)
                   # Commit your changes in the database
                   db.commit()
                except Exception as e:
                   # Rollback in case there is any error
                   print(f"db error: {e}")
                   db.rollback()
                print("done with sql.",flush=True)










def main():
    with pymysql.connect(host="localhost",user="shipuser",password="arrrrr",db="neeskay", cursorclass=pymysql.cursors.DictCursor) as db:

        f=None
        s=None

        if len(sys.argv) > 1:
            sumfile = sys.argv[1]
        else:
            sumfile="/opt/neeskay/data/windraw.cur.csv"

        gpsfile = "../data/shipdata-current.csv"

        print("sumfile=",sumfile)

        with socket.socket() as s:

            recount = -1

            s.connect(('192.168.148.56',4002))
            with s.makefile("r") as f:

                recount = -1
                totaln = 0
                totale = 0
                totalspd = 0
                maxspd = 0
                thistime = datetime.datetime.utcnow()
                print(thistime)
                lasttime = thistime
                while True:
                    os.system("/usr/bin/touch /tmp/windran.flag")
                    print("reading...",flush=True)
                    datalin =  f.readline().strip()
                    print(f"line read: '{datalin}'",flush=True)
                    lasttime=thistime
                    thistime = datetime.datetime.utcnow()

                    # is it a valid NMEA sentence?
                    if len(datalin) > 3 and datalin[0] == '$' and datalin[-3:] == 'N,A':
                        dataline = datalin.split(",")
                        print(f"thistime={thistime} lasttime={lasttime}",flush=True)
                        print(f"dataline={dataline}",flush=True)
                        # is it the sentence we are looking for?
                        if dataline[0] == "$WIMWV":
                            thisdir = float(dataline[1])
                            thisspd = float(dataline[3])
                            thisn = math.cos(thisdir*math.pi/180.)*thisspd
                            thise = math.sin(thisdir*math.pi/180.)*thisspd
                            totaln += thisn
                            totale += thise
                            if (thisspd > maxspd): maxspd = thisspd
                            totalspd += thisspd
                            recount = recount + 1

                    # check that a second boundary has been crossed
                    print(f"TIME CHECK: {thistime.second} {lasttime.second}")
                    if thistime.second != lasttime.second:
                        # ==== ONLY RUN FOLLOWING CODE ONCE PER SECOND ====
                        # if we have data, write them
                        if recount > 0:

                            gpsdata = open(gpsfile,"r").readline().split(",")
                            with open(sumfile+".tmp","w") as sumf:
                                avgwd = math.atan2(totale/recount,totaln/recount)/math.pi*180.
                                if (avgwd < 0): avgwd += 360
                                if (avgwd >= 360): avgwd -= 360
                                avgspd = math.sqrt(totale*totale+totaln*totaln)/recount
                                sumrec = [ thistime.strftime("%Y-%m-%d %H:%M:%S"), str(recount), str(avgwd), str(avgspd) ]
                                print(sumrec)
                                print(",".join(sumrec), file=sumf)
                            with open(sumfile+".log","a") as sumlog:
                                print(",".join(sumrec), file=sumlog)
                            if os.path.exists(sumfile+".tmp"):
                                try:
                                    shutil.move(sumfile+".tmp",sumfile)
                                except Exception as e:
                                    print(f"***{e}",file=os.stderr,flush=True)


                            # prepare a cursor object using cursor() method
                            cursor = db.cursor(pymysql.cursors.DictCursor)

                            # Prepare SQL query to INSERT a record into the database.
                            sql = f"INSERT INTO windraw (recdate, nrecs, avg_degrees,avg_speed) \
                               VALUES ('{sumrec[0]}',{recount},{avgwd},{avgspd});"
                            print (sql)
                            try:
                                # Execute the SQL command
                                cursor.execute(sql)
                                # Commit your changes in the database
                                print("sql successful, committing...",flush=True)
                                db.commit()
                            except:
                               # Rollback in case there is any error
                               print("db error.",flush=True)
                               db.rollback()
                            print("done w/SQL",flush=True)

                            # reset parameters
                            recount = 0
                            totaln = 0
                            totale = 0
                            totalspd = 0
                            maxspd = 0
                    


@atexit.register
def cleanup():
    print("program atexit.",file=sys.stderr,flush=True)


try:
    main()
except KeyboardInterrupt:
    print("--keyboard interrupt--")
    sys.exit(0)
