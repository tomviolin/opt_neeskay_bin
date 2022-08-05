#!/usr/bin/php
<?php
chdir ("/dev/shm");
function msg($str) {
	echo sprintf("[%5d: %s]:%s\n", getmypid(), date("H:i:s"), $str);
}
$maxfile = "";
while (true) {
	//msg("getting socket...");
	if ($socket !== false) @fclose($socket);
	$socket = @stream_socket_server("tcp://0.0.0.0:8080", $errno, $errstr);
	if ($errno === 0 && $socket !== false) {
		//msg("got socket.");
		//msg("entering wait loop...");
		if ($conn = @stream_socket_accept($socket)) {
			msg("got a connection!");
			fclose($socket);
			$pid = pcntl_fork();
			msg("forked: $pid");
			if ($pid == 0) {
				//we're the child, enter output loop
				msg("writing...");
				mysql_connect("localhost","shipuser","arrrrr");
				mysql_select_db("neeskay");
				$result = mysql_query("select max(recid) from raw_nmea");
				if(mysql_errno() === 0) {
					list($maxrec) = mysql_fetch_array($result);
				} else {
					$maxrec = -1;
				}
				fwrite($conn,"Content-Type: text-plain\r\n\r\n"); // so web browsers can see it
				while (true) {
					$result = mysql_query("select recid, nmea from raw_nmea where recid > $maxrec order by recid");
					$dataflag = false;
					while ($row = mysql_fetch_array($result)) {
						if (fwrite($conn, $row['nmea']."\r\n") == 0) {
							msg('exiting...');
							fclose($conn);
							exit(0);
						}
						$maxrec = $row['recid'];
						$dataflag = true;
					}
					if ($dataflag === true) {
						usleep(1000);
					} else {
						usleep(100000);
					}
				}
				msg("finished.");
				fclose ($conn);
				exit(0);
			}
			msg("looping back...");
		} else {
		}
	} else {
		echo "socket error: $errstr ($errno)\n";
		if ($socket !== 0) fclose($socket);
	}
}
?>
