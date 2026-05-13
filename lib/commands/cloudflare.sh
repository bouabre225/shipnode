#!/usr/bin/env bash

cmd_cloudflare() {
    local subcommand="${1:-}"

    case "$subcommand" in
        init)
            cmd_cloudflare_init
            ;;
        audit)
            cmd_cloudflare_audit
            ;;
        status)
            cmd_cloudflare_status
            ;;
        *)
            error "Unknown Cloudflare command: ${subcommand:-}\nAvailable: init, audit, status"
            ;;
    esac
}

cloudflare_require_local_tools() {
    command -v curl >/dev/null 2>&1 || error "curl is required for Cloudflare setup"
    command -v jq >/dev/null 2>&1 || error "jq is required for Cloudflare setup"
}

cloudflare_api() {
    local method="$1"
    local path="$2"
    local data="${3:-}"
    local url="https://api.cloudflare.com/client/v4$path"
    local response http_code

    if [ -z "${CLOUDFLARE_API_TOKEN:-}" ]; then
        error "CLOUDFLARE_API_TOKEN is not set. Export a scoped Cloudflare API token before running this command."
    fi

    if [ -n "$data" ]; then
        response=$(curl -sS -X "$method" "$url" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            --data "$data" \
            -w '\n%{http_code}')
    else
        response=$(curl -sS -X "$method" "$url" \
            -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
            -H "Content-Type: application/json" \
            -w '\n%{http_code}')
    fi

    http_code=$(printf '%s' "$response" | tail -n1)
    response=$(printf '%s' "$response" | sed '$d')

    if [[ ! "$http_code" =~ ^2 ]]; then
        printf '%s\n' "$response"
        return 0
    fi

    printf '%s\n' "$response"
}

cloudflare_validate_response() {
    local response="$1"
    local label="$2"

    if ! echo "$response" | jq -e '.success == true' >/dev/null 2>&1; then
        echo "$response" | jq -r '.errors[]?.message // empty' 2>/dev/null | sed 's/^/  - /' >&2 || true
        error "Cloudflare API request failed: $label"
    fi
}

cloudflare_get_zone_id() {
    local response
    response=$(cloudflare_api GET "/zones?name=$CLOUDFLARE_ZONE")
    cloudflare_validate_response "$response" "lookup zone"
    echo "$response" | jq -r '.result[0].id // empty'
}

cloudflare_get_account_id() {
    local zone_response
    zone_response=$(cloudflare_api GET "/zones?name=$CLOUDFLARE_ZONE")
    cloudflare_validate_response "$zone_response" "lookup zone account"
    echo "$zone_response" | jq -r '.result[0].account.id // empty'
}

cloudflare_get_or_create_tunnel() {
    local account_id="$1"
    local tunnel_name="$2"
    local response tunnel_id

    response=$(cloudflare_api GET "/accounts/$account_id/cfd_tunnel?name=$tunnel_name")
    cloudflare_validate_response "$response" "lookup tunnel"
    tunnel_id=$(echo "$response" | jq -r '.result[0].id // empty')

    if [ -n "$tunnel_id" ]; then
        echo "$tunnel_id"
        return
    fi

    response=$(cloudflare_api POST "/accounts/$account_id/cfd_tunnel" \
        "$(jq -n --arg name "$tunnel_name" '{name: $name, config_src: "cloudflare"}')")
    cloudflare_validate_response "$response" "create tunnel"
    echo "$response" | jq -r '.result.id'
}

cloudflare_get_tunnel_token() {
    local account_id="$1"
    local tunnel_id="$2"
    local response

    response=$(cloudflare_api GET "/accounts/$account_id/cfd_tunnel/$tunnel_id/token")
    cloudflare_validate_response "$response" "get tunnel token"
    echo "$response" | jq -r '.result'
}

cloudflare_upsert_tunnel_config() {
    local account_id="$1"
    local tunnel_id="$2"
    local app_hostname="$3"
    local app_service="$4"
    local ssh_hostname="$5"

    local desired_rules current_response existing_config payload response
    desired_rules=$(jq -n \
        --arg app_hostname "$app_hostname" \
        --arg app_service "$app_service" \
        --arg ssh_hostname "$ssh_hostname" \
        '[
            { hostname: $app_hostname, service: $app_service },
            { hostname: $ssh_hostname, service: "ssh://localhost:22" }
        ]')

    current_response=$(cloudflare_api GET "/accounts/$account_id/cfd_tunnel/$tunnel_id/configurations")
    if echo "$current_response" | jq -e '.success == true' >/dev/null 2>&1; then
        existing_config=$(echo "$current_response" | jq '.result.config // {}')
    else
        existing_config='{}'
    fi

    payload=$(jq -n \
        --argjson existing "$existing_config" \
        --argjson desired "$desired_rules" \
        '
        def key:
            if has("hostname") then "host:" + .hostname + "|path:" + (.path // "") else "fallback" end;

        ($desired | map(key) | unique) as $desired_keys
        | ($existing.ingress // []) as $existing_ingress
        | ($existing_ingress | map(select((key as $k | ($desired_keys | index($k) | not)) and has("hostname")))) as $preserved
        | ($existing | del(.ingress))
          + {
              ingress: (
                  $preserved
                  + $desired
                  + [($existing_ingress | map(select(has("hostname") | not)) | .[0] // {service: "http_status:404"})]
              )
            }
        | {config: .}')

    response=$(cloudflare_api PUT "/accounts/$account_id/cfd_tunnel/$tunnel_id/configurations" "$payload")
    cloudflare_validate_response "$response" "configure tunnel ingress"
}

cloudflare_upsert_dns_cname() {
    local zone_id="$1"
    local hostname="$2"
    local target="$3"
    local response record_id payload existing_records existing_count

    response=$(cloudflare_api GET "/zones/$zone_id/dns_records?name=$hostname")
    cloudflare_validate_response "$response" "lookup DNS record"
    existing_records=$(echo "$response" | jq '.result // []')
    existing_count=$(echo "$existing_records" | jq 'length')
    record_id=$(echo "$existing_records" | jq -r '.[] | select(.type == "CNAME") | .id' | head -1)
    payload=$(jq -n \
        --arg type "CNAME" \
        --arg name "$hostname" \
        --arg content "$target" \
        '{type: $type, name: $name, content: $content, ttl: 1, proxied: true}')

    if [ -n "$record_id" ]; then
        response=$(cloudflare_api PUT "/zones/$zone_id/dns_records/$record_id" "$payload")
    else
        if [ "$existing_count" -gt 0 ]; then
            echo "$existing_records" | jq -r '.[] | select(.type == "A" or .type == "AAAA") | .id' | while IFS= read -r conflicting_id; do
                [ -n "$conflicting_id" ] || continue
                local delete_response
                delete_response=$(cloudflare_api DELETE "/zones/$zone_id/dns_records/$conflicting_id")
                cloudflare_validate_response "$delete_response" "delete conflicting DNS record"
            done

            local remaining_blockers
            remaining_blockers=$(echo "$existing_records" | jq -r '.[] | select(.type != "A" and .type != "AAAA") | .type' | sort -u | tr '\n' ' ')
            if [ -n "$remaining_blockers" ]; then
                error "Cannot create CNAME for $hostname because non-address DNS records already exist: $remaining_blockers"
            fi
        fi
        response=$(cloudflare_api POST "/zones/$zone_id/dns_records" "$payload")
    fi
    cloudflare_validate_response "$response" "upsert DNS record"
}

cloudflare_upsert_access_app() {
    local account_id="$1"
    local ssh_hostname="$2"
    local response app_id payload

    response=$(cloudflare_api GET "/accounts/$account_id/access/apps?domain=$ssh_hostname")
    cloudflare_validate_response "$response" "lookup Access app"
    app_id=$(echo "$response" | jq -r '.result[0].id // empty')
    payload=$(jq -n \
        --arg name "ShipNode SSH" \
        --arg domain "$ssh_hostname" \
        '{name: $name, domain: $domain, type: "ssh", session_duration: "24h"}')

    if [ -n "$app_id" ]; then
        response=$(cloudflare_api PUT "/accounts/$account_id/access/apps/$app_id" "$payload")
    else
        response=$(cloudflare_api POST "/accounts/$account_id/access/apps" "$payload")
        app_id=$(echo "$response" | jq -r '.result.id // empty')
    fi
    cloudflare_validate_response "$response" "configure Access SSH app"

    if [ -n "${CLOUDFLARE_ACCESS_EMAILS:-}" ] && [ -n "$app_id" ]; then
        cloudflare_upsert_access_policy "$account_id" "$app_id"
    else
        warn "Access app created, but no policy was added. Set CLOUDFLARE_ACCESS_EMAILS to add an email allow policy automatically."
    fi
}

cloudflare_access_policy_count() {
    local account_id="$1"
    local ssh_hostname="$2"
    local response app_id

    response=$(cloudflare_api GET "/accounts/$account_id/access/apps?domain=$ssh_hostname")
    cloudflare_validate_response "$response" "lookup Access app policies"
    app_id=$(echo "$response" | jq -r '.result[0].id // empty')
    [ -n "$app_id" ] || echo "0"
    [ -n "$app_id" ] || return

    response=$(cloudflare_api GET "/accounts/$account_id/access/apps/$app_id/policies")
    cloudflare_validate_response "$response" "lookup Access policy count"
    echo "$response" | jq '.result | length'
}

cloudflare_upsert_access_policy() {
    local account_id="$1"
    local app_id="$2"
    local response policy_id include_json payload

    include_json=$(printf '%s' "$CLOUDFLARE_ACCESS_EMAILS" | jq -R 'split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(length > 0)) | map({email: {email: .}})')
    payload=$(jq -n \
        --arg name "ShipNode SSH allowed users" \
        --arg decision "allow" \
        --argjson include "$include_json" \
        '{name: $name, decision: $decision, include: $include}')

    response=$(cloudflare_api GET "/accounts/$account_id/access/apps/$app_id/policies")
    cloudflare_validate_response "$response" "lookup Access policies"
    policy_id=$(echo "$response" | jq -r '.result[]? | select(.name == "ShipNode SSH allowed users") | .id' | head -1)

    if [ -n "$policy_id" ]; then
        response=$(cloudflare_api PUT "/accounts/$account_id/access/apps/$app_id/policies/$policy_id" "$payload")
    else
        response=$(cloudflare_api POST "/accounts/$account_id/access/apps/$app_id/policies" "$payload")
    fi
    cloudflare_validate_response "$response" "configure Access SSH policy"
}

cloudflare_app_service() {
    if [ "$APP_TYPE" = "backend" ]; then
        echo "http://localhost:$BACKEND_PORT"
    else
        echo "http://localhost:80"
    fi
}

cloudflare_install_remote_service() {
    local tunnel_token="$1"
    remote_exec bash -s "$tunnel_token" << 'ENDSSH'
        set -e
        TUNNEL_TOKEN="$1"
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if ! command -v cloudflared >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
                curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | $SUDO tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
                echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" | $SUDO tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
                $SUDO apt-get update
                $SUDO apt-get install -y cloudflared
            elif command -v dnf >/dev/null 2>&1; then
                $SUDO dnf install -y cloudflared
            elif command -v yum >/dev/null 2>&1; then
                $SUDO yum install -y cloudflared
            else
                echo "ERROR: Install cloudflared manually, then rerun shipnode cloudflare init."
                exit 1
            fi
        fi

        if systemctl list-unit-files | grep -q '^cloudflared.service'; then
            $SUDO systemctl stop cloudflared 2>/dev/null || true
        fi

        $SUDO cloudflared service install "$TUNNEL_TOKEN" >/dev/null
        $SUDO systemctl enable cloudflared >/dev/null 2>&1 || true
        $SUDO systemctl restart cloudflared
ENDSSH
}

cloudflare_lockdown_remote_firewall() {
    remote_exec bash << 'ENDSSH'
        set -e
        SUDO=""
        if [ "$EUID" -ne 0 ]; then
            SUDO="sudo"
        fi

        if ! command -v ufw >/dev/null 2>&1; then
            if command -v apt-get >/dev/null 2>&1; then
                $SUDO apt-get update
                $SUDO apt-get install -y ufw
            else
                echo "UFW is not installed; skipping firewall lockdown."
                exit 0
            fi
        fi

        $SUDO ufw default deny incoming >/dev/null
        $SUDO ufw default allow outgoing >/dev/null
        $SUDO ufw delete allow 22/tcp >/dev/null 2>&1 || true
        $SUDO ufw delete allow 80/tcp >/dev/null 2>&1 || true
        $SUDO ufw delete allow 443/tcp >/dev/null 2>&1 || true
        echo "y" | $SUDO ufw enable >/dev/null
ENDSSH
}

cloudflare_with_bootstrap_host() {
    if [ -n "${SHIPNODE_BOOTSTRAP_SSH_HOST:-}" ]; then
        SSH_HOST="$SHIPNODE_BOOTSTRAP_SSH_HOST"
        SSH_PROXY_MODE="direct"
    fi
}

cmd_cloudflare_init() {
    load_config
    cloudflare_require_local_tools

    [ "$CLOUDFLARE_ENABLED" = "true" ] || error "Set CLOUDFLARE_ENABLED=true in $SHIPNODE_CONFIG_FILE"
    [ -n "${DOMAIN:-}" ] || error "DOMAIN is required for Cloudflare setup"
    [ -n "${SSH_HOST:-}" ] || error "SSH_HOST is required for Cloudflare SSH setup"
    [ -n "${CLOUDFLARE_ZONE:-}" ] || error "CLOUDFLARE_ZONE is required (example: example.com)"

    if is_raw_ip_address "$SSH_HOST"; then
        error "SSH_HOST must be a Cloudflare SSH hostname, not a raw IP"
    fi

    local app_hostname="${CLOUDFLARE_APP_HOSTNAME:-$DOMAIN}"
    local ssh_hostname="${CLOUDFLARE_SSH_HOSTNAME:-$SSH_HOST}"
    local tunnel_name="${CLOUDFLARE_TUNNEL_NAME:-shipnode-$(basename "$REMOTE_PATH")}"
    local app_service
    app_service=$(cloudflare_app_service)

    cloudflare_with_bootstrap_host
    if ! remote_exec "exit" >/dev/null 2>&1; then
        error "Cannot reach the server. For first-time setup, export SHIPNODE_BOOTSTRAP_SSH_HOST with a temporary private/direct SSH hostname or IP."
    fi

    info "Preparing Cloudflare Tunnel for $app_hostname and $ssh_hostname"

    local zone_id account_id tunnel_id tunnel_token tunnel_target
    zone_id=$(cloudflare_get_zone_id)
    [ -n "$zone_id" ] || error "Cloudflare zone not found: $CLOUDFLARE_ZONE"
    account_id=$(cloudflare_get_account_id)
    [ -n "$account_id" ] || error "Cloudflare account not found for zone: $CLOUDFLARE_ZONE"
    tunnel_id=$(cloudflare_get_or_create_tunnel "$account_id" "$tunnel_name")
    tunnel_target="$tunnel_id.cfargotunnel.com"
    tunnel_token=$(cloudflare_get_tunnel_token "$account_id" "$tunnel_id")

    cloudflare_upsert_tunnel_config "$account_id" "$tunnel_id" "$app_hostname" "$app_service" "$ssh_hostname"
    cloudflare_upsert_dns_cname "$zone_id" "$app_hostname" "$tunnel_target"
    cloudflare_upsert_dns_cname "$zone_id" "$ssh_hostname" "$tunnel_target"
    cloudflare_upsert_access_app "$account_id" "$ssh_hostname"
    local access_policy_count
    access_policy_count=$(cloudflare_access_policy_count "$account_id" "$ssh_hostname")

    info "Installing cloudflared on the server"
    cloudflare_install_remote_service "$tunnel_token"

    if [ "$CLOUDFLARE_LOCKDOWN_FIREWALL" = "true" ]; then
        if [ "${access_policy_count:-0}" -gt 0 ]; then
            warn "Locking down inbound 22/80/443. Make sure Cloudflare SSH works before closing this terminal."
            cloudflare_lockdown_remote_firewall
        else
            warn "Skipping firewall lockdown because no Cloudflare Access policy is configured for $ssh_hostname."
            warn "Set CLOUDFLARE_ACCESS_EMAILS and rerun, or add an Access policy in Cloudflare before locking down the origin."
        fi
    fi

    success "Cloudflare easy mode configured"
    echo "  App: https://$app_hostname"
    echo "  SSH: $SSH_USER@$ssh_hostname via Cloudflare Access"
    echo ""
    info "Run 'shipnode cloudflare audit' to verify the setup."
}

cmd_cloudflare_status() {
    load_config

    info "Cloudflare configuration:"
    echo "  Enabled:     $CLOUDFLARE_ENABLED"
    echo "  App host:    ${CLOUDFLARE_APP_HOSTNAME:-$DOMAIN}"
    echo "  SSH host:    ${CLOUDFLARE_SSH_HOSTNAME:-$SSH_HOST}"
    echo "  SSH proxy:   $SSH_PROXY_MODE"
    echo "  Firewall:    $CLOUDFLARE_LOCKDOWN_FIREWALL"
    echo ""

    info "Remote cloudflared status:"
    remote_exec "systemctl is-active cloudflared 2>/dev/null || echo inactive"
}

cmd_cloudflare_audit() {
    load_config

    local has_issues=false
    local app_hostname="${CLOUDFLARE_APP_HOSTNAME:-$DOMAIN}"
    local ssh_hostname="${CLOUDFLARE_SSH_HOSTNAME:-$SSH_HOST}"

    info "Auditing Cloudflare origin privacy..."
    echo ""

    if grep -Eq 'SSH_HOST=([0-9]{1,3}\.){3}[0-9]{1,3}|SSH_HOST=.*:' "$SHIPNODE_CONFIG_FILE"; then
        echo "  ✗ $SHIPNODE_CONFIG_FILE contains a raw IP in SSH_HOST"
        has_issues=true
    else
        echo "  ✓ SSH_HOST is not a raw IP in $SHIPNODE_CONFIG_FILE"
    fi

    if [ "$SSH_PROXY_MODE" = "cloudflare" ]; then
        echo "  ✓ SSH proxy mode is cloudflare"
    else
        echo "  ✗ SSH_PROXY_MODE should be cloudflare"
        has_issues=true
    fi

    if command -v cloudflared >/dev/null 2>&1; then
        echo "  ✓ local cloudflared is installed"
    else
        echo "  ✗ local cloudflared is required for Cloudflare SSH deploys"
        has_issues=true
    fi

    if command -v dig >/dev/null 2>&1 && [ -n "$app_hostname" ]; then
        local dns_answer
        dns_answer=$(dig +short "$app_hostname" 2>/dev/null | tr '\n' ' ')
        if echo "$dns_answer" | grep -Eq '([0-9]{1,3}\.){3}[0-9]{1,3}'; then
            echo "  ⚠ $app_hostname resolves to an A record; confirm it is Cloudflare, not your origin"
        elif echo "$dns_answer" | grep -q 'cfargotunnel.com'; then
            echo "  ✓ $app_hostname resolves through Cloudflare Tunnel"
        else
            echo "  ℹ DNS answer for $app_hostname: ${dns_answer:-none}"
        fi
    else
        echo "  ℹ dig not available; skipping DNS audit"
    fi

    if remote_exec "systemctl is-active cloudflared" >/dev/null 2>&1; then
        echo "  ✓ remote cloudflared service is active"
    else
        echo "  ✗ remote cloudflared service is not active"
        has_issues=true
    fi

    local ufw_status
    ufw_status=$(remote_exec "sudo ufw status 2>/dev/null || true")
    if echo "$ufw_status" | grep -q "Status: active"; then
        if echo "$ufw_status" | grep -Eq '(^|[[:space:]])(22|80|443)/tcp[[:space:]]+ALLOW'; then
            echo "  ✗ UFW still allows one of 22/80/443 publicly"
            has_issues=true
        else
            echo "  ✓ UFW does not publicly allow 22/80/443"
        fi
    else
        echo "  ⚠ UFW is not active or unavailable; verify provider firewall blocks 22/80/443"
    fi

    echo ""
    if [ "$has_issues" = true ]; then
        error "Cloudflare audit found issues."
    fi
    success "Cloudflare audit passed."
}
