# CHANGES:
##
## 2020-04-15
## Changes to the COVID19 package dictate the following changes:
##     1. The code now examines the most recent 'confirmed' count, to be sure that
##        it is not very different from the previous day.  (I reported
##        this as https://github.com/emanuele-guidotti/COVID19/issues/4)
##     2. The confirmed_new column has disappeared, so we now compute that.
##     3. We use covid19() instead of world().
##     4. The following changes to country names had to be made (meaning changes
##        in the Makefile and the index.html file).
##         * Burma -> Myanmar
##         * Cabo Verde -> Cape Verde
##         * Congo (Brazzaville) -> Congo
##         * Congo (Kinshasa) -> Congo, the Democratic Republic of the
##         * Czechia -> Czech Republic
##         * Eswatini -> removed, since I could not guess a new name
##         * North Macedonia -> Macedonia
##         * US -> United States
##         * West Bank and Gaza -> removed, since I could not guess a new name


library(COVID19)
library(oce)

recentNumberOfDays <- 10
## can specify region in the commandline
args <- commandArgs(trailingOnly=TRUE)
regions <- if (length(args)) args else "Denmark"
regions <- if (length(args)) args else "World"
regions <- if (length(args)) args else "United States"
regions <- if (length(args)) args else "Canada"
#regions <- if (length(args)) args else "Australia"

if (!exists("d")) { # cache to save server load during code development
    d <- covid19(end=Sys.Date()-1)
    d$time <- lubridate::with_tz(as.POSIXct(d$date), "UTC")
}

trimZeros <- function(x)
{
    x[x==0] <- NA
    x
}

## Construct world (inelegantly)
A <- split(d, d$date)
dateWorld <- names(lapply(A, function(x) x$date[[1]]))
tlim <- range(as.POSIXct(dateWorld, tz="UTC"))
confirmedWorld <- unlist(lapply(A, function(x) sum(x$confirmed)))
deathsWorld <- unlist(lapply(A, function(x) sum(x$deaths)))
now <- lubridate::with_tz(Sys.time(), "UTC")
mar <- c(2, 3, 1.5, 1.5)

for (region in regions) {
    message("handling ", region)
    if (region == "World") {
        sub <- tibble::tibble(date=dateWorld,
                              time=lubridate::with_tz(as.POSIXct(dateWorld), "UTC"),
                              confirmed=confirmedWorld,
                              confirmed_new=c(0, diff(confirmedWorld)),
                              deaths=deathsWorld,
                              pop=rep(7776617876, length(confirmedWorld)))
    } else {
        ##sub <- d[d$country == region, ]
        sub <- subset(d, d$country == region)
        sub$confirmed_new <- c(0, diff(sub$confirmed)) # until 2020-04-15, this was in dataset
    }
    sub$confirmed_new[sub$confirmed_new < 0] <- NA
    n <- length(sub$confirmed)
    if (n < 2) {
        cat("Under 2 data points for", region, "so it is not plotted\n")
        next
    }
    ## Check for unrealistic drops in most recent day, compared to SD over past week
    ## (excluding most recent day).  This became necessary on 2020-04-15, as
    ## reported at https://github.com/emanuele-guidotti/COVID19/issues/4
    subOrig <- sub
    SD <- sd(tail(head(sub$confirmed,-1), 7))
    if (abs(sub$confirmed[n] - sub$confirmed[n-1]) > 2 * SD) {
        message("dropping most recent point (",
               sub$confirmed[n], ") since it differs from previous by ",
                round(abs(sub$confirmed[n] - sub$confirmed[n-1])),
                ", more than 2* previous recent std-dev of ", round(SD))
        sub <- sub[seq(1, n-1), ]
    }
    lastTime <- tail(sub$time, 1)
    recent <- abs(as.numeric(now) - as.numeric(sub$time)) <= recentNumberOfDays * 86400
    if (!sum(recent))
        next

    if (!interactive()) png(paste0("covid19_", region, ".png"),
                            width=7, height=5, unit="in", res=120, pointsize=11)
    if (!any(sub$confirmed > 0)) {
        par(mfrow=c(1,1))
        plot(c(0, 1), c(0, 1), xlab="", ylab="", axes=FALSE, type="n")
        box()
        text(0.5, 0.5, paste0("No data are available for", region, ".\n(This is probably a temporary error; check back later.)"))
        next
    }
    par(mfrow=c(2,2))

    ## Cases, linear axis
    oce::oce.plot.ts(sub$date, sub$confirmed,
                     xlim=tlim,
                     type="p",
                     pch=20,
                     col=ifelse(recent, "black", "gray"),
                     cex=par("cex"),
                     xlab="Time",
                     ylab="Cumulative Case Count",
                     mar=mar,
                     drawTimeRange=FALSE)
    points(sub$time, sub$confirmed,
           pch=20,
           col=ifelse(recent, "black", "gray"),
           cex=par("cex"))
    points(sub$time, sub$deaths,
           pch=20,
           col=ifelse(recent, "red", "pink"),
           cex=par("cex"))
    legend("topleft", pt.cex=1, cex=0.8, pch=20,
           col=c("black", "red"),
           legend=c("Confirmed", "Deaths"),
           title=region)
    ##message(region)
    ##message(paste(head(sub$pop), collapse=" "))
    mtext(sprintf("Confirmed: %d (%5.3g%%); deaths: %d (%5.3g%%)",
                  tail(sub$confirmed, 1),
                  100*tail(sub$confirmed,1)/sub$pop[1],
                  tail(sub$deaths, 1),
                  100*tail(sub$deaths, 1)/sub$pop[1]),
                  side=3,
          cex=0.9*par("cex"))

    ## Cases, log axis
    ylim <- c(1, 2*max(sub$confirmed, na.rm=TRUE))
    positive <- sub$confirmed > 0
    oce::oce.plot.ts(sub$time[positive], sub$confirmed[positive], log="y", logStyle="decade",
                     xlim=tlim,
                     ylim=ylim,
                     type="p",
                     pch=20,
                     col=ifelse(recent, "black", "gray"),
                     cex=par("cex"),
                     xlab="Time",
                     ylab="Cumulative Case Count",
                     mar=mar,
                     drawTimeRange=FALSE)
    mtext(paste(format(tail(sub$time,1), "Last point at %Y %b %d")), adj=1, cex=0.9*par("cex"))
    points(sub$time[positive], sub$confirmed[positive],
           pch=20,
           col=ifelse(recent[positive], "black", "gray"),
           cex=par("cex"))
    x <- as.numeric(sub$time[recent])
    y <- log10(sub$confirmed[recent])
    ok <- is.finite(x) & is.finite(y)
    x <- x[ok]
    y <- y[ok]
    canFit <- length(x) > 3
    if (canFit) {
        m <- lm(y ~ x)
        abline(m)
        growthRate <- coef(m)[2] * 86400 # in days
        doubleTime <- log10(2) / growthRate
        if (doubleTime > 0)
            mtext(if (doubleTime < 100) sprintf(" Doubling time: %.1f days", doubleTime) else " Doubling time > 100 days",
                  side=3, line=-1, cex=0.9*par("cex"))
    }
    points(sub$time, sub$deaths,
           pch=20,
           col=ifelse(recent, "red", "pink"),
           cex=par("cex"))

    ## Daily change
    y <- sub$confirmed_new
    ylim <- c(0, max(y))
    oce::oce.plot.ts(sub$time, y,
                     xlim=tlim,
                     type="p",
                     pch=20,
                     col=ifelse(recent, "black", "gray"),
                     cex=par("cex"),
                     xlab="Time",
                     ylab="Daily Case Count",
                     mar=mar,
                     drawTimeRange=FALSE)
    ## spline with df proportional to data length (the 7 is arbitrary)
    points(sub$time, y,
           pch=20,
           col=ifelse(recent, "black", "gray"),
           cex=par("cex"))
    canSpline <- is.finite(y)
    splineModel <- smooth.spline(sub$time[canSpline], y[canSpline], df=length(y)/7)
    lines(splineModel, col="magenta")

    positive <- y > 0
    oce::oce.plot.ts(sub$date[positive], y[positive], log="y", logStyle="decade",
                     xlim=tlim,
                     type="p",
                     pch=20,
                     col=ifelse(recent[positive], "black", "gray"),
                     cex=par("cex"),
                     xlab="Time",
                     ylab="Daily Case Count",
                     mar=mar,
                     drawTimeRange=FALSE)
    lines(splineModel$x[positive], splineModel$y[positive], col="magenta")

    if (!interactive()) dev.off()
}
