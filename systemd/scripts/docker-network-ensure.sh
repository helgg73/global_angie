#!/bin/bash
# Скрипт создания Docker сети global_proxy
# Используется systemd сервисом docker-network-global_proxy.service

NETWORK_NAME="global_proxy"
NETWORK_DRIVER="bridge"

# Проверяем существование сети
if docker network inspect "$NETWORK_NAME" > /dev/null 2>&1; then
    echo "✓ Docker network '$NETWORK_NAME' already exists"
    exit 0
else
    echo "✗ Docker network '$NETWORK_NAME' not found, creating..."
    if docker network create \
        --driver "$NETWORK_DRIVER" \
        --attachable \
        --label "created_by=systemd" \
        --label "managed_by=angie-proxy" \
        "$NETWORK_NAME"; then
        echo "✓ Docker network '$NETWORK_NAME' created successfully"
        exit 0
    else
        echo "✗ Error creating the network $NETWORK_NAME"
        exit 1
    fi
fi