#!/usr/bin/env bash
set -euo pipefail

DEST="/boot/config/ssl/certs/unas-prod-d1_unraid_bundle.pem"
SRC="/mnt/user/appdata/vault-agent/out/unas-prod-d1_unraid_bundle.pem"
THRESHOLD_DAYS=14

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }
die() { log "ERROR: $*"; exit 1; }

command -v openssl >/dev/null 2>&1 || die "openssl not found"

[[ -f "$DEST" ]] || die "Destination file not found: $DEST"
[[ -f "$SRC"  ]] || die "Source file not found: $SRC"

# Get expiration epoch for a PEM (reads first cert it finds)
get_exp_epoch() {
  local pem="$1"
  local enddate
  enddate="$(openssl x509 -in "$pem" -noout -enddate 2>/dev/null | sed 's/^notAfter=//')" \
    || return 1
  date -d "$enddate" +%s 2>/dev/null
}

dest_exp_epoch="$(get_exp_epoch "$DEST")" || die "Could not parse cert from DEST: $DEST"
src_exp_epoch="$(get_exp_epoch "$SRC")"   || die "Could not parse cert from SRC:  $SRC"

now_epoch="$(date +%s)"
dest_days_left=$(( (dest_exp_epoch - now_epoch) / 86400 ))
src_days_left=$(( (src_exp_epoch  - now_epoch) / 86400 ))

log "DEST expires in ~${dest_days_left} day(s)"
log "SRC  expires in ~${src_days_left} day(s)"

if (( dest_exp_epoch <= now_epoch )); then
  log "DEST is already expired. Replacing..."
elif (( dest_days_left > THRESHOLD_DAYS )); then
  log "DEST is not within ${THRESHOLD_DAYS} days of expiry. No action."
  exit 0
else
  log "DEST is within ${THRESHOLD_DAYS} days of expiry. Replacing..."
fi

# Sanity check: don't replace with something worse/expired
if (( src_exp_epoch <= now_epoch )); then
  die "SRC cert is expired. Refusing to replace."
fi

# Backup and atomic-ish replace
backup="${DEST}.$(date '+%Y%m%d-%H%M%S').bak"
cp -a "$DEST" "$backup"
log "Backed up DEST to $backup"

tmp="${DEST}.tmp.$$"
cp -a "$SRC" "$tmp"

# Verify tmp parses
openssl x509 -in "$tmp" -noout >/dev/null 2>&1 || {
  rm -f "$tmp"
  die "Replacement file does not contain a readable cert (openssl x509 failed)."
}

# Preserve ownership/mode as much as possible
chmod --reference="$DEST" "$tmp" 2>/dev/null || true
chown --reference="$DEST" "$tmp" 2>/dev/null || true

mv -f "$tmp" "$DEST"
log "Replaced $DEST with $SRC successfully."

# Optional: show new expiration
new_exp="$(openssl x509 -in "$DEST" -noout -enddate | sed 's/^notAfter=//')"
log "New DEST notAfter: $new_exp"
