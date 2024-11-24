package main

import (
        "bufio"
        "bytes"
        "encoding/json"
        "fmt"
        "log"
        "net"
        "net/http"
        "os"
        "strings"

        "github.com/gosnmp/gosnmp"
)

// Config stores the Slack webhook URLs and community string
type Config struct {
        WebhookURLs map[string]string // Webhook URL'leri (severity'e göre)
        Community   string            // SNMP Community String
}

// SlackMessage represents the payload to send to Slack
type SlackMessage struct {
        Text string `json:"text"`
}

// LoadConfig reads Slack webhook URLs and SNMP community string from the configuration file
func LoadConfig(filePath string) (*Config, error) {
        file, err := os.Open(filePath)
        if err != nil {
                return nil, fmt.Errorf("failed to open config file: %w", err)
        }
        defer file.Close()

        webhookURLs := make(map[string]string)
        var community string

        scanner := bufio.NewScanner(file)
        for scanner.Scan() {
                line := strings.TrimSpace(scanner.Text())
                if strings.HasPrefix(line, "webhook.") {
                        parts := strings.SplitN(line, "=", 2)
                        if len(parts) == 2 {
                                severity := strings.TrimPrefix(parts[0], "webhook.")
                                webhookURLs[strings.TrimSpace(severity)] = strings.TrimSpace(parts[1])
                        }
                } else if strings.HasPrefix(line, "community=") {
                        community = strings.TrimPrefix(line, "community=")
                        community = strings.TrimSpace(community)
                }
        }
        if err := scanner.Err(); err != nil {
                return nil, fmt.Errorf("error reading config file: %w", err)
        }

        if community == "" {
                return nil, fmt.Errorf("community string is missing in config file")
        }

        return &Config{
                WebhookURLs: webhookURLs,
                Community:   community,
        }, nil
}

// sendToSlack sends a message to the Slack webhook
func sendToSlack(webhookURL, message string) error {
        payload := SlackMessage{
                Text: message,
        }

        jsonPayload, err := json.Marshal(payload)
        if err != nil {
                return fmt.Errorf("failed to marshal JSON: %w", err)
        }

        resp, err := http.Post(webhookURL, "application/json", bytes.NewBuffer(jsonPayload))
        if err != nil {
                return fmt.Errorf("failed to send POST request: %w", err)
        }
        defer resp.Body.Close()

        if resp.StatusCode != http.StatusOK && resp.StatusCode != http.StatusNoContent {
                return fmt.Errorf("unexpected response from Slack: %s", resp.Status)
        }

        return nil
}

// handleTrap processes incoming SNMP trap and forwards it to Slack
func handleTrap(packet *gosnmp.SnmpPacket, addr *net.UDPAddr, config *Config) {
        log.Printf("Received SNMP trap from %s", addr.IP)

        var severity string
        var messageBuilder strings.Builder
        messageBuilder.WriteString(fmt.Sprintf("🚨 *SNMP Trap Received* from %s:\n", addr.IP))

        // Parse variables in the SNMP trap
        for _, variable := range packet.Variables {
                switch variable.Type {
                case gosnmp.OctetString:
                        value := string(variable.Value.([]byte))
                        if strings.Contains(variable.Name, "severity") {
                                severity = value // Extract severity
                        }
                        messageBuilder.WriteString(fmt.Sprintf("- OID: %s, Value: %s\n", variable.Name, value))
                default:
                        messageBuilder.WriteString(fmt.Sprintf("- OID: %s, Value: %v\n", variable.Name, variable.Value))
                }
        }

        // Use default severity if not provided
        if severity == "" {
                severity = "unknown"
        }

        // Find the appropriate webhook URL
        webhookURL, exists := config.WebhookURLs[severity]
        if !exists {
                webhookURL = config.WebhookURLs["default"]
        }

        // Send the message to Slack
        err := sendToSlack(webhookURL, messageBuilder.String())
        if err != nil {
                log.Printf("Error sending to Slack: %v", err)
        } else {
                log.Printf("Message sent to Slack via [%s] webhook successfully", severity)
        }
}

func main() {
        // Load configuration
        configFilePath := "/etc/snmpx.conf"
        config, err := LoadConfig(configFilePath)
        if err != nil {
                log.Fatalf("Error loading config: %v", err)
        }

        // Configure SNMP trap listener
        trapListener := gosnmp.NewTrapListener()
        trapListener.OnNewTrap = func(packet *gosnmp.SnmpPacket, addr *net.UDPAddr) {
                handleTrap(packet, addr, config)
        }
        trapListener.Params = gosnmp.Default
        trapListener.Params.Version = gosnmp.Version2c
        trapListener.Params.Community = config.Community

        // Start listening for SNMP traps
        log.Println("SNMPX is listening for SNMP traps on UDP port 162...")
        err = trapListener.Listen("0.0.0.0:162")
        if err != nil {
                log.Fatalf("Error starting SNMP trap listener: %v", err)
        }
}

