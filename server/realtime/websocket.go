package realtime

import (
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"sync"
	"time"

	"github.com/gorilla/websocket"
)

// WebSocket upgrader with proper settings
var upgrader = websocket.Upgrader{
	ReadBufferSize:  1024,
	WriteBufferSize: 1024,
	CheckOrigin: func(r *http.Request) bool {
		// Allow all origins for now - in production, restrict this
		return true
	},
}

// Client represents a WebSocket connection
type Client struct {
	conn   *websocket.Conn
	send   chan []byte
	hub    *Hub
	id     string
}

// Hub maintains the set of active clients and broadcasts messages to them
type Hub struct {
	clients    map[*Client]bool
	broadcast  chan []byte
	register   chan *Client
	unregister chan *Client
	mutex      sync.RWMutex
}

// DeviceUpdate represents a device state change to send to clients
type DeviceUpdate struct {
	Type       string                 `json:"type"`        // "device_update", "device_list", etc.
	DeviceName string                 `json:"device_name,omitempty"`
	State      map[string]interface{} `json:"state,omitempty"`
	Device     interface{}            `json:"device,omitempty"`    // Full device object for new devices
	Timestamp  string                 `json:"timestamp"`
}

var globalHub *Hub

// Initialize creates the global hub instance
func Initialize() {
	globalHub = &Hub{
		clients:    make(map[*Client]bool),
		broadcast:  make(chan []byte),
		register:   make(chan *Client),
		unregister: make(chan *Client),
	}
	go globalHub.run()
}

// GetHub returns the global hub instance
func GetHub() *Hub {
	return globalHub
}

// run handles the main hub loop
func (h *Hub) run() {
	for {
		select {
		case client := <-h.register:
			h.mutex.Lock()
			h.clients[client] = true
			h.mutex.Unlock()
			fmt.Printf("[WEBSOCKET] Client connected: %s (total: %d)\n", client.id, len(h.clients))

		case client := <-h.unregister:
			h.mutex.Lock()
			if _, ok := h.clients[client]; ok {
				delete(h.clients, client)
				close(client.send)
				fmt.Printf("[WEBSOCKET] Client disconnected: %s (total: %d)\n", client.id, len(h.clients))
			}
			h.mutex.Unlock()

		case message := <-h.broadcast:
			h.mutex.RLock()
			for client := range h.clients {
				select {
				case client.send <- message:
				default:
					delete(h.clients, client)
					close(client.send)
				}
			}
			h.mutex.RUnlock()
		}
	}
}

// BroadcastDeviceUpdate sends a device state update to all connected clients
func (h *Hub) BroadcastDeviceUpdate(deviceName string, newState, oldState map[string]interface{}) {
	if h == nil {
		return
	}

	// Create incremental update with only changed fields
	diff := calculateStateDiff(oldState, newState)
	if len(diff) == 0 {
		return // No changes to broadcast
	}

	update := DeviceUpdate{
		Type:       "device_update",
		DeviceName: deviceName,
		State:      diff,
		Timestamp:  fmt.Sprintf("%d", int64(1000000)), // Microsecond timestamp
	}

	message, err := json.Marshal(update)
	if err != nil {
		fmt.Printf("[WEBSOCKET] Error marshaling device update: %v\n", err)
		return
	}

	fmt.Printf("[WEBSOCKET] Broadcasting device update for %s: %s\n", deviceName, string(message))
	select {
	case h.broadcast <- message:
	default:
		fmt.Println("[WEBSOCKET] Broadcast channel full, dropping message")
	}
}

// calculateStateDiff returns only the fields that changed between old and new state
func calculateStateDiff(oldState, newState map[string]interface{}) map[string]interface{} {
	diff := make(map[string]interface{})
	
	// Check for new or changed fields
	for key, newValue := range newState {
		if oldValue, exists := oldState[key]; !exists || !deepEqual(oldValue, newValue) {
			diff[key] = newValue
		}
	}
	
	// Check for removed fields (set to null)
	for key := range oldState {
		if _, exists := newState[key]; !exists {
			diff[key] = nil
		}
	}
	
	return diff
}

// deepEqual compares two interface{} values for deep equality
func deepEqual(a, b interface{}) bool {
	aJson, _ := json.Marshal(a)
	bJson, _ := json.Marshal(b)
	return string(aJson) == string(bJson)
}

// HandleWebSocket handles WebSocket connections
func HandleWebSocket(w http.ResponseWriter, r *http.Request) {
	if globalHub == nil {
		http.Error(w, "WebSocket hub not initialized", http.StatusInternalServerError)
		return
	}

	conn, err := upgrader.Upgrade(w, r, nil)
	if err != nil {
		log.Printf("WebSocket upgrade error: %v", err)
		return
	}

	clientID := fmt.Sprintf("%s_%d", r.RemoteAddr, int64(1000000))
	client := &Client{
		conn: conn,
		send: make(chan []byte, 256),
		hub:  globalHub,
		id:   clientID,
	}

	client.hub.register <- client

	// Start client goroutines
	go client.writePump()
	go client.readPump()
}

// readPump handles reading from the WebSocket connection
func (c *Client) readPump() {
	defer func() {
		c.hub.unregister <- c
		c.conn.Close()
	}()

	// Set read deadline and pong handler for keepalive
	c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
	c.conn.SetPongHandler(func(string) error {
		c.conn.SetReadDeadline(time.Now().Add(60 * time.Second))
		return nil
	})

	for {
		// Read message (mostly for keepalive, we don't expect many client messages)
		_, message, err := c.conn.ReadMessage()
		if err != nil {
			if websocket.IsUnexpectedCloseError(err, websocket.CloseGoingAway, websocket.CloseAbnormalClosure) {
				log.Printf("WebSocket error: %v", err)
			}
			break
		}
		
		// Handle client message if needed
		_ = message
	}
}

// writePump handles writing to the WebSocket connection
func (c *Client) writePump() {
	ticker := time.NewTicker(54 * time.Second)
	defer func() {
		ticker.Stop()
		c.conn.Close()
	}()

	for {
		select {
		case message, ok := <-c.send:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if !ok {
				c.conn.WriteMessage(websocket.CloseMessage, []byte{})
				return
			}

			if err := c.conn.WriteMessage(websocket.TextMessage, message); err != nil {
				log.Printf("WebSocket write error: %v", err)
				return
			}

		case <-ticker.C:
			c.conn.SetWriteDeadline(time.Now().Add(10 * time.Second))
			if err := c.conn.WriteMessage(websocket.PingMessage, nil); err != nil {
				return
			}
		}
	}
}