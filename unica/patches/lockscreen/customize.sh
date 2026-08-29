#!/usr/bin/env bash
# ==============================================================================
# Unica Patch Engine Script - LCD Density Sync
# Path: /unica/patches/lockscreen/customize.sh
# ==============================================================================

set -e

echo "[+] Starting LCD Density Enforcement Patch..."

# 1.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

#
WORK_SCOPE="${WORK_DIR:-${TARGET_DIR:-$PROJECT_ROOT/out}}"

echo "[+] Project Root : $PROJECT_ROOT"
echo "[+] Search Scope : $WORK_SCOPE"

#
if [ ! -d "$WORK_SCOPE" ]; then
    echo "[-] Warning: Work scope directory not found: $WORK_SCOPE"
    echo "[-] Skipping property injection."
    exit 0
fi

# ------------------------------------------------------------------------------
# 2.
# ------------------------------------------------------------------------------
VENDOR_DENSITY=""

#
while IFS= read -r -d '' V_FILE; do
    if [ -f "$V_FILE" ]; then
        DENSITY_VAL=$(grep -E "^ro\.sf\.lcd_density=" "$V_FILE" | cut -d'=' -f2 | tr -d '\r\n ')
        if [ -n "$DENSITY_VAL" ]; then
            VENDOR_DENSITY="$DENSITY_VAL"
            echo "[+] Found Vendor LCD Density: $VENDOR_DENSITY in $V_FILE"
            break
        fi
    fi
done < <(find "$WORK_SCOPE" -type f \( -name "vendor.prop" -o -name "build.prop" \) -path "*/vendor/*" -print0 2>/dev/null)

#
if [ -z "$VENDOR_DENSITY" ]; then
    echo "[!] Warning: Could not find ro.sf.lcd_density in vendor. Searching in all prop files..."
    while IFS= read -r -d '' ANY_PROP; do
        DENSITY_VAL=$(grep -E "^ro\.sf\.lcd_density=" "$ANY_PROP" | cut -d'=' -f2 | tr -d '\r\n ')
        if [ -n "$DENSITY_VAL" ]; then
            VENDOR_DENSITY="$DENSITY_VAL"
            echo "[+] Found Fallback LCD Density: $VENDOR_DENSITY in $ANY_PROP"
            break
        fi
    done < <(find "$WORK_SCOPE" -type f -name "*.prop" -print0 2>/dev/null)
fi

if [ -z "$VENDOR_DENSITY" ]; then
    echo "[-] Error: Unable to determine Vendor LCD Density! Aborting density enforcement."
    exit 0
fi

echo "[+] Target LCD Density to enforce: $VENDOR_DENSITY"

# ------------------------------------------------------------------------------
# 3.
# ------------------------------------------------------------------------------
PROCESSED_COUNT=0

while IFS= read -r -d '' PROP_FILE; do
    if [ -f "$PROP_FILE" ]; then
        echo "[+] Processing System Prop: $PROP_FILE"

#
        sed -i '/^ro\.sf\.lcd_density=/d' "$PROP_FILE"
        sed -i '/^ro\.sf\.init\.lcd_density=/d' "$PROP_FILE"
        sed -i '/^vendor\.display\.lcd_density=/d' "$PROP_FILE"
        sed -i '/^persist\.sys\.display\.density=/d' "$PROP_FILE"
        
#
        echo "ro.sf.lcd_density=$VENDOR_DENSITY" >> "$PROP_FILE"
        echo "ro.sf.init.lcd_density=$VENDOR_DENSITY" >> "$PROP_FILE"
        echo "vendor.display.lcd_density=$VENDOR_DENSITY" >> "$PROP_FILE"
        echo "persist.sys.display.density=$VENDOR_DENSITY" >> "$PROP_FILE"

        PROCESSED_COUNT=$((PROCESSED_COUNT + 1))
    fi
done < <(find "$WORK_SCOPE" -type f -name "build.prop" -path "*/system/*" -print0 2>/dev/null)

if [ $PROCESSED_COUNT -eq 0 ]; then
    echo "[!] Warning: Could not find build.prop inside system partition!"
else
    echo "[+] Successfully enforced density ($VENDOR_DENSITY) across $PROCESSED_COUNT file(s)."
fi

echo "[+] DPI FIX Completed Successfully!"