 JVM Watchtower

**JVM Watchtower** is an agentless, production-safe JVM monitoring and diagnostics toolkit
designed primarily for **Tomcat-based Java services**.

It provides automated heap monitoring, alerting, and on-demand diagnostics
without requiring any agents, JVM restarts, or external monitoring platforms.

---

## ✨ Features

- Agentless JVM monitoring (no JMX, no agents)
- Heap & OldGen usage detection
- Google Chat alert integration
- Automatic diagnostics on memory breach:
  - 🧵 Thread dumps (rate-limited)
  - 📊 GC trend snapshots
  - 🧯 Heap dumps (critical only, disk-safe)
- Cron-based execution
- Safe for production environments

---

## 📦 Included Files

Only **three scripts** are required:
tomcat_heap_chat_alert.sh # Main orchestrator
tomcat_heap_usage.sh # Calculates overall heap usage (%)
tomcat_oldgen_usage.sh # Calculates OldGen usage (%)


JVM Watchtower writes diagnostics to the following directories (replace the /dr01/diag/ with your own backup directory):
/backup/diag/
├── thread_dumps/ # jstack outputs
├── gc_trends/ # jstat snapshots
└── heap_dumps/ # heap dumps (.hprof)


Create them once per server:

mkdir -p /backup/diag/{thread_dumps,gc_trends,heap_dumps}
chown <app_user>:<app_group> /backup/diag/{thread_dumps,gc_trends,heap_dumps}
chmod 750 /backup/diag/{thread_dumps,gc_trends,heap_dumps}


Configuration

Edit tomcat_heap_chat_alert.sh and adjust the following:

Environment label
ENV="PROD"   # PROD / UAT / TEST / DEV

Google Chat Webhook
WEBHOOK_URL="https://chat.googleapis.com/v1/spaces/..."

Java Home (must match JVM)
JAVA_HOME="/tech/java/openjdk17.0.7.7"

Thresholds
HEAP_THRESHOLD=10        # Alert threshold
OLDGEN_THRESHOLD=75     # Alert threshold

Critical thresholds (heap dump)
HEAP >= 90% or OLDGEN >= 90%

🧠 How It Works

Cron executes tomcat_heap_chat_alert.sh

Script discovers running Tomcat JVMs

Heap and OldGen usage is calculated per JVM

If any JVM breaches thresholds:

One alert is sent to Google Chat

All Tomcats are listed with current stats

Diagnostics are captured with safeguards:

Thread dumps → once per hour per JVM

GC trends → per breach

Heap dumps → once per day per JVM + disk check

⏱️ Recommended Cron Configuration

Run every 3 hours:

0 */3 * * * /usr/local/bin/tomcat_heap_chat_alert.sh >> /tmp/jvm_watchtower.log 2>&1

🔒 Production Safety Guarantees
| Feature      | Protection            |
| ------------ | --------------------- |
| Thread dumps | Rate-limited (1/hour) |
| GC trends    | Lightweight           |
| Heap dumps   | Rate-limited (1/day)  |
| Disk safety  | Requires free space   |
| PID changes  | Auto-detected         |
| JVM restarts | Not required          |


Copy scripts to target server:

cp tomcat_heap_*.sh /usr/local/bin/

chmod 755 /usr/local/bin/tomcat_heap_*.sh

Create diagnostic directories

Update configuration values

Test manually:

/usr/local/bin/tomcat_heap_chat_alert.sh


Enable cron

🛠️ Requirements

Linux

Java 17 (same JDK used for JVM and tools)

jcmd, jstack, jstat available

jq installed

Network access to Google Chat webhook

🏷️ Versioning

v1.0 – Initial production release

👤 Author

odazu

📌 Notes

This tool is intentionally simple and transparent

No agents, no daemons, no vendor lock-in

Designed to be extended safely if needed

---

