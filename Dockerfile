# Small image with pg_dump included
FROM postgres:18-alpine

# Optional: tini for clean signals (Ctrl+C / docker stop)
RUN apk add --no-cache tini

# Add dump script
COPY dump.sh /usr/local/bin/dump.sh
RUN chmod +x /usr/local/bin/dump.sh

ENTRYPOINT ["/sbin/tini","--"]
CMD ["/usr/local/bin/dump.sh"]
