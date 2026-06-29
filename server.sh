#!/usr/bin/env bash

# server-stats.sh
# Basic Linux server performance stats

echo "========================================"
echo "        SERVER PERFORMANCE STATS"
echo "========================================"
echo

# =========================
# OS Version
# =========================
echo "OS Information:"
if [ -f /etc/os-release ]; then
    . /etc/os-release
    echo "OS Version     : $PRETTY_NAME"
else
    echo "OS Version     : Unknown"
fi

echo "Hostname       : $(hostname)"
echo "Uptime         : $(uptime -p 2>/dev/null || uptime)"
echo "Load Average   : $(awk '{print $1", "$2", "$3}' /proc/loadavg)"
echo "Logged-in Users: $(who | wc -l)"
echo

# =========================
# CPU Usage
# =========================
get_cpu_usage() {
    read -r _ user nice system idle iowait irq softirq steal _ < /proc/stat

    idle_all=$((idle + iowait))
    non_idle=$((user + nice + system + irq + softirq + steal))
    total=$((idle_all + non_idle))

    sleep 1

    read -r _ user2 nice2 system2 idle2 iowait2 irq2 softirq2 steal2 _ < /proc/stat

    idle_all2=$((idle2 + iowait2))
    non_idle2=$((user2 + nice2 + system2 + irq2 + softirq2 + steal2))
    total2=$((idle_all2 + non_idle2))

    total_diff=$((total2 - total))
    idle_diff=$((idle_all2 - idle_all))

    awk -v total="$total_diff" -v idle="$idle_diff" \
        'BEGIN {
            if (total > 0)
                printf "%.2f%%", (100 * (total - idle) / total)
            else
                printf "0.00%%"
        }'
}

echo "CPU Usage:"
echo "Total CPU Usage: $(get_cpu_usage)"
echo

# =========================
# Memory Usage
# =========================
echo "Memory Usage:"
awk '
/MemTotal/ { total=$2 }
/MemAvailable/ { available=$2 }
END {
    used = total - available
    used_percent = (used / total) * 100
    free_percent = (available / total) * 100

    printf "Total Memory : %.2f GB\n", total / 1024 / 1024
    printf "Used Memory  : %.2f GB (%.2f%%)\n", used / 1024 / 1024, used_percent
    printf "Free Memory  : %.2f GB (%.2f%%)\n", available / 1024 / 1024, free_percent
}
' /proc/meminfo
echo

# =========================
# Disk Usage
# =========================
echo "Disk Usage:"
df -kP -x tmpfs -x devtmpfs -x squashfs | awk '
NR > 1 {
    total += $2
    used += $3
    free += $4
}
END {
    used_percent = (used / total) * 100
    free_percent = (free / total) * 100

    printf "Total Disk : %.2f GB\n", total / 1024 / 1024
    printf "Used Disk  : %.2f GB (%.2f%%)\n", used / 1024 / 1024, used_percent
    printf "Free Disk  : %.2f GB (%.2f%%)\n", free / 1024 / 1024, free_percent
}
'
echo

# =========================
# Top Processes by CPU
# =========================
echo "Top 5 Processes by CPU Usage:"
ps -eo pid,comm,%cpu,%mem --sort=-%cpu | head -n 6
echo

# =========================
# Top Processes by Memory
# =========================
echo "Top 5 Processes by Memory Usage:"
ps -eo pid,comm,%cpu,%mem --sort=-%mem | head -n 6
echo

# =========================
# Failed Login Attempts
# =========================
echo "Failed Login Attempts:"
if [ -r /var/log/auth.log ]; then
    failed_count=$(grep -c "Failed password" /var/log/auth.log)
    echo "Failed login attempts: $failed_count"
elif [ -r /var/log/secure ]; then
    failed_count=$(grep -c "Failed password" /var/log/secure)
    echo "Failed login attempts: $failed_count"
else
    echo "Failed login attempts: Unable to read log file. Try running with sudo."
fi

echo
echo "========================================"
echo "              DONE"
echo "========================================"
