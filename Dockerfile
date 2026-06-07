FROM apache/airflow:2.8.0

USER root

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        default-jdk \
        r-base \
        r-base-dev \
        libcurl4-openssl-dev \
        libssl-dev \
        libxml2-dev \
        libfontconfig1-dev \
        libharfbuzz-dev \
        libfribidi-dev \
        libpng-dev \
        libjpeg-dev \
        libtiff-dev \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/default-java

RUN Rscript -e "install.packages(c('ggplot2', 'survival', 'dplyr'), repos='https://cran.rstudio.com/', quiet=TRUE)"

USER airflow

# Python packages
RUN pip install --no-cache-dir \
    pyspark==3.4.0 \
    delta-spark==2.4.0