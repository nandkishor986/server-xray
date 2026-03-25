#!/bin/bash

# This script is used to collect server stats and send them to a specified endpoint.

# Colors: 

# Define color codes using ANSI escape sequences

RED='\033[0;31m' # Red Color
GREEN='\033[0;32m' # Green Color
CYAN='\033[0;36m' # Cyan Color 
NC='\033[0m' # Reset Color (No Color)

echo -e "${CYAN}===== SERVER PERFORMANCE STATS =====${NC}" # '-e' enables interpretation of escape characters. 

echo "------------------------------------------------------"


# CPU Usage: 

echo -e "${GREEN}CPU Usage:${NC}"

top -bn1 | grep "Cpu(s)" | awk '{print "Used: " $2 + $4 "%"}'

# top - shows real-time system processes
# -b - batch mode (non-interactive, good for scripting)
# -n1 - number of iterations (1 means it will run once and exit)
# grep "Cpu(s)" - filters the output to show only the line containing CPU usage
# awk '{print "Used: " $2 + $4 "%"}' - processes the CPU line to calculate total CPU usage by adding user and system percentages (fields $2 and $4 respectively) and formats the output to show the total CPU usage percentage.

echo "------------------------------------------------------"


# Memory Usage: 

echo -e "${GREEN}Memory Usage:${NC}" 

free -m | awk 'NR==2 {printf "Total: %sMB | Used: %sMB | Free: %sMB | Usage: %.2f%%\n", $2, $3, $4, $3*100/$2 }'

echo "------------------------------------------------------"

# free - displays the amount of free and used memory in the system.
# -m - shows memory usage in megabytes.

# awk 'NR==2 { ... }' - processes the second line of the output (which contains the memory stats) and formats it to show total, used, free memory in MB, and calculates the percentage of memory used by dividing used memory ($3) by total memory ($2) and multiplying by 100 to get a percentage. The output is formatted to show the memory usage in a clear and concise manner.

# $2       -> total memory
# $3       -> used memory
# $4       -> free memory
# $3*100/$2 -> calculates percentage usage
# printf   -> formatted output (like C language)


# Disk Usage: 

echo -e "${GREEN}Disk Usage:${NC}"

df -h / | awk 'NR==2 {printf "Total: %s | Used: %s | Free: %s | Usage: %s\n", $2, $3, $4, $5 }'

echo "------------------------------------------------------"

# df       -> disk filesystem usage
# -h       -> human-readable (KB, MB, GB)
# /        -> checks root partition only
# awk      -> processes output
# NR==2    -> selects actual data row
# $2       -> total disk
# $3       -> used disk
# $4       -> available disk
# $5       -> usage percentage

# Top 5 CPU Processes:

echo -e "${GREEN}Top 5 CPU Processes:${NC}"

ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6  

echo "------------------------------------------------------"

# ps       -> process status
# -e       -> select all processes  
# -o       -> format output (pid, command, cpu usage)
# pid      -> process ID
# comm     -> command name
# %cpu     -> CPU usage percentage
# --sort=-%cpu -> sort by CPU usage in descending order 
# head -n 6 -> show top 5 processes (including header) (1 line header + 5 processes)


# Top 5 Memory Processes:

echo -e "${GREEN}Top 5 Memory Processes:${NC}"

ps -eo pid,comm,%mem --sort=-%mem | head -n 6 

echo "------------------------------------------------------"

# ps       -> process status
# -e       -> select all processes
# -o       -> format output (pid, command, memory usage)
# pid      -> process ID
# comm     -> command name
# %mem     -> memory usage percentage
# --sort=-%mem -> sort by memory usage in descending order
# head -n 6 -> show top 5 processes (including header) (1 line header + 5 processes)


# OS Info: 

echo -e "${GREEN}OS Version:${NC}"

grep PRETTY_NAME /etc/os-release | cut -d= -f2

echo "------------------------------------------------------"  

# grep PRETTY_NAME /etc/os-release -> searches for the line containing "PRETTY_NAME" in the /etc/os-release file, which typically contains a human-readable name of the operating system.

# cut -d= -f2 -> cuts the line using '=' as a delimiter and selects the second field (the value of PRETTY_NAME), which is the actual OS version information. This will output the OS version in a readable format.


# Uptime & Load: 

echo -e "${GREEN}Uptime & Load Average:${NC}"

uptime 

echo "------------------------------------------------------"

# uptime -> shows how long the system has been running and the load average (the average number of processes waiting to run) over the last 1, 5, and 15 minutes. This provides insight into the system's performance and workload over time.


# Logged in Users: 

echo -e "${GREEN}Logged in Users:${NC}"

who 

echo "------------------------------------------------------"

# who -> displays a list of users currently logged into the system, along with their login time and terminal information. This can help identify active sessions and user activity on the server.


# Failed Login Attempts: 

echo -e "${GREEN}Failed Login Attempts:${NC}"

if [[ -f /var/log/auth.log ]]; then
    grep "Failed password" /var/log/auth.log | tail -n 5 
elif [[ -f /var/log/secure ]]; then
    grep "Failed password" /var/log/secure | tail -n 5
else 
    echo -e "${RED}Log file not found.${NC}"
fi 

echo "------------------------------------------------------"

# This section checks for failed login attempts by searching for "Failed password" in the appropriate log file (auth.log for Debian-based systems or secure for Red Hat-based systems). It then displays the last 5 failed login attempts. If neither log file is found, it outputs an error message in red.    

# This script provides a comprehensive overview of the server's performance and security status, making it easier for administrators to monitor and manage their systems effectively.

# Note: Depending on the server's configuration and permissions, some commands may require elevated privileges (e.g., using sudo) to access certain information or log files. Always ensure you have the necessary permissions to run these commands safely.

# End of script

echo -e "${CYAN}===== END OF REPORT =====${NC}"