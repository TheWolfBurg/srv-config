#!/bin/bash
#
# Domain Setup Script for Mailcow + Caddy
# Automatically configures new domains with mail and web hosting
#
# Author: Claude
# Date: 2025-12-27
#
# Usage: ./add-domain.sh domain.com [website-path]
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAILCOW_HOSTNAME="mail.clocklight.de"
MAILCOW_API_URL="https://127.0.0.1:8443/api/v1"
MAILCOW_API_KEY_FILE="/root/.mailcow-api-key"
ADMIN_EMAIL="admin@wolfgang-burger.de"
CADDY_SITES_DIR="/srv/caddy/sites"
CADDY_CONFIG_BACKUP="/srv/config/caddy/sites"
WEBSITE_ROOT="/var/www"
SERVER_IP="46.224.122.105"

# Functions
print_header() {
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  Domain Setup Script${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
}

check_api_key() {
    if [[ ! -f "$MAILCOW_API_KEY_FILE" ]]; then
        print_warning "Mailcow API key not found!"
        echo ""
        echo "Please create an API key:"
        echo "1. Go to: https://${MAILCOW_HOSTNAME}:8443"
        echo "2. Login as admin"
        echo "3. Go to: System > API"
        echo "4. Create new API key with read/write permissions"
        echo "5. Save it to: $MAILCOW_API_KEY_FILE"
        echo ""
        echo "Example:"
        echo "  echo 'YOUR-API-KEY-HERE' > $MAILCOW_API_KEY_FILE"
        echo "  chmod 600 $MAILCOW_API_KEY_FILE"
        echo ""
        exit 1
    fi

    MAILCOW_API_KEY=$(cat "$MAILCOW_API_KEY_FILE")

    if [[ -z "$MAILCOW_API_KEY" ]]; then
        print_error "API key file is empty"
        exit 1
    fi

    print_success "Mailcow API key loaded"
}

validate_domain() {
    local domain=$1

    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        print_error "Invalid domain name: $domain"
        exit 1
    fi
}

# Mailcow API Functions
mailcow_api_call() {
    local method=$1
    local endpoint=$2
    local data=$3

    if [[ -n "$data" ]]; then
        curl -s -k -X "$method" \
            -H "X-API-Key: $MAILCOW_API_KEY" \
            -H "Content-Type: application/json" \
            -d "$data" \
            "${MAILCOW_API_URL}/${endpoint}"
    else
        curl -s -k -X "$method" \
            -H "X-API-Key: $MAILCOW_API_KEY" \
            "${MAILCOW_API_URL}/${endpoint}"
    fi
}

add_mailcow_domain() {
    local domain=$1

    print_info "Adding domain to Mailcow: $domain"

    # Check if domain already exists
    local existing=$(mailcow_api_call "GET" "get/domain/$domain")

    if echo "$existing" | grep -q "\"domain\":\"$domain\""; then
        print_warning "Domain already exists in Mailcow: $domain"
        return 0
    fi

    # Add domain
    local data=$(cat <<EOF
{
    "domain": "$domain",
    "description": "Auto-created by add-domain.sh",
    "aliases": 400,
    "mailboxes": 10,
    "defquota": 3072,
    "maxquota": 10240,
    "quota": 10240,
    "active": 1,
    "relay_all_recipients": 0,
    "backupmx": 0
}
EOF
)

    local result=$(mailcow_api_call "POST" "add/domain" "$data")

    if echo "$result" | grep -q '"type":"success"'; then
        print_success "Domain added to Mailcow: $domain"
    else
        print_error "Failed to add domain: $result"
        return 1
    fi
}

add_mailcow_alias() {
    local address=$1
    local goto=$2

    print_info "Creating alias: $address → $goto"

    # Check if alias already exists
    local existing=$(mailcow_api_call "GET" "get/alias/all")

    if echo "$existing" | grep -q "\"address\":\"$address\""; then
        print_warning "Alias already exists: $address"
        return 0
    fi

    # Add alias
    local data=$(cat <<EOF
{
    "address": "$address",
    "goto": "$goto",
    "active": 1
}
EOF
)

    local result=$(mailcow_api_call "POST" "add/alias" "$data")

    if echo "$result" | grep -q '"type":"success"'; then
        print_success "Alias created: $address → $goto"
    else
        print_error "Failed to create alias: $result"
        return 1
    fi
}

create_caddy_config() {
    local domain=$1
    local website_path=$2

    print_info "Creating Caddy configuration for: $domain"

    local config_file="${CADDY_SITES_DIR}/${domain}.caddy"

    # Check if config already exists
    if [[ -f "$config_file" ]]; then
        print_warning "Caddy config already exists: $config_file"
        read -p "Overwrite? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Skipping Caddy config creation"
            return 0
        fi
    fi

    # Determine website root
    local site_root
    if [[ -n "$website_path" ]]; then
        site_root="$website_path"
    else
        site_root="${WEBSITE_ROOT}/${domain}"
    fi

    # Create Caddy config
    cat > "$config_file" <<EOF
$domain, www.$domain {
    root * $site_root
    file_server
    import ../snippets/compression.caddy
    import ../snippets/security_headers.caddy

    log {
        output file /var/log/caddy/${domain}.log
    }
}
EOF

    print_success "Caddy config created: $config_file"

    # Copy to backup
    cp "$config_file" "$CADDY_CONFIG_BACKUP/"
    print_success "Config backed up to: $CADDY_CONFIG_BACKUP/"
}

create_website_directory() {
    local domain=$1
    local website_path=$2

    local site_root
    if [[ -n "$website_path" ]]; then
        site_root="$website_path"
    else
        site_root="${WEBSITE_ROOT}/${domain}"
    fi

    if [[ -d "$site_root" ]]; then
        print_warning "Website directory already exists: $site_root"
        return 0
    fi

    print_info "Creating website directory: $site_root"

    mkdir -p "$site_root"

    # Create simple index.html
    cat > "${site_root}/index.html" <<EOF
<!DOCTYPE html>
<html lang="de">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Welcome to $domain</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif;
            display: flex;
            justify-content: center;
            align-items: center;
            min-height: 100vh;
            margin: 0;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }
        .container {
            text-align: center;
            padding: 2rem;
        }
        h1 {
            font-size: 3rem;
            margin: 0 0 1rem 0;
        }
        p {
            font-size: 1.2rem;
            opacity: 0.9;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Welcome to $domain</h1>
        <p>Your website is ready!</p>
        <p><small>Created by add-domain.sh</small></p>
    </div>
</body>
</html>
EOF

    # Set permissions
    chown -R wolf:webusers "$site_root"
    chmod -R 755 "$site_root"

    print_success "Website directory created: $site_root"
}

reload_caddy() {
    print_info "Reloading Caddy configuration..."

    # Validate config first
    if docker exec caddy-webserver caddy validate --config /etc/caddy/Caddyfile 2>&1 | grep -q "Valid configuration"; then
        print_success "Caddy config is valid"
    else
        print_error "Caddy config validation failed!"
        docker exec caddy-webserver caddy validate --config /etc/caddy/Caddyfile
        return 1
    fi

    # Reload
    if docker exec caddy-webserver caddy reload --config /etc/caddy/Caddyfile 2>&1; then
        print_success "Caddy reloaded successfully"
    else
        print_error "Failed to reload Caddy"
        return 1
    fi
}

get_dkim_record() {
    local domain=$1

    print_info "Fetching DKIM record from Mailcow..."

    # Wait a bit for Mailcow to generate DKIM
    sleep 3

    # Get DKIM from API
    local dkim_response=$(mailcow_api_call "GET" "get/dkim/${domain}")

    # Parse DKIM public key
    local dkim_pubkey=$(echo "$dkim_response" | grep -o '"pubkey":"[^"]*"' | cut -d'"' -f4)

    if [[ -n "$dkim_pubkey" ]]; then
        print_success "DKIM record retrieved"
        echo "$dkim_pubkey"
    else
        print_warning "DKIM record not yet available (will be generated soon)"
        echo ""
    fi
}

generate_dns_records() {
    local domain=$1

    # Get DKIM record
    local dkim_record=$(get_dkim_record "$domain")

    echo ""
    echo -e "${BLUE}================================${NC}"
    echo -e "${BLUE}  DNS Records for $domain${NC}"
    echo -e "${BLUE}================================${NC}"
    echo ""
    echo "Add these DNS records to your domain registrar:"
    echo ""
    echo -e "${GREEN}# Website (A Record)${NC}"
    echo "Type: A"
    echo "Name: @"
    echo "Value: $SERVER_IP"
    echo "TTL: 3600"
    echo ""
    echo -e "${GREEN}# WWW Subdomain (CNAME)${NC}"
    echo "Type: CNAME"
    echo "Name: www"
    echo "Value: $domain"
    echo "TTL: 3600"
    echo ""
    echo -e "${GREEN}# Mail Server (MX Record)${NC}"
    echo "Type: MX"
    echo "Name: @"
    echo "Value: $MAILCOW_HOSTNAME"
    echo "Priority: 10"
    echo "TTL: 3600"
    echo ""
    echo -e "${GREEN}# SPF Record (TXT)${NC}"
    echo "Type: TXT"
    echo "Name: @"
    echo "Value: \"v=spf1 mx ~all\""
    echo "TTL: 3600"
    echo ""
    echo -e "${GREEN}# DMARC Record (TXT)${NC}"
    echo "Type: TXT"
    echo "Name: _dmarc"
    echo "Value: \"v=DMARC1; p=quarantine; rua=mailto:postmaster@$domain\""
    echo "TTL: 3600"
    echo ""

    if [[ -n "$dkim_record" ]]; then
        echo -e "${GREEN}# DKIM Record (TXT) ⭐ WICHTIG!${NC}"
        echo "Type: TXT"
        echo "Name: dkim._domainkey"
        echo "Value: \"$dkim_record\""
        echo "TTL: 3600"
        echo ""
        echo -e "${GREEN}✓ DKIM record is ready to use!${NC}"
    else
        echo -e "${YELLOW}# DKIM Record (TXT)${NC}"
        echo -e "${YELLOW}⚠ DKIM record not yet available${NC}"
        echo "Please wait a few minutes, then get it from:"
        echo "https://${MAILCOW_HOSTNAME}:8443"
        echo "→ Konfiguration → Routings → DKIM-Schlüssel → $domain"
    fi
    echo ""
}

create_summary_file() {
    local domain=$1
    local summary_file="/srv/domains/${domain}-setup-summary.txt"
    local dkim_record=$2

    mkdir -p /srv/domains

    cat > "$summary_file" <<EOF
Domain Setup Summary
====================
Domain: $domain
Date: $(date)
Created by: add-domain.sh

Mail Configuration:
-------------------
- Domain added to Mailcow: $domain
- Aliases created:
  * info@$domain → $ADMIN_EMAIL
  * postmaster@$domain → $ADMIN_EMAIL

Web Configuration:
------------------
- Caddy config: ${CADDY_SITES_DIR}/${domain}.caddy
- Website root: ${WEBSITE_ROOT}/${domain}
- URLs:
  * http://$domain (redirects to HTTPS)
  * https://$domain
  * https://www.$domain

DNS Records:
------------
A Record:
  Type: A, Name: @, Value: $SERVER_IP

CNAME Record:
  Type: CNAME, Name: www, Value: $domain

MX Record:
  Type: MX, Name: @, Value: $MAILCOW_HOSTNAME, Priority: 10

SPF Record:
  Type: TXT, Name: @, Value: "v=spf1 mx ~all"

DMARC Record:
  Type: TXT, Name: _dmarc, Value: "v=DMARC1; p=quarantine; rua=mailto:postmaster@$domain"

DKIM Record:
$(if [[ -n "$dkim_record" ]]; then
    echo "  Type: TXT, Name: dkim._domainkey, Value: \"$dkim_record\""
    echo "  ✓ DKIM is ready!"
else
    echo "  ⚠ Not yet available - get it from Mailcow admin panel"
    echo "  https://${MAILCOW_HOSTNAME}:8443 → Konfiguration → DKIM-Schlüssel"
fi)

Next Steps:
-----------
1. Add ALL DNS records to your domain registrar (including DKIM!)
2. Wait for DNS propagation (10-30 minutes)
3. Test website: https://$domain
4. Test email: Send to info@$domain
5. Verify DNS: https://mxtoolbox.com/SuperTool.aspx?action=mx:$domain

Testing Email:
--------------
Test SPF/DKIM/DMARC:
  - https://mxtoolbox.com/dkim.aspx
  - Send test email to: check-auth@verifier.port25.com

Files Created:
--------------
- ${CADDY_SITES_DIR}/${domain}.caddy
- ${WEBSITE_ROOT}/${domain}/index.html
- $summary_file

EOF

    print_success "Summary saved to: $summary_file"
}

# Main Script
main() {
    print_header

    # Check if running as root
    check_root

    # Check arguments
    if [[ $# -lt 1 ]]; then
        echo "Usage: $0 <domain> [website-path]"
        echo ""
        echo "Examples:"
        echo "  $0 example.com"
        echo "  $0 example.com /var/www/custom-path"
        echo ""
        exit 1
    fi

    DOMAIN=$1
    WEBSITE_PATH=${2:-}

    # Validate domain
    validate_domain "$DOMAIN"
    print_success "Domain validated: $DOMAIN"

    # Check API key
    check_api_key

    echo ""
    print_info "Setting up domain: $DOMAIN"
    print_info "Admin email: $ADMIN_EMAIL"
    if [[ -n "$WEBSITE_PATH" ]]; then
        print_info "Website path: $WEBSITE_PATH"
    else
        print_info "Website path: ${WEBSITE_ROOT}/${DOMAIN} (default)"
    fi
    echo ""

    read -p "Continue? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        print_info "Aborted by user"
        exit 0
    fi

    echo ""
    echo -e "${BLUE}Step 1: Mailcow Configuration${NC}"
    echo "----------------------------"

    # Add domain to Mailcow
    add_mailcow_domain "$DOMAIN"

    # Wait a bit for Mailcow to process
    sleep 2

    # Create aliases
    add_mailcow_alias "info@${DOMAIN}" "$ADMIN_EMAIL"
    add_mailcow_alias "postmaster@${DOMAIN}" "$ADMIN_EMAIL"

    echo ""
    echo -e "${BLUE}Step 2: Caddy Configuration${NC}"
    echo "---------------------------"

    # Create Caddy config
    create_caddy_config "$DOMAIN" "$WEBSITE_PATH"

    # Create website directory
    create_website_directory "$DOMAIN" "$WEBSITE_PATH"

    # Reload Caddy
    reload_caddy

    echo ""
    echo -e "${BLUE}Step 3: DNS Configuration${NC}"
    echo "-------------------------"

    # Generate DNS records (this also fetches DKIM)
    generate_dns_records "$DOMAIN"

    # Get DKIM record for summary
    DKIM_RECORD=$(get_dkim_record "$DOMAIN" 2>/dev/null)

    # Create summary
    create_summary_file "$DOMAIN" "$DKIM_RECORD"

    echo ""
    echo -e "${GREEN}================================${NC}"
    echo -e "${GREEN}  Setup Complete!${NC}"
    echo -e "${GREEN}================================${NC}"
    echo ""
    print_success "Domain $DOMAIN has been configured"
    echo ""
    echo "Next steps:"
    echo "1. Add the DNS records shown above"
    echo "2. Wait for DNS propagation (10-30 minutes)"
    echo "3. Test: https://$DOMAIN"
    echo "4. Test email: Send to info@$DOMAIN"
    echo ""
    print_info "Summary saved to: /srv/domains/${DOMAIN}-setup-summary.txt"
    echo ""
}

# Run main function
main "$@"
