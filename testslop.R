#


minslope <- function(x,minslope=0.4) {

	i = 1:length(x)
	while (TRUE) {
		N=length(x)

		d=x[2:N]-x[1:(N-1)]
		print("--d--");
		print(d)
		print(minslope)
		l=(d>=minslope)
		print(l+0)
		if (sum(l) == N-1) {
			break
		}
		t=l[2:(N-1)]-l[1:(N-2)]
		print(t)
		b=(1:(N-2))[t==-1]
		e=(1:(N-2))[t==1]
		print("--raw b e--")
		print(b)
		print(e)
		if (length(e)==0 && length(b) == 0) {
			if (l[1]==TRUE) {
				break;
			}
		}

		if(length(e)>=length(b) && (length(b)==0 || b[1]>e[1])) {
			b=c(0,b)
		}
		if (length(b)>length(e)) {
			e=c(e,N-1)
		}
		print("--b e almost there--")
		print(b)
		print(e)

		b=b+2

		cull=(1:(N-2))[(e-b)<0]
		if (length(cull)>0) {
			b=b[-cull]
			e=e[-cull]
		}
		if(length(b)>0) {
			print("--b e about to be used--")
			print (b)
			print(e)
			span=seq(from=b-1, to=e+1, ZZ
			dels=round((e+b)/2)
			x=x[-dels]
			i=i[-dels]
		} else {
			break
		}
	}
	return(i)
}




x=sin(c(1:50)/3)+c(1:50)/3
plot(x[minslope(x,0.6)])

