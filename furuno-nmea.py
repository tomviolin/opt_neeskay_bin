#!/home/neeskay/mambaforge3/bin/python3
# vim:expandtab:ts=4:sw=4:softtabstop=4:

import os,sys,socket
import math
import datetime
from pathlib import Path
import pymysql
import time
import serial

import signal
import tzlocal, pytz
from multiprocessing import Queue, Process
db=None
DBQ = Queue()

database_proc = None

def handler(signum, frame):
    print('*** INTERRUPT ***',file=sys.stderr,flush=True) 
    DBQ.put(None)
    print('*** waiting for db proc ***',file=sys.stderr,flush=True) 
    database_proc.join()
    print('*** done waiting! ***',file=sys.stderr,flush=True) 
    sys.exit(1)
 
def dbhandler(signum, frame):
    print('*** DB INTERRUPT ***',file=sys.stderr,flush=True) 
    if db is not None:
        db.close()
    sys.exit(1)
 


def to_float(k):
    try:
        return float(k)
    except Exception as e:
        return None

def to_int(k):
    try:
        return int(k)
    except Exception as e:
        return None

#
#  This is a Python (formerly Kermit) script that monitors the depth, temperature, and 
#  GPS readings from the Furuno unit on the Neeskay and records this dataset
#  to a CSV file and also saves it to a MySQL database.
#


# define function to convert latitude and longitude from
# the NMEA format to decimal degrees

def NMEAtoDecCoords(rawcoord,rawdir):
        # (note that since N,S,E,W are all unique it is not necessary to
        #  specify latitude vs longitude with this function.)

    if rawcoord=='' or rawdir=='': return None

    deccoord = math.floor(to_float(rawcoord)/100.0)
    deccoord = deccoord + (to_float(rawcoord) - (deccoord * 100.0)) / 60.0
    if rawdir == 'S' or rawdir == 'W':
        deccoord = -deccoord

    return deccoord

"""
        # fancy S-expressions are the easiest way to do math in Kermit
        (setq deccoord (truncate (/ rawcoord 100)))
        (setq deccoord (+ deccoord (/ (- rawcoord (* deccoord 100)) 60)))
        if equal {\m(rawdir)} {S} {
            (setq deccoord (- deccoord))
        }
        if equal {\m(rawdir)} {W} {
            (setq deccoord (- deccoord))
        }
        }
        }
        return \m(deccoord)
}
"""
print(f"==== furuno-nmea START: {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} ====",file=sys.stderr,flush=True)



GPSdepth       = "NULL"
GPSlat         = "NULL"
GPSlng         = "NULL"
GPSdepth       = "NULL"
GPStempc       = "NULL"
GPSFixQuality  = "NULL"
GPSnSats       = "NULL"
GPSHDOP        = "NULL"
GPSAlt         = "NULL"
GPSTTMG        = "NULL"
GPSMTMG        = "NULL"
GPSSOGN        = "NULL"
GPSSOGK        = "NULL"
GPSMagVar      = "NULL"


def nmea_generator_inet(server_address):
    try:
        # make connection
        host_sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        host_sock.connect(server_address)
    except Exception as e:
        with open("error.flag","w") as f:
            f.write(f'Exception: {e}:<br>Unable to connect to Furuno<br>Check MOXA on bridge.\n')
        sys.exit(1)

    with host_sock as s:
        s.settimeout(10)
        fil = s.makefile()
        linein=""
        while True:
            try:
                linein = fil.readline().strip()
            except Exception as e:
                #print(f"in nmeaGenerator: {e}",file=sys.stderr,flush=True)
                return
            if (len(linein) > 6 and 
                    linein[0] == '$' and 
                    linein[-3] == '*'):

                line = linein[:-3].split(',')
                yield line

def nmea_generator(nmea_port):
    try:
        # make connection
        ser = serial.Serial('/dev/ttyUSB0',38400,parity=serial.PARITY_NONE)
    except Exception as e:
        with open("error.flag","w") as f:
            f.write(f'Exception: {e}:<br>Unable to connect to USB Serial Port<br>Check USB cable plugged into "SHIP DATA SYSTEM"\n')
        sys.exit(1)

    with ser as s:
        fil = ser
        linein=""
        while True:
            try:
                linein = fil.readline().decode('UTF-8').strip()
            except Exception as e:
                print(f"in nmeaGenerator: {e}",file=sys.stderr,flush=True)
                return
            if (len(linein) > 6 and 
                    linein[0] == '$' and 
                    linein[-3] == '*'):

                line = linein[:-3].split(',')
                yield line


def save_to_database_helper(db, sql):
    # save to mysql database
    # now invoke mysql to import the data
    #print("helper.")
    cursor = db.cursor()
    
    try:
        # Execute the SQL command
        cursor.execute(sql)
        # Commit your changes in the database
        #print('commited to db',file=sys.stderr,flush=True)
        db.commit()
    except Exception as e:
        # Rollback in case there is any error
        db.rollback()
        print(f'db ROLLBACK: {e}', file=sys.stderr,flush=True)

def DatabaseThread():
    signal.signal(signal.SIGINT, dbhandler)
    signal.signal(signal.SIGQUIT, dbhandler)
    #print('opening the database.',file=sys.stderr, flush=True)
    with pymysql.connect(host="localhost", user="shipuser", password="arrrrr", db="neeskay", cursorclass=pymysql.cursors.DictCursor) as db:
        while True:
            sql = DBQ.get()
            #print("dbthread recvd req.")
            if sql is None:
                print("*** DB PROC EXIT ***",file=sys.stderr,flush=True)
                break
            save_to_database_helper(db,sql)
                        
def save_to_database(sql):
    DBQ.put(sql)

#  start db thread
#print("db process starting")
database_proc = Process(target=DatabaseThread)
database_proc.start()
#print(f"started {database_proc}")

signal.signal(signal.SIGINT, handler)
signal.signal(signal.SIGQUIT, handler)
    
if True:
    #print('database open!',file=sys.stderr,flush=True)
    # initiate the nema generator 
    # nmeaGen = nmea_generator(('192.168.148.25',4001))
    nmeaGen = nmea_generator(('/dev/ttyUSB0',4800))
    #print("nmea_generator created!",file=sys.stderr,flush=True)
    while True:
        #print("going to try.",file=sys.stderr,flush=True)
        try:
            line = next(nmeaGen)
        except Exception as e:
            with open("error.flag","w") as f:
                print(f"DATA ERROR: no data coming from Furuno: {e}",file=f)
                print(f"data stream stopped: {e}",file=sys.stderr,flush=True)
            time.sleep(1)
            #print("trying...",file=sys.stderr,flush=True)
            #nmeaGen = nmea_generator() #('192.168.148.25',4001))
            nmeaGen = nmea_generator(('/dev/ttyUSB0',38400))
            continue
        print(f"{line}",flush=True,file=sys.stdout)
        open("error.flag","w").write("")
        nmeaCode = line[0]

        if nmeaCode == "":    # included for completeness- should never be reached
            sys.stderr.write(f"no data received\n")

        if nmeaCode[3:] == "DPT":  # $GPDPT - depth
            GPSdepth = line[1]

        if nmeaCode == "$GPGLL":  # $GPGLL - GPS location

            rawlatn = line[1] # \fword(\%l,1,{,})
            rawlatd = line[2] # \fword(\%l,2,{,})
            rawlngn = line[3] # \fword(\%l,3,{,})
            rawlngd = line[4] # \fword(\%l,4,{,})
            rawutc  = line[5] # \fword(\%l,5,{,})

            GPSlat = NMEAtoDecCoords (rawlatn,rawlatd)

            GPSlng = NMEAtoDecCoords (rawlngn,rawlngd)

        if nmeaCode[3:] == "MTW":  # $GPMTW - water temperature

            temp = to_float(line[1]) # \fword(\%l,1,{,})
            unit = line[2] # \fword(\%l,2,{,})
            # echo unit=\m(unit)
            if unit[0] == "F":
                GPStempc = (temp-32)*5/9
            else:
                GPStempc = temp

        if nmeaCode == "$GPZDA":  # $GPZDA  Date & Time
            #
            #  SPECIAL NOTE ON THE $GPZDA RECORD:
            #
            #  This sentence is always the last sentence received from
            #  the Furuno in each burst of sentences that is issued once a second.
            #  Therefore, reception of this sentence is used to trigger the
            #  output of the data record, which simply consists of the most recently
            #  received values of all supported data.
            #

            # get data from YSI sonde
            x = ""   # YSI fields
            z = ""   # YSI data

            # is there any YSI data?
            if os.path.exists("../data/ysi-nmea.csv"):
                # yes -- invoke ysi-nmea.php to generate list of fields and data
                os.system("./ysi-nmea.php ../data/ysi.csv")
                # now read them
                with open("../data/ysi-nmea-data.csv","r") as f:
                    x,z = f.readlines(2) 

            UTC      = line[1] # \fword(\%l,1,{,})
            GPShour  = to_int(UTC[0:2])
            GPSmin   = to_int(UTC[2:4])
            GPSsec   = to_int(UTC[4:6])
            GPSday   = to_int(line[2]) # \fword(\%l,2,{,})
            GPSmonth = to_int(line[3]) # \fword(\%l,3,{,})
            GPSyear  = to_int(line[4]) # \fword(\%l,4,{,})

            GPStime  = f"{GPShour:02d}:{GPSmin:02d}:{GPSsec:02d}"
            print(f"** Uncorrected GPStime: {GPSyear:04d}-{GPSmonth:02d}-{GPSday:02d} {GPStime}",flush=True)

            GPStime  = f"{GPShour:02d}:{GPSmin:02d}:{GPSsec:02d}"
            print(f"GPStime: {GPStime}",flush=True)

            pydt = datetime.datetime(GPSyear,GPSmonth,GPSday,GPShour,GPSmin,GPSsec) #, tzinfo=pytz.UTC)
            unixtime = pydt.timestamp()
            if GPSyear < 2009:
                # add 1024weeks * 7 days/wk * 24 h/day * 60 min/h * 60 s/min
                correctedtime = unixtime + 1024*7*24*60*60
            else:
                correctedtime = unixtime
            cpydt = datetime.datetime.fromtimestamp(correctedtime)
            utczone = pytz.timezone('UTC')
            cpydt = utczone.localize(cpydt)
            print(f"CORRECTED TZINFO: {cpydt.tzinfo}")
            GPSyear = cpydt.year
            GPSmonth = cpydt.month
            GPSday = cpydt.day

            GPStime  = f"{cpydt.hour:02d}:{cpydt.minute:02d}:{cpydt.second:02d}"
            print(f"**   CORRECTED GPStime: {GPSyear:04d}-{GPSmonth:02d}-{GPSday:02d} {GPStime}",flush=True)

            # correct to local time 
            #localdt = cpydt.astimezone(tzlocal.get_localzone())

            #print(f"**   LOCALIZED GPStime: {localdt.year:04d}-{localdt.month:02d}-{localdt.day:02d} {localdt.hour:02d}:{localdt.minute:02d}:{localdt.second:02d}",flush=True)
            """
            # write to file upon receiving date/time
            with open("../data/shipdata.csv","a") as f:
                f.write(f"{GPSyear:04d}-{GPSmonth:02d}-{GPSday:02d} {GPStime},{GPSlat},{GPSlng},{GPSdepth},{GPStempc},{GPSFixQuality},{GPSnSats},{GPSHDOP},{GPSAlt},{GPSTTMG},{GPSMTMG},{GPSSOGN},{GPSSOGK},{GPSMagVar}{z}\n")

            # write to file upon receiving date/time
            with open("../data/shipdata-current.tmp","w") as f:
                f.write(f"{GPSyear}-{GPSmonth:02d}-{GPSday:02d} {GPStime},{GPSlat},{GPSlng},{GPSdepth},{GPStempc},{GPSFixQuality},{GPSnSats},{GPSHDOP},{GPSAlt},{GPSTTMG},{GPSMTMG},{GPSSOGN},{GPSSOGK},{GPSMagVar}{z}\n")
            os.rename('../data/shipdata-current.tmp','../data/shipdata-current.csv')
            Path('../data/shipdata-current.flag').touch()
            """
            # save to mysql database
            # now invoke mysql to import the data


            sql = f"""
        INSERT INTO trackingdata_flex (
        	recdate,
    	gpslat,gpslng,depthm,tempc,gpsfixquality,gpsnsats,gpshdop,gpsalt,
    	gpsttmg,gpsmtmg,gpssogn,gpssogk,gpsmagvar{x})
            VALUES (
                '{GPSyear}-{GPSmonth:02d}-{GPSday:02d} {GPStime}',
    	{GPSlat},{GPSlng},{GPSdepth},{GPStempc},{GPSFixQuality},{GPSnSats},{GPSHDOP},{GPSAlt},
    	{GPSTTMG},{GPSMTMG},{GPSSOGN},{GPSSOGK},{GPSMagVar}{z});"""

            save_to_database(sql)

        if nmeaCode == '$GPGGA': # $GPGGA - Global Positioning System Fix Data

            GPSFixQuality = to_int(line[6])  # Fix Quality 0=invalid, 1=GPS, 2=DGPS
            GPSnSats      = to_int(line[7])  # Number of satellites in view
            GPSHDOP       = to_float(line[8])  # Horizontal Dilution of Position
            GPSAlt        = to_float(line[9])  # altitude of antenna above sea level

        if nmeaCode == '$GPVTG': # $GPVTG

            GPSTTMG       = to_float(line[1])  # True track made good
            GPSMTMG       = to_float(line[3])  # Magnetic track made good
            GPSSOGN       = to_float(line[5])  # Speed Over Ground in Nautical mph
            GPSSOGK       = to_float(line[7])  # Speed Over Ground in kilometeres per hour

        if nmeaCode == '$GPRMC':  # $GPRMC - recommended minimum specific GPS/Transit data
            # Sample data record:
            # ['$GPRMC', '193042.60', 'A', '4301.071', 'N', '08754.220', 'W', '0.0', '92.8', '040705', '3.0', 'W']
            # most of this we already have from other sentences
            GPSMagVar    = to_float(line[10])  # Magnetic variation magnitude, degrees

            # adjust sign: west means negative
            if line[11] == 'W': 
                GPSMagVar = -GPSMagVar

            GPSlat = NMEAtoDecCoords (line[3],line[4])
            GPSlng = NMEAtoDecCoords (line[5],line[6])
            GPSSOGN       = to_float(line[7])  # Speed Over Ground in Nautical mph
            GPSTTMG       = to_float(line[8])  # True track made good

            UTC      = line[1] # \fword(\%l,1,{,})
            GPShour  = to_int(UTC[0:2])
            GPSmin   = to_int(UTC[2:4])
            GPSsec   = to_int(UTC[4:6])
            GPSmsec  = to_int(UTC[7:9]+'0')
            GPSday   = to_int(line[2]) # \fword(\%l,2,{,})
            GPSmonth = to_int(line[3]) # \fword(\%l,3,{,})
            GPSyear  = to_int(line[4]) # \fword(\%l,4,{,})

    # end while True
