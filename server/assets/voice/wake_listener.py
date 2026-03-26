#!/usr/bin/env python3
import argparse
import os
import time
import numpy as np
import threading
import sys
import select
import json
import io
from collections import deque
from enum import Enum

# pip install openwakeword faster-whisper librosa
print("[wake_listener] Loading models...", file=sys.stderr, flush=True)
from openwakeword.model import Model
from faster_whisper import WhisperModel
import librosa
print("[wake_listener] Models loaded", file=sys.stderr, flush=True)

FRAME_MS = 80                   # preferred frame duration
SR = 16000                      # Hz
SAMPLE_BYTES = 2                # 16-bit
FRAME_BYTES = int(SR * (FRAME_MS/1000.0) * SAMPLE_BYTES)  # 2560 bytes
WAV_HEADER = 44                 # bytes

# Transcription settings
MAX_AUDIO_SECONDS = 10          # Max audio to buffer for transcription
SILENCE_TIMEOUT_MS = 1000       # Silence duration to trigger transcription
AUDIO_BUFFER_SIZE = int(SR * MAX_AUDIO_SECONDS * SAMPLE_BYTES)  # bytes

# Pre-filter defaults
FRAME_SAMPLES = int(SR * (FRAME_MS / 1000.0))  # 1280 samples per frame
DEFAULT_NOISE_REDUCTION = 1.5
DEFAULT_LIMITER_THRESHOLD = 0.7
DEFAULT_ATTACK_THRESHOLD = 15.0
DEFAULT_ATTACK_SUPPRESS_FRAMES = 2
DEFAULT_MIN_WAKE_DURATION = 0.3
PREFILTER_HISTORY_FRAMES = 15   # ~1.2 seconds at 80ms/frame

class ListenerState(Enum):
    WAKE_WORD_DETECTION = "wake_detection"
    LISTENING_FOR_SPEECH = "listening"
    PROCESSING_SPEECH = "processing"


class AudioPreFilter:
    """Pre-filters audio before wake word detection to reject transient sounds."""

    def __init__(self, noise_reduction=DEFAULT_NOISE_REDUCTION,
                 limiter_threshold=DEFAULT_LIMITER_THRESHOLD,
                 attack_threshold=DEFAULT_ATTACK_THRESHOLD,
                 attack_suppress_frames=DEFAULT_ATTACK_SUPPRESS_FRAMES,
                 min_wake_duration=DEFAULT_MIN_WAKE_DURATION):
        self.noise_reduction = noise_reduction
        self.limiter_threshold = limiter_threshold
        self.attack_threshold = attack_threshold
        self.attack_suppress_frames = attack_suppress_frames
        self.min_wake_duration = min_wake_duration

        # Noise reduction state
        rfft_size = FRAME_SAMPLES // 2 + 1
        self.noise_floor = np.zeros(rfft_size, dtype=np.float64)
        self._noise_frames_seen = 0
        self._noise_bootstrap_frames = 12  # ~1s at 80ms/frame

        # Attack gate state
        self._energy_history = deque(maxlen=6)  # ~480ms of RMS history
        self._suppress_countdown = 0
        self._suppressed = False

        # Duration validation state
        self._rms_history = deque(maxlen=PREFILTER_HISTORY_FRAMES)

        # Logging
        self._log_counter = 0

    def _log(self, message):
        """Emit a prefilter log event."""
        event = {"type": "prefilter_debug", "message": message, "timestamp": time.time()}
        print(json.dumps(event), flush=True)

    def process(self, samples):
        """Apply noise reduction, limiter, and attack gate. Returns filtered int16 samples."""
        raw_rms = np.sqrt(np.mean((samples.astype(np.float32) / 32768.0) ** 2))
        audio = samples.astype(np.float32) / 32768.0

        # 1. Noise reduction (spectral subtraction)
        if self.noise_reduction > 0:
            audio = self._apply_noise_reduction(audio)

        # 2. Soft limiter
        if self.limiter_threshold > 0:
            audio = self._apply_limiter(audio)

        # 3. Attack gate
        rms = np.sqrt(np.mean(audio ** 2))
        self._rms_history.append(raw_rms)  # track raw RMS for duration validation
        suppressed = False

        if self.attack_threshold > 0:
            suppressed = self._check_attack_gate(rms)

        self._energy_history.append(rms)

        if suppressed:
            self._suppressed = True
            self._log(f"Attack gate SUPPRESSED frame (raw_rms={raw_rms:.4f}, filtered_rms={rms:.4f})")
            # Return silence so the model's internal buffer stays aligned
            return np.zeros(len(samples), dtype=np.int16)

        self._suppressed = False
        # Convert back to int16
        return np.clip(audio * 32768.0, -32768, 32767).astype(np.int16)

    def should_suppress(self):
        """True if the last frame was gated by the attack detector."""
        return self._suppressed

    def validate_detection(self):
        """Check if recent audio energy is sustained enough to be a real wake word."""
        if self.min_wake_duration <= 0:
            return True

        if len(self._rms_history) < 3:
            return True

        history = list(self._rms_history)
        median_rms = np.median(history)
        elevated_threshold = max(median_rms * 2.0, 0.005)

        # Find the longest consecutive elevated region anywhere in the buffer,
        # not just from the end (model detection lags a few frames behind speech)
        best_run = 0
        current_run = 0
        gap_budget = 1  # allow 1 non-elevated frame within a run

        for rms_val in history:
            if rms_val >= elevated_threshold:
                current_run += 1
                gap_budget = 1  # reset gap allowance
            else:
                if gap_budget > 0:
                    gap_budget -= 1
                    current_run += 1  # count the gap frame
                else:
                    best_run = max(best_run, current_run)
                    current_run = 0
                    gap_budget = 1
        best_run = max(best_run, current_run)

        duration_s = best_run * (FRAME_MS / 1000.0)
        rms_values = [f"{v:.4f}" for v in history]
        self._log(f"Duration check: {duration_s:.2f}s (need {self.min_wake_duration}s), threshold={elevated_threshold:.4f}, rms=[{', '.join(rms_values)}]")
        if duration_s < self.min_wake_duration:
            return False
        return True

    def _apply_noise_reduction(self, audio):
        """Spectral subtraction using exponential moving average noise floor."""
        spectrum = np.fft.rfft(audio)
        magnitude = np.abs(spectrum)
        phase = np.angle(spectrum)

        # Adapt noise floor estimate — only during quiet periods to prevent
        # speech or response playback from polluting the noise estimate
        rms = np.sqrt(np.mean(audio ** 2))
        self._noise_frames_seen += 1

        if self._noise_frames_seen <= self._noise_bootstrap_frames:
            # Fast adaptation during bootstrap (first ~1s)
            alpha = 0.2
            self.noise_floor = alpha * magnitude + (1.0 - alpha) * self.noise_floor
        elif rms < 0.015:
            # Only update noise floor when audio is clearly just ambient noise
            alpha = 0.05
            self.noise_floor = alpha * magnitude + (1.0 - alpha) * self.noise_floor

        # Subtract noise floor from magnitude
        cleaned_magnitude = np.maximum(magnitude - self.noise_reduction * self.noise_floor, 0.0)

        # Reconstruct signal
        cleaned_spectrum = cleaned_magnitude * np.exp(1j * phase)
        cleaned_audio = np.fft.irfft(cleaned_spectrum, n=len(audio)).astype(np.float32)
        return cleaned_audio

    def _apply_limiter(self, audio):
        """Soft limiter using tanh compression."""
        peak = np.max(np.abs(audio))
        if peak > self.limiter_threshold:
            audio = np.tanh(audio / self.limiter_threshold) * self.limiter_threshold
        return audio

    def _check_attack_gate(self, current_rms):
        """Check if energy appeared too suddenly (transient/impulse)."""
        # Still in suppress period from a previous transient
        if self._suppress_countdown > 0:
            self._suppress_countdown -= 1
            return True

        if len(self._energy_history) < 3:
            return False

        # Mean of previous 3 frames
        recent = list(self._energy_history)[-3:]
        prev_mean = np.mean(recent)
        epsilon = 1e-6

        attack_ratio = current_rms / (prev_mean + epsilon)

        # Only gate truly loud transients — speech onset is moderate (RMS 0.02-0.08),
        # glass clicks/knocks are very loud (RMS 0.2+)
        is_loud_transient = current_rms > 0.15

        # Check if previous frames were quiet (ambient noise level)
        quiet_floor = np.median(list(self._energy_history)) + np.std(list(self._energy_history))
        was_quiet = prev_mean < max(quiet_floor, 0.02)

        if attack_ratio > self.attack_threshold and was_quiet and is_loud_transient:
            self._suppress_countdown = self.attack_suppress_frames
            return True

        return False


class RestartableFileReader:
    def __init__(self, path):
        self.path = path
        self.f = None
        self.leftover = b''
        self.restart_requested = False
        self.open_file()
    
    def open_file(self):
        if self.f:
            self.f.close()
        self.f = open(self.path, 'rb', buffering=0)
        self.f.seek(WAV_HEADER)
        self.leftover = b''
        self.restart_requested = False
    
    def request_restart(self):
        self.restart_requested = True
    
    def read_frame(self):
        """Read one 80ms frame, returns None if restart requested"""
        if self.restart_requested:
            restart_event = {
                "type": "info",
                "message": "File reader restarted",
                "timestamp": time.time()
            }
            print(json.dumps(restart_event), flush=True)
            self.open_file()
            
            # Send listening_start event after restart to track restart time
            listening_restart_event = {
                "type": "listening_start",
                "message": "Resumed listening after file restart",
                "timestamp": time.time()
            }
            print(json.dumps(listening_restart_event), flush=True)
            return None
            
        chunk = self.f.read(FRAME_BYTES - len(self.leftover))
        if not chunk:
            time.sleep(0.03)
            return None
            
        buf = self.leftover + chunk
        if len(buf) < FRAME_BYTES:
            self.leftover = buf
            return None
            
        frame = buf[:FRAME_BYTES]
        self.leftover = buf[FRAME_BYTES:]
        return np.frombuffer(frame, dtype=np.int16)

class SpeechProcessor:
    def __init__(self, whisper_model="base", device="cpu", compute_type="int8"):
        self.whisper_model = WhisperModel(whisper_model, device=device, compute_type=compute_type)
        self.audio_buffer = deque(maxlen=int(AUDIO_BUFFER_SIZE // FRAME_BYTES))
        self.state = ListenerState.WAKE_WORD_DETECTION
        self.silence_start_time = None
        self.last_speech_time = None
        self.last_transcription_time = None
        self.cooldown_period = 1.0  # 1 seconds cooldown after transcription
    
    def add_audio_frame(self, samples):
        """Add audio frame to buffer when in listening state"""
        if self.state == ListenerState.LISTENING_FOR_SPEECH:
            self.audio_buffer.append(samples)
            
            # Librosa-based audio analysis
            audio_float = samples.astype(np.float32) / 32768.0
            current_time = time.time()
            
            # Use librosa for RMS energy calculation
            rms = librosa.feature.rms(y=audio_float, frame_length=len(audio_float), hop_length=len(audio_float))[0][0]
            
            # Use librosa for spectral centroid (helps distinguish speech from noise)
            spectral_centroid = librosa.feature.spectral_centroid(y=audio_float, sr=SR)[0][0]
            
            # Use librosa for zero crossing rate (helps identify speech characteristics)
            zcr = librosa.feature.zero_crossing_rate(y=audio_float)[0][0]
            
            # Dynamic threshold based on recent audio levels
            if not hasattr(self, 'recent_features'):
                self.recent_features = deque(maxlen=50)  # Keep last 50 frames (~4 seconds)
            
            features = {
                'rms': rms,
                'spectral_centroid': spectral_centroid,
                'zcr': zcr
            }
            self.recent_features.append(features)
            
            # Calculate adaptive thresholds
            if len(self.recent_features) > 10:
                recent_rms = [f['rms'] for f in list(self.recent_features)]
                recent_zcr = [f['zcr'] for f in list(self.recent_features)]
                
                avg_rms = np.mean(recent_rms)
                std_rms = np.std(recent_rms)
                avg_zcr = np.mean(recent_zcr)
                
                # More sophisticated silence detection
                rms_threshold = max(avg_rms * 0.25, 0.01)  # 25% of average RMS, min 0.01
                zcr_threshold = avg_zcr * 1.5  # High ZCR might indicate noise
                
                # Consider silent if RMS is low AND ZCR is not too high (not noisy)
                is_silent = (rms < rms_threshold) and (zcr < zcr_threshold)
            else:
                # Initial thresholds during calibration
                rms_threshold = 0.02
                zcr_threshold = 0.1
                is_silent = rms < rms_threshold
            
            # Debug logging every 1 second (12.5 frames at 80ms each)
            if not hasattr(self, 'debug_counter'):
                self.debug_counter = 0
            self.debug_counter += 1
            
            if self.debug_counter % 12 == 0:  # Every ~1 second
                debug_event = {
                    "type": "audio_debug",
                    "message": f"RMS: {rms:.3f} (thresh: {rms_threshold:.3f}), ZCR: {zcr:.3f}, SC: {spectral_centroid:.0f}Hz, Silent: {is_silent}",
                    "timestamp": time.time()
                }
                print(json.dumps(debug_event), flush=True)
            
            if is_silent:
                if self.silence_start_time is None:
                    self.silence_start_time = current_time
                elif (current_time - self.silence_start_time) * 1000 > SILENCE_TIMEOUT_MS:
                    # Silence detected for too long, process audio
                    silence_event = {
                        "type": "silence_detected",
                        "message": f"Silence detected after {SILENCE_TIMEOUT_MS}ms (RMS: {rms:.3f} < {rms_threshold:.3f}, ZCR: {zcr:.3f}), starting transcription...",
                        "timestamp": time.time()
                    }
                    print(json.dumps(silence_event), flush=True)
                    return self.process_buffered_audio()
            else:
                # Speech detected, reset silence timer
                self.silence_start_time = None
                self.last_speech_time = current_time
            
            # Check for max buffer size
            if len(self.audio_buffer) >= self.audio_buffer.maxlen - 10:
                max_buffer_event = {
                    "type": "max_buffer_reached",
                    "message": f"Max buffer size reached ({MAX_AUDIO_SECONDS}s), starting transcription...",
                    "timestamp": time.time()
                }
                print(json.dumps(max_buffer_event), flush=True)
                return self.process_buffered_audio()
        
        return None
    
    def start_listening(self):
        """Start listening for speech after wake word"""
        self.state = ListenerState.LISTENING_FOR_SPEECH
        self.audio_buffer.clear()
        self.silence_start_time = None
        self.last_speech_time = time.time()
        
        return {
            "type": "listening_start",
            "timestamp": time.time()
        }
    
    def process_buffered_audio(self):
        """Process buffered audio with Whisper"""
        if len(self.audio_buffer) == 0:
            self.state = ListenerState.WAKE_WORD_DETECTION
            return None
            
        self.state = ListenerState.PROCESSING_SPEECH
        
        # Convert buffer to numpy array
        audio_data = np.concatenate(list(self.audio_buffer))
        audio_duration = len(audio_data) / SR
        
        # Convert to float32 and normalize
        audio_float = audio_data.astype(np.float32) / 32768.0
        
        # Start timing
        start_time = time.time()
        
        try:
            # Transcribe with VAD
            segments, _ = self.whisper_model.transcribe(
                audio_float,
                vad_filter=True,
                vad_parameters=dict(min_silence_duration_ms=SILENCE_TIMEOUT_MS),
                language="en"  # You can make this configurable
            )
            
            # Combine all segments
            transcription = " ".join([segment.text.strip() for segment in segments])
            
            # Calculate processing time
            processing_time = time.time() - start_time
            
            result = {
                "type": "transcription",
                "text": transcription,
                "audio_duration": round(audio_duration, 2),
                "processing_time": round(processing_time, 3),
                "timestamp": time.time()
            }
            
        except Exception as e:
            processing_time = time.time() - start_time
            result = {
                "type": "error",
                "message": f"Transcription failed: {str(e)}",
                "processing_time": round(processing_time, 3),
                "timestamp": time.time()
            }
        
        # Reset to wake word detection
        self.state = ListenerState.WAKE_WORD_DETECTION
        self.audio_buffer.clear()
        self.last_transcription_time = time.time()
        
        # Clear any internal state
        self.recent_features = deque(maxlen=50) if hasattr(self, 'recent_features') else None
        self.debug_counter = 0 if hasattr(self, 'debug_counter') else None
        self.cooldown_logged = False  # Reset cooldown logging flag
        
        # Send cooldown start event
        cooldown_event = {
            "type": "info",
            "message": f"Starting {self.cooldown_period}s cooldown to prevent false wake word triggers",
            "timestamp": time.time()
        }
        print(json.dumps(cooldown_event), flush=True)
        
        return result
    
    def is_in_cooldown(self):
        """Check if we're in cooldown period after transcription"""
        if self.last_transcription_time is None:
            return False
        return (time.time() - self.last_transcription_time) < self.cooldown_period

def tail_wav_bytes(reader):
    """Yield successive 80 ms chunks using RestartableFileReader"""
    while True:
        samples = reader.read_frame()
        if samples is not None:
            yield samples


def stdin_monitor(reader):
    """Monitor stdin for restart commands"""
    # print("[stdin_monitor] Starting stdin monitor thread", file=sys.stderr)
    while True:
        try:
            # Use blocking read for both Windows and Unix
            # This works better with piped stdin from subprocess
            line = sys.stdin.readline()
            if not line:  # EOF
                # print("[stdin_monitor] EOF reached, exiting monitor", file=sys.stderr)
                break
            line = line.strip()
            # print(f"[stdin_monitor] Received: '{line}'", file=sys.stderr)
            if line == "RESTART":
                # print("[stdin_monitor] Restart command received", file=sys.stderr)
                reader.request_restart()
        except Exception as e:
            print(f"[stdin_monitor] Error: {e}", file=sys.stderr)
            time.sleep(1)

def main():
    print("Starting wake word listener...")
    
    ap = argparse.ArgumentParser()
    ap.add_argument('--file', required=True, help='Path to audio.wav written by Go')
    ap.add_argument('--threshold', type=float, default=0.6, help='Activation threshold')
    ap.add_argument('--vad', type=float, default=-1.0, help='Set >=0.0 to enable VAD gate (0..1)')
    ap.add_argument('--model', action='append', default=["sumika-model.onnx"], help='Optional paths or names of wakeword models to load')
    ap.add_argument('--whisper-model', default="base", help='Whisper model to use (tiny, base, small, medium, large-v1, large-v2, large-v3, turbo)')
    ap.add_argument('--whisper-device', default="cpu", help='Device for Whisper (cpu/cuda)')
    ap.add_argument('--compute-type', default="int8", help='Compute type for Whisper (int8, int16, float16, float32)')
    ap.add_argument('--noise-reduction', type=float, default=DEFAULT_NOISE_REDUCTION, help='Noise floor subtraction strength (0 to disable)')
    ap.add_argument('--limiter-threshold', type=float, default=DEFAULT_LIMITER_THRESHOLD, help='Soft limiter threshold 0-1 (0 to disable)')
    ap.add_argument('--attack-threshold', type=float, default=DEFAULT_ATTACK_THRESHOLD, help='Transient attack ratio threshold (0 to disable)')
    ap.add_argument('--attack-suppress-frames', type=int, default=DEFAULT_ATTACK_SUPPRESS_FRAMES, help='Frames to suppress after transient')
    ap.add_argument('--min-wake-duration', type=float, default=DEFAULT_MIN_WAKE_DURATION, help='Min wake word duration in seconds (0 to disable)')
    args = ap.parse_args()

    if not os.path.exists(args.file):
        raise SystemExit(f"{args.file} does not exist yet")

    print("[wake_listener] Downloading/checking wake word models...", file=sys.stderr, flush=True)
    import openwakeword
    openwakeword.utils.download_models()
    print("[wake_listener] Wake word models ready", file=sys.stderr, flush=True)

    # Convert model filenames to full paths if they exist in the script directory
    script_dir = os.path.dirname(os.path.abspath(__file__))
    resolved_models = []
    for model in args.model:
        # If it's just a filename, check if it exists in the script directory
        if not os.path.sep in model and not os.path.isabs(model):
            script_model_path = os.path.join(script_dir, model)
            if os.path.exists(script_model_path):
                resolved_models.append(script_model_path)
                print(f"Found model file: {script_model_path}")
            else:
                # Keep original name (might be a built-in model)
                resolved_models.append(model)
        else:
            resolved_models.append(model)
    
    args.model = resolved_models

    print("Loading openWakeWord models with arguments:")
    for model in args.model:
        print(f" - {model}")

    print("[wake_listener] Loading wake word model...", file=sys.stderr, flush=True)
    wake_model = Model(
        wakeword_models=args.model if args.model else None,
        # vad_threshold=None if args.vad < 0 else float(args.vad),
        enable_speex_noise_suppression=False,
        inference_framework="onnx", # for windows
    )
    print("[wake_listener] Wake word model loaded", file=sys.stderr, flush=True)

    print(f"[wake_listener] Loading Whisper model '{args.whisper_model}' on {args.whisper_device}...", file=sys.stderr, flush=True)
    speech_processor = SpeechProcessor(
        whisper_model=args.whisper_model,
        device=args.whisper_device,
        compute_type=args.compute_type
    )
    print("[wake_listener] Whisper model loaded", file=sys.stderr, flush=True)

    # Create audio pre-filter for wake word detection
    audio_prefilter = AudioPreFilter(
        noise_reduction=args.noise_reduction,
        limiter_threshold=args.limiter_threshold,
        attack_threshold=args.attack_threshold,
        attack_suppress_frames=args.attack_suppress_frames,
        min_wake_duration=args.min_wake_duration,
    )
    print(f"[wake_listener] Audio pre-filter enabled (noise={args.noise_reduction}, limiter={args.limiter_threshold}, attack={args.attack_threshold}, min_dur={args.min_wake_duration})", file=sys.stderr, flush=True)

    # Create file reader and start stdin monitor
    reader = RestartableFileReader(args.file)
    print("[main] Starting stdin monitor thread", file=sys.stderr)
    stdin_thread = threading.Thread(target=stdin_monitor, args=(reader,), daemon=True)
    stdin_thread.start()
    print(f"[main] stdin monitor thread started, is_alive={stdin_thread.is_alive()}", file=sys.stderr)

    print("Listening for wake words… (Ctrl+C to exit)")
    for samples in tail_wav_bytes(reader):
        # Process audio with speech processor (handles buffering when in listening state)
        transcription_result = speech_processor.add_audio_frame(samples)
        if transcription_result:
            print(json.dumps(transcription_result), flush=True)
            # Reset wake word model's internal buffers so it can detect immediately
            wake_model.reset()
        
        # Only check for wake words when in wake word detection state and not in cooldown
        if speech_processor.state == ListenerState.WAKE_WORD_DETECTION and not speech_processor.is_in_cooldown():
            # Pre-filter audio before wake word detection
            filtered_samples = audio_prefilter.process(samples)
            preds = wake_model.predict(filtered_samples)

            # If attack gate fired, ignore this prediction entirely
            if audio_prefilter.should_suppress():
                continue

            # preds is typically a dict {label: score} or a list of such dicts per frame
            if isinstance(preds, dict):
                frame_scores = preds
            else:
                try:
                    frame_scores = preds[-1]
                except Exception:
                    continue

            # Send any activations above threshold as JSON
            triggered = [(k, v) for k, v in frame_scores.items() if v >= args.threshold]
            if triggered:
                # Duration validation: reject if audio energy was too brief
                if not audio_prefilter.validate_detection():
                    reject_event = {
                        "type": "info",
                        "message": "Wake word rejected: audio too brief (likely transient/click)",
                        "timestamp": time.time()
                    }
                    print(json.dumps(reject_event), flush=True)
                    wake_model.reset()
                else:
                    for label, score in triggered:
                        # Wake word detected, start listening for speech
                        listening_event = speech_processor.start_listening()
                        print(json.dumps(listening_event), flush=True)

                        wake_event = {
                            "type": "wakeword",
                            "label": str(label),
                            "score": round(float(score), 3),
                            "timestamp": time.time()
                        }
                        print(json.dumps(wake_event), flush=True)
                        break  # Only process first wake word detection
        elif speech_processor.state == ListenerState.WAKE_WORD_DETECTION and speech_processor.is_in_cooldown():
            # During cooldown, still feed frames through pre-filter (keeps noise floor updated)
            # and to wake word model to clear its internal state
            filtered_samples = audio_prefilter.process(samples)
            _ = wake_model.predict(filtered_samples)


if __name__ == "__main__":
    main()
