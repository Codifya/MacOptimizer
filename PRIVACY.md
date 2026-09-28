# Privacy

This page describes what MacOptimizer Pro stores on your Mac and what it sends over the network.

## What stays on your Mac

- System monitoring, cleaning, duplicate finding and the watchdog run locally.
- Telemetry history (CPU, memory, memory pressure and disk use, one sample per minute) is stored
  in `~/Library/Application Support/com.osmancagrigenc.MacOptimizer/telemetry.sqlite` and pruned
  after 48 hours. The file is not encrypted.
- Settings and the list of completed operations (the last 500) are stored in the app's
  preferences (UserDefaults).
- None of this is uploaded anywhere.

## No tracking

MacOptimizer Pro contains no analytics, tracking, advertising or crash-reporting SDKs.

## API keys

An NVIDIA NIM API key you configure is stored in the macOS Keychain. It is not written to
UserDefaults and is sent only to the NVIDIA NIM endpoint as the HTTPS authorization credential.

## AI assistant

- Built-in local heuristics are the default and work offline.
- NVIDIA NIM is disabled by default and requires accepting an in-app disclosure before its first
  request.
- NVIDIA NIM receives the Mac hardware model, chip, macOS version, RAM/CPU/disk percentages,
  detected junk size, the number of apps with pending updates, and the recent chat messages sent
  to the assistant. The API key is sent only as the HTTPS authorization credential and is not
  part of the request body.
- Running app names and process IDs are excluded by default. The separate "Include running app
  names" setting opts them into NVIDIA NIM requests. File paths and file contents are not
  included in AI requests.
- Testing the connection or refreshing the model list contacts the configured NVIDIA NIM
  endpoint with your key.

## Other network requests

- App update checks read the configured Sparkle appcasts of installed apps; a feed configured
  with plain HTTP is contacted over HTTP.
- The VS Code update checker contacts the VS Code update API.
- Homebrew update and package operations invoke `brew`, which may contact its configured
  repositories and services.
