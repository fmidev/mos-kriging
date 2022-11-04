FROM rockylinux/rockylinux:8 AS builder

RUN rpm -ivh https://download.fmi.fi/smartmet-open/rhel/8/x86_64/smartmet-open-release-latest-8.noarch.rpm

RUN dnf -y install dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf -y install epel-release && \
    dnf config-manager --setopt="epel.exclude=eccodes*" --save && \
    dnf -y install --setopt=install_weak_deps=False R-core \
                   R-devel \
                   gcc-c++ \
                   zlib-devel \
                   libssh2-devel \
                   openssl-devel \
                   libcurl-devel \
                   libxml2-devel \
                   proj-devel \
                   eccodes eccodes-devel \
                   geos-devel \
                   gdal-devel \
                   netcdf-devel \
                   udunits2-devel \
                   sqlite-devel \
                   cdo \
                   harfbuzz-devel \
                   fribidi-devel \
                   freetype-devel \
                   libpng-devel \
                   libtiff-devel \
                   libjpeg-turbo-devel \
    && dnf clean all && rm -rf /var/cache/yum

ENV LC_ALL=C
ENV MAKE="make -j 2"
RUN R -e 'install.packages(c("devtools","optparse","sp","rgeos","rgdal","raster","aws.s3","outliers","ncdf4","gstat","spatstat","geogrid"),repos="http://ftp.eenet.ee/pub/cran/",build_vignettes=F)'
RUN R -e 'devtools::install_github(c("mjlaine/fastgrid","harphub/Rgrib2","fmidev/MOSfieldutils"),build_vignettes=F)'

FROM rockylinux/rockylinux:8

RUN rpm -ivh https://download.fmi.fi/smartmet-open/rhel/8/x86_64/smartmet-open-release-21.3.26-2.el8.fmi.noarch.rpm && \
    dnf -y install dnf-plugins-core && \
    dnf config-manager --set-enabled powertools && \
    dnf -y install epel-release && dnf -y install s3cmd R-core netcdf eccodes cdo proj geos gdal && dnf clean all && rm -rf /var/cache/yum

COPY --from=builder /usr/lib64/R/library /usr/lib64/R/library

ADD mandtg /usr/local/bin
ADD MOStoECgrid.R /tmp
ADD run-kriging.sh /tmp
ADD download-background.sh /tmp
ADD download-mos.sh /tmp
ADD start.sh /tmp
ADD copy-to-lake.sh /tmp
WORKDIR /tmp
