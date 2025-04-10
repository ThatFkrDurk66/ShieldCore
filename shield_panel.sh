#!/data/data/com.termux/files/usr/bin/bash

# === CONFIG ===
SHELL_PORT=5425
ALERT_SOUND="/system/media/audio/ui/KeypressStandard.ogg"
DEVICE_LIST=".device_list.tmp"
LOG_FILE="shield_log.txt"
ROTATE_INTERVAL=300  # 5 minutes
DUMP_DIR="/sdcard/CyberShieldLogs"

# === COLORS ===
green="\e[32m"
red="\e[31m"
reset="\e[0m"

# === SETUP TOR HIDDEN SERVICE ===
setup_tor_service() {
    mkdir -p ~/.tor_hidden
    echo "HiddenServiceDir /data/data/com.termux/files/home/.tor_hidden" > $PREFIX/etc/tor/torrc
    echo "HiddenServicePort $SHELL_PORT 127.0.0.1:$SHELL_PORT" >> $PREFIX/etc/tor/torrc
    pkill tor &> /dev/null
    tor &> /dev/null &
    sleep 10
    if [ -f ~/.tor_hidden/hostname ]; then
        echo -e "${green}[+] Hidden service address:${reset}"
        cat ~/.tor_hidden/hostname
    else
        echo -e "${red}[-] Failed to get hidden service address.${reset}"
    fi
}

# === DEVICE MONITOR ===
device_alert_loop() {
    echo "[!] Starting device monitor..."
    nmap -sn 192.168.1.0/24 -oG - | grep Up | awk '{print $2}' > "$DEVICE_LIST"
    while true; do
        sleep 60
        nmap -sn 192.168.1.0/24 -oG - | grep Up | awk '{print $2}' > ".current_list.tmp"
        diff "$DEVICE_LIST" ".current_list.tmp" | grep ">" && {
            echo -e "${red}[!] New device detected!${reset}"
            play-audio "$ALERT_SOUND"
        }
        mv .current_list.tmp "$DEVICE_LIST"
    done
}

# === AUTO IP ROTATOR ===
rotate_ip_loop() {
    echo "[*] Tor IP rotator running every 5 mins..."
    while true; do
        sleep $ROTATE_INTERVAL
        pkill -HUP tor
        echo "[+] Tor IP rotated at $(date)" >> "$LOG_FILE"
    done
}

# === MALWARE SCANNER ===
run_malware_scan() {
    read -p "File or directory to scan: " path
    if [ -e "$path" ]; then
        clamscan -r "$path"
    else
        echo -e "${red}File/dir not found.${reset}"
    fi
}

# === WEB SHIELD ===
web_shield_monitor() {
    echo "[*] Starting basic web shield monitor..."
    while true; do
        netstat -tn 2>/dev/null | grep -E ':80|:443|:22' | grep ESTABLISHED | tee -a "$LOG_FILE"
        sleep 10
    done
}

# === REAL-TIME PROTECTION + AUTO COUNTERMEASURE ===
real_time_protection() {
    echo "[*] Watching for active scans or shells..."
    while true; do
        hits=$(netstat -an | grep ESTABLISHED | grep -v 127.0.0.1)
        if [ ! -z "$hits" ]; then
            echo "$hits" >> "$LOG_FILE"
            echo -e "${red}[!] Suspicious activity detected! Running countermeasure...${reset}"
            termux-vibrate -d 500
            play-audio "$ALERT_SOUND"
        fi
        sleep 5
    done
}

# === STOP BACKGROUND TASKS ===
stop_all_background_tasks() {
    echo "[*] Stopping all background shield processes..."
    pkill -f device_alert_loop
    pkill -f rotate_ip_loop
    pkill -f web_shield_monitor
    pkill -f real_time_protection
    pkill -f log_dump_loop
    pkill -f monitor_background_processes
    echo "[+] All shield services stopped."
}

# === VIEW LOG FILE ===
view_logs() {
    echo "[*] Displaying shield log entries:"
    cat "$LOG_FILE"
    echo
    read -p "Press Enter to return to menu..."
}

# === MONITOR RUNNING PROCESSES (REAL-TIME) ===
monitor_background_processes() {
    while true; do
        clear
        echo -e "${green}[*] Background shield processes:${reset}"
        ps | grep -E 'device_alert_loop|rotate_ip_loop|web_shield_monitor|real_time_protection|log_dump_loop' | grep -v grep
        echo
        echo -e "${green}[*] System performance:${reset}"
        top -n 1 | head -20
        echo -e "${red}Press Ctrl+C to stop monitoring${reset}"
        sleep 5
    done
}

# === AUTO LOG DUMP TO SD ===
log_dump_loop() {
    mkdir -p "$DUMP_DIR"
    while true; do
        timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
        cp "$LOG_FILE" "$DUMP_DIR/log_$timestamp.txt"
        sleep 3600
    done
}

# === AUTO STARTUP (SILENT MODE) ===
auto_start_services() {
    setup_tor_service &
    device_alert_loop &
    rotate_ip_loop &
    web_shield_monitor &
    real_time_protection &
    log_dump_loop &
    echo "[+] All core protections are running silently."
}

# === MAIN MENU ===
while true; do
clear
echo -e "${green}=== ULTIMATE CYBER SHIELD MENU ===${reset}"
echo "[1] Start Tor Hidden Shell"
echo "[2] Launch Malware Scanner"
echo "[3] Monitor for New Devices (with beep)"
echo "[4] Start IP Auto-Rotator"
echo "[5] Start Web Shield Monitor"
echo "[6] Start Real-Time Protection"
echo "[7] Exit"
echo "[8] Stop All Background Tasks"
echo "[9] View Shield Logs"
echo "[10] Monitor Background Tasks & Performance (Live)"
echo "[11] Launch Stealth Mode (Run all silently)"
echo
read -p "Choose an option [1-11]: " choice

case $choice in
    1) setup_tor_service & echo -e "${green}[+] Tor shell setup launched in background.${reset}" ;;
    2) run_malware_scan ;;
    3) device_alert_loop & echo -e "${green}[+] Device monitor running in background.${reset}" ;;
    4) rotate_ip_loop & echo -e "${green}[+] IP auto-rotator started in background.${reset}" ;;
    5) web_shield_monitor & echo -e "${green}[+] Web shield monitor active in background.${reset}" ;;
    6) real_time_protection & echo -e "${green}[+] Real-time protection active in background.${reset}" ;;
    7) echo "Goodbye, stay safe." && exit ;;
    8) stop_all_background_tasks ;;
    9) view_logs ;;
    10) monitor_background_processes & echo -e "${green}[+] Performance monitor running. Press Ctrl+C to stop.${reset}" ;;
    11) auto_start_services ;;
    *) echo "Invalid option." ;;
esac

read -p "Press Enter to return to menu..."
done
