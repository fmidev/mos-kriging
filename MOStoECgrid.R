#!/usr/bin/env Rscript
# grid MOS point stations values to EC background grid
#
# usage: script -m MOSstations.csv -a ECanalysis.grib -f ECforecast.grib variable1 variable2 ...

# marko.laine@fmi.fi

# set path to R libraries
#.libPaths("/lustre/apps/lapsrut/Projects/POSSE/R/Libs_R_oper")
#.libPaths(Sys.getenv("POSSE_R_LIBS"))

## load the packages needed
library('fastgrid')
library('MOSfieldutils')
library('geogrid')
library('Rgrib2')
library('methods') # needed for command line call at some environments

## parse command line arguments
library("optparse", quietly=TRUE, verbose=FALSE)
args <- MOS_parse_command_line()

MOSfile <- args$MOSfile # MOS stations file name
ECanal <- args$ECanal  # EC analysis grib file for lsm and z (optional)
ECfile <- args$ECfile # EC forecast file
outputfile <- args$outputfile # name for the output grib file
variables <- args$variables # variable names from command line
nvars <- length(variables)

failfile <- paste0('GRIDFAILED')
gridding_failed <- FALSE
# maybe not needed here
if (file.exists(failfile)) dum <- file.remove(failfile)

if (args$verbose) {
  cat(paste("MOS file:",MOSfile),"\n")
  cat(paste("EC forecasts file:",ECfile),"\n")
  cat(paste("EC analysis file:",ECanal),"\n")
  cat("Variables to analyse:",paste(variables),"\n")
  cat("OUT file:",outputfile,"\n")
  cat("Failure file:",failfile,"\n")
}

# if no analysis file, assume z and lsm are in fc file
if (is.null(ECanal)) {
  variables2 <- c(variables,'lsm','geopotential')
  gnames2 <- MOSget('varnames')[variables2,'gribname']
} else {
  variables2 <- variables
  gnames2 <- gnames
}

# grib names
gnames <- MOSget('varnames')[variables,'gribname']
if (any(is.na(gnames))) {
  stop('do not know the grib names of the variables')
}

# combine analysis and fc file and produce spatialgrid (obs the naming of arguments)
ECfc <- ECMWF_bg_gload(analysis = ECanal, file = ECfile,variables=gnames2,varnames=variables2)

# names(ECfc)

# grid the data to the (default) background grid
# loop over variable names
for (ivar in 1:nvars) {
  
  # gridding options
  if (variables[ivar] == "temperature") {
    MOSset('cov.pars',c(2.5^2, 1.0 , 0.0)) # sigmasq, clen, nugget 
  #  MOSset('altlen',150) # altitude correlation range (m)
    MOSset('altlen',100) # altitude correlation range (m) *************TEST HERE*****************
  }
  else if (variables[ivar] == "dewpoint") {
    MOSset('cov.pars',c(2.5^2, 1.0 , 0.0)) # sigmasq, clen, nugget 
    MOSset('altlen',150) # altitude correlation range (m)
  } else {
    MOSset('cov.pars',c(2.5^2, 1.0 , 0.0)) # sigmasq, clen, nugget 
    MOSset('altlen',150) # altitude correlation range (m)
  }
  
  if (ivar == 1) {
    out <- MOSgrid(stationsfile = MOSfile, bgfield = ECfc, variable = variables[ivar],
                   uselsm = FALSE, usereallsm = TRUE,
                   LapseRate = MOSget('LapseRate'))
  } else {
    out2 <- MOSgrid(stationsfile = MOSfile, bgfield = ECfc, variable = variables[ivar],
                    uselsm = FALSE, usereallsm = TRUE,
                    LapseRate = MOSget('LapseRate'))
    out@data[,variables[ivar]] <- out2@data[,variables[ivar]]
    # copy some attributes 
    a <- c('failed',paste0(variables[ivar],'_failed'), paste0(variables[ivar],'_nobs'))
    for (ia in 1:length(a)) 
      attr(out,a[ia]) <- attr(out2,a[ia]) 
  }
  fail <- attr(out,'failed')
  # copy more attributes
  attr(out@data[,variables[ivar]],'gribattr') <- attr(ECfc@data[,variables[ivar]],'gribattr')

  if (!is.null(fail)) {
    if (fail != 0) {
      gridding_failed <- TRUE
    }
  }

}

# add geopotential to the output
out$geopotential <- ECfc$geopotential
variables <- c(variables,'geopotential')
gnames <- c(gnames,'z')

# save to GRIB file
#if (grep("\\.grib$",outputfile)) {
if (length(grep("\\.grib$",outputfile))>0) {
  gsavefile <- paste0(outputfile)
} else {
  gsavefile <- paste0(outputfile,'.grib')
}
sptogrib(out,gsavefile,variables=variables,varnames=gnames,tokelvin=TRUE)

if (args$saverds) {
  # save output in R format
  rsavefile <- paste0(outputfile,'.rds')
  saveRDS(out,rsavefile)
}

if (args$plotit) {
# plot to file
  psavefile <- paste0(outputfile,'.png')
  MOSplotting::MOS_plot_field(out,layer = 1, zoom=MOS.options$finland.zoom,pngfile = psavefile)
}

# if there is any problems, write info to a file (NEEDS SOME WORK STILL)
# now writes *_nobs attributes of the output
if (gridding_failed) {
  warning(paste('Some failure in gridding, created ',failfile))
  l<-paste0(variables,'_nobs')
  writeLines(text = paste(l,lapply(l,function(x)attr(out,x))),con=failfile)
}
