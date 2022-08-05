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
	ylen = 200
	MAPPING=TRUE
	SCREENWIDTH=960
	SCREENHEIGHT=640

	KMLWIDTH=SCREENWIDTH*2
	KMLHEIGHT=SCREENHEIGHT*2

	# load the interpolation and graph plotting libraries

qlib <- function(lib) {
	dummy = suppressPackageStartupMessages(library(lib, character.only=TRUE))
}
	writeLines("-- loading R libraries --")
	#library(fields)

	qlib("gplots")
	qlib("akima")
	qlib("Cairo")
	qlib("sp")
	qlib("colorspace")
	qlib("plotrix")
	qlib("shape")
	qlib("lattice")
	qlib("aws")
	qlib("RMySQL")
	qlib("rjson")

	is.invalid <- function(var) {
		return (is.null(var) || is.na(var))
	}

	is.empty <- function(var) {
		return (is.invalid(var) || var == "")
	}

	# read config file with settings

	source("2dbathym.cfg");

	bbox = read.csv(bboxfilename,header=FALSE, encoding="UTF-8")
	paramcol = ""
	depthmode = is.empty(bbox[1,7])
	if (!depthmode) {
		paramcol = bbox[1,7]
	}

	if ((! is.empty(bbox[1,15])) && bbox[1,15] == 1) {
		MAPPING=FALSE
	}

	sqlcon <- dbConnect(MySQL(), user="shipuser", password="arrrrr", dbname="neeskay", host="waterdata.glwi.uwm.edu")

	query = paste(readLines("rquery.sql"),collapse="\n")

	writeLines('--reading data from SQL database--')
	ct = suppressWarnings((dbGetQuery(sqlcon, query)))
	writeLines('--converting data to real scale--')
	if (paramcol == "depthm") {
		ct$lng = ct$lng / 1000000
		ct$lat = ct$lat / 1000000
		ct$depth = ct$depth / 10000
	}
	writeLines('--converting data types--')
	ct$depth = as.numeric(ct$depth)
	ct$recdate = as.POSIXct(ct$recdate, tz="UTC")
	# ct = read.csv(ctfilename)

	if (FALSE && paramcol == "depthm") {
		writeLines('--removing outliers--')
		# outlier cleaning
		# overall approach is to break up the ship tracks
		# into segments based on breaks in the timeline of the data.
		# then each contiguous segment of data
		# is then filtered and cleaned separately.
		DEBUG=FALSE

		# size of dataset
		N = length(ct$depth)

		# differences between adjacent points' times

		diftime = ct$recdate[2:N] - ct$recdate[1:(N-1)]

		# any gap exceeding 5 seconds will be conidered a break
		breakpos = (1:N)[diftime > 5]

		# break positions represent the positions before each break.
		# so to get the beginnings of each break, we take
		# the concatenation of 1 and all the break positions plus one.
		breakidx = c(1, breakpos+1)

		# the endings are simply the break positions
		# concatenated with N

		breakid2 = c(breakpos,N)


		#plot (x=ct$lng,y=ct$lat, pch=".", col="red")

		colors=c("red","orange", "violet", "blue","green")
		cp=1

		cleantrack = data.frame()

		for (i in 1:length(breakidx)) {
			# isolate the segment
			bt = ct[breakidx[i]:breakid2[i],]

			# repeat the outlier discovery until there are no more outliers
			oc=1
			while ((bN=length(bt$depth))>4) {
				#print(sprintf("--outlier %d:%d--",i,oc))

				# check for breaks in the depth

				#determine the slopes of the segments between each point
				#with respect to time. (the ship can't go fast enough for
				#distance to be that much of a factor)
				Ddepth = bt$depth[2:bN] - bt$depth[1:(bN-1)]
				Dtime  = as.numeric(bt$recdate[2:bN]-bt$recdate[1:(bN-1)])
				DdepthDtime = Ddepth / Dtime

				# now for the second differential difference (numerical second derivative)

				DDdepth = DdepthDtime[2:(bN-1)] - DdepthDtime[1:(bN-2)]
				Dtimetime = as.numeric(bt$recdate[3:bN] - bt$recdate[1:(bN-2)])/2

				ddiff = DDdepth / Dtimetime


				# now calculate some statistics on the second derivative
				mdd = mean(ddiff)
				sdd = sd(ddiff)
				add = abs(ddiff-mdd)
				bdd = add > max(sdd*2,20)

				#characterize outliers as being two times the standard
				# deviation away from the mean of the second derivatives
				breaks = c(1:bN)[add > max(sdd*2, 20)]

				if (length(breaks) > 0) {
					for (j in 1:length(breaks)) {
						m = mean(bt$depth)
						ji = which.max(c(
								abs(bt$depth[breaks[j]]-m),
								abs(bt$depth[breaks[j]+1]-m),
								abs(bt$depth[breaks[j]+2]-m)
						))
						breaks[j] = breaks[j] + ji-1
					}
				}
				if (DEBUG) {	
					# plot depth with breaks highlighted in red
					jpeg(file=sprintf("seg%05d-%02d-a.jpg",i,oc),width=640,height=480)
					plot(x=1:bN, y=bt$depth, pch=1, cex=0.1, main=length(breaks))
					if (length(breaks)>0) points(x=breaks, y=bt$depth[breaks],pch=1,cex=1,col="red")
					dummy=dev.off()
					# plot differences with breaks highlighted in red
					jpeg(file=sprintf("seg%05d-%02d-b.jpg",i,oc),width=640,height=480)
					plot(x=1:(bN-2), y=ddiff, pch=1, cex=0.1, main=length(breaks))
					if (length(breaks)>0) points(x=breaks, y=ddiff[breaks],pch=1,cex=1,col="red")
					dummy=dev.off()
				}

				if (length(breaks) > 0) {
					oc=oc+1
					# delete the outliers from the segment
					bt = bt[-breaks,]
				} else {
					# no outliers- exit
					break;
				}
			}
			cleantrack = rbind(cleantrack, bt)
		}

	} else {
		# this is for when we skip the outlier removal
		cleantrack = ct
	}

	writeLines('--binning the data--')
	designmatrix = as.matrix(c(cleantrack$lng,cleantrack$lat),nrow=length(cleantrack$lng),ncol=2)
	dim(designmatrix) = c(length(cleantrack$lng),2)

	bins = binning(x=designmatrix, y=cleantrack$depth, nbins=c(xlen,ylen))



	badata = list (
		lng = bins$x[,1],
		lat = bins$x[,2],
		depth = bins$means
	)

	writeLines('--calculating dimensions of output--')

	# make depths negative
	if (depthmode || bbox[1,7] == "depthm") {
		badata$depth = -badata$depth
	}


	# calculate aspect ratio of longitude. (latitude is constant)
	#first let's pretend that latitude and longitude are the same distance

	latrange = max(badata$lat, na.rm=TRUE) - min(badata$lat, na.rm=TRUE)
	lngrange = max(badata$lng, na.rm=TRUE) - min(badata$lng, na.rm=TRUE)
	if (latrange > 0) {
		lngaspect = lngrange / latrange
	} else {
		lngaspect = 1
	}

	# now introduce the scaling factor

	latscaling = cos(mean(badata$lat, na.rm=TRUE)/180/pi)/1.5
	lngaspect = lngaspect * latscaling


	# maintitle = paste(dd2dms(ship$V2, NS=TRUE), dd2dms(ship$V3), " depth",ship$V4, "m")
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
	writeLines('--initializing graphic output--')
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
	write.table(cvt, file=pngxlatefilename, row.names=FALSE, col.names=T, sep=",")
	pngx1 = grconvertX(u[1],"user","device")
	pngy1 = grconvertY(u[4],"user","device")
	pngx2 = grconvertX(u[2],"user","device")
	pngy2 = grconvertY(u[3],"user","device")
	# these are computed for use later in the KML file
	lxlng1 = grconvertX(0.5,"device","user")
	lxlng2 = grconvertX(SCREENWIDTH+0.5,"device","user")
	lxlat1 = grconvertY(0.5,"device","user")
	lxlat2 = grconvertY(SCREENHEIGHT+0.5,"device","user")
	if (MAPPING) {
		writeLines('--initiating retrieval of mapping tiles--')
		system(paste("rm -f ",bbxmapfilename,"; (wget -O ",bbxmaptmpfilename," 'http://neeskay.dyndns.org/neeskay/gettile.php?bbx1=",u[1],
			"&bbx2=",u[2],"&bby1=",u[3],"&bby2=",u[4],
			"'; mv ",bbxmaptmpfilename," ",bbxmapfilename,"; cp ",bbxmapfilename," bbxmap-bak.png) &",
			sep=""))
	}
	# --- TPS method ----
	#
	#cat("running thin-plate spline...\n")

	# run the thin-plate-spline interpolation - creates 3D spline curves
	#krig <- Tps(x=array(c(badata$lng, badata$lat),c(length(badata$lng),2)), Y=badata$depth, m=2)

	# create a surface map into an xlen by ylen matrix (see defs above at top of file)
	#li <- predict.surface(krig, nx=xlen, ny=ylen, xy=c(1,2), order.variables="xy")

	# --- linear interpolation method ---
	writeLines("--performing surface interpolation--")
	dummy=(system.time((li <- interp((badata$lng), (badata$lat), badata$depth, 
		linear = TRUE, extrap = FALSE,
		xo = seq(min(badata$lng),max(badata$lng),len=xlen),
		yo = seq(min(badata$lat),max(badata$lat),len=ylen)))))
	# li$z <- image.smooth(li$z, theta=.1)$z


	#smli <- image.smooth(li$z, theta=0.1)
	#li$z <- smli$z
	writeLines("--calculating color scale--")
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
	#trk <- read.csv(tracktabfilename, header=TRUE)
	writeLines('--reading additional points--')
	# read current ship position
	ship <- read.csv(shipcurrentfilename, header=FALSE)

	# read additional points of interest
	if (file.exists(poifilename)) {
		POIs <- read.csv(poifilename, header=FALSE)
	} else {
		POIs <- list()
	}
	writeLines('--preparing track points--')
	plottrack <- cleantrack

	lip <- li
	if (depthmode || bbox[1,7]=="depthm") {
		lip$z = -lip$z
	}


	if (is.empty(bbox[1,13]) || is.empty(bbox[1,14])) {
		imagezlim = c(min(lip$z,na.rm=T),max(lip$z,na.rm=T))
	} else {
		imagezlim = c(bbox[1,13],bbox[1,14])
	}
	writeLines('--creating color plot image--')
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
		pcex = as.numeric(pointparam[1])
		if (length(pointparam) > 1) {
			ppch = pointparam[2]
		} else {
			ppch = "."
		}
	}
	
	writeLines('--calculating and plotting track points--')
	# points to plot (maximum 65000, evenly distributed subset if necessary)
	if (length(plottrack$lng) > 65000) {
		subset = seq(from=1,to=length(plottrack$lng),length.out=65000)
		plottrack = plottrack[subset,]
	}
	points(plottrack$lng, plottrack$lat, type="p", pch=ppch, cex=pcex,
		col="#FFffffFF")
	# clickable points to pass to client (maximum 20000, even distrib subset if nec)
	if (length(plottrack$lng) > 20000) {
		subset = seq(from=1, to=length(plottrack$lng), length.out=20000)
		idpoints = plottrack[subset,]
		points(idpoints$lng, idpoints$lat, type="p", pch=".", cex=1,
			col="#FFeeFFFF")
	} else {
		idpoints = plottrack
	}
	if (length(idpoints$lng)>0) {
		idpoints$recdate = format(as.POSIXct(idpoints$recdate, tz="UTC"),tz="America/Chicago", usetz=TRUE)
	}


	bold <- c("Arial","bold")
	plain <- c("Arial","plain")


	## calculate contour lines ##
	#
	# This, as it turns out, is very computationally expensive.
	#  I will attempt to match the algorithm used by the color scale
	writeLines('--plotting contour lines--')
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
	points(POIs$V1, POIs$V2, type="p", cex=2, pch=21, col="#000000CC", bg="#CCCCFF33")
	points(POIs$V1, POIs$V2, type="p", cex=2, pch=3, col="#000000CC")

	# ships pos 
	points(ship$V3, ship$V2, type="p", cex=4, pch=21, col="#330000CC", bg="#FFCCCC99")
	points(ship$V3, ship$V2, type="p", cex=4, pch=3, col="#000000FF")

	writeLines('--creating color legend--')
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
	gendate = date();
	systime = Sys.time();
	mtext(paste("Generated ",date(),sep=""), side=1, padj=4.5, cex=0.9)
	dummy=dev.off()
	writeLines('--finished with web version of graph--')
	# convert for web first
	system(paste("convert ",bathytmpfilename," -quality 90 -background white -flatten bathyx.jpg"))

	dir.create (path="./cooking", showWarnings=FALSE)
	cvt$time = paste(date(),runif(1))
	writeLines(toJSON(cvt),"cooking/bathyimageinfo.json")

	writeLines(c('{"points":[',
		sprintf('{"lat":%f,"lng":%f,"depth":%f,"recdate":"%s"},',idpoints$lat,idpoints$lng,idpoints$depth, idpoints$recdate),
		'{}]}'),"cooking/bathydatapoints.json")

	system(paste("mv -f bathyx.jpg bathy.jpg; mv -f cooking/* .; mv -f ",bathytmpfilename," bathy.png"))

	# now lets make one with just the color graphic interpolation on it
	writeLines('--now creating transparent PNG for Google Earth--')
	dir.create(path="/tmp/bathykmz/files",showWarnings=FALSE, recursive=TRUE)
	Cairo(file="/tmp/bathykmz/files/bathyco.png", width=KMLWIDTH, height=KMLHEIGHT, dpi=144, type="png", units="px")
	par(mar=c(4.02,4,4.5,5.7))
	plot(x=c(min(badata$lng),max(badata$lng)), y=c(min(badata$lat),max(badata$lat)), type="n", main = "", xlab="", ylab="", xlim=c(min(badata$lng),max(badata$lng)), ylim=c(min(badata$lat),max(badata$lat)), asp=1/latscaling, xaxt="n", yaxt="n", frame.plot=FALSE)
	image(lip, co=depthcolors, add=TRUE, asp=1/latscaling,zlim=imagezlim)
	contour(lip, add=TRUE, labcex=0.9, levels=contours, lwd=0.8,vfont=c("sans serif","bold"),  col="black")
	if (!is.null(fcontours)) contour(lip, add=TRUE, drawlabels=FALSE, levels=fcontours, lwd=0.4, lty="31")
	# the 0.5 reflects the center of the pixels (a bit fussy but it does make a difference)
	lblng1 = grconvertX(0.5,"device","user")
	lblng2 = grconvertX(KMLWIDTH+0.5,"device","user")
	lblat1 = grconvertY(0.5,"device","user")
	lblat2 = grconvertY(KMLHEIGHT+0.5,"device","user")

	# colorlegend(posx=c(0.92,0.94),zlim=zl, digit=3, col=legcolors , zval=legcontours)
	trackcoords = paste(plottrack$lng,",",plottrack$lat,",0\n",sep="",collapse="")
	writeLines('--creating KML file--')
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
		<north>',lxlat2,'</north>
		<south>',lxlat1,'</south>
		<east>',lxlng2,'</east>
		<west>',lxlng1,'</west>
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



	dummy=dev.off()
	write('--done preparing KML content--')
	if (MAPPING) {
		# see how the background process compiling the map tiles is doing
		# if bbxmaptmpfilename exists, it's at least working on it
		# if bbxmapfilename exists, its done
		# if neither exist, it isn't going to run.
		writeLines('--checking map tiles--')
		if (file.exists(bbxmaptmpfilename) || file.exists(bbxmapfilename)) {
			# let's give it .5 seconds to finish (sleep is .5 seconds!)
			timout = 1
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
			writeLines('--mapping tiles are downloaded--')
			writeLines('--overlaying map tiles--')
			Sys.sleep(0.5) # give it a half second
			# composite the images with ImageMagick composite command
			cmd = (paste("composite -define png:format=png24 -geometry ",
				pngx2-pngx1,"x",pngy2-pngy1,"\\!+",pngx1,"+",pngy1,
				" -define png:format=png24 ",bbxmapfilename," ",bathytmpfilename," -define png:format=png24 bathytmp2.png; ",
				"mv bathytmp2.png bathy.png; rm -f ",bathytmpfilename," ",bbxmapfilename," ",bbxmaptmpfilename,sep=""));
			system(cmd);
			# update web info
			writeLines('--updating image info--')
			system(paste("convert bathy.png -quality 90 -background white -flatten cooking/bathy.jpg"))
			cvt$time = paste(date(),runif(1))
			writeLines(toJSON(cvt),"cooking/bathyimageinfo.json")
			system("mv -f cooking/* .");
		} else {
			writeLines('--mapping tiles not found, not overlaying--')
			file.rename(bathytmpfilename,"bathy.png")
		}



	} # end if mapping

	# compile kmz file with everything
	writeLines('--compiling KMZ--')
	system("cp bathy.png /tmp/bathykmz/files; cd /tmp/bathykmz; zip /tmp/bathy.kmz.zip doc.kml files/*; mv /tmp/bathy.kmz.zip /var/www/neeskay/bathy.kmz")
writeLines("--map generation completed --\n")
