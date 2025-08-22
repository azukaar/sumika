package services

import (
    "bufio"
    "encoding/binary"
    "encoding/json"
    "errors"
    "io"
    "log"
    "os"
    "os/exec"
    "path/filepath"
    "sync"
    "time"

    malgo "github.com/gen2brain/malgo"
    "github.com/azukaar/sumika/server/utils"
    "github.com/azukaar/sumika/server/types"
)

const (
    sampleRate    = 16000
    channels      = 1
    bitsPerSample = 16
    wavHeaderLen  = 44
    resetInterval = 10 * time.Minute
)

// VoiceRunner manages voice recognition with configurable callbacks
type VoiceRunner struct {
    config    types.VoiceConfig
    callbacks types.VoiceCallbacks
    stopChan  chan bool
    running   bool
    mutex     sync.RWMutex
}

type PythonEvent struct {
    Type           string  `json:"type"`
    Label          string  `json:"label,omitempty"`
    Score          float64 `json:"score,omitempty"`
    Message        string  `json:"message,omitempty"`
    Text           string  `json:"text,omitempty"`
    AudioDuration  float64 `json:"audio_duration,omitempty"`
    ProcessingTime float64 `json:"processing_time,omitempty"`
    Timestamp      float64 `json:"timestamp"`
}

// getExecutableDir returns the directory of the current executable
func getExecutableDir() (string, error) {
    exePath, err := os.Executable()
    if err != nil {
        return "", err
    }
    // Resolve any symlinks
    exePath, err = filepath.EvalSymlinks(exePath)
    if err != nil {
        return "", err
    }
    return filepath.Dir(exePath), nil
}

// buildPath constructs a path relative to the executable directory
func buildPath(relativePath string) string {
    execDir, err := getExecutableDir()
    if err != nil {
        log.Printf("⚠️  Failed to get executable directory, using relative path: %v", err)
        return relativePath
    }
    return filepath.Join(execDir, relativePath)
}

// buildAssetPath constructs a path for assets in the assets/voice directory
func buildAssetPath(filename string) string {
    return buildPath(filepath.Join("assets", "voice", filename))
}

// ListAudioInputDevices enumerates and displays all available audio input devices
func ListAudioInputDevices() error {
    log.Printf("🎙️  Enumerating available audio input devices...")
    
    ctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(message string) {
        // Silent callback for device enumeration
    })
    if err != nil {
        return err
    }
    defer func() {
        _ = ctx.Uninit()
        ctx.Free()
    }()

    devices, err := ctx.Devices(malgo.Capture)
    if err != nil {
        return err
    }

    if len(devices) == 0 {
        log.Printf("❌ No audio input devices found")
        return nil
    }

    log.Printf("📋 Found %d audio input device(s):", len(devices))
    for i, device := range devices {
        info, err := ctx.DeviceInfo(malgo.Capture, device.ID, malgo.Shared)
        if err != nil {
            log.Printf("   [%d] %s (ID: %v) - Error getting info: %v", i, device.Name(), device.ID, err)
            continue
        }
        
        log.Printf("   [%d] %s", i, device.Name())
        // log.Printf("       ID: %v", device.ID)
        if info.IsDefault == 1 {
            log.Printf("       ⭐ Default device")
        }
    }
    
    return nil
}

// PlayWAVFile plays a WAV file using malgo
func PlayWAVFile(filename string) error {
    // Read WAV file
    file, err := os.Open(filename)
    if err != nil {
        return err
    }
    defer file.Close()

    // Read WAV header to skip it
    header := make([]byte, 44)
    if _, err := file.Read(header); err != nil {
        return err
    }

    // Read audio data
    audioData, err := io.ReadAll(file)
    if err != nil {
        return err
    }

    if len(audioData) == 0 {
        return nil // Empty file
    }

    // Initialize malgo context for playback
    ctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(message string) {
        // Silent callback
    })
    if err != nil {
        return err
    }
    defer func() {
        _ = ctx.Uninit()
        ctx.Free()
    }()

    // Setup playback device config
    deviceConfig := malgo.DefaultDeviceConfig(malgo.Playback)
    deviceConfig.Playback.Format = malgo.FormatS16
    deviceConfig.Playback.Channels = 1 // Assuming mono for audio files
    deviceConfig.SampleRate = 16000    // Assuming same as capture

    var playbackPos int
    finished := make(chan bool)

    onSendFrames := func(pOutputSample []byte, pInputSample []byte, frameCount uint32) {
        bytesToCopy := int(frameCount) * 2 // 2 bytes per sample for S16
        if playbackPos+bytesToCopy > len(audioData) {
            bytesToCopy = len(audioData) - playbackPos
        }

        if bytesToCopy > 0 {
            copy(pOutputSample, audioData[playbackPos:playbackPos+bytesToCopy])
            playbackPos += bytesToCopy
        }

        // Fill remaining with silence
        for i := bytesToCopy; i < len(pOutputSample); i++ {
            pOutputSample[i] = 0
        }

        // Check if we've finished playing
        if playbackPos >= len(audioData) {
            select {
            case finished <- true:
            default:
            }
        }
    }

    deviceCallbacks := malgo.DeviceCallbacks{
        Data: onSendFrames,
    }

    playbackDevice, err := malgo.InitDevice(ctx.Context, deviceConfig, deviceCallbacks)
    if err != nil {
        return err
    }
    defer playbackDevice.Uninit()

    if err := playbackDevice.Start(); err != nil {
        return err
    }

    // Wait for playback to finish or timeout
    select {
    case <-finished:
        // Playback finished
    case <-time.After(5 * time.Second):
        // Timeout after 5 seconds
    }

    _ = playbackDevice.Stop()
    return nil
}

// PlayAudioFile plays a WAV file in a separate goroutine to avoid blocking
func PlayAudioFile(filename string) {
    go func() {
        fullPath := buildAssetPath(filename)
        if err := PlayWAVFile(fullPath); err != nil {
            log.Printf("🔊 Failed to play %s: %v", filename, err)
        }
    }()
}

// WAV header helpers
func writeWavHeader(f *os.File, dataLen uint32) error {
    // See RIFF/WAVE specification
    var (
        chunkID       = []byte{'R', 'I', 'F', 'F'}
        format        = []byte{'W', 'A', 'V', 'E'}
        subchunk1ID   = []byte{'f', 'm', 't', ' '}
        subchunk1Size = uint32(16) // PCM
        audioFormat   = uint16(1)  // PCM
        numChannels   = uint16(channels)
        sampleRateU   = uint32(sampleRate)
        byteRate      = sampleRateU * uint32(numChannels) * uint32(bitsPerSample/8)
        blockAlign    = uint16(numChannels * bitsPerSample / 8)
        bitsPS        = uint16(bitsPerSample)
        subchunk2ID   = []byte{'d', 'a', 't', 'a'}
        subchunk2Size = dataLen
        chunkSize     = uint32(36) + subchunk2Size
    )

    if _, err := f.Seek(0, 0); err != nil {
        return err
    }
    bw := bufio.NewWriter(f)
    // RIFF
    if _, err := bw.Write(chunkID); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, chunkSize); err != nil { return err }
    if _, err := bw.Write(format); err != nil { return err }
    // fmt
    if _, err := bw.Write(subchunk1ID); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, subchunk1Size); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, audioFormat); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, numChannels); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, sampleRateU); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, byteRate); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, blockAlign); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, bitsPS); err != nil { return err }
    // data
    if _, err := bw.Write(subchunk2ID); err != nil { return err }
    if err := binary.Write(bw, binary.LittleEndian, subchunk2Size); err != nil { return err }

    if err := bw.Flush(); err != nil { return err }
    // seek to the start of data
    _, err := f.Seek(wavHeaderLen, 0)
    return err
}

// NewVoiceRunner creates a new voice runner with configuration and callbacks
func NewVoiceRunner(config types.VoiceConfig, callbacks types.VoiceCallbacks) *VoiceRunner {
    return &VoiceRunner{
        config:    config,
        callbacks: callbacks,
        stopChan:  make(chan bool, 1),
    }
}

// Start starts the voice recognition
func (vr *VoiceRunner) Start() error {
    vr.mutex.Lock()
    defer vr.mutex.Unlock()
    
    if vr.running {
        return errors.New("voice recognition already running")
    }
    
    vr.running = true
    go vr.run()
    return nil
}

// Stop stops the voice recognition
func (vr *VoiceRunner) Stop() error {
    vr.mutex.Lock()
    defer vr.mutex.Unlock()
    
    if !vr.running {
        return nil
    }
    
    vr.running = false
    select {
    case vr.stopChan <- true:
    default:
    }
    
    return nil
}

// IsRunning returns whether voice recognition is currently running
func (vr *VoiceRunner) IsRunning() bool {
    vr.mutex.RLock()
    defer vr.mutex.RUnlock()
    return vr.running
}

// run is the main voice recognition loop (refactored from original Run function)
func (vr *VoiceRunner) run() {
    defer func() {
        vr.mutex.Lock()
        vr.running = false
        vr.mutex.Unlock()
    }()

    log.Printf("🚀 OpenWake Voice Assistant")
    log.Printf("   Whisper Model: %s", vr.config.WhisperModel)
    log.Printf("   Whisper Device: %s", vr.config.WhisperDevice)  
    log.Printf("   Compute Type: %s", vr.config.ComputeType)
    log.Printf("   Wake Threshold: %.2f", vr.config.WakeThreshold)
    
    // Log the executable directory for debugging
    if execDir, err := getExecutableDir(); err == nil {
        log.Printf("   Executable Dir: %s", execDir)
        log.Printf("   Assets Dir: %s", filepath.Join(execDir, "assets", "voice"))
    }
    log.Printf("")

    // List available audio input devices
    if err := ListAudioInputDevices(); err != nil {
        log.Printf("⚠️  Failed to enumerate audio devices: %v", err)
    }
    log.Printf("") // Empty line for better readability

    // Prepare audio file (relative to executable)
    outPath := buildPath("audio.wav")
    f, err := os.Create(outPath)
    if err != nil {
        log.Fatalf("create wav: %v", err)
    }
    defer f.Close()

    // Placeholder header (dataLen = 0); we update on exit
    if err := writeWavHeader(f, 0); err != nil {
        log.Fatalf("header: %v", err)
    }

    var py *exec.Cmd
    var pyStdin *os.File

    var totalBytes uint64
    var fileMutex sync.RWMutex

    processIntent := func(transcription string) *types.IntentResult {
        log.Printf("🤖 Processing intent for: \"%s\"", transcription)
        
        // Use Python script from assets/voice directory
        intentScript := buildAssetPath("intent.py")
        cmd := exec.Command("python3", intentScript, transcription)
        output, err := cmd.Output()
        if err != nil {
            log.Printf("❌ Intent processing failed: %v", err)
            return nil
        }
        
        var result types.IntentResult
        if err := utils.ParseScriptOutput(output, &result); err != nil {
            log.Printf("❌ Failed to parse intent result: %v", err)
            log.Printf("Raw intent.py output: %q", string(output))
            log.Printf("Output length: %d bytes", len(output))
            return nil
        }
        
        return &result
    }

    restartPythonReader := func() {
        if py == nil || pyStdin == nil {
            log.Printf("Python not running, cannot restart reader")
            return
        }
        _, err := pyStdin.WriteString("RESTART\n")
        if err != nil {
            log.Printf("Failed to send restart signal: %v", err)
        }
        if err := pyStdin.Sync(); err != nil {
        }
    }

    resetFile := func() {
        fileMutex.Lock()
        defer fileMutex.Unlock()
        
        _ = f.Close()
        
        f, err = os.Create(outPath)
        if err != nil {
            log.Printf("reset file error: %v", err)
            return
        }
        if err := writeWavHeader(f, 0); err != nil {
            log.Printf("reset header error: %v", err)
            return
        }
        totalBytes = 0
        restartPythonReader()
    }

    startPython := func() {
        if py != nil {
            return // Python already running
        }
        
        // Use Python script from assets/voice directory
        wakeListenerScript := buildAssetPath("wake_listener.py")
        py = exec.Command("python3", wakeListenerScript, 
            "--file", outPath,
            "--whisper-model", vr.config.WhisperModel,
            "--whisper-device", vr.config.WhisperDevice,
            "--compute-type", vr.config.ComputeType)
        py.Stderr = os.Stderr
        
        // Create pipes for stdin and stdout
        stdin, err := py.StdinPipe()
        if err != nil {
            log.Printf("stdin pipe error: %v", err)
            return
        }
        pyStdin = stdin.(*os.File)
        
        stdout, err := py.StdoutPipe()
        if err != nil {
            log.Printf("stdout pipe error: %v", err)
            return
        }
        
        if err := py.Start(); err != nil {
            log.Printf("start python error: %v", err)
            return
        }
        
        log.Printf("Python listener started, pid=%d", py.Process.Pid)
        
        // Monitor Python stdout in a goroutine
        go func() {
            scanner := bufio.NewScanner(stdout)
            for scanner.Scan() {
                line := scanner.Text()
                var event PythonEvent
                if err := json.Unmarshal([]byte(line), &event); err != nil {
                    continue
                }
                
                switch event.Type {
                case "wakeword":
                    log.Printf("🎯 WAKE WORD DETECTED: %s (score: %.3f)", event.Label, event.Score)
                    PlayAudioFile("request-arnav-geddada.wav")
                    if vr.callbacks.OnWakeWordDetected != nil {
                        vr.callbacks.OnWakeWordDetected(event.Label, event.Score)
                    }
                case "listening_start":
                    if event.Message != "" {
                        log.Printf("👂 %s", event.Message)
                    } else {
                        log.Printf("👂 Started listening for speech...")
                    }
                case "audio_debug":
                case "silence_detected":
                    PlayAudioFile("processing-rusu-gabriel.wav")
                    log.Printf("🔇 %s", event.Message)
                case "max_buffer_reached":
                    log.Printf("📦 %s", event.Message)
                case "transcription":
                    if event.AudioDuration > 0 && event.ProcessingTime > 0 {
                        log.Printf("💬 TRANSCRIPTION (%.2fs audio, %.3fs processing): \"%s\"", 
                            event.AudioDuration, event.ProcessingTime, event.Text)
                    } else {
                        log.Printf("💬 TRANSCRIPTION: \"%s\"", event.Text)
                    }
                    
                    // Call transcription callback
                    if vr.callbacks.OnTranscription != nil {
                        vr.callbacks.OnTranscription(event.Text, event.AudioDuration, event.ProcessingTime)
                    }
                    
                    if event.Text != "" {
                        intentResult := processIntent(event.Text)
                        if intentResult != nil {
                            if intentResult.Success {
                                log.Printf("🎯 SUCCESS: Processed %d device commands", len(intentResult.Commands))
                                for i, cmd := range intentResult.Commands {
                                    log.Printf("📋 COMMAND %d: %s (%s) -> %s = %v", 
                                        i+1, cmd.CustomName, cmd.IEEEAddress, cmd.Property, cmd.Value)
                                }
                                
                                // Call intent callback
                                if vr.callbacks.OnIntent != nil {
                                    vr.callbacks.OnIntent(event.Text, intentResult)
                                }
                            } else {
                                log.Printf("❓ Intent processing failed: %s", intentResult.Error)
                            }
                        }
                    }
                    
                    PlayAudioFile("done-arnav-geddada.wav")
                    
                    log.Printf("🔄 Resetting audio file after transcription...")
                    resetFile()
                case "error":
                    if event.ProcessingTime > 0 {
                        log.Printf("❌ Error (%.3fs processing): %s", event.ProcessingTime, event.Message)
                    } else {
                        log.Printf("❌ Error: %s", event.Message)
                    }
                    
                    // Call error callback
                    if vr.callbacks.OnError != nil {
                        vr.callbacks.OnError(event.Message, event.ProcessingTime)
                    }
                case "info":
                    log.Printf("ℹ️  %s", event.Message)
                default:
                    log.Printf("Unknown event type: %s", event.Type)
                }
            }
            if err := scanner.Err(); err != nil {
                log.Printf("Python stdout scanner error: %v", err)
            }
        }()
    }

    startPython()

    resetTimer := time.NewTicker(resetInterval)
    defer resetTimer.Stop()
    go func() {
        for range resetTimer.C {
            resetFile()
        }
    }()

    ctx, err := malgo.InitContext(nil, malgo.ContextConfig{}, func(message string) {
        log.Printf("[malgo] %s", message)
    })
    if err != nil {
        log.Fatalf("malgo.InitContext: %v", err)
    }
    defer func() {
        _ = ctx.Uninit()
        ctx.Free()
    }()

    deviceConfig := malgo.DefaultDeviceConfig(malgo.Capture)
    deviceConfig.Capture.Format = malgo.FormatS16
    deviceConfig.Capture.Channels = channels
    deviceConfig.SampleRate = sampleRate
    deviceConfig.Alsa.NoMMap = 1

    onRecvFrames := func(_ []byte, pInputSample []byte, frameCount uint32) {
        if len(pInputSample) == 0 {
            return
        }
        
        fileMutex.RLock()
        defer fileMutex.RUnlock()
        
        if f == nil {
            return
        }
        
        if _, err := f.Write(pInputSample); err != nil {
            if !errors.Is(err, os.ErrClosed) {
                log.Printf("write error: %v", err)
            }
            return
        }
        totalBytes += uint64(len(pInputSample))
    }

    deviceCallbacks := malgo.DeviceCallbacks{
        Data: onRecvFrames,
    }

    device, err := malgo.InitDevice(ctx.Context, deviceConfig, deviceCallbacks)
    if err != nil {
        log.Fatalf("InitDevice: %v", err)
    }
    defer device.Uninit()

    if err := device.Start(); err != nil {
        log.Fatalf("Start: %v", err)
    }
    log.Printf("Capturing @ %d Hz, %d ch, %d-bit… Voice recognition active.", sampleRate, channels, bitsPerSample)

    // Wait for stop signal
    <-vr.stopChan

    _ = device.Stop()

    if totalBytes > 0 {
        if err := writeWavHeader(f, uint32(totalBytes)); err != nil {
            log.Printf("finalize header: %v", err)
        }
    }

    time.Sleep(300 * time.Millisecond)
    if py != nil {
        if pyStdin != nil {
            _ = pyStdin.Close()
        }
        _ = py.Process.Signal(os.Interrupt)
    }
}