#!/usr/bin/php
<?

	class CircularBuffer {
		protected $cb;     // circular buffer itself
		protected $cbi;    // current index
		protected $cbsize; // max size
		function CircularBuffer($c_cbsize) {
			$this->cb = array();
			for ($i = 0; $i < $c_cbsize; ++$i) $this->cb[$i] = NULL;
			$this->cbi = 0;
			$this->cbsize = $c_cbsize;
		}
		function addValue($val) {
			// echo ">>> adding ".$val."\n";
			$this->cb[$this->cbi++] = $val;
			$this->cbi %= $this->cbsize;
		}
		function avgValue() {
			// echo ">>> cb = ";
			$total = 0;
			$count = 0;
			for ($i=0; $i<$this->cbsize; $i++) {
				$c = $this->cb[$i];
				if ($c !== NULL) {
					$total += $this->cb[$i];
					$count ++;
				}
			}
			if ($count > 0) {
				return ($total / $count);
			} else {
				return NULL;
			}
		}
	}

	$link = mysql_connect("localhost","root","glucos197");

	mysql_select_db("neeskay");



	// find out what the highest date in the 'bathy' table is.

	$result = mysql_query("select max(recdate) from bathy");
	if (mysql_num_rows($result) != 1) {
		die(mysql_error());
	}

	$maxbathy = mysql_fetch_array($result);
	mysql_free_result($result);
	echo "highest date in the bathy table is ".$maxbathy[0]."\n";
	if ($maxbathy[0] == "") {
		$maxbathy[0] = "2007-01-01";
	}

	// start from 1 hour before the highest date in bathy
	$start = date("Y-m-d H:i:s",strtotime($maxbathy[0]));
	echo "Cleaning from ".$maxbathy[0]." onwards.\n";
	$query = "select recdate, gpslat, gpslng, depthm from trackingdata_flex where recdate > '".$maxbathy[0]."' and recdate < '2020-01-01' order by recdate";

	$result = mysql_query($query);
	if (mysql_errno() > 0) {
		die(mysql_error()."\n$query\n");
	}
	// echo ">>> rows=". mysql_num_rows($result)."\n";
	// establish circular buffer
	$dcb = new CircularBuffer(8);

	// now loop thru data
	while (($row = mysql_fetch_array($result)) != NULL) {

		$depth = $row['depthm'];
		$avg = $dcb->avgValue();
		// echo ">>> ".$row['recdate'].','.$row['gpslat'].','.$row['gpslng'].','.$depth."\n";
		if (($depth <= 2) ||  //throw out depths less than 2
		   ($depth < 10 && $depth == floor($depth) && abs($depth - $avg) > 0.5)) { // throw out integer depths less than 10 
			$dcb->addValue(NULL);
			echo ">>> threw out ".$row['recdate'].','.$row['gpslat'].','.$row['gpslng'].','.$depth."\n";
			continue;
		}
		// echo ">>> avg=$avg\n";
		if ($avg != NULL) {
			if (abs($depth - $avg) < 4) {
				// less than 1 meter different than moving average
				$dcb->addValue($depth); // add to circular buffer
				// echo "."; // echo $row['recdate'].','.$row['gpslat'].','.$row['gpslng'].','.$depth."\n";

				$query2 = ("insert ignore into bathy (recdate,gpslat,gpslng,depthm) "
					."values ('{$row['recdate']}','{$row['gpslat']}','{$row['gpslng']}','$depth')");
				$result2 = mysql_query($query2);
				if (mysql_errno() > 0) {
					die(mysql_error()."\n$query2\n");
				}
echo ".";
			} else {
				echo ">>> threw out ".$row['recdate'].','.$row['gpslat'].','.$row['gpslng'].','.$depth."\n";
				$dcb->addValue(NULL);
			}
		} else {
			$dcb->addvalue($depth);
		}
	}



/*


	$latmin = 43.023967;
	$latmax = 43.028190;

	$lngmin = -87.893852;
	$lngmax = -87.884341;

	$query = <<<_ENDQ_
select gpslat, gpslng, depthm from trackingdata_flex 
where	(gpslat between 43.023967 and 43.028190  )
and	(gpslng between -87.893852 and -87.884341 )
group by lat, lng
_ENDQ_;

	

	$query = <<<_ENDQ_
select round(gpslat*5000)/5000 as lat, round(gpslng*5000)/5000 as lng, avg(depthm) as depth from trackingdata_flex 
where	(gpslat between 43.023967 and 43.028190  )
and	(gpslng between -87.893852 and -87.884341 )
group by lat, lng
_ENDQ_;

*/

?>
