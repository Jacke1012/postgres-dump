#!/usr/bin/env sh
set -eu

# Required: PGHOST, PGUSER, PGDATABASE
# Optional: PGPASSWORD (or use .pgpass), PGPORT, PGSSLMODE, EXTRA_ARGS, DUMP_DIR, DUMP_FORMAT
# DUMP_FORMAT: plain | custom | directory | tar (maps to pg_dump -F)
# If PGURI is provided, it overrides separate PG* vars (e.g. postgres://user:pass@host:5432/db?sslmode=require)

: "${DUMP_DIR:=/backup}"
: "${DUMP_FORMAT:=plain}"

mkdir -p "$DUMP_DIR"

timestamp="$(date -u +%Y%m%d-%H%M%S)"
base="dump_${PGDATABASE:-db}_${timestamp}"

# Choose extension based on format
case "$DUMP_FORMAT" in
  plain)      ext="sql"; flag="-F p" ;;
  custom)     ext="dump"; flag="-F c" ;;
  directory)  ext="dir"; flag="-F d" ;;
  tar)        ext="tar"; flag="-F t" ;;
  *) echo "Unknown DUMP_FORMAT: $DUMP_FORMAT" >&2; exit 2 ;;
esac

outfile="${DUMP_DIR}/${base}.${ext}"

# Decide how we connect
if [ -n "${PGURI:-}" ]; then
  conn_args="$PGURI"
else
  : "${PGHOST:?PGHOST is required when PGURI is not set}"
  : "${PGUSER:?PGUSER is required when PGURI is not set}"
  : "${PGDATABASE:?PGDATABASE is required when PGURI is not set}"
  conn_args=""
fi

# Respect optional vars
pgport_arg="${PGPORT:+-p $PGPORT}"
sslmode_arg="${PGSSLMODE:+--sslmode=$PGSSLMODE}"

# If directory format, outfile is a directory
if [ "$DUMP_FORMAT" = "directory" ]; then
  mkdir -p "$outfile"
fi

echo "Starting pg_dump to: $outfile"
if [ -n "$conn_args" ]; then
  # Using connection URI
  pg_dump $flag \
    ${EXTRA_ARGS:-} \
    -f "$outfile" \
    "$conn_args"
else
  # Using discrete PG* env vars
  pg_dump $flag \
    ${EXTRA_ARGS:-} \
    -h "$PGHOST" \
    -U "$PGUSER" \
    ${pgport_arg:-} \
    ${sslmode_arg:-} \
    -d "$PGDATABASE" \
    -f "$outfile"
fi

# Optionally gzip plain format automatically (common case)
if [ "$DUMP_FORMAT" = "plain" ]; then
  gzip -f "$outfile"
  outfile="${outfile}.gz"
fi

echo "Done. Wrote: $outfile"
