#!/usr/bin/php
<?
// $skip=64;
define('BBOX_FILE', "/var/www/neeskay/bbox.csv");

function DMStoDEC($deg,$min,$sec)
{

// Converts DMS ( Degrees / minutes / seconds ) 
// to decimal format longitude / latitude

    return $deg+((($min*60)+($sec))/3600);
}  

	$bbox = explode(",",trim(file_get_contents(BBOX_FILE)));
	$paramcol = $bbox[6];

	$link = mysql_connect("waterdata.glwi.uwm.edu","shipuser","arrrrr");
	mysql_select_db("neeskay");

	// command line
	if ($argc < 7) {
		die ("usage: ".$argv[0]." latmin latmax lngmin lngmax round setsel\n");
	}
	$latmin = $argv[1]; // minimum latitude
	$latmax = $argv[2]; // maximum latitude
	$lngmin = $argv[3]; // minimum longitude
	$lngmax = $argv[4]; // maximum longitude
	$round  = $argv[5]; // round to nearest 1/n degree lat & long
	$setsel = $argv[6]; // set selection: 'noaa' 'neeskay' 'both'
	if(isset($argv[7]) && $argv[7] != "") {
		$maxdate= date("Y-m-d H:i:s", strtotime($argv[7]));
		if (substr($maxdate,0,4) < 1979) {
			$maxdate="";
		}
	} else {
		$maxdate="2015-01-01";
	}
	//echo "maxdate=$maxdate\n";

	$shipdatafile     = "/opt/neeskay/data/shipdata-current.csv";
	$shipdataoverride = "/opt/neeskay/bin/shipdata-over.csv";
	if (file_exists($shipdataoverride)) {
		$shipdatafile = $shipdataoverride;
	}
	$shipdata = explode(",", file_get_contents($shipdatafile));
	if ($maxdate != "" && substr($maxdate,0,4) != "1969" && $setsel != "noaa") {
		// fetch just the one record before or at the maxdate
		$result = mysql_query("select gpslat,gpslng,recdate,depthm from bathy where ".(strlen($maxdate) < 10  ? '1' : "recdate <= '$maxdate'")." order by recdate desc limit 1");
		if (mysql_errno() != 0) {
			echo mysql_error()."\n";
			exit(1);
		}
		if (mysql_num_rows($result) == 1) {
			$curpos = mysql_fetch_array($result);
			// make the ship's positon be where that record was
			$shipdata[0] = $curpos['recdate'];
			$shipdata[1] = $curpos['gpslat'];
			$shipdata[2] = $curpos['gpslng'];
		}	
	}
	if ($maxdate == "") {
		$maxdate = $shipdata[0];
	}
	file_put_contents("../data/bathypos.tab",$shipdata[0].",".$shipdata[1].",".$shipdata[2].",".$shipdata[3]."\n");

	if ($latmin == 1) { // 1 means use bounding box file or internal defaults
		if (file_exists(BBOX_FILE)) {
			if ($bbox[0]=="Rel") {
				// first item "Rel" means relative to ship
				$latmin = $shipdata[1] - $bbox[1];
				$latmax = $shipdata[1] + $bbox[2];
				$lngmin = $shipdata[2] - $bbox[3];
				$lngmax = $shipdata[2] + $bbox[4];
			} else {
				// otherwise they are absolute coordinates
				$latmin = $bbox[1];
				$latmax = $bbox[2];
				$lngmin = $bbox[3];
				$lngmax = $bbox[4];
			}
		} else {
			$latmin = $shipdata[1] - 0.005;
			$latmax = $shipdata[1] + 0.005;

			$lngmin = $shipdata[2] - 0.01;
			$lngmax = $shipdata[2] + 0.01;
		}
	}

	//echo "bounding box: lat $latmin to $latmax, lng $lngmin to $lngmax\n";
	//echo "max date = ".$maxdate."\n";

	// == arbitrary parameter option ===

	//echo "PARAM: $paramcol\n";


	if ($paramcol == "") {
		// echo "no parameter, defaulting to depth...\n";
		// iterative process to whittle down the number of points
		// to be used to calculate 3D surface
		// this is necessary because bathymetry data set is huge
		while (true) {

			// adjust points	
			if ($setsel == 'noaa') {
				$querywhere = "and recdate is null";
			} elseif ($setsel == 'neeskay') {
				$querywhere = "and ((depthm <=0.5 and depthm < 500) or (recdate is not null and recdate <= '$maxdate'))";
			} elseif ($setsel == 'both') {
				$querywhere = "and (recdate is null or recdate <= '$maxdate')";
			}

			if ($skip > 0) {
				$querywhere .= " and ((recdate is null) or ((recid mod $skip) = 0))";
			}

			// perform preliminary query to see how many points there are
			$prequery = "
				select  count(*)
				from	bathy
				where	(gpslat between $latmin and $latmax )
				and	(gpslng between $lngmin and $lngmax )
				$querywhere
			";
			$result = mysql_query($prequery);
			if (mysql_errno() != 0) {
				die (mysql_error()."\n$prequery\n");
			}
			$points = mysql_fetch_array($result);
			mysql_free_result($result);
			//echo "points=" . $points[0]."\n";

			if ($points[0] < 90000) {
				break;
			}

			if ($skip == "") {
				$newskip = floor($points[0] / 80000);
			} else {
				$newskip = floor($skip * 2);
			}
			if ($newskip == $skip) {
				$skip ++;
			} else {
				$skip = $newskip;
			}
		}



		// write out group-by averaged bathy data
		$roundlat = 100/($latmax - $latmin);
		$roundlng = 100/($lngmax - $lngmin);
		$roundlat=$roundlng=$round;
		if ($setsel != 'noaa') {
			$query = "
				select	round(gpslat*$roundlat)/$roundlat as lat,
					round(gpslng*$roundlng)/$roundlng as lng,
					avg(depthm) as depth, max(recdate) as maxdate
				from	bathy
				where	(gpslat between $latmin and $latmax  )
				and	(gpslng between $lngmin and $lngmax )
				$querywhere
				group by lat, lng
			";
		} else {
			$query= "
				select	gpslat as lat,
					gpslng as lng,
					depthm as depth, recdate as maxdate
				from bathy
				where	(gpslat between $latmin and $latmax  )
				and	(gpslng between $lngmin and $lngmax )
				and	recdate is null
			";
		}
		echo "executing query...\n";
		//echo $query."\n";
		$result = mysql_query($query);
		//echo "done query.\n";
		@mkdir("../data");
		$fd = fopen("../data/bathyavg.tab","w");
		fwrite($fd, "lat,lng,depth,color\n");
		while (($row=mysql_fetch_array($result)) != NULL) {
			$color=(strtotime($row['maxdate']) > time()-86400 ?
				"#FF6666" : "#FFFFFF50");
			if ($row['depth'] <0) $row['depth']=0;
			fwrite($fd, $row['lat'].",".$row['lng'].",".
				$row['depth'].",\"$color\"\n");
		}
		fclose($fd);

		if (TRUE || $setsel == 'neeskay' || $setsel == 'both') {
			// write out complete raw neeskay track data for graphing
			echo "writing track data...\n";
			$query = "
				select round(gpslat,5) as lat, round(gpslng,5) as lng
				from	bathy
				where	(gpslat between $latmin and $latmax  )
				and	(gpslng between $lngmin and $lngmax )
				and	(depthm > 0)
				$querywhere
				group by lat,lng
			";
			$result = mysql_query($query);
			$fd = fopen("../data/bathyneeskay.tab","w");
			fwrite($fd, "lat,lng,depth\n");
			while (($row=mysql_fetch_array($result)) != NULL) {
				//if ($row['depthm'] > 0) {
					fwrite($fd, $row['lat'].",".$row['lng'].",".$row['depth']."\n");
				//}
			}
			fclose($fd);
		}


	} else {
		//echo "processing for param $paramcol\n";

		$start = stripslashes($bbox[7]);
		$end= stripslashes($bbox[8]);
		if ($start == "") $start="'2007-01-01'";
		if ($end == "") $end="'2015-01-01'";

		if ($paramcol == "depthm") {
			// just write query to file for R to process

			file_put_contents("rquery.sql",
				"select lat, lng, depth, recdate
				from	bathyfast
				where	lat between $latmin*1000000 and $latmax*1000000
				and	lng between $lngmin*1000000 and $lngmax*1000000
				and	recdate between $start and $end
				order by recdate\n");

			/*
			file_put_contents("rquery.sql",
				"select gpslat as lat, gpslng as lnglng, depthm as depth
				from	bathy
				where	gpslat between $latmin and $latmax
				and	gpslng between $lngmin and $lngmax
				and	recdate between $start and $end 
				order by recdate");
			*/
		} else {

			$lag = $bbox[10]+0;

			$res = mysql_query ("drop table if exists bathytrack");

			$query = "
				create table bathytrack 
				(recdate datetime, gpslat decimal(10,5), gpslng decimal(10,5), paramc varchar(10),
				primary key (recdate))
				select 
					recdate,
					gpslat,
					gpslng,
					($paramcol) as paramc,
					ysi_layout_id
				from	trackingdata_flex
				where	(gpslat between $latmin and $latmax)
				and	(gpslng between $lngmin and $lngmax)
				and	recdate between $start and date_add($end, interval $lag second) ";

			echo "% QUERY: $query\n";	
			$resultt = mysql_query($query);
			if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
			echo "% N:".mysql_num_rows($resultt).": ".mysql_error()."\n";

			/* -- bathytrack now non-temporary --
			$query="
			create temporary table bathytrackb
				(recdate datetime, gpslat float, gpslng float, paramcol float,
				primary key (recdate))
				engine=memory select * from bathytrack;";

			echo "QUERY: $query\n";	
			$resultt = mysql_query($query);
			if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
			echo "N:".mysql_num_rows($resultt)."\n";
			*/

			/* Binning is now done in R.  So the "complete track" query
				below has been modified to execute this join.
			$query = "
				create temporary table bathylag
				select a.gpslat, a.gpslng, b.paramc, a.recdate
				from bathytrack a, bathytrackb b
				where b.recdate = date_add(a.recdate, interval $lag second)
				order by recdate";
			
			echo "QUERY: $query\n";	
			$resultt = mysql_query($query);
			if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
			echo "N:".mysql_num_rows($resultt)."\n";
			*/
			// binning is now done in R.
			// so this query is no longer necessary.
			/*
			$query = "
				select 
					round(gpslat,4) as lat,
					round(gpslng,4) as lng,
					avg(paramc) as paramcol,
					max(recdate) as maxrecdate,
					stddev(paramc) as sd
				from	bathylag
				where	(paramc) is not null and
					(paramc) <> ''
				and	(gpslat between $latmin and $latmax)
				and	(gpslng between $lngmin and $lngmax)
				and	recdate between $start and $end group by lat,lng;"; //   -- > date_add(now(), interval -1 day);
			echo "QUERY: $query\n";	
			$result = mysql_query($query);
			if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
			echo "N:".mysql_num_rows($result)."\n";
			$fddata = fopen("../data/bathyavg.tab","w");
			fwrite($fddata, "lat,lng,depth,color\n");
			$fdtrack = fopen("../data/bathyneeskay.tab","w");
			fwrite($fdtrack, "lat,lng,depth\n");
			while ($row = mysql_fetch_array($result)) {
				// write out data and track simultaneously
				if ($row['sd']<abs($row['paramcol']/2)) {
					fwrite($fddata, $row['lat'].",".$row['lng'].",".$row['paramcol'].",x\n");
					fwrite($fdtrack, $row['lat'].",".$row['lng'].",".$row['paramcol']."\n");
				}
			}
			fclose ($fdtrack);
			fclose ($fddata);
			*/

			// write complete track data

			$query = "create or replace view bathyview as
				select 
					a.gpslat as lat,
					a.gpslng as lng,
					b.paramc as depth,
					a.recdate
				from	bathytrack a, bathytrack b
				where 	b.paramc is not null and
					b.paramc <> '' and
					b.paramc < 500 and
					b.recdate = date_add(a.recdate, interval $lag second)
				and	a.recdate between $start and date_add($end, interval $lag second)
				order by a.recdate;";
			//echo "QUERY: $query\n";	
			$result = mysql_query($query);
			if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
			echo "% N:".mysql_num_rows($result)."\n";
			/* == no longer necessary ==
			echo "writing complete track file...\n";
			$fdtrack = fopen("../data/bathycompletetrack.tab","w");
			fwrite($fdtrack, "lat,lng,depth\n");
			while ($row = mysql_fetch_array($result)) {
				fwrite($fdtrack, $row['lat'].",".$row['lng'].",".$row['depth'].",".$row['maxrecdate']."\n");
			}
			fclose ($fdtrack);
			echo "done.";
			*/

			file_put_contents("rquery.sql","select * from bathyview\n");
		}

		# TODO: This stuff belongs in the web interface

		# write out table of parameters for beginning of data range

		# load up array of YSI fields
		$ysifields = array();
		$result = mysql_query("select * from ysi_fields order by ysi_field_id");
		while ($row = mysql_fetch_array($result)) {
			if (trim($row['ysi_field_desc']) != "") {
				$ysifields[$row['ysi_field_id']] = trim($row['ysi_field_desc']);
			}
		}

		//print_r($ysifields);

		$ysifieldsfile = "../data/bathysifields.csv";

		@unlink($ysifieldsfile."-tmp");
		$query = "
			select	ysi_layout_id
			from	trackingdata_flex
			where	recdate >= $start
			order by recdate
			limit 1";
		//echo "QUERY: $query\n";	
		$result = mysql_query($query);
		if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
		echo "% N:".mysql_num_rows($result)."\n";
		if (mysql_num_rows($result) == 1) {
			$r = mysql_fetch_array($result);
			$ysilayoutid = $r['ysi_layout_id'];
			if ($ysilayoutid > 0) {
				$query="
					select * from ysi_layout 
					where ysi_layout_id=$ysilayoutid";
				//echo "% QUERY: $query\n";	
				$result = mysql_query($query);
				if (mysql_errno() !== 0) { die(mysql_error()."\n"); }
				if (mysql_num_rows($result) == 1) {
					$row=mysql_fetch_array($result);
					//print_r($row);
					$csv = "";
					foreach ($row as $rkey => $rval) {
						if ($rval+0 > 0) {
							if (preg_match('/^ysi_([0-9][0-9])_fld$/',$rkey)==1) {
								$csv .= substr($rkey,0,6).',"'.trim($ysifields[$rval])."\"\n";
							}
						}
					}
					file_put_contents($ysifieldsfile."-tmp",$csv);
				}
			}
		}
		if (file_exists($ysifieldsfile."-tmp")) {
			@rename($ysifieldsfile."-tmp", $ysifieldsfile);
			@unlink($ysifieldsfile."-tmp");
		} else {
			@unlink($ysifieldstable);
		}
	}



