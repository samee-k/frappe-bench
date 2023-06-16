FROM debian:10.2

###############################################
# ARG
###############################################
ARG adminPass=Admin
ARG mysqlPass=frappe@123
ARG pythonVersion=python3
ARG appBranch=version-13

###############################################
# ENV 
###############################################
# user pass
ENV systemUser=frappe
# locales
ENV LANGUAGE=en_US \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8
# prerequisite version
ENV mariadbVersion=10.3 \
    nodejsVersion=12.x
# frappe
ENV benchPath=bench-repo \
    benchFolderName=bench \
    benchRepo="https://github.com/frappe/bench" \
    # Hot-fix: master branch didn't get jinja version bump and causing the error
    # https://github.com/frappe/bench/pull/1270
    benchBranch=v5.x \
    frappeRepo="https://github.com/frappe/frappe" \
    erpnextRepo="https://github.com/frappe/erpnext" \
    siteName=samee.com

###############################################
# INSTALL PREREQUISITE
###############################################
RUN apt-get -y update \
    ###############################################
    # config
    ###############################################
    && apt-get -y -q install \
    # locale
    locales locales-all \
    # [fix] "debconf: delaying package configuration, since apt-utils is not installed"
    apt-utils \
    # [fix] "debconf: unable to initialize frontend: Dialog"
    # https://github.com/moby/moby/issues/27988
    && echo "debconf debconf/frontend select Noninteractive" | debconf-set-selections \
    ###############################################
    # install
    ###############################################
    # basic tools
    && apt-get -y -q install \
    wget \
    curl \
    cron \
    sudo \
    git \
    nano \
    openssl \
    ###############################################
    # python 3
    ###############################################
    && apt-get -y -q install \
    build-essential \
    python3-venv \
    python3-dev \
    python3-setuptools \
    python3-pip \
    ###############################################
    # [playbook] common
    ###############################################
    # debian_family.yml
    && apt-get -y -q install \
    dnsmasq \
    fontconfig \
    htop \
    libcrypto++-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libwebp-dev \
    libxext6 \
    libxrender1 \
    libxslt1-dev \
    libxslt1.1 \
    libffi-dev \
    ntp \
    postfix \
    python3-dev \
    python-tk \
    screen \
    xfonts-75dpi \
    xfonts-base \
    zlib1g-dev \
    apt-transport-https \
    libsasl2-dev \
    libldap2-dev \
    libcups2-dev \
    pv \
    # debian.yml
    ## pillow prerequisites for Debian >= 10
    && apt-get -y -q install \
    libjpeg62-turbo-dev \
    libtiff5-dev \
    tcl8.6-dev \
    tk8.6-dev \
    ## pdf prerequisites debian
    && apt-get -y -q install \
    libssl-dev \
    ## Setup OpenSSL dependancy
    && pip3 install --upgrade pyOpenSSL==16.2.0 \
    ###############################################
    # [playbook] mariadb
    ###############################################
    # add repo from mariadb mirrors
    # https://downloads.mariadb.org/mariadb/repositories
    && apt-get install -y -q software-properties-common dirmngr \
    && apt-key adv --fetch-keys "https://mariadb.org/mariadb_release_signing_key.asc" \
    && add-apt-repository "deb [arch=amd64] http://nyc2.mirrors.digitalocean.com/mariadb/repo/${mariadbVersion}/debian buster main" \
    # mariadb.yml
    && apt-get update \
    && apt-get install -y -q \
    mariadb-server \
    mariadb-client \
    mariadb-common \
    libmariadbclient18 \
    python3-mysqldb \
    ###############################################
    # psutil
    ###############################################
    && pip3 install --upgrade psutil \
    ###############################################
    # [playbook] wkhtmltopdf
    ###############################################
    # https://github.com/frappe/frappe_docker/blob/master/Dockerfile
    # https://gitlab.com/castlecraft/erpnext_kubernetes/blob/master/erpnext-python/Dockerfile
    && apt-get install -y -q \
    wkhtmltopdf \
    libssl-dev \
    fonts-cantarell \
    xfonts-75dpi \
    xfonts-base \
    && wget https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6-1/wkhtmltox_0.12.6-1.buster_amd64.deb \
    && dpkg -i wkhtmltox_0.12.6-1.buster_amd64.deb \
    && rm wkhtmltox_0.12.6-1.buster_amd64.deb \
    ###############################################
    # redis
    ###############################################
    && apt-get install -y -q \
    redis-server \
    ###############################################
    # [production] supervisor
    ###############################################
    && apt-get install -y -q \
    supervisor \
    ###############################################
    # [production] nginx
    ###############################################
    && apt-get install -y -q \
    nginx \
    ###############################################
    # nodejs
    ###############################################
    # https://github.com/nodesource/distributions
    && curl --silent --location https://deb.nodesource.com/setup_${nodejsVersion} | bash - \
    && apt-get install -y -q nodejs \
    && sudo npm install -g -y yarn \
    ###############################################
    # docker production setup
    ###############################################
    && apt-get install -y -q \
    # used for envsubst, making nginx cnf from template
    gettext-base \
    ###############################################
    # add sudoers
    ###############################################
    && adduser --disabled-password --gecos "" $systemUser \
    && usermod -aG sudo $systemUser \
    && echo "%sudo  ALL=(ALL)  NOPASSWD: ALL" > /etc/sudoers.d/sudoers \
    ###############################################
    # clean-up
    ###############################################
    && apt-get autoremove --purge -y \
    && apt-get clean -y

###############################################
# SET USER AND WORKDIR
###############################################
USER $systemUser
WORKDIR /home/$systemUser

###############################################
# COPY
###############################################
# mariadb config
# COPY ./mariadb.cnf /etc/mysql/mariadb.cnf
COPY ./my.cnf /etc/mysql/my.cnf

###############################################
# INSTALL FRAPPE
###############################################
RUN sudo chmod 644 /etc/mysql/my.cnf \
    && sudo service mysql start \
    && mysql --user="root" --execute="ALTER USER 'root'@'localhost' IDENTIFIED BY '${mysqlPass}';" \
    ###############################################
    # install bench
    ###############################################
    && sudo pip3 install frappe-bench \
    && bench init $benchFolderName --frappe-path $frappeRepo --frappe-branch $appBranch --python $pythonVersion \
    # cd into bench folder
    && cd $benchFolderName \
    # install erpnext
    && bench get-app erpnext $erpnextRepo --branch $appBranch \
    # delete temp file
    && sudo rm -rf /tmp/* \
    # start new site
    && bench new-site $siteName \
    --mariadb-root-password $mysqlPass  \
    --admin-password $adminPass \
    && bench --site $siteName install-app erpnext \
    # compile all python file
    ## the reason for not using python3 -m compileall -q /home/$systemUser/$benchFolderName/apps
    ## is to ignore frappe/node_modules folder since it will cause syntax error
    && $pythonVersion -m compileall -q /home/$systemUser/$benchFolderName/apps/frappe/frappe \
    && $pythonVersion -m compileall -q /home/$systemUser/$benchFolderName/apps/erpnext/erpnext

###############################################

COPY ./sites/currentsite.txt /home/$systemUser/$benchFolderName/sites/currentsite.txt

# image entrypoint
COPY --chown=1000:1000 entrypoint.sh /usr/local/bin/entrypoint.sh

# set entrypoint permission
## prevent: docker Error response from daemon OCI runtime create failed starting container process caused "permission denied" unknown
# RUN sudo chmod +x /home/$systemUser/production_config/entrypoint_prd.sh \
#     && sudo chmod +x /usr/local/bin/entrypoint.sh

RUN sudo chmod +x /usr/local/bin/entrypoint.sh

###############################################
# WORKDIR
###############################################
WORKDIR /home/$systemUser/$benchFolderName

###############################################
# FINALIZED
###############################################
# image entrypoint script
CMD ["/usr/local/bin/entrypoint.sh"]

# expose port
EXPOSE 8000 9000 3306