import openwakeword
openwakeword.utils.download_models()

from faster_whisper import WhisperModel
import os

# Initialize and preload the WhisperModel
model = WhisperModel("base", compute_type="int8")

# Preload by transcribing a dummy file
dummy_file = os.path.join(os.path.dirname(__file__), "request-arnav-geddada.wav")
if os.path.exists(dummy_file):
    segments, info = model.transcribe(dummy_file)
    # Process the segments to fully load the model
    list(segments)
