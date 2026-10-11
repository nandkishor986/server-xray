#!/bin/bash

# Server Health Report Script
# All commands are READ-ONLY — safe to run on production servers.
# Some sections (dmesg, auth logs) may require sudo for full output.

# ── Color codes ──────────────────────────────────────────────────────────────
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
NC=$'\033[0m'

SEP="──────────────────────────────────────────────────────"

section() { echo -e "\n${CYAN}${BOLD}$1${NC}\n${SEP}"; }
ok()      { echo -e "  ${GREEN}✔${NC} $1"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $1"; }
crit()    { echo -e "  ${RED}✘${NC} $1"; }

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║      SERVER HEALTH REPORT            ║"
echo "  ║  Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')   ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"

# ── 1. OS & SYSTEM IDENTITY ──────────────────────────────────────────────────
section "1. SYSTEM IDENTITY"

HOSTNAME=$(hostname -f 2>/dev/null || hostname)
KERNEL=$(uname -r)
ARCH=$(uname -m)
OS=$(grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"')

echo "  Hostname   : ${BOLD}${HOSTNAME}${NC}"
echo "  OS         : ${OS}"
echo "  Kernel     : ${KERNEL}"
echo "  Arch       : ${ARCH}"

# ── 2. UPTIME & LOAD AVERAGE ─────────────────────────────────────────────────
section "2. UPTIME & LOAD AVERAGE"

UPTIME_STR=$(uptime -p 2>/dev/null || uptime)
LOAD=$(cat /proc/loadavg)
LOAD1=$(echo $LOAD | awk '{print $1}')
LOAD5=$(echo $LOAD | awk '{print $2}')
LOAD15=$(echo $LOAD | awk '{print $3}')
CPU_CORES=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo)

echo "  Uptime     : ${UPTIME_STR}"
echo "  CPU Cores  : ${CPU_CORES}"
echo "  Load Avg   : ${LOAD1} (1m)  ${LOAD5} (5m)  ${LOAD15} (15m)"

# Warn if load > number of cores
LOAD1_INT=$(echo "$LOAD1" | cut -d. -f1)
if [ "$LOAD1_INT" -ge "$CPU_CORES" ] 2>/dev/null; then
    crit "1-min load (${LOAD1}) >= CPU cores (${CPU_CORES}) — system may be overloaded"
elif (( $(echo "$LOAD1 > $CPU_CORES * 0.7" | bc -l 2>/dev/null || echo 0) )); then
    warn "1-min load (${LOAD1}) is above 70% of CPU capacity"
else
    ok "Load average is within healthy range"
fi

# ── 3. CPU USAGE ─────────────────────────────────────────────────────────────
section "3. CPU USAGE"

# Use /proc/stat for reliable cross-distro CPU metrics
read CPU_LINE < /proc/stat
CPU_VALS=($CPU_LINE)
USER=${CPU_VALS[1]}; NICE=${CPU_VALS[2]}; SYS=${CPU_VALS[3]}
IDLE=${CPU_VALS[4]}; IOWAIT=${CPU_VALS[5]}; STEAL=${CPU_VALS[8]:-0}

TOTAL=$((USER + NICE + SYS + IDLE + IOWAIT + STEAL))
IDLE_PCT=$(awk "BEGIN {printf \"%.1f\", ${IDLE}*100/${TOTAL}}")
USED_PCT=$(awk "BEGIN {printf \"%.1f\", 100 - ${IDLE_PCT}}")
IOWAIT_PCT=$(awk "BEGIN {printf \"%.1f\", ${IOWAIT}*100/${TOTAL}}")
STEAL_PCT=$(awk "BEGIN {printf \"%.1f\", ${STEAL}*100/${TOTAL}}")

echo "  CPU Used   : ${BOLD}${USED_PCT}%${NC}"
echo "  CPU Idle   : ${IDLE_PCT}%"
echo "  I/O Wait   : ${IOWAIT_PCT}%   (high = disk bottleneck)"
echo "  CPU Steal  : ${STEAL_PCT}%   (non-zero = VM host is throttling you)"

USED_INT=$(echo "$USED_PCT" | cut -d. -f1)
IOWAIT_INT=$(echo "$IOWAIT_PCT" | cut -d. -f1)
[ "$USED_INT" -ge 90 ] 2>/dev/null && crit "CPU usage critical: ${USED_PCT}%"
[ "$USED_INT" -ge 75 ] && [ "$USED_INT" -lt 90 ] 2>/dev/null && warn "CPU usage elevated: ${USED_PCT}%"
[ "$USED_INT" -lt 75 ] 2>/dev/null && ok "CPU usage normal: ${USED_PCT}%"
[ "$IOWAIT_INT" -ge 20 ] 2>/dev/null && warn "High I/O wait (${IOWAIT_PCT}%) — possible disk bottleneck"
[ "$(echo "$STEAL_PCT > 5" | bc -l 2>/dev/null)" = "1" ] && warn "CPU steal (${STEAL_PCT}%) is elevated — VM host may be oversubscribed"

# ── 4. MEMORY USAGE ──────────────────────────────────────────────────────────
section "4. MEMORY USAGE"

MEM_TOTAL=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_FREE=$(grep MemFree /proc/meminfo | awk '{print $2}')
MEM_AVAIL=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
MEM_BUFFERS=$(grep Buffers /proc/meminfo | awk '{print $2}')
MEM_CACHED=$(grep "^Cached:" /proc/meminfo | awk '{print $2}')
MEM_USED=$((MEM_TOTAL - MEM_AVAIL))
MEM_PCT=$(awk "BEGIN {printf \"%.1f\", ${MEM_USED}*100/${MEM_TOTAL}}")

MEM_TOTAL_MB=$((MEM_TOTAL / 1024))
MEM_USED_MB=$((MEM_USED / 1024))
MEM_AVAIL_MB=$((MEM_AVAIL / 1024))
MEM_BUFFERS_MB=$((MEM_BUFFERS / 1024))
MEM_CACHED_MB=$((MEM_CACHED / 1024))

echo "  Total      : ${MEM_TOTAL_MB} MB"
echo "  Used       : ${BOLD}${MEM_USED_MB} MB (${MEM_PCT}%)${NC}"
echo "  Available  : ${MEM_AVAIL_MB} MB   (free + reclaimable cache)"
echo "  Buffers    : ${MEM_BUFFERS_MB} MB"
echo "  Cached     : ${MEM_CACHED_MB} MB"

MEM_PCT_INT=$(echo "$MEM_PCT" | cut -d. -f1)
[ "$MEM_PCT_INT" -ge 90 ] 2>/dev/null && crit "Memory usage critical: ${MEM_PCT}%"
[ "$MEM_PCT_INT" -ge 75 ] && [ "$MEM_PCT_INT" -lt 90 ] 2>/dev/null && warn "Memory usage elevated: ${MEM_PCT}%"
[ "$MEM_PCT_INT" -lt 75 ] 2>/dev/null && ok "Memory usage normal: ${MEM_PCT}%"

# ── 5. SWAP USAGE ────────────────────────────────────────────────────────────
section "5. SWAP USAGE"

SWAP_TOTAL=$(grep SwapTotal /proc/meminfo | awk '{print $2}')
SWAP_FREE=$(grep SwapFree /proc/meminfo | awk '{print $2}')
SWAP_USED=$((SWAP_TOTAL - SWAP_FREE))

if [ "$SWAP_TOTAL" -eq 0 ] 2>/dev/null; then
    warn "No swap configured — OOM killer will trigger under severe memory pressure"
else
    SWAP_TOTAL_MB=$((SWAP_TOTAL / 1024))
    SWAP_USED_MB=$((SWAP_USED / 1024))
    SWAP_FREE_MB=$((SWAP_FREE / 1024))
    SWAP_PCT=$(awk "BEGIN {printf \"%.1f\", ${SWAP_USED}*100/${SWAP_TOTAL}}")
    SWAP_PCT_INT=$(echo "$SWAP_PCT" | cut -d. -f1)

    echo "  Total      : ${SWAP_TOTAL_MB} MB"
    echo "  Used       : ${BOLD}${SWAP_USED_MB} MB (${SWAP_PCT}%)${NC}"
    echo "  Free       : ${SWAP_FREE_MB} MB"

    [ "$SWAP_PCT_INT" -ge 50 ] 2>/dev/null && crit "Swap usage high (${SWAP_PCT}%) — system is under memory pressure"
    [ "$SWAP_PCT_INT" -gt 0 ] && [ "$SWAP_PCT_INT" -lt 50 ] 2>/dev/null && warn "Swap in use (${SWAP_PCT}%) — monitor memory closely"
    [ "$SWAP_PCT_INT" -eq 0 ] 2>/dev/null && ok "Swap not in use — memory is healthy"
fi

# ── 6. DISK USAGE (ALL PARTITIONS) ───────────────────────────────────────────
section "6. DISK USAGE (ALL PARTITIONS)"

printf "  %-20s %-8s %-8s %-8s %s\n" "Mount Point" "Total" "Used" "Free" "Usage"
echo "  ${SEP:2:50}"

df -h --output=target,size,used,avail,pcent 2>/dev/null | tail -n +2 | grep -v "^/sys\|^/proc\|^/dev/loop\|^tmpfs\|^udev\|^devtmpfs\|^none" | while read -r TARGET SIZE USED AVAIL PCENT; do
    PCT_INT=${PCENT//%/}
    printf "  %-20s %-8s %-8s %-8s %s\n" "$TARGET" "$SIZE" "$USED" "$AVAIL" "$PCENT"
    if [ "$PCT_INT" -ge 90 ] 2>/dev/null; then
        echo -e "    ${RED}✘ CRITICAL: ${TARGET} is ${PCENT} full!${NC}"
    elif [ "$PCT_INT" -ge 75 ] 2>/dev/null; then
        echo -e "    ${YELLOW}⚠  WARNING: ${TARGET} is ${PCENT} full${NC}"
    fi
done

# Inode usage
echo ""
echo "  Inode Usage (exhausted inodes = can't create files even with free space):"
printf "  %-20s %-10s %-10s %s\n" "Mount Point" "IUsed%" "IFree" "Total Inodes"
df -i --output=target,ipcent,ifree,itotal 2>/dev/null | tail -n +2 | grep -v "^/sys\|^/proc\|^/dev/loop\|^tmpfs\|^udev\|^devtmpfs\|^none" | while read -r TARGET IPCENT IFREE ITOTAL; do
    IPCT_INT=${IPCENT//%/}
    printf "  %-20s %-10s %-10s %s\n" "$TARGET" "$IPCENT" "$IFREE" "$ITOTAL"
    [ "$IPCT_INT" -ge 90 ] 2>/dev/null && echo -e "    ${RED}✘ CRITICAL: Inodes on ${TARGET} nearly exhausted!${NC}"
done

# ── 7. TOP PROCESSES BY CPU ──────────────────────────────────────────────────
section "7. TOP 10 PROCESSES BY CPU"

printf "  %-8s %-25s %-8s %-8s %s\n" "PID" "Command" "CPU%" "MEM%" "User"
echo "  ${SEP:2:55}"
ps -eo pid,comm,%cpu,%mem,user --sort=-%cpu 2>/dev/null | head -n 11 | tail -n +2 | \
    awk '{printf "  %-8s %-25s %-8s %-8s %s\n", $1, $2, $3, $4, $5}'

# ── 8. TOP PROCESSES BY MEMORY ───────────────────────────────────────────────
section "8. TOP 10 PROCESSES BY MEMORY"

printf "  %-8s %-25s %-8s %-8s %s\n" "PID" "Command" "MEM%" "RSS(KB)" "User"
echo "  ${SEP:2:55}"
ps -eo pid,comm,%mem,rss,user --sort=-%mem 2>/dev/null | head -n 11 | tail -n +2 | \
    awk '{printf "  %-8s %-25s %-8s %-8s %s\n", $1, $2, $3, $4, $5}'

# ── 9. ZOMBIE PROCESSES ──────────────────────────────────────────────────────
section "9. ZOMBIE PROCESSES"

ZOMBIES=$(ps aux 2>/dev/null | awk '$8 == "Z"' | wc -l)
if [ "$ZOMBIES" -eq 0 ] 2>/dev/null; then
    ok "No zombie processes found"
else
    crit "${ZOMBIES} zombie process(es) detected:"
    ps aux 2>/dev/null | awk 'NR==1 || $8 == "Z"' | head -6
fi

# ── 10. NETWORK I/O STATS ────────────────────────────────────────────────────
section "10. NETWORK INTERFACES & I/O"

# Show active non-loopback interfaces
for IFACE in $(ls /sys/class/net/ 2>/dev/null | grep -v lo); do
    STATE=$(cat /sys/class/net/${IFACE}/operstate 2>/dev/null)
    RX_BYTES=$(cat /sys/class/net/${IFACE}/statistics/rx_bytes 2>/dev/null || echo 0)
    TX_BYTES=$(cat /sys/class/net/${IFACE}/statistics/tx_bytes 2>/dev/null || echo 0)
    RX_ERRORS=$(cat /sys/class/net/${IFACE}/statistics/rx_errors 2>/dev/null || echo 0)
    TX_ERRORS=$(cat /sys/class/net/${IFACE}/statistics/tx_errors 2>/dev/null || echo 0)
    RX_DROP=$(cat /sys/class/net/${IFACE}/statistics/rx_dropped 2>/dev/null || echo 0)

    RX_MB=$(awk "BEGIN {printf \"%.1f\", ${RX_BYTES}/1048576}")
    TX_MB=$(awk "BEGIN {printf \"%.1f\", ${TX_BYTES}/1048576}")

    echo "  Interface  : ${BOLD}${IFACE}${NC} [${STATE}]"
    echo "    RX: ${RX_MB} MB   TX: ${TX_MB} MB"
    echo "    Errors — RX: ${RX_ERRORS}  TX: ${TX_ERRORS}  Dropped: ${RX_DROP}"
    [ "$RX_ERRORS" -gt 0 ] || [ "$TX_ERRORS" -gt 0 ] 2>/dev/null && warn "Network errors detected on ${IFACE}"
    echo ""
done

# Active TCP connections count
TCP_ESTABLISHED=$(ss -s 2>/dev/null | grep "TCP:" | awk '{print $4}' | tr -d ',')
[ -n "$TCP_ESTABLISHED" ] && echo "  Active TCP connections: ${TCP_ESTABLISHED}"

# ── 11. OOM KILLER EVENTS ────────────────────────────────────────────────────
section "11. OOM KILLER EVENTS (Last 30 days)"

echo "  Checking kernel ring buffer for OOM kills..."
OOM_EVENTS=$(dmesg --time-format=reltime 2>/dev/null | grep -i "out of memory\|oom.kill\|killed process" | tail -20)

if [ -z "$OOM_EVENTS" ]; then
    # Fallback: check kernel log files
    OOM_EVENTS=$(grep -i "out of memory\|oom.kill\|killed process" /var/log/kern.log /var/log/messages 2>/dev/null | tail -20)
fi

if [ -z "$OOM_EVENTS" ]; then
    ok "No OOM killer events found in kernel logs"
else
    crit "OOM killer events detected — processes were forcibly killed due to memory exhaustion:"
    echo "$OOM_EVENTS" | while IFS= read -r line; do
        echo "  ${RED}|${NC} $line"
    done
fi

# ── 12. KERNEL ERRORS & WARNINGS ─────────────────────────────────────────────
section "12. RECENT KERNEL ERRORS & WARNINGS"

echo "  Checking dmesg for errors/warnings (last 50 entries)..."
KERN_ERRORS=$(dmesg -l err,crit,alert,emerg 2>/dev/null | tail -15)

if [ -z "$KERN_ERRORS" ]; then
    ok "No recent kernel errors found"
else
    warn "Kernel errors detected:"
    echo "$KERN_ERRORS" | while IFS= read -r line; do
        echo "  ${YELLOW}|${NC} $line"
    done
fi

# ── 13. MEMORY PRESSURE EVENTS (vmstat) ──────────────────────────────────────
section "13. MEMORY PRESSURE INDICATORS"

VMSTAT=$(vmstat 1 3 2>/dev/null | tail -1)
if [ -n "$VMSTAT" ]; then
    SI=$(echo $VMSTAT | awk '{print $7}')   # swap-in rate
    SO=$(echo $VMSTAT | awk '{print $8}')   # swap-out rate
    BI=$(echo $VMSTAT | awk '{print $9}')   # block-in (disk reads)
    BO=$(echo $VMSTAT | awk '{print $10}')  # block-out (disk writes)
    WA=$(echo $VMSTAT | awk '{print $16}')  # iowait %

    echo "  Swap-in rate  : ${SI} KB/s  (non-zero = paging from disk)"
    echo "  Swap-out rate : ${SO} KB/s  (non-zero = memory pressure)"
    echo "  Disk reads    : ${BI} blocks/s"
    echo "  Disk writes   : ${BO} blocks/s"
    echo "  I/O wait      : ${WA}%"

    [ "$SI" -gt 0 ] 2>/dev/null && warn "Active swap-in detected — system is reading from swap (memory too low)"
    [ "$SO" -gt 0 ] 2>/dev/null && warn "Active swap-out detected — system is writing to swap (memory pressure)"
    [ "$SI" -eq 0 ] && [ "$SO" -eq 0 ] 2>/dev/null && ok "No active swapping — memory pressure is low"
fi

# ── 14. CPU TEMPERATURE (if available) ───────────────────────────────────────
section "14. CPU TEMPERATURE"

if command -v sensors &>/dev/null; then
    sensors 2>/dev/null | grep -E "Core|Package|temp" | while IFS= read -r line; do
        echo "  $line"
    done
elif [ -d /sys/class/thermal ]; then
    for ZONE in /sys/class/thermal/thermal_zone*/; do
        TEMP_RAW=$(cat "${ZONE}temp" 2>/dev/null)
        TYPE=$(cat "${ZONE}type" 2>/dev/null)
        if [ -n "$TEMP_RAW" ]; then
            TEMP_C=$(awk "BEGIN {printf \"%.1f\", ${TEMP_RAW}/1000}")
            TEMP_INT=$(echo "$TEMP_C" | cut -d. -f1)
            echo "  ${TYPE}: ${TEMP_C}°C"
            [ "$TEMP_INT" -ge 85 ] 2>/dev/null && crit "High temperature on ${TYPE}: ${TEMP_C}°C"
        fi
    done
else
    echo "  Temperature sensors not available (install lm-sensors for CPU temps)"
fi

# ── 15. OPEN FILE DESCRIPTORS ────────────────────────────────────────────────
section "15. OPEN FILE DESCRIPTORS"

FD_MAX=$(cat /proc/sys/fs/file-max 2>/dev/null)
FD_USED=$(cat /proc/sys/fs/file-nr 2>/dev/null | awk '{print $1}')
if [ -n "$FD_MAX" ] && [ -n "$FD_USED" ]; then
    FD_PCT=$(awk "BEGIN {printf \"%.1f\", ${FD_USED}*100/${FD_MAX}}")
    echo "  Used : ${FD_USED}"
    echo "  Max  : ${FD_MAX}"
    echo "  Usage: ${FD_PCT}%"
    FD_PCT_INT=$(echo "$FD_PCT" | cut -d. -f1)
    [ "$FD_PCT_INT" -ge 80 ] 2>/dev/null && warn "File descriptor usage is high: ${FD_PCT}%"
    [ "$FD_PCT_INT" -lt 80 ] 2>/dev/null && ok "File descriptor usage normal: ${FD_PCT}%"
fi

# Top 5 processes by open FDs
echo ""
echo "  Top 5 processes by open file descriptors:"
ls /proc/*/fd 2>/dev/null | grep -oP '/proc/\d+' | sort | uniq -c | sort -rn | head -5 | while read COUNT PPATH; do
    PID=$(echo $PPATH | grep -oP '\d+')
    PNAME=$(cat /proc/${PID}/comm 2>/dev/null || echo "unknown")
    echo "    PID ${PID} (${PNAME}): ${COUNT} FDs"
done

# ── 16. FAILED LOGIN ATTEMPTS ────────────────────────────────────────────────
section "16. FAILED LOGIN ATTEMPTS (Last 10)"

if [[ -f /var/log/auth.log ]]; then
    COUNT=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    echo "  Total failed attempts in auth.log: ${COUNT}"
    echo ""
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -n 10 | while IFS= read -r line; do
        echo "  ${RED}|${NC} $line"
    done
elif [[ -f /var/log/secure ]]; then
    COUNT=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo 0)
    echo "  Total failed attempts in secure log: ${COUNT}"
    echo ""
    grep "Failed password" /var/log/secure 2>/dev/null | tail -n 10 | while IFS= read -r line; do
        echo "  ${RED}|${NC} $line"
    done
else
    echo -e "  ${YELLOW}Log file not found (may need sudo to access)${NC}"
fi

# ── 17. DOCKER HEALTH ────────────────────────────────────────────────────────
section "17. DOCKER HEALTH"

if ! command -v docker &>/dev/null; then
    echo "  Docker is not installed on this system"
else
    # Docker daemon status
    if ! docker info &>/dev/null; then
        crit "Docker daemon is not running or not accessible"
    else
        DOCKER_VER=$(docker version --format '{{.Server.Version}}' 2>/dev/null)
        ok "Docker daemon is running  (v${DOCKER_VER})"
        echo ""

        # ── Container summary ─────────────────────────────────────────────────
        TOTAL_C=$(docker ps -aq 2>/dev/null | wc -l)
        RUNNING_C=$(docker ps -q 2>/dev/null | wc -l)
        STOPPED_C=$(docker ps -aq --filter status=exited 2>/dev/null | wc -l)
        PAUSED_C=$(docker ps -aq --filter status=paused 2>/dev/null | wc -l)
        RESTARTING_C=$(docker ps -aq --filter status=restarting 2>/dev/null | wc -l)

        echo "  Container Summary:"
        echo "    Total      : ${TOTAL_C}"
        echo "    Running    : ${GREEN}${RUNNING_C}${NC}"
        [ "$STOPPED_C" -gt 0 ] 2>/dev/null && echo "    Exited     : ${YELLOW}${STOPPED_C}${NC}" || echo "    Exited     : ${STOPPED_C}"
        [ "$PAUSED_C" -gt 0 ] 2>/dev/null && echo "    Paused     : ${YELLOW}${PAUSED_C}${NC}" || echo "    Paused     : ${PAUSED_C}"
        [ "$RESTARTING_C" -gt 0 ] 2>/dev/null && echo "    Restarting : ${RED}${RESTARTING_C}${NC}" || echo "    Restarting : ${RESTARTING_C}"
        echo ""

        # ── Running containers with resource usage ────────────────────────────
        if [ "$RUNNING_C" -gt 0 ]; then
            echo "  Running Containers (live resource usage):"
            printf "  %-30s %-12s %-10s %-12s %-12s %-10s\n" "Name" "Status" "CPU%" "MEM" "MEM%" "Restarts"
            echo "  $(printf '─%.0s' {1..80})"

            # docker stats gives live snapshot; --no-stream takes one reading
            # Join stats with inspect data for restart count
            docker stats --no-stream --format '{{.Name}}|{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}' 2>/dev/null | \
            while IFS='|' read -r NAME CPU MEM_USAGE MEM_PCT; do
                RESTARTS=$(docker inspect --format '{{.RestartCount}}' "$NAME" 2>/dev/null || echo "?")
                STATUS=$(docker inspect --format '{{.State.Status}}' "$NAME" 2>/dev/null || echo "?")
                HEALTH=$(docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$NAME" 2>/dev/null)

                # Warn on high restart count
                RESTART_DISPLAY="${RESTARTS}"
                [ "$RESTARTS" -ge 5 ] 2>/dev/null && RESTART_DISPLAY="${RED}${RESTARTS}${NC}"
                [ "$RESTARTS" -ge 1 ] && [ "$RESTARTS" -lt 5 ] 2>/dev/null && RESTART_DISPLAY="${YELLOW}${RESTARTS}${NC}"

                printf "  %-30s %-12s %-10s %-12s %-12s %b\n" \
                    "${NAME:0:29}" "$STATUS" "$CPU" "${MEM_USAGE%/*}" "$MEM_PCT" "$RESTART_DISPLAY"

                # Health check status
                if [ "$HEALTH" = "unhealthy" ]; then
                    echo "    ${RED}✘ UNHEALTHY: ${NAME}${NC}"
                elif [ "$HEALTH" = "starting" ]; then
                    echo "    ${YELLOW}⚠  Health check starting: ${NAME}${NC}"
                fi
            done
            echo ""
        fi

        # ── Crash-looping containers (restarted >= 5 times) ───────────────────
        echo "  Containers with High Restart Counts (>=5):"
        CRASH_FOUND=0
        docker ps -a --format '{{.Names}}' 2>/dev/null | while read -r CNAME; do
            RC=$(docker inspect --format '{{.RestartCount}}' "$CNAME" 2>/dev/null || echo 0)
            if [ "$RC" -ge 5 ] 2>/dev/null; then
                CRASH_FOUND=1
                LAST_START=$(docker inspect --format '{{.State.StartedAt}}' "$CNAME" 2>/dev/null)
                crit "${CNAME} has restarted ${RC} times  (last started: ${LAST_START})"
            fi
        done
        [ "$CRASH_FOUND" -eq 0 ] 2>/dev/null && ok "No crash-looping containers"
        echo ""

        # ── Exited containers ─────────────────────────────────────────────────
        if [ "$STOPPED_C" -gt 0 ]; then
            echo "  Exited Containers:"
            printf "  %-30s %-20s %s\n" "Name" "Exited At" "Exit Code"
            echo "  $(printf '─%.0s' {1..60})"
            docker ps -a --filter status=exited \
                --format '{{.Names}}|{{.Status}}' 2>/dev/null | \
            while IFS='|' read -r CNAME CSTATUS; do
                EXIT_CODE=$(docker inspect --format '{{.State.ExitCode}}' "$CNAME" 2>/dev/null || echo "?")
                FINISHED=$(docker inspect --format '{{.State.FinishedAt}}' "$CNAME" 2>/dev/null | cut -c1-19)
                CODE_DISPLAY="$EXIT_CODE"
                [ "$EXIT_CODE" != "0" ] && [ "$EXIT_CODE" != "?" ] 2>/dev/null && CODE_DISPLAY="${RED}${EXIT_CODE} (non-zero — abnormal exit)${NC}"
                printf "  %-30s %-20s %b\n" "${CNAME:0:29}" "$FINISHED" "$CODE_DISPLAY"
            done
            echo ""
        fi

        # ── Docker disk usage ─────────────────────────────────────────────────
        echo "  Docker Disk Usage:"
        docker system df 2>/dev/null | while IFS= read -r line; do
            echo "    $line"
        done
        echo ""

        # ── Dangling images (untagged, wasted space) ──────────────────────────
        DANGLING=$(docker images -f dangling=true -q 2>/dev/null | wc -l)
        if [ "$DANGLING" -gt 0 ]; then
            warn "${DANGLING} dangling image(s) taking up space — run: docker image prune"
        else
            ok "No dangling images"
        fi

        # ── Unused volumes ────────────────────────────────────────────────────
        UNUSED_VOLS=$(docker volume ls -f dangling=true -q 2>/dev/null | wc -l)
        if [ "$UNUSED_VOLS" -gt 0 ]; then
            warn "${UNUSED_VOLS} unused volume(s) found — run: docker volume prune"
        else
            ok "No unused volumes"
        fi

        # ── Docker networks ───────────────────────────────────────────────────
        echo ""
        echo "  Docker Networks:"
        printf "  %-25s %-12s %-15s %s\n" "Name" "Driver" "Scope" "Containers"
        echo "  $(printf '─%.0s' {1..65})"
        docker network ls --format '{{.Name}}|{{.Driver}}|{{.Scope}}' 2>/dev/null | \
        while IFS='|' read -r NNAME NDRIVER NSCOPE; do
            NCONTAINERS=$(docker network inspect "$NNAME" --format '{{len .Containers}}' 2>/dev/null || echo "?")
            printf "  %-25s %-12s %-15s %s\n" "${NNAME:0:24}" "$NDRIVER" "$NSCOPE" "$NCONTAINERS"
        done

    fi
fi

# ── 18. ACTIVE SERVICES (systemd) ────────────────────────────────────────────
section "19. FAILED SYSTEMD SERVICES"

if command -v systemctl &>/dev/null; then
    FAILED=$(systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null | grep "●\|failed" | wc -l)
    if [ "$FAILED" -eq 0 ] 2>/dev/null; then
        ok "No failed systemd services"
    else
        crit "${FAILED} failed service(s):"
        systemctl list-units --state=failed --no-legend --no-pager 2>/dev/null | head -10
    fi
else
    echo "  systemctl not available on this system"
fi

# ── 18. LOGGED-IN USERS ──────────────────────────────────────────────────────
section "20. LOGGED-IN USERS"

WHO_OUT=$(who 2>/dev/null)
if [ -z "$WHO_OUT" ]; then
    echo "  No users currently logged in"
else
    echo "$WHO_OUT"
fi

# ── SUMMARY ──────────────────────────────────────────────────────────────────
echo ""
echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════════╗"
echo "  ║           END OF REPORT              ║"
echo "  ║  $(date '+%Y-%m-%d %H:%M:%S %Z')            ║"
echo "  ╚══════════════════════════════════════╝"
echo -e "${NC}"
