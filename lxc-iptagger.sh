#!/bin/bash

set -euo pipefail

function get_ip() {
    local vmid="$1"
    # The '|| true' prevents the script from exiting if no IP is found
    pct exec "$vmid" -- ip -4 addr show |
        awk '/inet / {print $2}' | cut -d/ -f1 |
        grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01]))' |
        head -n1 || true
}

function update_tag() {
    local vmid="$1"
    local ip="$2"
    local conf_file="/etc/pve/lxc/${vmid}.conf"

    if [[ ! -f "$conf_file" ]]; then
        echo "⚠️  Config file not found for VMID $vmid"
        return
    fi

    local existing_tags=""
    local raw_tags
    local current_ip=""
    
    # Read existing tags, handling the case where the line might not exist
    raw_tags=$(grep -E '^tags:' "$conf_file" | cut -d':' -f2- | xargs || true)

    # Separate IP tags from other tags
    for tag in ${raw_tags//,/ }; do
        if [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            current_ip="$tag"
        else
            # Append tag to list, ensuring it's not empty
            if [[ -n "$tag" ]]; then
                existing_tags+="$tag,"
            fi
        fi
    done

    if [[ "$current_ip" == "$ip" ]]; then
        echo "ℹ️  VMID $vmid already tagged with IP $ip"
        return
    elif [[ -n "$current_ip" ]]; then
        echo "🔁 VMID $vmid IP tag updated from $current_ip to $ip"
    else
        echo "➕ VMID $vmid tagged with new IP $ip"
    fi

    local new_tags="${existing_tags}${ip}"
    new_tags="${new_tags%,}" # Remove trailing comma if any

    # Use a temporary file and atomic move for safer update
    local temp_file
    temp_file=$(mktemp)
    
    # Ensure cleanup of temp_file on script exit or interruption
    trap 'rm -f "$temp_file"' EXIT

    if grep -q '^tags:' "$conf_file"; then
        sed "s/^tags:.*/tags: ${new_tags}/" "$conf_file" > "$temp_file"
    else
        cp "$conf_file" "$temp_file"
        echo -e "\ntags: ${new_tags}" >> "$temp_file"
    fi
    
    # Atomically replace the old config file with the new one
    mv "$temp_file" "$conf_file"
    
    # Remove the trap since the file has been moved
    trap - EXIT
}

function process_vmid() {
    local vmid="$1"
    echo "🔍 Processing VMID: $vmid"

    local ip
    ip=$(get_ip "$vmid")
    if [[ -z "$ip" ]]; then
        echo "❌ No valid IP found for VMID $vmid"
        return
    fi

    update_tag "$vmid" "$ip"
}

export -f get_ip
export -f update_tag
export -f process_vmid

# Get all running VMIDs and process them in parallel
# The number of parallel jobs is set to the number of CPU cores, or 8 if 'nproc' is not available.
N_JOBS=$(nproc 2>/dev/null || echo 8)
pct list | awk 'NR>1 && $2 == "running" {print $1}' | xargs -I {} -P "$N_JOBS" bash -c 'process_vmid "{}"'

echo "✅ All running containers have been processed."
