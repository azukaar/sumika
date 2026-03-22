package services

import (
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	malgo "github.com/gen2brain/malgo"
	"github.com/gorilla/websocket"

	"github.com/azukaar/sumika/server/config"
	"github.com/azukaar/sumika/server/types"
	"github.com/azukaar/sumika/server/utils"
)

// ---------------------------------------------------------------------------
// .env loader (no external deps, does not override existing env vars)
// ---------------------------------------------------------------------------

func loadDotEnv() {
	// Try working directory first (typical location), then executable directory.
	candidates := []string{".env", buildPath(".env")}
	var data []byte
	for _, path := range candidates {
		var err error
		data, err = os.ReadFile(path)
		if err == nil {
			utils.Debug(fmt.Sprintf("Loaded .env from %s", path))
			break
		}
	}
	if data == nil {
		return
	}
	for _, line := range strings.Split(string(data), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.SplitN(line, "=", 2)
		if len(parts) != 2 {
			continue
		}
		key := strings.TrimSpace(parts[0])
		val := strings.TrimSpace(parts[1])
		val = strings.Trim(val, `"'`)
		if os.Getenv(key) == "" {
			os.Setenv(key, val)
		}
	}
}

// ---------------------------------------------------------------------------
// intents.json types
// ---------------------------------------------------------------------------

type IntentsData struct {
	Devices []IntentDevice         `json:"devices"`
	Zones   map[string]interface{} `json:"zones"`
}

type IntentDevice struct {
	FriendlyName string           `json:"friendly_name"`
	IEEEAddress  string           `json:"ieee_address"`
	CustomName   string           `json:"custom_name"`
	Categories   []string         `json:"categories"`
	Zones        []string         `json:"zones"`
	Properties   []IntentProperty `json:"properties"`
}

type IntentProperty struct {
	Name       string        `json:"name"`
	Type       string        `json:"type"`
	IsWritable bool          `json:"is_writable"`
	Values     []string      `json:"values,omitempty"`
	MinValue   *float64      `json:"min_value,omitempty"`
	MaxValue   *float64      `json:"max_value,omitempty"`
	Unit       string        `json:"unit,omitempty"`
	Presets    []IntentPreset `json:"presets,omitempty"`
}

type IntentPreset struct {
	Name        string  `json:"name"`
	Value       float64 `json:"value"`
	Description string  `json:"description,omitempty"`
}

// ---------------------------------------------------------------------------
// OpenAI Realtime session
// ---------------------------------------------------------------------------

const (
	openAIRealtimeURL   = "wss://api.openai.com/v1/realtime"
	defaultRealtimeModel = "gpt-4o-realtime-preview"
	defaultVoice         = "alloy"
	sessionTimeout       = 2 * time.Minute
	audioInBufSize       = 100
	audioOutBufSize      = 300
)

// OpenAISession manages a single voice conversation over the OpenAI
// Realtime WebSocket API.
type OpenAISession struct {
	conn    *websocket.Conn
	writeMu sync.Mutex // serialises WebSocket writes

	apiKey  string
	model   string
	voice   string
	devices []IntentDevice

	audioIn  chan []byte // 16 kHz PCM from mic
	audioOut chan []byte // 24 kHz PCM to speaker

	// Callbacks — set by the caller before Connect().
	OnCommand    func(types.DeviceCommand)
	OnTranscript func(text string)
	OnError      func(err error)
	OnEnd        func()

	ending    bool
	active    bool
	speaking  bool // true while AI is producing audio — mic is muted to prevent echo
	mu        sync.Mutex
	closeOnce sync.Once
	done      chan struct{}
}

// NewOpenAISession creates a session. Call Connect() to start it.
func NewOpenAISession(apiKey string, devices []IntentDevice) *OpenAISession {
	model := os.Getenv("OPENAI_REALTIME_MODEL")
	if model == "" {
		model = defaultRealtimeModel
	}
	voice := os.Getenv("OPENAI_VOICE")
	if voice == "" {
		voice = defaultVoice
	}
	return &OpenAISession{
		apiKey:   apiKey,
		model:    model,
		voice:    voice,
		devices:  devices,
		audioIn:  make(chan []byte, audioInBufSize),
		audioOut: make(chan []byte, audioOutBufSize),
		done:     make(chan struct{}),
	}
}

// Connect dials the WebSocket and starts background goroutines.
func (s *OpenAISession) Connect() error {
	url := fmt.Sprintf("%s?model=%s", openAIRealtimeURL, s.model)

	header := http.Header{}
	header.Set("Authorization", "Bearer "+s.apiKey)
	header.Set("OpenAI-Beta", "realtime=v1")

	dialer := websocket.Dialer{
		HandshakeTimeout: 10 * time.Second,
	}
	conn, _, err := dialer.Dial(url, header)
	if err != nil {
		return fmt.Errorf("openai realtime dial: %w", err)
	}
	s.conn = conn

	s.mu.Lock()
	s.active = true
	s.mu.Unlock()

	go s.readLoop()
	go s.audioSendLoop()

	// Session timeout
	go func() {
		timer := time.NewTimer(sessionTimeout)
		defer timer.Stop()
		select {
		case <-timer.C:
			utils.Warn("OpenAI Realtime: session timeout, closing")
			s.Close()
		case <-s.done:
		}
	}()

	utils.Log(fmt.Sprintf("OpenAI Realtime: connected (model=%s, voice=%s)", s.model, s.voice))
	return nil
}

// Close tears down the session. Safe to call multiple times.
func (s *OpenAISession) Close() {
	s.closeOnce.Do(func() {
		s.mu.Lock()
		s.active = false
		s.mu.Unlock()

		if s.conn != nil {
			_ = s.conn.Close()
		}
		close(s.done)

		if s.OnEnd != nil {
			s.OnEnd()
		}
	})
}

// Done returns a channel closed when the session ends.
func (s *OpenAISession) Done() <-chan struct{} { return s.done }

// IsActive reports whether the session is connected.
func (s *OpenAISession) IsActive() bool {
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.active
}

// SendAudio queues a 16 kHz PCM chunk for transmission to OpenAI.
// Non-blocking; drops audio if the send buffer is full.
// Muted while the AI is speaking to prevent echo feedback.
func (s *OpenAISession) SendAudio(pcm16k []byte) {
	if !s.IsActive() {
		return
	}
	s.mu.Lock()
	muted := s.speaking
	s.mu.Unlock()
	if muted {
		return
	}
	buf := make([]byte, len(pcm16k))
	copy(buf, pcm16k)
	select {
	case s.audioIn <- buf:
	default:
	}
}

// ---------------------------------------------------------------------------
// Event loop
// ---------------------------------------------------------------------------

func (s *OpenAISession) readLoop() {
	defer s.Close()
	for {
		_, msg, err := s.conn.ReadMessage()
		if err != nil {
			if s.IsActive() {
				utils.Warn(fmt.Sprintf("OpenAI Realtime: read error: %v", err))
				if s.OnError != nil {
					s.OnError(err)
				}
			}
			return
		}
		s.handleEvent(msg)
	}
}

func (s *OpenAISession) handleEvent(raw []byte) {
	var ev map[string]interface{}
	if err := json.Unmarshal(raw, &ev); err != nil {
		utils.Warn(fmt.Sprintf("OpenAI Realtime: bad JSON: %v", err))
		return
	}
	evType, _ := ev["type"].(string)

	switch evType {
	case "session.created":
		utils.Debug("OpenAI Realtime: session created, sending config")
		s.sendEvent(s.buildSessionUpdate())

	case "session.updated":
		utils.Debug("OpenAI Realtime: session configured")

	case "response.audio.delta":
		// Mute mic on first audio chunk to prevent echo feedback.
		s.mu.Lock()
		if !s.speaking {
			s.speaking = true
			// Discard any mic audio OpenAI already buffered.
			go func() { _ = s.sendEvent(map[string]interface{}{"type": "input_audio_buffer.clear"}) }()
		}
		s.mu.Unlock()
		s.handleAudioDelta(ev)

	case "response.audio.done":
		// AI finished producing audio. Wait for speaker to drain before un-muting.
		go func() {
			time.Sleep(800 * time.Millisecond)
			s.mu.Lock()
			s.speaking = false
			s.mu.Unlock()
			utils.Debug("OpenAI Realtime: mic un-muted after AI speech")
		}()

	case "response.done":
		s.handleResponseDone(ev)

	case "conversation.item.input_audio_transcription.completed":
		if transcript, ok := ev["transcript"].(string); ok && transcript != "" {
			utils.Log(fmt.Sprintf("OpenAI Realtime: user said: \"%s\"", transcript))
			if s.OnTranscript != nil {
				s.OnTranscript(transcript)
			}
		}

	case "input_audio_buffer.speech_started":
		utils.Debug("OpenAI Realtime: speech started")

	case "input_audio_buffer.speech_stopped":
		utils.Debug("OpenAI Realtime: speech stopped")

	case "response.audio_transcript.done":
		if transcript, ok := ev["transcript"].(string); ok && transcript != "" {
			utils.Debug(fmt.Sprintf("OpenAI Realtime: assistant said: \"%s\"", transcript))
		}

	case "error":
		errObj, _ := ev["error"].(map[string]interface{})
		errMsg, _ := errObj["message"].(string)
		utils.Warn(fmt.Sprintf("OpenAI Realtime: error: %s", errMsg))
		if s.OnError != nil {
			s.OnError(fmt.Errorf("openai: %s", errMsg))
		}

	default:
		if os.Getenv("DEBUG_OPENAI") != "" {
			utils.Debug(fmt.Sprintf("OpenAI Realtime: %s", evType))
		}
	}
}

// ---------------------------------------------------------------------------
// Audio I/O
// ---------------------------------------------------------------------------

func (s *OpenAISession) audioSendLoop() {
	for {
		select {
		case pcm, ok := <-s.audioIn:
			if !ok {
				return
			}
			upsampled := upsample16to24(pcm)
			encoded := base64.StdEncoding.EncodeToString(upsampled)
			_ = s.sendEvent(map[string]interface{}{
				"type":  "input_audio_buffer.append",
				"audio": encoded,
			})
		case <-s.done:
			return
		}
	}
}

func (s *OpenAISession) handleAudioDelta(ev map[string]interface{}) {
	deltaB64, ok := ev["delta"].(string)
	if !ok || deltaB64 == "" {
		return
	}
	pcm, err := base64.StdEncoding.DecodeString(deltaB64)
	if err != nil {
		return
	}
	select {
	case s.audioOut <- pcm:
	default:
		// drop if buffer full
	}
}

// ---------------------------------------------------------------------------
// Response / function calling
// ---------------------------------------------------------------------------

func (s *OpenAISession) handleResponseDone(ev map[string]interface{}) {
	resp, ok := ev["response"].(map[string]interface{})
	if !ok {
		return
	}
	output, ok := resp["output"].([]interface{})
	if !ok {
		return
	}

	for _, item := range output {
		m, ok := item.(map[string]interface{})
		if !ok {
			continue
		}
		if m["type"] == "function_call" {
			callID, _ := m["call_id"].(string)
			name, _ := m["name"].(string)
			args, _ := m["arguments"].(string)
			s.executeFunctionCall(callID, name, args)
		}
	}
}

func (s *OpenAISession) executeFunctionCall(callID, name, argsJSON string) {
	var result string

	switch name {
	case "control_device":
		result = s.controlDevice(argsJSON)

	case "end_conversation":
		utils.Log("OpenAI Realtime: AI called end_conversation")
		result = `{"success":true}`
		s.mu.Lock()
		s.ending = true
		s.mu.Unlock()
		// Close after the AI has time to produce farewell audio.
		go func() {
			time.Sleep(4 * time.Second)
			s.Close()
		}()

	default:
		result = fmt.Sprintf(`{"error":"unknown function %s"}`, name)
	}

	// Return the function result and trigger continuation.
	_ = s.sendEvent(map[string]interface{}{
		"type": "conversation.item.create",
		"item": map[string]interface{}{
			"type":    "function_call_output",
			"call_id": callID,
			"output":  result,
		},
	})
	_ = s.sendEvent(map[string]interface{}{
		"type": "response.create",
	})
}

func (s *OpenAISession) controlDevice(argsJSON string) string {
	var args struct {
		IEEEAddress string `json:"ieee_address"`
		Property    string `json:"property"`
		Value       string `json:"value"`
	}
	if err := json.Unmarshal([]byte(argsJSON), &args); err != nil {
		return fmt.Sprintf(`{"success":false,"error":"bad args: %s"}`, err)
	}

	// Resolve device name for logging.
	deviceName := args.IEEEAddress
	for _, dev := range s.devices {
		if dev.IEEEAddress == args.IEEEAddress {
			if dev.CustomName != "" {
				deviceName = dev.CustomName
			}
			break
		}
	}

	// Parse value: try numeric first, fall back to string.
	var value interface{} = args.Value
	if f, err := strconv.ParseFloat(args.Value, 64); err == nil {
		value = f
	}

	cmd := types.DeviceCommand{
		IEEEAddress: args.IEEEAddress,
		CustomName:  deviceName,
		Property:    args.Property,
		Value:       value,
	}

	utils.Log(fmt.Sprintf("OpenAI Realtime: %s → %s = %v", deviceName, args.Property, value))

	if s.OnCommand != nil {
		s.OnCommand(cmd)
	}

	return fmt.Sprintf(`{"success":true,"device":"%s","property":"%s"}`, deviceName, args.Property)
}

// ---------------------------------------------------------------------------
// Session configuration builders
// ---------------------------------------------------------------------------

func (s *OpenAISession) buildSessionUpdate() map[string]interface{} {
	return map[string]interface{}{
		"type": "session.update",
		"session": map[string]interface{}{
			"modalities":   []string{"text", "audio"},
			"instructions": buildSystemPrompt(s.devices),
			"voice":        s.voice,
			"input_audio_format":  "pcm16",
			"output_audio_format": "pcm16",
			"input_audio_transcription": map[string]interface{}{
				"model": "gpt-4o-mini-transcribe",
			},
			"turn_detection": map[string]interface{}{
				"type":               "server_vad",
				"threshold":          0.5,
				"prefix_padding_ms":  300,
				"silence_duration_ms": 500,
			},
			"tools":       buildTools(s.devices),
			"tool_choice": "auto",
			"temperature": 0.6,
		},
	}
}

func buildTools(devices []IntentDevice) []interface{} {
	tools := []interface{}{
		map[string]interface{}{
			"type":        "function",
			"name":        "control_device",
			"description": "Control a smart home device by setting a property to a value. Use the exact ieee_address from the device list.",
			"parameters": map[string]interface{}{
				"type": "object",
				"properties": map[string]interface{}{
					"ieee_address": map[string]interface{}{
						"type":        "string",
						"description": "The IEEE address of the device to control",
					},
					"property": map[string]interface{}{
						"type":        "string",
						"description": "Property name to set (e.g. state, brightness, color_temp)",
					},
					"value": map[string]interface{}{
						"type":        "string",
						"description": "Value to set. Use ON/OFF/TOGGLE for binary, a number as string for numeric.",
					},
				},
				"required": []string{"ieee_address", "property", "value"},
			},
		},
		map[string]interface{}{
			"type":        "function",
			"name":        "end_conversation",
			"description": "End the voice session. Call when the user's request is fulfilled or they say goodbye.",
			"parameters": map[string]interface{}{
				"type":       "object",
				"properties": map[string]interface{}{},
			},
		},
	}
	return tools
}

func buildSystemPrompt(devices []IntentDevice) string {
	var sb strings.Builder
	sb.WriteString("You are Sumika, a smart home voice assistant. ")
	sb.WriteString("Control devices with the control_device function. ")
	sb.WriteString("When the user's request is done or they say goodbye, call end_conversation. ")
	sb.WriteString("Keep spoken responses short and natural.\n\nAvailable devices:\n")

	for _, dev := range devices {
		name := dev.CustomName
		if name == "" {
			name = dev.FriendlyName
		}

		// Filter to writable properties only.
		var props []string
		for _, p := range dev.Properties {
			if !p.IsWritable {
				continue
			}
			desc := p.Name
			if len(p.Values) > 0 {
				desc += "(" + strings.Join(p.Values, "/") + ")"
			}
			if p.MinValue != nil && p.MaxValue != nil {
				desc += fmt.Sprintf("(%.0f–%.0f", *p.MinValue, *p.MaxValue)
				if p.Unit != "" {
					desc += " " + p.Unit
				}
				desc += ")"
			}
			if len(p.Presets) > 0 {
				var names []string
				for _, pr := range p.Presets {
					names = append(names, pr.Name)
				}
				desc += " presets:" + strings.Join(names, "/")
			}
			props = append(props, desc)
		}
		if len(props) == 0 {
			continue // skip read-only devices
		}

		zones := filterNonEmpty(dev.Zones)
		zonePart := ""
		if len(zones) > 0 {
			zonePart = ", " + strings.Join(zones, "/")
		}
		catPart := ""
		if len(dev.Categories) > 0 {
			catPart = " [" + dev.Categories[0] + "]"
		}

		sb.WriteString(fmt.Sprintf("\n- %s (ieee: %s%s)%s\n", name, dev.IEEEAddress, zonePart, catPart))
		sb.WriteString("    " + strings.Join(props, " | ") + "\n")
	}
	return sb.String()
}

func filterNonEmpty(ss []string) []string {
	var out []string
	for _, s := range ss {
		if s != "" {
			out = append(out, s)
		}
	}
	return out
}

// ---------------------------------------------------------------------------
// WebSocket helpers
// ---------------------------------------------------------------------------

func (s *OpenAISession) sendEvent(ev map[string]interface{}) error {
	s.writeMu.Lock()
	defer s.writeMu.Unlock()
	if s.conn == nil {
		return fmt.Errorf("connection closed")
	}
	return s.conn.WriteJSON(ev)
}

// ---------------------------------------------------------------------------
// intents.json loader
// ---------------------------------------------------------------------------

func loadIntentsData() (*IntentsData, error) {
	path := buildAssetPath("intents.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, fmt.Errorf("read intents.json: %w", err)
	}
	var intents IntentsData
	if err := json.Unmarshal(data, &intents); err != nil {
		return nil, fmt.Errorf("parse intents.json: %w", err)
	}
	return &intents, nil
}

// ---------------------------------------------------------------------------
// Audio resampling: 16 kHz → 24 kHz (ratio 3:2, linear interpolation)
// ---------------------------------------------------------------------------

func upsample16to24(pcm16k []byte) []byte {
	inSamples := len(pcm16k) / 2
	if inSamples < 2 {
		return pcm16k
	}
	outSamples := inSamples * 3 / 2
	out := make([]byte, outSamples*2)

	for i := 0; i < outSamples; i++ {
		srcPos := float64(i) * 2.0 / 3.0
		idx := int(srcPos)
		frac := srcPos - float64(idx)

		if idx >= inSamples-1 {
			copy(out[i*2:], pcm16k[(inSamples-1)*2:(inSamples-1)*2+2])
			continue
		}
		s0 := int16(binary.LittleEndian.Uint16(pcm16k[idx*2:]))
		s1 := int16(binary.LittleEndian.Uint16(pcm16k[(idx+1)*2:]))
		sample := int16(float64(s0) + frac*float64(s1-s0))
		binary.LittleEndian.PutUint16(out[i*2:], uint16(sample))
	}
	return out
}

// ---------------------------------------------------------------------------
// Streaming audio playback (24 kHz)
// ---------------------------------------------------------------------------

// audioBuffer is a simple thread-safe byte buffer for bridging the
// WebSocket reader goroutine and the malgo playback callback thread.
type audioBuffer struct {
	data []byte
	mu   sync.Mutex
}

func (b *audioBuffer) Write(p []byte) {
	b.mu.Lock()
	b.data = append(b.data, p...)
	b.mu.Unlock()
}

func (b *audioBuffer) Read(p []byte) int {
	b.mu.Lock()
	defer b.mu.Unlock()
	n := copy(p, b.data)
	b.data = append(b.data[:0], b.data[n:]...)
	return n
}

// startOpenAIPlayback plays 24 kHz PCM audio chunks arriving on audioOut.
// Blocks until done is closed.
func startOpenAIPlayback(audioOut <-chan []byte, done <-chan struct{}) {
	buf := &audioBuffer{}

	// Feeder: channel → buffer
	go func() {
		for {
			select {
			case chunk, ok := <-audioOut:
				if !ok {
					return
				}
				buf.Write(chunk)
			case <-done:
				return
			}
		}
	}()

	// Reuse shared malgo context if available.
	sharedAudioCtxMutex.RLock()
	ctx := sharedAudioCtx
	sharedAudioCtxMutex.RUnlock()

	var ownCtx *malgo.AllocatedContext
	if ctx == nil {
		var err error
		ownCtx, err = malgo.InitContext(nil, malgo.ContextConfig{}, func(msg string) {})
		if err != nil {
			utils.Warn(fmt.Sprintf("OpenAI playback: init context: %v", err))
			return
		}
		ctx = ownCtx
		defer func() {
			_ = ownCtx.Uninit()
			ownCtx.Free()
		}()
	}

	devCfg := malgo.DefaultDeviceConfig(malgo.Playback)
	devCfg.Playback.Format = malgo.FormatS16
	devCfg.Playback.Channels = 1
	devCfg.SampleRate = 24000

	// Use configured output device.
	cfg := config.GetConfig()
	if cfg.Voice.OutputDevice != "default" && cfg.Voice.OutputDevice != "" {
		if info, err := findAudioDevice(ctx, cfg.Voice.OutputDevice, malgo.Playback); err == nil {
			devCfg.Playback.DeviceID = info.ID.Pointer()
		}
	}

	onSendFrames := func(pOutput []byte, _ []byte, _ uint32) {
		n := buf.Read(pOutput)
		for i := n; i < len(pOutput); i++ {
			pOutput[i] = 0 // silence
		}
	}

	device, err := malgo.InitDevice(ctx.Context, devCfg, malgo.DeviceCallbacks{Data: onSendFrames})
	if err != nil {
		utils.Warn(fmt.Sprintf("OpenAI playback: init device: %v", err))
		return
	}
	defer device.Uninit()

	if err := device.Start(); err != nil {
		utils.Warn(fmt.Sprintf("OpenAI playback: start: %v", err))
		return
	}
	defer func() { _ = device.Stop() }()

	<-done
}
