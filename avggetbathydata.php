#!/usr/bin/php
<?
function DMStoDEC($deg,$min,$sec)
{

// Converts DMS ( Degrees / minutes / seconds ) 
// to decimal format longitude / latitude

    return $deg+((($min*60)+($sec))/3600);
}  


	$link = mysql_connect("localhost","root","glucos197");

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
	if($argv[7] != "") {
		$maxdate= date("Y-m-d H:i:s", strtotime($argv[7]));
		if (substr($maxdate,0,4) < 1971) {
			$maxdate="";
		}
	} else {
		$maxdate="";
	}
	echo "maxdate=$maxdate\n";

	$shipdatafile = "/opt/neeskay/data/shipdata-current.csv";
	$shipdataoverride = "/opt/neeskay/bin/shipdata-over.csv";
	if (file_exists($shipdataoverride)) {
		$shipdatafile = $shipdataoverride;
	}
	$shipdata = explode(",", file_get_contents($shipdatafile));
	if ($maxdate != "" && substr($maxdate,0,4) != "1969") {
		// fetch just the one record before or at the maxdate
		$result = mysql_query("select gpslat,gpslng,recdate,depthm from bathy where recdate <= '$maxdate' order by recdate desc limit 1");
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

	if ($latmin == 1) {
		$latmin = $shipdata[1] - 0.04;
		$latmax = $shipdata[1] + 0.04;

		$lngmin = $shipdata[2] - 0.06;
		$lngmax = $shipdata[2] + 0.06;
	}

	echo "bounding box: lat $latmin to $latmax, lng $lngmin to $lngmax\n";
	echo "max date = ".$maxdate."\n";
/*
	while (true) {
	
		if ($setsel == 'noaa') {
			$querywhere = "and recdate is null";
		} elseif ($setsel == 'neeskay') {
			$querywhere = "and recdate is not null";
		} elseif ($setsel == 'both') {
			$querywhere = "";
		}

		if ($skip > 0) {
			$querywhere .= " and (recid mod $skip) = 0";
		}
		// perform preliminary query to see how many points there are
		$prequery = <<<_ENDQ_
select  count(*)
from	bathy
where	(gpslat between $latmin and $latmax  )
and	(gpslng between $lngmin and $lngmax )
and recdate <= '$maxdate'
$querywhere
_ENDQ_;
		$result = mysql_query($prequery);
		if (mysql_errno() != 0) {
			die (mysql_error()."\n$prequery\n");
		}
		$points = mysql_fetch_array($result);
		mysql_free_result($result);
		echo "points=" . $points[0]."\n";

		if ($points[0] < 700000) {
			break;
		}

		if ($skip == "") {
			$skip = floor($points[0] / 710000);
		} else {
			$skip = floor($skip * 2);
		}
	}
	// write out group-by averaged bathy data
	$roundlat = 100/($latmax - $latmin);
	$roundlng = 100/($lngmax - $lngmin);
	$roundlat=$roundlng=$round;
	$query = <<<_ENDQ_
select round(gpslat*$roundlat)/$roundlat as lat, round(gpslng*$roundlng)/$roundlng as lng, avg(depthm) as depth, max(recdate) as maxdate
from	bathy
where	(gpslat between $latmin and $latmax  )
and	(gpslng between $lngmin and $lngmax )
and recdate <= '$maxdate'
$querywhere
group by lat, lng
_ENDQ_;
*/

	// all that stuff above replaced with this
	$query="select gpslat as lat, gpslng as lng, avg_depthm as depth, maxrecdate as maxdate "
		."from bathyavg where (gpslat between $latmin and $latmax) "
		."and (gpslng between $lngmin and $lngmax) ";
	echo "executing query...\n";
	$result = mysql_query($query);
	echo "done query.\n";
	@mkdir("../data");
	$fd = fopen("../data/bathyavg.tab","w");
	fwrite($fd, "lat\tlng\tdepth\tcolor\n");
	while (($row=mysql_fetch_array($result)) != NULL) {
		$color=(strtotime($row['maxdate']) > time()-86400 ?
			"#FF6666" : "#FFFFFF50");
		fwrite($fd, $row['lat']."\t".$row['lng']."\t".
			$row['depth']."\t\"$color\"\n");
	}
	fclose($fd);


	if ($setsel == 'neeskay' || $setsel == 'both') {
		// write out complete raw neeskay track data for graphing
		echo "writing track data...\n";
		$query = <<<_ENDQ_
	select round(gpslat,5) as lat, round(gpslng,5) as lng
	from	bathy
	where	(gpslat between $latmin and $latmax  )
	and	(gpslng between $lngmin and $lngmax )
	and	recdate is not null
and recdate <= '$maxdate'
$querywhere
	group by lat,lng
_ENDQ_;
		$result = mysql_query($query);
		$fd = fopen("../data/bathyneeskay.tab","w");
		fwrite($fd, "lat\tlng\n");
		while (($row=mysql_fetch_array($result)) != NULL) {
			fwrite($fd, $row['lat']."\t".$row['lng']."\t".$row['depth']."\n");
		}
		fclose($fd);
	}


	// make sure user positioning files are in place

//	if (!file_exists("../data/userMatrix.tab")) {
//		copy("../data_template/userMatrix.tab","../data/userMatrix.tab");
//		copy("../data_template/windowRect.tab","../data/windowRect.tab");
//		copy("../data_template/zoom.tab","../data/zoom.tab");
//	}
