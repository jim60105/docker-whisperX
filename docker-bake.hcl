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
      "large-v3",
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
      "te",
      "hi",
      "ca",
    ]
  }

  args = {
    WHISPER_MODEL = "${WHISPER_MODEL}"
    LANG          = "${LANG}"
  }

  name       = "whisperx-${WHISPER_MODEL}-${LANG}"
  dockerfile = "Dockerfile"
  tags = [
    "ghcr.io/jim60105/whisperx:${WHISPER_MODEL}-${LANG}"
  ]
  platforms  = ["linux/amd64", "linux/arm64"]
  cache-from = ["type=local,mode=max,src=cache"]
  cache-to   = ["type=local,mode=max,dest=cache"]
}

target "no_model" {
  dockerfile = "Dockerfile.no_model"
  tags = [
    "ghcr.io/jim60105/whisperx:latest",
    "ghcr.io/jim60105/whisperx:no_model"
  ]
  platforms  = ["linux/amd64", "linux/arm64"]
  cache-from = ["type=local,mode=max,src=cache"]
  cache-to   = ["type=local,mode=max,dest=cache"]
}

target "ubi-no_model" {
  dockerfile = "Dockerfile.ubi-no_model"
  tags = [
    "ghcr.io/jim60105/whisperx:ubi-no_model"
  ]
  platforms  = ["linux/amd64", "linux/arm64"]
  cache-from = ["type=local,mode=max,src=cache"]
  cache-to   = ["type=local,mode=max,dest=cache"]
}