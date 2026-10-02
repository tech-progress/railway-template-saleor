FROM ghcr.io/saleor/saleor:3.23.37@sha256:42ac24ce691f6b1a1f31f6e80907b6ccf77e4701bbf489e339affe9e959b7dc3

USER root
COPY scripts/bootstrap.py scripts/load-jwt-key.py scripts/start-api.sh scripts/start-worker.sh scripts/storage-smoke.py scripts/with-jwt-key.sh /template/
RUN chmod 0555 /template/start-api.sh /template/start-worker.sh /template/with-jwt-key.sh \
    && chmod 0444 /template/bootstrap.py /template/load-jwt-key.py /template/storage-smoke.py

USER saleor
CMD ["/template/start-api.sh"]
