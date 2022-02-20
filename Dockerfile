FROM alpine:3.15

# install packages
RUN apk upgrade --no-cache \
        && apk add --no-cache \
        bind bind-tools bind-dnssec-tools \
        s6 setpriv

# add the custom configurations
COPY rootfs/ /

#  5300: dns (remapped from unpriv account, should be mapped to 53)
EXPOSE 5300/udp 5300/tcp

CMD [ "/entrypoint.sh" ]

