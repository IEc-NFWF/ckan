# See CKAN docs on installation from Docker Compose on usage
FROM ubuntu:20.04
MAINTAINER Open Knowledge

# Upgrade apt to use HTTPS
RUN echo 'Acquire::https::Verify-Peer "false";' > /etc/apt/apt.conf.d/99_tmp_ssl-verify-off.conf \
    && sed --in-place=.orig --regexp-extended 's%http://(.*archive|security).ubuntu.com%https://mirrors.edge.kernel.org%g' /etc/apt/sources.list \
    && apt-get -q -y update \
    && apt-get -q -y install \
        ca-certificates \
        wget \
    && rm /etc/apt/apt.conf.d/99_tmp_ssl-verify-off.conf

# Install required system packages
RUN apt-get -q -y update \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y upgrade \
    && DEBIAN_FRONTEND=noninteractive apt-get -q -y install \
        python2 \
        libpq-dev \
        libxml2-dev \
        libxslt-dev \
        libgeos-dev \
        libssl-dev \
        libffi-dev \
        postgresql-client \
        build-essential \
        git-core \
        vim \
    && wget https://bootstrap.pypa.io/pip/2.7/get-pip.py \
    && python2 get-pip.py \
    && pip2 install virtualenv \
    && apt-get -q clean \
    && rm -rf /var/lib/apt/lists/*

# Define environment variables
ENV CKAN_HOME /usr/lib/ckan
ENV CKAN_VENV $CKAN_HOME/venv
ENV CKAN_CONFIG /etc/ckan
ENV CKAN_STORAGE_PATH=/var/lib/ckan

# Build-time variables specified by docker-compose.yml / .env
ARG CKAN_SITE_URL

# Create ckan user
RUN useradd -r -u 900 -m -c "ckan account" -d $CKAN_HOME -s /bin/false ckan

# Setup virtual environment for CKAN
RUN mkdir -p $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    virtualenv $CKAN_VENV && \
    ln -s $CKAN_VENV/bin/pip /usr/local/bin/ckan-pip &&\
    ln -s $CKAN_VENV/bin/paster /usr/local/bin/ckan-paster

# Setup CKAN
ADD . $CKAN_VENV/src/ckan/
RUN ckan-pip install -U 'pip<21' && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirement-setuptools.txt && \
    ckan-pip install --upgrade --no-cache-dir -r $CKAN_VENV/src/ckan/requirements.txt && \
    ckan-pip install -e $CKAN_VENV/src/ckan/ && \
    ln -s $CKAN_VENV/src/ckan/ckan/config/who.ini $CKAN_CONFIG/who.ini && \
    cp -v $CKAN_VENV/src/ckan/contrib/docker/ckan-entrypoint.sh /ckan-entrypoint.sh && \
    chmod +x /ckan-entrypoint.sh && \
    chown -R ckan:ckan $CKAN_HOME $CKAN_VENV $CKAN_CONFIG $CKAN_STORAGE_PATH && \
    ckan-pip install ckanext-oauth2 && \
    ckan-pip install ckanext-envvars && \ 
    ckan-pip install -e $CKAN_VENV/src/ckan/contrib/nfwf-ckan-extensions/ckanext-nfwf_fields/ && \
    ckan-pip install -e $CKAN_VENV/src/ckan/contrib/nfwf-ckan-extensions/ckanext-nfwf_theme/

ENTRYPOINT ["/ckan-entrypoint.sh"]

USER ckan
EXPOSE 5000

CMD ["ckan-paster","serve","/etc/ckan/production.ini"]
