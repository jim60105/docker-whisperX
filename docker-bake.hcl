group "default" {
  targets = ["no_model", "build"]
}

variable "WHISPER_MODEL" {
  default = "base"
}

variable "LANG" {
  default = "en"
}

target "build" {
  matrix = {
    "WHISPER_MODEL" = [
      "tiny",
      "base",
      "small",
      "medium",
      "large-v2",
    ]
    "LANG" = [
      "en",
      "fr",
      "de",
      "es",
      "it",
      "ja",
      "zh",
      "nl",
      "uk",
      "pt",
      "ar",
      "cs",
      "ru",
      "pl",
      "hu",
      "fi",
      "fa",
      "el",
      "tr",
      "da",
      "he",
      "vi",
      "ko",
      "ur",
      "te"
    ]
  }

  name       = "whisperx-${WHISPER_MODEL}-${LANG}"
  dockerfile = "Dockerfile"
  tags = [
    "ghcr.io/jim60105/whisperx:${WHISPER_MODEL}-${LANG}",
    "quay.io/jim60105/whisperx:${WHISPER_MODEL}-${LANG}"
  ]
  platforms  = ["linux/amd64"]
  cache-from = ["type=local,mode=max,src=cache"]
  cache-to   = ["type=local,mode=max,dest=cache"]
}

target "no_model" {
  dockerfile = "Dockerfile.no_model"
  tags = [
    "quay.io/jim60105/whisperx:latest",
    "ghcr.io/jim60105/whisperx:latest",
    "quay.io/jim60105/whisperx:no_model",
    "ghcr.io/jim60105/whisperx:no_model"
  ]
  platforms  = ["linux/amd64"]
  cache-from = ["type=local,mode=max,src=cache"]
  cache-to   = ["type=local,mode=max,dest=cache"]
}