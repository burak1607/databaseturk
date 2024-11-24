# SNMPX - SNMP Trap Listener with Slack Integration
MySQL Enterprise Monitoring (MEM) only supported SNMP and email for event notifications. To fulfill the need for sending event notifications to Slack, the SNMPX application was developed.
It processes SNMP traps and seamlessly forwards them to designated Slack channels.
SNMPX is a lightweight and highly configurable SNMP trap listener that forwards SNMP traps to Slack channels. Designed to monitor SNMP traps in real-time,
SNMPX supports SNMPv1 and SNMPv2c protocols, and processes severity levels such as critical, warning, info, and more.

## Features
### SNMP Trap Listener:
    * Supports SNMPv1 and SNMPv2c protocols.
    * Filters and processes SNMP traps based on severity levels.
    * Community string-based authentication for added security.

### Slack Integration:

    * Sends processed SNMP traps directly to Slack channels via Webhook URLs.
    * Configurable Slack Webhook URLs for different severity levels.

### Flexible Configuration:
    * All settings, including Slack Webhook URLs and SNMP community strings, are managed via a simple configuration file.

### Error Handling:
    * Default severity (unknown) is assigned if no severity is specified in the incoming SNMP trap.

## Configuration
SNMPX reads its configuration from /etc/snmpx.conf. Below is an example configuration file:

### Slack Webhook URLs /etc/snmpx.conf
```webhook.default=https://hooks.slack.com/services/your-default-webhook
webhook.critical=https://hooks.slack.com/services/your-critical-webhook
webhook.warning=https://hooks.slack.com/services/your-warning-webhook
webhook.info=https://hooks.slack.com/services/your-info-webhook
community=publicx
```

### Clone & Build
```
git clone https://github.com/burak1607/databaseturk.git
cd databaseturk/snmpx
go build -o snmpx
sudo nano /etc/snmpx.conf
sudo ./snmpx
```

### Future Enhancements
 Add support for SNMPv3 with authentication and encryption.
 Extend integration to other platforms (e.g., email, custom dashboards).
 Implement richer Slack message formatting (e.g., attachments, color coding).


