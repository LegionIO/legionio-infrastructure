#!/bin/bash
set -euo pipefail

export GEM_HOME=/opt/legion/gems
export PATH=/opt/legion/gems/bin:/opt/legion/bin:$PATH

# allow config override via mounted volume
if [ -f /opt/legion/config/settings.json ]; then
  export LEGION_SETTINGS_FILE=/opt/legion/config/settings.json
fi

# drop to legion user if running as root
if [ "$(id -u)" = "0" ]; then
  exec gosu legion "$@"
fi

exec "$@"
