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

# load the interpolation and graph plotting libraries

loadlibs <- function() {
library(fields)
library(gplots)
library(akima)
library(Cairo)
library(sp)
library(colorspace)
library("lattice")
# load the RGL library
#require(rgl)
}
# now load the libraries
loadlibs()

# define functions

savepos <- function() {
	write.table(par3d("userMatrix"), file="../data/userMatrix.tab", row.names=FALSE, col.names=FALSE)
	write.table(par3d("zoom"),   file="../data/zoom.tab", row.names=FALSE, col.names=FALSE)
	write.table(par3d("windowRect"), file="../data/windowRect.tab", row.names=FALSE, col.names=FALSE)
}


readpos <- function(filename="userMatrix.tab") {
	par3d(
		userMatrix =  matrix(scan(file="../data/userMatrix.tab"),c(4,4), byrow=TRUE),
		zoom = scan(file="../data/zoom.tab"),
		windowRect = scan(file="../data/windowRect.tab")
	)
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

#doplot <- function(avgtabfilename="../data/bathyavg.tab", tracktabfilename="../data/bathyneeskay.tab") {

avgtabfilename="../data/r_proc/bathyavg.tab"
tracktabfilename="../data/r_proc/bathyneeskay.tab"
shipcurrentfilename="../data/bathypos.tab"
poifilename="poi.tab"


	# read the bathymetric data
	badata = read.table(avgtabfilename, header=TRUE, 
		colClasses=c("numeric","numeric","numeric","character"))

	# make depths negative
	badata$depth = -badata$depth

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

	# calculate aspect ratio of longitude. (latitude is constant)
	#first let's pretend that latitude and longitude are the same distance

	latrange = max(li$y, na.rm=TRUE) - min(li$y, na.rm=TRUE)
	lngrange = max(li$x, na.rm=TRUE) - min(li$x, na.rm=TRUE)
	print(paste("latrange=",latrange))
	print(paste("lngrange=",lngrange))
	if (latrange > 0) {
		lngaspect = lngrange / latrange
	} else {
		lngaspect = 1
	}

	# now introduce the scaling factor

	latscaling = cos(mean(li$y, na.rm=TRUE)/2/pi)
	print(paste("mean li$y",mean(li$y, na.rm=TRUE)))
	print(paste("latscaling=",latscaling))
	lngaspect = lngaspect * latscaling
	print(paste("lngaspect=",lngaspect))
	# need to have 10 surface waves on longest side
	# compute range of x coordinates [longitude] passed to function
	#lngrangewav = lngrange * latscaling
	# compute range of y coordinates [latitude] passed to function
	#latrangewav = latrange
	# determine length of longest side
	#rangewav = max(c(lngrangewav,latrangewav))
	# compute multiplier such that range * factor = 2*pi*10
	#rangewavmult = 2*3.14*10 / rangewav
	# compute desired wave height factor
	#waveheight = max(abs(li$z), na.rm=TRUE) / 100 
	# create waterline surface
	# copy the surface interpolation structure
	#sfc = li
	# create array of random numbers (actually Poisson distributed)
	#sfcz = rpois(xlen*ylen, 10) / 30
	# plug the numbers back into the surface matrix
	# sfc$z = array(sfcz, c(xlen,ylen))
	#outfun <- function(x,y) { (sin(x*(rangewavmult)*latscaling) + sin(y*rangewavmult))*waveheight/2 }
	#sfc$z <- outer(sfc$x,sfc$y,"outfun")


     for (graphtype in c(2)) {  #  1=PDF, 2=png   }
	print (paste("Creating graphic #" , graphtype))
	# --- lattice trellis device ---
	if (graphtype == 0) trellis.device(device="png", file="bathytmp.png", width=1024, height=768) ### X11( type="nbcairo")
	# --- PDF ---
	if (graphtype == 1) pdf(file="bathy.pdf", onefile=TRUE, paper="special", width=8, height=11)

	# --- PNG ---
	if (graphtype == 2) Cairo(file="bathytmp.png", width=1024, height=768, dpi=72, type="png", units="px")


	#*** Plotting Section ***
	#print(li)

	#smli <- image.smooth(li$z, theta=0.1)
	#li$z <- smli$z

	minz=min(c(li$z), na.rm=TRUE)
	maxz=max(c(li$z), na.rm=TRUE)
	zcoloradj = (maxz-minz)/100
	if (zcoloradj == 0) {
		zcoloradj = 1
	}

	depthcolors = rich.colors(250, palette="temperature")
	depthcolors = depthcolors[150:20]
	depthcolors=hex(hex2RGB(depthcolors))
	depthcolors[1] = "#339933";
	colarray = array(depthcolors[((-c(li$z)+maxz) / zcoloradj)+1], c(xlen-1,ylen-1))
	sfcarray = array("blue", c(xlen,ylen))
	do3dplot <- function() {
	# Initialize the 3D graphic device
	clear3d("all")
	readpos()
	bg3d(color="#EEEEFF")
	light3d(theta=15)
	light3d(ambient="black", specular="black")
	material3d(color="blue", colors="blue", col="blue")
	sfccolor=array(c("white"), c(xlen,ylen))
	persp3d(sfc, col=sfccolor, colors=sfccolor, alpha=0.50, aspect=c(lngaspect,1,0.4), xlab="longitude", ylab="latitude", zlab="depth(m)", zlim=c(0,min(li$z,na.rm=TRUE)), smooth=TRUE, texture="../images/watertiled2.png")
	material3d(color="black", colors="black", col="black")
	persp3d(li, colors=colarray, col=colarray, add=TRUE, smooth=TRUE)
	readpos()
	}
	# do3dplot()


	#inline <- readln("\nPress Enter for tracks: ")
	#savepos()
	inline = ""
	
	#if (inline != "n") {
		# read tracks table
		trk <- read.table(tracktabfilename, header=TRUE)

		# read current ship position
		ship <- read.csv(shipcurrentfilename, header=FALSE)

		# read additional points of interest
		if (file.exists(poifilename)) {
			POIs <- read.csv(poifilename, header=FALSE)
		} else {
			POIs <- list()
		}

	#	do3dlines <- function() {
	#	points3d(x=trk$lng, y=trk$lat, z=trk$depth, add=TRUE, cex=3)
	#	points3d(x=trk$lng, y=trk$lat, z=0, add=TRUE, cex=3)
	#	}
		#do3dlines()

			# old
		# points3d(x=badata$lng, y=badata$lat, z=badata$depth, add=TRUE, size=2)
		# points3d(x=badata$lng, y=badata$lat, z=0, add=TRUE, size=2)
	#}

	#inline <- readln("Press Enter for 2D contour plot: ")
	#savepos()

	if (TRUE) {
		lip <- li
		lip$z = -lip$z

		# 2d plot (this works)
		# maintitle = paste(dd2dms(ship$V2, NS=TRUE), dd2dms(ship$V3), " depth",ship$V4, "m")
		print ( paste("latscaling=", latscaling))
		maintitle = "Bathymetry w/Neeskay tracks"
		plot(lip, type="n", main = maintitle, xlab="", ylab="", asp=1/latscaling, xaxt="n", yaxt="n")
		image(lip, co=depthcolors, add=TRUE, asp=1/latscaling)

		# 3d plot (under construction)
		#colarray = array(depthcolors[((-c(li$z)+maxz) / zcoloradj)+1], c(xlen,ylen))
		#colarray = colarray[1:(xlen-1),1:(ylen-1)]

		#persp(li, border="#FFFFFF00", ltheta=-120, shade=0.75, col="green", scale=TRUE, phi=30, theta=135, expand=0.3)

		#drape.plot(li$x,li$y,li$z, border=NA, phi=60, shade=0.5)

		#print(wireframe(volcano, drape=TRUE, col.regions=depthcolors[1:100], 
		#	at=seq(min(volcano),max(volcano),(max(volcano)-min(volcano))/100),
		#	shade=TRUE, aspect=c(lngaspect,0.1),
		#	light.source=c(10,0,10)))
		axis(1, axTicks(1), labels=paste(dd2dms(axTicks(1)         ),"\n",'[',axTicks(1),']', sep=''))
		axis(2, axTicks(2), labels=paste(dd2dms(axTicks(2), NS=TRUE),"\n",'[',axTicks(2),']', sep=''))

		# previous tracks
		points(trk$lng, trk$lat, type="p", cex=0.9, pch=".", 
			col="#FFffff80")

		bold <- c("Arial","bold")
		plain <- c("Arial","plain")
		contour(lip, add=TRUE, labcex=0.6, font=bold, levels=seq(0,200,by=5),lwd=0.9)
		contour(lip, add=TRUE, labcex=0.6, font=plain, levels=seq(2.5,200,by=5),lwd=0.5,lty="41")
		contour(lip, add=TRUE, labcex=0.4, drawlabels=FALSE, levels=seq(1.25, 200, by=2.5),lwd=0.2, lty="31")
		#contour(lip, add=TRUE, labcex=0.2, levels=seq(0.625, 200, by=1.25), lwd=0.02)


		# additional POIs
		# points(POIs$V1, POIs$V2, type="p", cex=3, pch=".", col="#FF0000CC", bg="#CCCCFF33")
		# temporarily disabled 1-22-10
		points(POIs$V1, POIs$V2, type="p", cex=2, pch=21, col="#000000CC", bg="#CCCCFF33")
		points(POIs$V1, POIs$V2, type="p", cex=2, pch=3, col="#000000CC")



		#points(badata$lng, badata$lat, type="p", cex=0.2, pch=20, 
		#	col=badata$color)

		
		# ships pos 
		points(ship$V3, ship$V2, type="p", cex=4, pch=21, col="#330000CC", bg="#FFCCCC99")
		points(ship$V3, ship$V2, type="p", cex=4, pch=3, col="#000000FF")
	}

	if (graphtype == 99) {
		readln("Press ENTER to continue: ");
	} else {
		if (graphtype == 2) {
			# PNG file, write coordinate conversion factors
			cvt = list()
			cvt$ux1 = min(lip$x)
			cvt$ux2 = max(lip$x)
			cvt$uy1 = min(lip$y)
			cvt$uy2 = max(lip$y)
			cvt$dx1 = grconvertX(cvt$ux1,from="user", to="device")
			cvt$dx2 = grconvertX(cvt$ux2,from="user", to="device")
			cvt$dy1 = grconvertY(cvt$uy1,from="user", to="device")
			cvt$dy2 = grconvertY(cvt$uy2,from="user", to="device")
			write.table(cvt, file="pngxlate.tab", row.names=FALSE, col.names=FALSE, sep=",")
		}
	        dev.off()
		if(graphtype == 2 || graphtype == 0) {
			file.rename("bathytmp.png","bathy.png")
		}
	}
    } # end loop through devices

# extract bathymetric data from the database

# east reef plateau (very flat)
# system('../bin/getcoords.php 43.03 43.04 -87.36 -87.35 1000000 neeskay');

# harbor
# system('../bin/getcoords.php 43.020000 43.030000 -87.900000 -87.880000 3000 neeskay')

# harbor detail
#system('../bin/getcoords.php 43.020000 43.027000 -87.894000 -87.885000 3000 neeskay')

# harbor closeup
#system('../bin/getcoords.php 43.020000 43.025500 -87.894000 -87.885000 3000 neeskay')

# sheboygan reef
# system('../bin/getcoords.php 43.3 43.4 -87.25 -87.0 2000 neeskay')


# system('../bin/getcoords.php 43.325 43.355 -87.180 -87.0 5000 neeskay')


readln("\nPress Enter to end program: ")

doplots <- function() {
	loadlibs()
	do3dplot()
	do3dlines()
	do2dplot()
	do2dtracks()
}
