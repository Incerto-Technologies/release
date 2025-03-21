FROM debian:bullseye-slim

COPY ./collector.bin /collector
RUN chmod +x /collector

ARG USER_UID=10001
ARG USER_GID=10001

USER ${USER_UID}:${USER_GID}

ENTRYPOINT ["/collector"]
CMD ["--config", "/tmp/config.yaml"]