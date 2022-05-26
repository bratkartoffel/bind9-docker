FROM alpine:3.16

# install packages
RUN apk upgrade --no-cache \
        && apk add --no-cache \
        bind bind-tools bind-dnssec-tools doas \
        s6 setpriv \
	# configure doas for cron
	&& echo 'permit nopass named as root cmd /usr/sbin/crond' >>/etc/doas.d/doas.conf

# add the custom configurations
COPY rootfs/ /

EXPOSE 53/udp 53/tcp

CMD [ "/entrypoint.sh" ]

