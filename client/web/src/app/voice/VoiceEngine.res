// SPDX-License-Identifier: PMPL-1.0-or-later
//
// VoiceEngine — WebRTC voice connection manager.
//
// Handles the client side of the voice pipeline:
//   1. getUserMedia for microphone access
//   2. WebRTC peer connection to the Burble SFU
//   3. ICE candidate exchange (TURN-only in privacy mode)
//   4. Opus audio encoding/decoding
//   5. E2EE via Insertable Streams (when enabled)
//   6. Push-to-talk / VAD switching
//   7. Audio level monitoring (for speaking indicators)
//   8. Per-user volume control (on received streams)
//
// The voice engine is framework-agnostic — it manages WebRTC state
// and exposes callbacks. The UI layer subscribes to state changes.

/// Voice connection state.
type connectionState =
  | /// Not connected to any room.
  Disconnected
  | /// Connecting to the SFU (ICE negotiation in progress).
  Connecting
  | /// Connected and ready for voice.
  Connected
  | /// Connection lost, attempting to reconnect.
  Reconnecting
  | /// Connection failed permanently.
  Failed(string)

/// Voice input mode.
type inputMode =
  | /// Microphone is always open; VAD determines when speaking.
  VoiceActivity
  | /// Microphone only active while push-to-talk key is held.
  PushToTalk

/// Voice state (mirrors server-side Participant voice states).
type voiceState =
  | /// Mic active, can speak and hear.
  Active
  | /// Self-muted (can hear, can't speak).
  Muted
  | /// Self-deafened (can't hear or speak).
  Deafened

/// Audio device info.
type audioDevice = {
  deviceId: string,
  label: string,
  kind: string,
}

/// Voice engine configuration.
type config = {
  /// Input mode (VAD or push-to-talk).
  inputMode: inputMode,
  /// Push-to-talk key code (default: Space).
  pttKeyCode: string,
  /// VAD threshold (0.0-1.0, default 0.02).
  vadThreshold: float,
  /// Whether E2EE is enabled.
  e2eeEnabled: bool,
  /// Privacy mode from server.
  privacyMode: string,
  /// Noise suppression (browser-native).
  noiseSuppression: bool,
  /// Echo cancellation (browser-native).
  echoCancellation: bool,
  /// Auto gain control.
  autoGainControl: bool,
}

/// Default voice engine configuration.
let defaultConfig: config = {
  inputMode: VoiceActivity,
  pttKeyCode: "Space",
  vadThreshold: 0.02,
  e2eeEnabled: false,
  privacyMode: "turn_only",
  noiseSuppression: true,
  echoCancellation: true,
  autoGainControl: true,
}

/// Voice engine state (mutable, managed internally).
type t = {
  mutable state: connectionState,
  mutable voiceState: voiceState,
  mutable config: config,
  mutable isSpeaking: bool,
  mutable audioLevel: float,
  /// Peer volumes (user_id => volume 0.0-2.0).
  peerVolumes: dict<float>,
  /// Callback: state changed.
  mutable onStateChange: option<connectionState => unit>,
  /// Callback: speaking state changed.
  mutable onSpeakingChange: option<bool => unit>,
  /// Callback: audio level updated (called per frame).
  mutable onAudioLevel: option<float => unit>,
  /// Callback: remote peer started/stopped speaking.
  mutable onPeerSpeaking: option<(string, bool) => unit>,
}

/// Create a new voice engine instance.
let make = (~config: config=defaultConfig): t => {
  state: Disconnected,
  voiceState: Active,
  config,
  isSpeaking: false,
  audioLevel: 0.0,
  peerVolumes: Dict.make(),
  onStateChange: None,
  onSpeakingChange: None,
  onAudioLevel: None,
  onPeerSpeaking: None,
}

/// Connect to a room's voice session.
/// In production, this creates a WebRTC PeerConnection to the SFU.
let connect = (engine: t, ~roomId: string, ~token: string): unit => {
  ignore(roomId)
  ignore(token)
  engine.state = Connecting
  switch engine.onStateChange {
  | Some(cb) => cb(Connecting)
  | None => ()
  }
  // TODO: Create RTCPeerConnection, request SDP offer from server,
  // apply ICE policy (TURN-only), set up Insertable Streams if E2EE.
  // For now, simulate successful connection.
  engine.state = Connected
  switch engine.onStateChange {
  | Some(cb) => cb(Connected)
  | None => ()
  }
}

/// Disconnect from voice.
let disconnect = (engine: t): unit => {
  engine.state = Disconnected
  engine.isSpeaking = false
  switch engine.onStateChange {
  | Some(cb) => cb(Disconnected)
  | None => ()
  }
}

/// Toggle mute state.
let toggleMute = (engine: t): voiceState => {
  engine.voiceState = switch engine.voiceState {
  | Active => Muted
  | Muted => Active
  | Deafened => Active
  }
  engine.voiceState
}

/// Toggle deafen state.
let toggleDeafen = (engine: t): voiceState => {
  engine.voiceState = switch engine.voiceState {
  | Deafened => Active
  | _ => Deafened
  }
  engine.voiceState
}

/// Set input mode (VAD or push-to-talk).
let setInputMode = (engine: t, mode: inputMode): unit => {
  engine.config = {...engine.config, inputMode: mode}
}

/// Set per-peer volume (0.0 = silent, 1.0 = normal, 2.0 = boosted).
let setPeerVolume = (engine: t, ~peerId: string, ~volume: float): unit => {
  let clamped = Math.max(0.0, Math.min(2.0, volume))
  Dict.set(engine.peerVolumes, peerId, clamped)
}

/// Get the audio device list.
/// NOTE: Only called when user explicitly opens device settings.
/// We never enumerate devices preemptively (privacy protection).
let getAudioDevices = async (): array<audioDevice> => {
  // TODO: Call navigator.mediaDevices.enumerateDevices()
  // Only after getUserMedia has been granted (labels require permission)
  []
}

/// Get current connection state.
let getState = (engine: t): connectionState => engine.state

/// Get current voice state.
let getVoiceState = (engine: t): voiceState => engine.voiceState

/// Whether the user is currently speaking.
let isSpeaking = (engine: t): bool => engine.isSpeaking

/// Current audio input level (0.0-1.0).
let getAudioLevel = (engine: t): float => engine.audioLevel
