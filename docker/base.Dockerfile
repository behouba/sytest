ARG DEBIAN_VERSION=buster

FROM debian:${DEBIAN_VERSION}

ENV DEBIAN_FRONTEND noninteractive

# Install base dependencies that Python or Go would require
RUN apt-get -qq update && apt-get -qq install -y \
    build-essential \
    dos2unix \
    eatmydata \
    git \
    haproxy \
    jq \
    libffi-dev \
    libjpeg-dev \
    libpq-dev \
    libssl-dev \
    libxslt1-dev \
    libz-dev \
    locales \
    perl \
    postgresql \
    rsync \
    sqlite3 \
    wget \
 && rm -rf /var/lib/apt/lists/*

# Set up the locales, as the default Debian image only has C, and PostgreSQL needs the correct locales to make a UTF-8 database
RUN sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    dpkg-reconfigure --frontend=noninteractive locales && \
    update-locale LANG=en_US.UTF-8

# Set the locales in the environment
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8

# Copy in the sytest dependencies and install them
# The dockerfile context, when run by the buildscript, will actually be the
# repo root, not the docker folder
ADD install-deps.pl ./install-deps.pl
ADD cpanfile ./cpanfile
RUN dos2unix ./cpanfile ./install-deps.pl
RUN perl ./install-deps.pl -T
RUN rm cpanfile install-deps.pl

# this is a dependency of the TAP-JUnit converter
RUN cpan XML::Generator

# /logs is where we should expect logs to end up
RUN mkdir /logs

# Add the bootstrap file.
ADD docker/bootstrap.sh /bootstrap.sh
RUN dos2unix /bootstrap.sh

# PostgreSQL setup
ENV PGHOST=/var/run/postgresql
ENV PGDATA=$PGHOST/data
ENV PGUSER=postgres
RUN for ver in `ls /usr/lib/postgresql | head -n 1`; do su -c '/usr/lib/postgresql/'$ver'/bin/initdb -E "UTF-8" --lc-collate="en_US.UTF-8" --lc-ctype="en_US.UTF-8" --username=postgres' postgres; done

# Turn off all the fsync stuff for postgres
RUN for ver in /etc/postgresql/*/main; do mkdir -p $ver/conf.d/; echo -e "fsync=off\nfull_page_writes=off" >> $ver/conf.d/fsync.conf; done