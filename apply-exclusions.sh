#!/bin/bash
set -e

EXCLUSIONS_FILE="my-exclusions.txt"

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
# 2. APPLY DOMAIN EXCLUSIONS
# Strips excluded domains from all blocklist
# files across all supported formats.
# ─────────────────────────────────────────────

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

