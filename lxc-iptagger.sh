#!/bin/bash

set -euo pipefail

function get_ip() {
    local vmid="$1"
    pct exec "$vmid" -- ip -4 addr show |
        awk '/inet / {print $2}' | cut -d/ -f1 |
        grep -E '^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01]))' |
        head -n1
}

function update_tag() {
    local vmid="$1"
    local ip="$2"
    local conf_file="/etc/pve/lxc/${vmid}.conf"

    if [[ ! -f "$conf_file" ]]; then
        echo "⚠️  Config file not found for VMID $vmid"
        return
    fi

    local existing_tags raw_tags current_ip=""
    raw_tags=$(grep -E '^tags:' "$conf_file" | cut -d':' -f2- | xargs || true)

    for tag in ${raw_tags//,/ }; do
        if [[ "$tag" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            current_ip="$tag"
        else
            existing_tags+="$tag,"
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
    new_tags="${new_tags%,}"

    if grep -q '^tags:' "$conf_file"; then
        sed -i "s/^tags:.*/tags: ${new_tags}/" "$conf_file"
    else
        echo "tags: ${new_tags}" >> "$conf_file"
    fi
}

for vmid in $(pct list | awk 'NR>1 {print $1}'); do
    echo "🔍 Processing VMID: $vmid"

    if ! pct status "$vmid" | grep -q "running"; then
        echo "⏸️  VMID $vmid is not running. Skipping."
        continue
    fi

    ip=$(get_ip "$vmid")
    if [[ -z "$ip" ]]; then
        echo "❌ No valid IP found for VMID $vmid"
        continue
    fi

    update_tag "$vmid" "$ip"
done
