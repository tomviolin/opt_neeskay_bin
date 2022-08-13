#!/usr/bin/R < 


#
# R program to produce bathymetric plots from sounding data
#
#  Author: Tom Hansen <tomh@uwm.edu>
#
#  Expects a file called "bathyavg.tab" to exist in the ../data directory.
#  The file is expected to be a tab-separated file with three columns:
#       lat, lng, depth
#  where:
#       lat         is the latitude in decimal degrees
#       lng         is the longitude in decimal degrees
#       depth       is the depth of the sounding in meters
#

	# define resolution of 3D surface interpolation
	xlen = 300
	ylen = 300

	SCREENWIDTH=1024
	SCREENHEIGHT=768

	KMLWIDTH=SCREENWIDTH
	KMLHEIGHT=SCREENHEIGHT

	# load the interpolation and graph plotting libraries

	library(fields)
	library(gplots)
	library(akima)
	library(Cairo)
	library(sp)
	library(colorspace)
	library(plotrix)
	library(shape)
	library("lattice")

	is.invalid <- function(var) {
		return (is.null(var) || is.na(var))
	}

	is.empty <- function(var) {
		return (is.invalid(var) || var == "")
	}

	readlnxx <- function(prompttext="Press ENTER to continue: ") {
		conout <- file('/dev/tty','w')
		write (conout, prompttext)
		close (conout)
		conin <- file('/dev/tty','r')
		x <- readLines(conin,1)
		close(conin)
		return (x)
	}

	readln <- function(prompttext) {
		return (readline(prompttext))
	}

	# read config file with settings

	source("2dbathym.cfg");

	# read the bathymetric data
	badata = read.csv(avgtabfilename, header=TRUE, sep=",",
		colClasses=c("numeric","numeric","numeric","character"))

	sdtrim <- function(depthlist) {
		for (i in c(1:10)) {	
			rowisbad = is.na(depthlist$depth) | (abs(depthlist$depth - mean(depthlist$depth)) > sd(depthlist$depth)*10)
			rr = c(1:(length(depthlist$depth)))
			rr =rr[rowisbad]
			if (length(rr)>0) {
				depthlist = depthlist[-rr,]
			}
		}
		return (depthlist)
	}

	badata = sdtrim(badata)

	bbox = read.csv(bboxfilename,header=FALSE, encoding="UTF-8")
	depthmode = is.empty(bbox[1,7])
	if (!depthmode) {
		paramcol = bbox[1,7]
	}

	# make depths negative
	if (depthmode || bbox[1,7] == "depthm") {
		badata$depth = -badata$depth
	}


	# calculate aspect ratio of longitude. (latitude is constant)
	#first let's pretend that latitude and longitude are the same distance

	latrange = max(badata$lat, na.rm=TRUE) - min(badata$lat, na.rm=TRUE)
	lngrange = max(badata$lng, na.rm=TRUE) - min(badata$lng, na.rm=TRUE)
	print(paste("latrange=",latrange))
	print(paste("lngrange=",lngrange))
	if (latrange > 0) {
		lngaspect = lngrange / latrange
	} else {
		lngaspect = 1
	}

	# now introduce the scaling factor

	latscaling = cos(mean(badata$lat, na.rm=TRUE)/2/pi)
	print(paste("mean li$y",mean(badata$lat, na.rm=TRUE)))
	print(paste("latscaling=",latscaling))
	lngaspect = lngaspect * latscaling
	print(paste("lngaspect=",lngaspect))

	print (paste("Creating graphic "))

	# maintitle = paste(dd2dms(ship$V2, NS=TRUE), dd2dms(ship$V3), " depth",ship$V4, "m")
	print ( paste("latscaling=", latscaling))
	maintitle = "Bathymetry w/GPS tracks"
	if (!depthmode) {
		if (paramcol=="depthm") {
			maintitle = "Bathymetry w/ GPS Tracks"
		} else {
			ysiflds = read.csv(ysifieldsfilename, header=FALSE)
			ysif = ysiflds$V2[as.integer(substr(ysiflds$V1,5,6))]
			ysifdesc = ysif[as.integer(substr(bbox[1,7],5,6))]
			maintitle = paste(ysifdesc,"w/ GPS Tracks")
		}
	}
	if (!is.empty(bbox[1,12])) {
		maintitle = paste(bbox[1,12],maintitle,sep=": ")
	}
	Cairo(file=bathytmpfilename, width=SCREENWIDTH, height=SCREENHEIGHT, dpi=72, type="png", units="px")
	cold=par("mar")
	par(mar=c(4.02,4,4.5,5.7))
	CairoFonts(
             regular="DejaVu Sans:style=Book",
             bold="DejaVu Sans:style=Bold",
             italic="DejaVu Sans:style=Oblique",
             bolditalic="DejaVu Sans:style=Bold Oblique",
             symbol="Symbol"
	)
	
	plot(x=c(min(badata$lng),max(badata$lng)), y=c(min(badata$lat),max(badata$lat)), type="n", main = maintitle, xlab="", ylab="", xlim=c(min(badata$lng),max(badata$lng)), ylim=c(min(badata$lat),max(badata$lat)), asp=1/latscaling, xaxt="n", yaxt="n")
	mtext(paste("Generated ",date(),sep=""), side=1, padj=4.5, cex=0.9)
	# record user coordinates
	u=par("usr");
	polygon(c(u[1],u[2],u[2],u[1]),c(u[3],u[3],u[4],u[4]),col="#99EEFF", border=NA)

	points(rep(seq(u[1],u[2],l=50),50), rep(seq(u[3],u[4],l=50), each=50), pch="~", col="#66DDFF")
	points(rep(seq(u[1],u[2],l=50),50)+(u[2]-u[1])/100, rep(seq(u[3],u[4],l=50), each=50)+(u[4]-u[3])/100, pch="~", col="#66DDFF")
	# compute physical device extent of user coordinates
	cvt = list()
	cvt$ux1 = u[1]
	cvt$ux2 = u[2]
	cvt$uy1 = u[3]
	cvt$uy2 = u[4]
	cvt$dx1 = grconvertX(cvt$ux1,from="user", to="device")
	cvt$dx2 = grconvertX(cvt$ux2,from="user", to="device")
	cvt$dy1 = grconvertY(cvt$uy1,from="user", to="device")
	cvt$dy2 = grconvertY(cvt$uy2,from="user", to="device")
	write.table(cvt, file=pngxlatefilename, row.names=FALSE, col.names=FALSE, sep=",")
	pngx1 = grconvertX(u[1],"user","device")
	pngy1 = grconvertY(u[4],"user","device")
	pngx2 = grconvertX(u[2],"user","device")
	pngy2 = grconvertY(u[3],"user","device")
	print (paste(pngx1,pngx2,pngy1,pngy2))

	system(paste("rm -f ",bbxmapfilename,"; (wget -O ",bbxmaptmpfilename," 'http://localhost/neeskay/gettile.php?bbx1=",u[1],
		"&bbx2=",u[2],"&bby1=",u[3],"&bby2=",u[4],
		"'; mv ",bbxmaptmpfilename," ",bbxmapfilename,"; cp ",bbxmapfilename," bbxmap-bak.png) &",
		sep=""))
	# --- TPS method ----
	#
	#cat("running thin-plate spline...\n")

	# run the thin-plate-spline interpolation - creates 3D spline curves
	#krig <- Tps(x=array(c(badata$lng, badata$lat),c(length(badata$lng),2)), Y=badata$depth, m=2)

	# create a surface map into an xlen by ylen matrix (see defs above at top of file)
	#li <- predict.surface(krig, nx=xlen, ny=ylen, xy=c(1,2), order.variables="xy")

	# --- linear interpolation method ---
	li <- interp(badata$lng, badata$lat, badata$depth, 
		linear = TRUE, extrap = FALSE,
		xo = seq(min(badata$lng),max(badata$lng),len=xlen),
		yo = seq(min(badata$lat),max(badata$lat),len=ylen))
	#li$z <- image.smooth(li$z, theta=0.5)


	#smli <- image.smooth(li$z, theta=0.1)
	#li$z <- smli$z

	minz=min(c(li$z), na.rm=TRUE)
	maxz=max(c(li$z), na.rm=TRUE)
	zcoloradj = (maxz-minz)/100
	if (zcoloradj == 0) {
		zcoloradj = 1
	}

	depthcolors = rich.colors(250, palette="temperature")
	if (depthmode || bbox[1,7] == "depthm") {
		depthcolors = depthcolors[150:20]
	} else {
		depthcolors = depthcolors[50:200]
	}
	depthcolors=hex(hex2RGB(substr(depthcolors,1,7)))

	colarray = array(depthcolors[((-c(li$z)+maxz) / zcoloradj)+1], c(xlen-1,ylen-1))

	# read tracks table
	trk <- read.csv(tracktabfilename, header=TRUE)

	# read current ship position
	ship <- read.csv(shipcurrentfilename, header=FALSE)

	# read additional points of interest
	if (file.exists(poifilename)) {
		POIs <- read.csv(poifilename, header=FALSE)
	} else {
		POIs <- list()
	}

	completetrack <- read.csv(ctfilename, header=TRUE)

	completetrack = sdtrim(completetrack)

	lip <- li
	if (depthmode || bbox[1,7]=="depthm") {
		lip$z = -lip$z
	}


	if (is.empty(bbox[1,13]) || is.empty(bbox[1,14])) {
		imagezlim = c(min(lip$z,na.rm=T),max(lip$z,na.rm=T))
	} else {
		imagezlim = c(bbox[1,13],bbox[1,14])
	}
	print (imagezlim)
	image(lip, co=depthcolors, add=TRUE, asp=1/latscaling, zlim=imagezlim)

	# axis(1, axTicks(1), labels=paste(dd2dms(axTicks(1)         ),"\n",'[',axTicks(1),']', sep=''))
	# axis(2, axTicks(2), labels=paste(dd2dms(axTicks(2), NS=TRUE),"\n",'[',axTicks(2),']', sep=''))
	axis(1, axTicks(1), labels=paste(axTicks(1),' W', sep=''))
	axis(2, axTicks(2), labels=paste(axTicks(2),' N', sep=''))

	# previous tracks
	minzp = imagezlim[1]  # min(lip$z,na.rm=TRUE)
	maxzp = imagezlim[2]  # max(lip$z,na.rm=TRUE)
	if (is.null(bbox[1,10]) || is.na(bbox[1,10]) || bbox[1,10] == "") {
		pcex = 0.3
		ppch = "."
	} else {
		pointparam = strsplit(as.character(bbox[1,10]),";")[[1]]
		pcex = pointparam[1]
		if (length(pointparam) > 1) {
			ppch = pointparam[2]
		} else {
			ppch = "."
		}
	}
	
	#points(trk$lng, trk$lat, type="p", pch=19, cex=pcex,
	#	col=depthcolors[1+(trk$depth-minzp)/(maxzp-minzp)*length(depthcolors)])

	#if (depthmode || bbox[1,7] == "depthm") {
	#	points(trk$lng, trk$lat, type="p", pch=".", cex=0.5,
	#		col="#FFffffFF")
	#} else {
	#	points(trk$lng, trk$lat, type="p", pch=ppch, cex=pcex,
	#		col="#FFffffFF")
	#}

	points(completetrack$lng, completetrack$lat, type="p", pch=ppch, cex=pcex,
		col="#FFffffFF")

	bold <- c("Arial","bold")
	plain <- c("Arial","plain")


	## calculate contour lines ##
	#
	# This, as it turns out, is very computationally expensive.
	#  I will attempt to match the algorithm used by the color scale

	# establish range of values

	# determine roughly what a reasonable range is
	contours = pretty(imagezlim, 15) #, u5.bias=0)
	while (contours[1] < minzp) contours=contours[-1]
	while (contours[length(contours)] > maxzp) contours=contours[-length(contours)]
	if (length(contours) > 1) {
		diff = contours[2] - contours[1]
		fcontours = c(contours - diff/2, max(contours)+diff/2)
		while (fcontours[1] < minzp) fcontours=fcontours[-1]
		while (fcontours[length(fcontours)] > maxzp) fcontours=fcontours[-length(fcontours)]
	} else {
		fcontours = NULL
	}

	if (FALSE) {

	ifc = 1
	ic = 1
	while (TRUE) {
		while (as.numeric(as.character(fcontours[ifc])) < as.numeric(as.character(contours[ic]))) {
			ifc = ifc + 1
			if (ifc > length(fcontours)) break;
		}
		if (ifc > length(fcontours)) break;
		while (as.numeric(as.character(fcontours[ifc])) == as.numeric(as.character(contours[ic]))) {
			fcontours=fcontours[-ifc]
			ic = ic + 1
			if ((ifc > length(fcontours)) || (ic > length(contours))) break;
		}
		if ((ifc > length(fcontours)) || (ic > length(contours))) break;
	}
	}
	#

	#contour(lip, add=TRUE, labcex=0.6, font=bold, levels=seq(0,1200,by=5),lwd=0.9)
	#contour(lip, add=TRUE, labcex=0.6, font=plain, levels=seq(2.5,1200,by=5),lwd=0.5,lty="41")
	#contour(lip, add=TRUE, labcex=0.4, drawlabels=FALSE, levels=seq(1.25, 1200, by=2.5),lwd=0.2, lty="31")
	#contour(lip, add=TRUE, labcex=0.2, levels=seq(0.625, 1200, by=1.25), lwd=0.02)
	contour(lip, add=TRUE, labcex=0.9, levels=contours, lwd=0.8)
	if (!is.null(fcontours)) contour(lip, add=TRUE, drawlabels=FALSE, levels=fcontours, lwd=0.4, lty="31")

	# additional POIs
	# points(POIs$V1, POIs$V2, type="p", cex=3, pch=".", col="#FF0000CC", bg="#CCCCFF33")
	# temporarily disabled 1-22-10
	points(POIs$V1, POIs$V2, type="p", cex=2, pch=21, col="#000000CC", bg="#CCCCFF33")
	points(POIs$V1, POIs$V2, type="p", cex=2, pch=3, col="#000000CC")

	#complete track
	if (!depthmode) {
	#	points(completetrack$lng, completetrack$lat, pch=".", cex=0.2, col="white")
	}


	#points(badata$lng, badata$lat, type="p", cex=0.2, pch=20, 
	#	col=badata$color)

	# ships pos 
	points(ship$V3, ship$V2, type="p", cex=4, pch=21, col="#330000CC", bg="#FFCCCC99")
	points(ship$V3, ship$V2, type="p", cex=4, pch=3, col="#000000FF")
	if (depthmode || bbox[1,7] == "depthm") {
		zl = c(maxzp,minzp)
		legcontours = rev(contours)
		legcolors = rev(depthcolors)
	} else {
		zl = c(minzp,maxzp)
		legcolors = depthcolors
		legcontours = contours
	}
	colorlegend(posx=c(0.92,0.94),zlim=zl, digit=3, col=legcolors , zval=legcontours)

	# close out our file
	dev.off()
	# now lets make one with just the color graphic interpolation on it
	dir.create(path="/tmp/bathykmz/files",showWarnings=FALSE, recursive=TRUE)
	Cairo(file="/tmp/bathykmz/files/bathyco.png", width=KMLWIDTH, height=KMLHEIGHT, dpi=72, type="png", units="px")
	par(mar=c(4.02,4,4.5,5.7))
	plot(x=c(min(badata$lng),max(badata$lng)), y=c(min(badata$lat),max(badata$lat)), type="n", main = "", xlab="", ylab="", xlim=c(min(badata$lng),max(badata$lng)), ylim=c(min(badata$lat),max(badata$lat)), asp=1/latscaling, xaxt="n", yaxt="n")
	image(lip, co=depthcolors, add=TRUE, asp=1/latscaling,zlim=imagezlim)
	contour(lip, add=TRUE, labcex=0.4, levels=contours, lwd=0.4)
	# the 0.5 reflects the center of the pixels (a bit fussy but it does make a difference)
	lblng1 = grconvertX(0.5,"device","user")
	lblng2 = grconvertX(KMLWIDTH+0.5,"device","user")
	lblat1 = grconvertY(0.5,"device","user")
	lblat2 = grconvertY(KMLHEIGHT+0.5,"device","user")

	colorlegend(posx=c(0.92,0.94),zlim=zl, digit=3, col=legcolors , zval=legcontours)
	trackcoords = paste(completetrack$lng,",",completetrack$lat,"\n",sep="",collapse="")
	kml = paste('<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2" xmlns:kml="http://www.opengis.net/kml/2.2" xmlns:atom="http://www.w3.org/2005/Atom">
<Folder>
<Style id="TrackPoint">
	<IconStyle>
		<scale>1.2</scale>
	</IconStyle>
	<LineStyle>
		<color>ff7feeff</color>
		<width>1</width>
	</LineStyle>
</Style>
<name>',maintitle,'</name>
<open>1</open>
<Placemark>
<name>Ship GPS Track</name>
<description>Path of R/V Neeskay from 2011-10-24 01:47:54 to 2011-10-25 01:47:54</description>
<styleUrl>#TrackPoint</styleUrl>
<LineString>
	<tessellate>1</tessellate>
	<coordinates>
',trackcoords,'
	</coordinates>
</LineString>
</Placemark>
<GroundOverlay>
	<name>Full Map</name>
	<visibility>0</visibility>
	<Icon>
		<href>files/bathy.png</href>
		<viewBoundScale>0.75</viewBoundScale>
	</Icon>
	<LatLonBox>
		<north>',lblat2,'</north>
		<south>',lblat1,'</south>
		<east>',lblng2,'</east>
		<west>',lblng1,'</west>
	</LatLonBox>
</GroundOverlay>
<GroundOverlay>
	<name>Interpolation, Box, and Colorscale only</name>
	<Icon>
		<href>files/bathyco.png</href>
		<viewBoundScale>0.75</viewBoundScale>
	</Icon>
	<LatLonBox>
		<north>',lblat2,'</north>
		<south>',lblat1,'</south>
		<east>',lblng2,'</east>
		<west>',lblng1,'</west>
	</LatLonBox>
</GroundOverlay>
</Folder>
</kml>', sep='')

	write(x=kml,file="/tmp/bathykmz/doc.kml",sep="")



	dev.off()
	# see how the background process compiling the map tiles is doing
	# if bbxmaptmpfilename exists, it's at least working on it
	# if bbxmapfilename exists, its done
	# if neither exist, it isn't going to run.
	if (file.exists(bbxmaptmpfilename) || file.exists(bbxmapfilename)) {
		# let's give it 30 seconds to finish (sleep is .5 seconds!)
		timout = 60
		while( ! file.exists(bbxmapfilename)) {
			Sys.sleep(0.5);
			timout = timout - 1
			if (timout <= 0) {
				break;
			}
		}
	}
	# let's see if we ended up with anything
	if (file.exists(bbxmapfilename)) {
		# composite the images with ImageMagick composite command
		cmd = (paste("composite -define png:format=png24 -geometry ",
			pngx2-pngx1,"x",pngy2-pngy1,"\\!+",pngx1,"+",pngy1,
			" -define png:format=png24 ",bbxmapfilename," ",bathytmpfilename," -define png:format=png24 bathytmp2.png; ",
			"mv bathytmp2.png bathy.png; rm -f ",bathytmpfilename," ",bbxmapfilename," ",bbxmaptmpfilename,sep=""));
		print(cmd)
		system(cmd);
	} else {
		file.rename(bathytmpfilename,"bathy.png")
	}


	# compile kmz file with everything
	system("cp bathy.png /tmp/bathykmz/files; cd /tmp/bathykmz; zip /tmp/bathy.kmz.zip doc.kml files/*; mv /tmp/bathy.kmz.zip /var/www/neeskay/bathy.kmz")

print("--30--\n");

