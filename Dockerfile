FROM ghcr.io/saleor/saleor:3.23.23@sha256:3fc21b69182fd0d94731e12c2121faeef022ddf6bbf1398e12e19cb12add2049

USER root
COPY scripts/bootstrap.py scripts/load-jwt-key.py scripts/start-api.sh scripts/start-worker.sh scripts/storage-smoke.py scripts/with-jwt-key.sh /template/
RUN chmod 0555 /template/start-api.sh /template/start-worker.sh /template/with-jwt-key.sh \
    && chmod 0444 /template/bootstrap.py /template/load-jwt-key.py /template/storage-smoke.py

USER saleor
CMD ["/template/start-api.sh"]
