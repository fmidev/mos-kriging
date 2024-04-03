FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt -y update && apt -y install \
	r-cran-devtools \
	r-cran-gstat \
	r-cran-ncdf4 \
	r-cran-optparse \
	r-cran-rgdal \
	r-cran-raster \
	r-cran-spatstat \
	g++ \
	libudunits2-dev \
	libssl-dev \
	gdal-bin \
	libgdal-dev \
	libproj-dev \
	libeccodes-dev \
	libnetcdf-dev \
	curl \
	bc \
	s3cmd \
	libeccodes-tools \
	&& apt -y clean

RUN R -e 'install.packages(c("sp","aws.s3","outliers","ncdf4","geogrid"),repos="http://ftp.eenet.ee/pub/cran/",build_vignettes=F, Nprocs=4)'
RUN R -e 'devtools::install_github(c("mjlaine/fastgrid","harphub/Rgrib2","fmidev/MOSfieldutils"),build_vignettes=F)'

ADD mandtg /usr/local/bin
ADD MOStoECgrid.R /tmp
ADD run-kriging.sh /tmp
ADD download-background.sh /tmp
ADD download-mos.sh /tmp
ADD start.sh /tmp
ADD copy-to-lake.sh /tmp
WORKDIR /tmp
