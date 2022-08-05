#
# Sample R Code for grconvertX and grconvertY
#
library(Cairo)
# make fake data
tDat <- cbind(rnorm(10), rnorm(10));

#
# Example #1 -- plot them to an X11 window
#
Cairo(file="bathytmp.png", width=1024, height=768, dpi=72, type="png", units="px")
plot(tDat);
print(paste(grconvertX(tDat[, 1], "user", "device"), grconvertY(tDat[, 2], "user", "device")));

# turn off the x11 device
dev.off()
