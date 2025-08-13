package MQTT

import (
  "log"
	"os"
	"os/signal"
	"syscall"
  "fmt"
  "strings"
  // "time"

  mqtt "github.com/mochi-mqtt/server/v2"
  "github.com/mochi-mqtt/server/v2/hooks/auth"
  "github.com/mochi-mqtt/server/v2/listeners"
	"github.com/mochi-mqtt/server/v2/packets"
	
	// External MQTT client
	paho "github.com/eclipse/paho.mqtt.golang"
)

var MQQTServer *mqtt.Server
var ExternalClient paho.Client
var IsExternalBroker bool

func Init(cb func()) {
  // Check for external MQTT broker configuration
  externalBroker := os.Getenv("EXTERNAL_MQTT_BROKER")
  
  if externalBroker != "" {
    log.Printf("Using external MQTT broker: %s", externalBroker)
    initExternalBroker(externalBroker, cb)
    return
  }
  
  log.Println("Starting embedded MQTT server")
  initEmbeddedBroker(cb)
}

func initEmbeddedBroker(cb func()) {
  // Create signals channel to run server until interrupted
  sigs := make(chan os.Signal, 1)
  done := make(chan bool, 1)
  signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
  go func() {
    <-sigs
    done <- true
  }()

  IsExternalBroker = false

  // Create the new MQTT Server.
  MQQTServer = mqtt.New(&mqtt.Options{
		InlineClient: true, // you must enable inline client to use direct publishing and subscribing.
	})
  
  // Allow all connections.
  _ = MQQTServer.AddHook(new(auth.AllowHook), nil)
  
  // Create a TCP listener on a standard port.
  tcp := listeners.NewTCP(listeners.Config{ID: "t1", Address: ":1883"})
  err := MQQTServer.AddListener(tcp)
  if err != nil {
    log.Fatal(err)
  }
  

  go func() {
    err := MQQTServer.Serve()
    if err != nil {
      log.Fatal(err)
    }
  }()

  go (func() {
    // time.Sleep(1 * time.Second)
    cb()
    ListenAll()
  })()

  // Run server until interrupted
  <-done

  // Cleanup
  err = MQQTServer.Close()
  if err != nil {
    log.Fatal(err)
  }

  log.Println("MQTT server stopped")
}

func initExternalBroker(brokerURL string, cb func()) {
  IsExternalBroker = true
  
  // Create MQTT client options
  opts := paho.NewClientOptions()
  opts.AddBroker(brokerURL)
  opts.SetClientID("sumika-server")
  opts.SetAutoReconnect(true)
  
  // Set username/password if provided via environment variables
  if username := os.Getenv("EXTERNAL_MQTT_USERNAME"); username != "" {
    opts.SetUsername(username)
    if password := os.Getenv("EXTERNAL_MQTT_PASSWORD"); password != "" {
      opts.SetPassword(password)
    }
  }
  
  // Create and start the client
  ExternalClient = paho.NewClient(opts)
  if token := ExternalClient.Connect(); token.Wait() && token.Error() != nil {
    log.Fatalf("Failed to connect to external MQTT broker: %v", token.Error())
  }
  
  log.Println("Connected to external MQTT broker")
  
  // Setup graceful shutdown
  sigs := make(chan os.Signal, 1)
  done := make(chan bool, 1)
  signal.Notify(sigs, syscall.SIGINT, syscall.SIGTERM)
  go func() {
    <-sigs
    done <- true
  }()
  
  go (func() {
    cb()
    ListenAll()
  })()
  
  // Run until interrupted
  <-done
  
  // Cleanup
  ExternalClient.Disconnect(250)
  log.Println("MQTT client disconnected")
}

var ListenersCache = make(map[string]func(topic string, payload []byte))

func ListenAll() {
  if IsExternalBroker {
    // Subscribe to topics on external broker
    if token := ExternalClient.Subscribe("zb2m-sumika/#", 0, externalMessageHandler); token.Wait() && token.Error() != nil {
      log.Printf("Failed to subscribe to zb2m-sumika/#: %v", token.Error())
    } else {
      log.Println("Subscribed to zb2m-sumika/# on external broker")
    }
  } else {
    // on message for embedded broker
    MQQTServer.Subscribe("zb2m-sumika/#", 0, MessageBroker)
    // MQQTServer.Subscribe("homeassistant-sumika", 0, MessageBroker)
    // MQQTServer.Subscribe("homeassistant/#", 0, MessageBroker)
  }
}

func MessageBroker(cl *mqtt.Client, sub packets.Subscription, pk packets.Packet) {
  handleMessage(pk.TopicName, pk.Payload)
}

func externalMessageHandler(client paho.Client, msg paho.Message) {
  handleMessage(msg.Topic(), msg.Payload())
}

func handleMessage(topic string, payload []byte) {
  fmt.Println("[MQTT] Message:", topic, (string)(payload))
  
  // Check exact match first
  if ListenersCache[topic] != nil {
      ListenersCache[topic](topic, payload)
  }
  
  topicParts := strings.Split(topic, "/")
  parts := []string{}
  
  // Handle /# wildcards (matches any number of levels)
  for _, part := range topicParts {
      parts = append(parts, part)
      partialTopic := fmt.Sprintf("%s/#", strings.Join(parts, "/"))
      if ListenersCache[partialTopic] != nil {
          ListenersCache[partialTopic](topic, payload)
      }
  }
  
  // Handle /+ wildcard (matches exact number of levels)
  parts = []string{}
  for i := 0; i < len(topicParts)-1; i++ {
      parts = append(parts, topicParts[i])
      partialTopic := fmt.Sprintf("%s/+", strings.Join(parts, "/"))
      if ListenersCache[partialTopic] != nil && len(topicParts) == len(parts)+1 {
          ListenersCache[partialTopic](topic, payload)
      }
  }
}

func Publish(topic string, payload []byte) {
  fmt.Println("[MQTT] Publish:", topic, (string)(payload))
  
  if IsExternalBroker {
    token := ExternalClient.Publish(topic, 2, true, payload)
    go func() {
      if token.Wait() && token.Error() != nil {
        log.Printf("Failed to publish to %s: %v", topic, token.Error())
      }
    }()
  } else {
    go MQQTServer.Publish(topic, payload, true, 2)
  }
}

func Subscribe(topic string, cb func(topic string, payload []byte)) {
  fmt.Println("[MQTT] Subscribe:", topic)

  ListenersCache[topic] = cb
  
  // If using external broker, subscribe to the topic
  if IsExternalBroker {
    if token := ExternalClient.Subscribe(topic, 0, externalMessageHandler); token.Wait() && token.Error() != nil {
      log.Printf("Failed to subscribe to %s: %v", topic, token.Error())
    }
  }
}