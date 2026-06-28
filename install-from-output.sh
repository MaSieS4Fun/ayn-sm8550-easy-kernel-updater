#!/bin/bash
# Legacy interactive installer — prefer ./update.sh (backup + reboot).
set -euo pipefail

echo "Use ./update.sh for backup, install, and reboot."
echo ""
exec "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/update.sh"
