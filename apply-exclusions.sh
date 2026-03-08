#!/bin/bash
set -e

EXCLUSIONS_FILE="my-exclusions.txt"

if [ ! -f "$EXCLUSIONS_FILE" ]; then
  echo "No exclusions file found, skipping."
  exit 0
fi

while IFS= read -r domain || [ -n "$domain" ]; do
  # Skip empty lines and comments
  [[ -z "$domain" || "$domain" == \#* ]] && continue

  echo "Removing entries matching: $domain"

  # blocklist.txt — ||domain^
  sed -i.bak "/||${domain}^/d" blocklist.txt

  # wildcard-blocklist.txt — *.domain
  sed -i.bak "/\*\.${domain}/d" wildcard-blocklist.txt

  # unbound-blocklist.txt — local-zone: "domain." always_null
  sed -i.bak "/local-zone: \"${domain}\.\" always_null/d" unbound-blocklist.txt

  # rpz-blocklist.txt — domain CNAME .
  sed -i.bak "/^${domain} CNAME \./d" rpz-blocklist.txt

  # domains.txt — plain domain
  sed -i.bak "/^${domain}$/d" domains.txt

  # pihole-blocklist.txt and hosts-blocklist.txt — 0.0.0.0 domain
  sed -i.bak "/^0\.0\.0\.0 ${domain}$/d" pihole-blocklist.txt
  sed -i.bak "/^0\.0\.0\.0 ${domain}$/d" hosts-blocklist.txt

  # little-snitch-blocklist.lsrules — "domain",
  sed -i.bak "/\"${domain}\",/d" little-snitch-blocklist.lsrules

  # Clean up .bak files
  rm -f blocklist.txt.bak wildcard-blocklist.txt.bak unbound-blocklist.txt.bak \
        rpz-blocklist.txt.bak domains.txt.bak pihole-blocklist.txt.bak \
        hosts-blocklist.txt.bak little-snitch-blocklist.lsrules.bak

done < "$EXCLUSIONS_FILE"

echo "Done. All exclusions applied."

