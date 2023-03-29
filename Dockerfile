FROM ubuntu:kinetic

ENV TZ=UTC
LABEL maintainer="sk3l <mike@skelton.onl>"

##
# Parameterize install
ARG listen_port=3128
ARG squid_args=-NYC

##
# Install squid
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		squid ca-certificates tzdata net-tools; \
	DEBIAN_FRONTEND=noninteractive apt-get remove --purge --auto-remove -y; \
	rm -rf /var/lib/apt/lists/*; \
	# smoketest
	/usr/sbin/squid --version

##
# Install conf
COPY ./stage/conf/squid.conf /etc/squid/squid.conf

EXPOSE $listen_port
#VOLUME /var/log/squid \
#	/var/spool/squid


##
# Setup start script
COPY ./stage/entrypoint.sh /entrypoint.sh
#COPY ./stage/entrypoint-debug.sh /entrypoint-debug.sh

ENV SQUID_OPTIONS=$squid_args
CMD /entrypoint.sh -f /etc/squid/squid.conf $SQUID_OPTIONS
