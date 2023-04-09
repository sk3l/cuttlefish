FROM ubuntu:kinetic

ENV TZ=UTC
LABEL maintainer="sk3l <mike@skelton.onl>"

##
# Parameterize install
ARG listen_port=3128
ARG squid_args=-NYC
ARG username=cfuser
ARG password=abc123

##
# Install squid
RUN set -eux; \
	apt-get update; \
	DEBIAN_FRONTEND=noninteractive apt-get full-upgrade -y; \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
		apache2-utils     \
		ca-certificates   \
		less              \
		net-tools         \
		squid             \
		tzdata            \
		vim;              \
	DEBIAN_FRONTEND=noninteractive apt-get remove --purge --auto-remove -y; \
	rm -rf /var/lib/apt/lists/*; \
	# smoketest
	/usr/sbin/squid --version

##
# Install conf
COPY ./stage/conf/squid.conf /etc/squid/squid.conf

##
# Setup proxy auth
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN touch /etc/squid/passwords;     \
    chmod 777 /etc/squid/passwords; \
    echo $password | htpasswd -i /etc/squid/passwords $username

EXPOSE $listen_port

## TODO - Fix volume mount for logs
#VOLUME /var/log/squid \
#	/var/spool/squid

##
# Setup start script
COPY ./stage/entrypoint.sh /entrypoint.sh

ENV SQUID_OPTIONS=$squid_args
CMD /entrypoint.sh -f /etc/squid/squid.conf $SQUID_OPTIONS
