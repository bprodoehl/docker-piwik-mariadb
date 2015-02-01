# Piwik (https://piwik.org/)
# MariaDB (https://mariadb.org/)

FROM ubuntu:14.04
MAINTAINER Brian Prodoehl <bprodoehl@connectify.me>

RUN echo "deb http://archive.ubuntu.com/ubuntu trusty main universe" > /etc/apt/sources.list

# Ensure UTF-8
RUN apt-get update
RUN locale-gen en_US.UTF-8
ENV LANG       en_US.UTF-8
ENV LC_ALL     en_US.UTF-8

ENV DEBIAN_FRONTEND noninteractive

# Ensure the system has the latest patches
RUN apt-get -y upgrade

# Install MariaDB from repository.
RUN apt-get -y install software-properties-common python-software-properties && \
    apt-key adv --recv-keys --keyserver hkp://keyserver.ubuntu.com:80 0xcbcb082a1bb943db && \
    add-apt-repository 'deb http://mirror.jmu.edu/pub/mariadb/repo/5.5/ubuntu trusty main' && \
    apt-get update && \
    apt-get install -y mariadb-server

# Install other tools.
RUN apt-get install -y pwgen inotify-tools

# Decouple our data from our container.
VOLUME ["/data"]

# Configure the database to use our data dir.
RUN sed -i -e 's/^datadir\s*=.*/datadir = \/data/' /etc/mysql/my.cnf

# Install piwik dependencies
RUN apt-get -y install apache2 libapache2-mod-php5 php5-gd php5-json \
                       php5-mysql wget supervisor

# remove default apache page
RUN rm /var/www/html/index.html

# deploy piwik
RUN cd /var/www/html && \
    wget http://builds.piwik.org/piwik-2.10.0.tar.gz && \
    tar --strip-components=1 -zxvf piwik-2.10.0.tar.gz && \
    rm piwik-2.10.0.tar.gz 

# set permissions for piwik
RUN chown -R www-data:www-data /var/www/html

EXPOSE 80 3306
ADD scripts /scripts
RUN chmod +x /scripts/start.sh
RUN touch /firstrun

ENTRYPOINT ["/scripts/start.sh"]
