#!/bin/sh
set -eu

bin="${UZ_BIN:-/srv/uwebzockets}"
pids=""

for mode in h2c tls h3; do
    UZ_MODE="$mode" "$bin" &
    pids="$pids $!"
done
sleep 5

UZ_MODE=http "$bin" &
pids="$pids $!"

trap 'kill $pids 2>/dev/null' TERM INT

while :; do
    for pid in $pids; do
        if ! kill -0 "$pid" 2>/dev/null; then
            kill $pids 2>/dev/null || true
            wait || true
            exit 1
        fi
    done
    sleep 1
done
