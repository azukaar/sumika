import openwakeword
openwakeword.utils.download_models()

from faster_whisper import WhisperModel
WhisperModel("base")