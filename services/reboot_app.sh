#!/bin/bash
sleep 1
cd "$(dirname "$0")/../.."
exec python3 /nsatt/nsatt.py "$@"
