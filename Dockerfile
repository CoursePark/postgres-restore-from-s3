ARG PG_ALPINE_BRANCH
FROM alpine:${PG_ALPINE_BRANCH}

ARG PG_ALPINE_BRANCH
ARG PG_VERSION

#--------------------------------------------------------------------------------
# Install dependencies
#--------------------------------------------------------------------------------
# "postgresql" is required for "pg_restore"
# "python" is required for "aws-cli"
#--------------------------------------------------------------------------------
RUN echo "http://dl-cdn.alpinelinux.org/alpine/v${PG_ALPINE_BRANCH}/main" >> /etc/apk/repositories

RUN apk --no-cache add dumb-init postgresql=${PG_VERSION} python py-pip && \
	pip install awscli && \
	apk --purge -v del py-pip

#--------------------------------------------------------------------------------
# Set script permissions and create required directories
#--------------------------------------------------------------------------------
COPY aws-mfa.sh action.sh /
RUN chmod +x action.sh && chmod +x aws-mfa.sh
RUN mkdir -p /cache && mkdir -p /root/.aws

#--------------------------------------------------------------------------------
# Use the `dumb-init` init system (PID 1) for process handling
#--------------------------------------------------------------------------------
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

#--------------------------------------------------------------------------------
# Configure and apply a cronjob
#--------------------------------------------------------------------------------
CMD echo "${CRON_MINUTE:-$(shuf -i 0-59 -n1)} ${CRON_HOUR:-*} * * * /action.sh" \
> /var/spool/cron/crontabs/root && crond -d 8 -f
