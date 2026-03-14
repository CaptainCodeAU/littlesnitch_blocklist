#!/bin/bash
set -e

EXCLUSIONS_FILE="my-exclusions.txt"
INCLUSIONS_FILE="my-inclusions.txt"

# ─────────────────────────────────────────────
# 1. RESTORE FORK-SPECIFIC FILES
# Ensures HTML install files always point to
# this repo, not the upstream original.
# ─────────────────────────────────────────────

echo "Restoring fork-specific HTML files..."

cat > install.html << 'EOF'
<!DOCTYPE html>
<html class="js" lang="en-US">
<head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ph00lt0 - blocklist installation</title>
</head>
<body>
    <a target="_blank" href="abp:subscribe?location=https%3A%2F%2Fraw.githubusercontent.com%2FCaptainCodeAU%2Flittlesnitch_blocklist%2Fmaster%2Fblocklist.txt&title=ph00lt0%20-%20blocklist" title="ph00lt0 - blocklist">
        Click here to install the blocklist
    </a>, else follow manual instructions
</body>
</html>
EOF

cat > little-snitch-install.html << 'EOF'
<!DOCTYPE html>
<html class="js" lang="en-US">
<head>
    <meta http-equiv="content-type" content="text/html; charset=UTF-8">
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>ph00lt0 - blocklist installation for Little Snitch</title>
    <script>
        window.location.href="x-littlesnitch:subscribe-rules?url=https://raw.githubusercontent.com/CaptainCodeAU/littlesnitch_blocklist/master/little-snitch-blocklist.lsrules"
    </script>
</head>
<body>
<a target="_blank" href="x-littlesnitch:subscribe-rules?url=https://raw.githubusercontent.com/CaptainCodeAU/littlesnitch_blocklist/master/little-snitch-blocklist.lsrules">
    Click here to install the blocklist
</a>, else follow manual instructions
</body>
</html>
EOF

echo "HTML files restored."

# ─────────────────────────────────────────────
# 2. FIX README URLS
# Replaces upstream URLs with fork-specific
# URLs in README.md after every sync.
# ─────────────────────────────────────────────

echo "Fixing README URLs..."

# Replace raw githubusercontent URLs
sed -i.bak 's|https://raw.githubusercontent.com/ph00lt0/blocklist/master/|https://raw.githubusercontent.com/CaptainCodeAU/littlesnitch_blocklist/master/|g' README.md

# Replace GitHub Pages URLs
sed -i.bak 's|https://ph00lt0.github.io/blocklist/|https://captaincodeau.github.io/littlesnitch_blocklist/|g' README.md

# Replace abp: protocol links
sed -i.bak 's|abp:subscribe?location=https%3A%2F%2Fraw.githubusercontent.com%2Fph00lt0%2Fblocklist%2Fmaster%2Fblocklist.txt&title=ph00lt0%20-%20blocklist|https://captaincodeau.github.io/littlesnitch_blocklist/install.html|g' README.md

# Replace x-littlesnitch: protocol links
sed -i.bak 's|x-littlesnitch:subscribe-rules?url=https://raw.githubusercontent.com/ph00lt0/blocklist/master/little-snitch-blocklist.lsrules|https://captaincodeau.github.io/littlesnitch_blocklist/little-snitch-install.html|g' README.md

# Replace GitHub issue links
sed -i.bak 's|https://github.com/ph00lt0/blocklist/issues|https://github.com/CaptainCodeAU/littlesnitch_blocklist/issues|g' README.md

rm -f README.md.bak
echo "README URLs fixed."

# ─────────────────────────────────────────────
# 3. FIX LITTLE SNITCH METADATA
# Updates name and description in .lsrules
# to point to this fork.
# ─────────────────────────────────────────────

echo "Fixing Little Snitch metadata..."

python3 - << 'PYEOF'
import json

with open('little-snitch-blocklist.lsrules', 'r') as f:
    data = json.load(f)

data['name'] = 'CaptainCodeAU - blocklist'
data['description'] = 'https://github.com/CaptainCodeAU/littlesnitch_blocklist'

with open('little-snitch-blocklist.lsrules', 'w') as f:
    json.dump(data, f, indent=4)

print("Little Snitch metadata updated.")
PYEOF

# ─────────────────────────────────────────────
# 4. APPLY DOMAIN EXCLUSIONS
# Strips excluded domains from all blocklist
# files across all supported formats.
# ─────────────────────────────────────────────

if [ ! -f "$EXCLUSIONS_FILE" ]; then
  echo "No exclusions file found, skipping."
else

while IFS= read -r domain || [ -n "$domain" ]; do
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

  # little-snitch-blocklist.lsrules — via Python (JSON-safe)
  python3 - << PYEOF
import json
with open('little-snitch-blocklist.lsrules', 'r') as f:
    data = json.load(f)
domain = "${domain}"
data['denied-remote-domains'] = [d for d in data.get('denied-remote-domains', []) if d != domain]
with open('little-snitch-blocklist.lsrules', 'w') as f:
    json.dump(data, f, indent=4)
PYEOF

  # Clean up .bak files
  rm -f blocklist.txt.bak wildcard-blocklist.txt.bak unbound-blocklist.txt.bak \
        rpz-blocklist.txt.bak domains.txt.bak pihole-blocklist.txt.bak \
        hosts-blocklist.txt.bak

done < "$EXCLUSIONS_FILE"
echo "Done. All exclusions applied."
fi

# ─────────────────────────────────────────────
# 5. APPLY SURGICAL INCLUSIONS
# Removes exact bare domain matches only.
# Never removes wildcards or subdomains.
# ─────────────────────────────────────────────

if [ ! -f "$INCLUSIONS_FILE" ]; then
  echo "No inclusions file found, skipping."
  exit 0
fi

while IFS= read -r domain || [ -n "$domain" ]; do
  [[ -z "$domain" || "$domain" == \#* ]] && continue

  echo "Unblocking exact domain: $domain"

  # blocklist.txt — exact ||domain^ only
  sed -i.bak "/^||${domain}\^$/d" blocklist.txt

  # domains.txt — exact domain only
  sed -i.bak "/^${domain}$/d" domains.txt

  # pihole-blocklist.txt and hosts-blocklist.txt — exact 0.0.0.0 domain only
  sed -i.bak "/^0\.0\.0\.0 ${domain}$/d" pihole-blocklist.txt
  sed -i.bak "/^0\.0\.0\.0 ${domain}$/d" hosts-blocklist.txt

  # unbound-blocklist.txt — exact local-zone: "domain." always_null only
  sed -i.bak "/^local-zone: \"${domain}\.\" always_null$/d" unbound-blocklist.txt

  # rpz-blocklist.txt — exact domain CNAME . only
  sed -i.bak "/^${domain} CNAME \.$/d" rpz-blocklist.txt

  # little-snitch-blocklist.lsrules — via Python (JSON-safe, exact match only)
  python3 - << PYEOF
import json
with open('little-snitch-blocklist.lsrules', 'r') as f:
    data = json.load(f)
domain = "${domain}"
data['denied-remote-domains'] = [d for d in data.get('denied-remote-domains', []) if d != domain]
with open('little-snitch-blocklist.lsrules', 'w') as f:
    json.dump(data, f, indent=4)
PYEOF

  # Clean up .bak files
  rm -f blocklist.txt.bak domains.txt.bak pihole-blocklist.txt.bak \
        hosts-blocklist.txt.bak unbound-blocklist.txt.bak rpz-blocklist.txt.bak

done < "$INCLUSIONS_FILE"

echo "Done. All inclusions applied."

# ─────────────────────────────────────────────
# 6. APPLY DOMAIN ADDITIONS
# Adds domains from my-additions.txt to all
# blocklist formats (if not already present).
# ─────────────────────────────────────────────

ADDITIONS_FILE="my-additions.txt"

if [ ! -f "$ADDITIONS_FILE" ]; then
  echo "No additions file found, skipping."
else

while IFS= read -r domain || [ -n "$domain" ]; do
  [[ -z "$domain" || "$domain" == \#* ]] && continue

  echo "Adding domain: $domain"

  # blocklist.txt — ||domain^
  grep -qxF "||${domain}^" blocklist.txt 2>/dev/null || echo "||${domain}^" >> blocklist.txt

  # domains.txt — plain domain
  grep -qxF "${domain}" domains.txt 2>/dev/null || echo "${domain}" >> domains.txt

  # wildcard-blocklist.txt — *.domain
  grep -qxF "*.${domain}" wildcard-blocklist.txt 2>/dev/null || echo "*.${domain}" >> wildcard-blocklist.txt

  # unbound-blocklist.txt — local-zone: "domain." always_null
  grep -qxF "local-zone: \"${domain}.\" always_null" unbound-blocklist.txt 2>/dev/null || echo "local-zone: \"${domain}.\" always_null" >> unbound-blocklist.txt

  # rpz-blocklist.txt — domain CNAME .
  grep -qxF "${domain} CNAME ." rpz-blocklist.txt 2>/dev/null || echo "${domain} CNAME ." >> rpz-blocklist.txt

  # pihole-blocklist.txt — 0.0.0.0 domain
  grep -qxF "0.0.0.0 ${domain}" pihole-blocklist.txt 2>/dev/null || echo "0.0.0.0 ${domain}" >> pihole-blocklist.txt

  # hosts-blocklist.txt — 0.0.0.0 domain
  grep -qxF "0.0.0.0 ${domain}" hosts-blocklist.txt 2>/dev/null || echo "0.0.0.0 ${domain}" >> hosts-blocklist.txt

  # little-snitch-blocklist.lsrules — add to denied-remote-domains JSON array
  python3 - << PYEOF
import json
with open('little-snitch-blocklist.lsrules', 'r') as f:
    data = json.load(f)
domain = "${domain}"
if domain not in data.get('denied-remote-domains', []):
    data.setdefault('denied-remote-domains', []).append(domain)
    with open('little-snitch-blocklist.lsrules', 'w') as f:
        json.dump(data, f, indent=4)
PYEOF

done < "$ADDITIONS_FILE"

# Re-sort text-based blocklist files
for f in blocklist.txt domains.txt wildcard-blocklist.txt unbound-blocklist.txt \
         rpz-blocklist.txt pihole-blocklist.txt hosts-blocklist.txt; do
  sort -uf "$f" -o "$f"
done

echo "Done. All additions applied."
fi

