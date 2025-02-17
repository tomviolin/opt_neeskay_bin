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
