🚀 **Server Performance Stats Script**

## 🔗 Project URL

https://github.com/nandkishor986/server-xray.git

🚀 A lightweight DevOps project demonstrating real-world Linux monitoring using Bash scripting.

* A simple and lightweight Bash script to analyze basic server performance metrics on any Linux system.

* This project is designed to help DevOps engineers, system administrators, and learners quickly understand the health of a server without using heavy monitoring tools.

📌 Features

✅ CPU usage calculation

✅ Memory usage (Total, Used, Free, Percentage)

✅ Disk usage (Root partition)

✅ Top 5 processes by CPU usage

✅ Top 5 processes by Memory usage

✅ OS version detection

✅ System uptime and load average

✅ Logged-in users

✅ Failed login attempts (security insight)

✅ Clean and colored output


🛠️ Tech Stack: 

* Bash Scripting
* Linux System Commands (top, ps, df, free, uptime, awk, grep)


## 📂 Project Structure

```
.
├── server-stats.sh   # Main script
└── README.md         # Project documentation
```


⚙️ Installation & Usage: 

1. Clone the repository: 

```bash
git clone https://github.com/nandkishor986/server-xray.git
```

```bash
cd server-stats
```

2. Make the script executable: 

```bash
sudo chmod +x server-stats.sh
```

3. Run the script: 

```bash
sudo ./server-stats.sh
```

📊 Sample Output

===== SERVER PERFORMANCE STATS =====

1. CPU Usage:

    Used: 23.5%

2. Memory Usage:

    Total: 7972MB | Used: 4123MB | Free: 1200MB | Usage: 51.7%

3. Disk Usage:

    Total: 50G | Used: 20G | Free: 28G | Usage: 42%

4. Top 5 Processes by CPU:

    PID   COMMAND   %CPU...


![server-stats](./Images/server-stats.png)


⚡ How It Works

**This script uses standard Linux commands to fetch system data:**

- top → CPU usage
- free → Memory usage
- df → Disk usage
- ps → Process information
- uptime → System load and uptime
- who → Logged-in users
- grep → Filter logs for failed login attempts

**The output is formatted using awk and printf for readability.**

🚀 Future Enhancements: 


1. Add threshold-based alerts (CPU, Memory, Disk). 

2. Export output in JSON format. 

3. Integrate with monitoring tools (Prometheus / Grafana). 

4. Send alerts to Slack or Email. 

5. Add support for multiple disk partitions.


🤝 Contributing

Contributions are welcome!
Feel free to fork this repo and improve the script.

#devops | #bash | #linux | #monitoring