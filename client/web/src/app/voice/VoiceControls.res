// SPDX-License-Identifier: PMPL-1.0-or-later
//
// VoiceControls — Voice control bar UI state.
//
// The persistent bottom bar showing:
//   - Mute/deafen buttons
//   - Push-to-talk indicator
//   - Audio level meter
//   - Connection quality indicator
//   - Settings gear
//
// This module manages the state; rendering is handled by the UI layer.

/// Network quality indicator levels.
type networkQuality =
  | Excellent
  | Good
  | Fair
  | Poor
  | Disconnected

/// Voice control bar state.
type t = {
  mutable voiceState: VoiceEngine.voiceState,
  mutable connectionState: VoiceEngine.connectionState,
  mutable isSpeaking: bool,
  mutable audioLevel: float,
  mutable networkQuality: networkQuality,
  mutable inputMode: VoiceEngine.inputMode,
  mutable pttActive: bool,
  mutable roomName: string,
  mutable participantCount: int,
}

/// Create initial voice controls state.
let make = (): t => {
  voiceState: Active,
  connectionState: VoiceEngine.Disconnected,
  isSpeaking: false,
  audioLevel: 0.0,
  networkQuality: Disconnected,
  inputMode: VoiceActivity,
  pttActive: false,
  roomName: "",
  participantCount: 0,
}

/// Update from voice engine state.
let syncFromEngine = (controls: t, engine: VoiceEngine.t): unit => {
  controls.voiceState = VoiceEngine.getVoiceState(engine)
  controls.connectionState = VoiceEngine.getState(engine)
  controls.isSpeaking = VoiceEngine.isSpeaking(engine)
  controls.audioLevel = VoiceEngine.getAudioLevel(engine)
}

/// Display text for the mute button.
let muteButtonLabel = (controls: t): string =>
  switch controls.voiceState {
  | Active => "Mute"
  | Muted => "Unmute"
  | Deafened => "Unmute"
  }

/// Display text for the deafen button.
let deafenButtonLabel = (controls: t): string =>
  switch controls.voiceState {
  | Deafened => "Undeafen"
  | _ => "Deafen"
  }

/// Connection status display string.
let connectionLabel = (controls: t): string =>
  switch controls.connectionState {
  | VoiceEngine.Disconnected => "Not connected"
  | VoiceEngine.Connecting => "Connecting..."
  | VoiceEngine.Connected =>
    if controls.participantCount > 0 {
      `${controls.roomName} (${Int.toString(controls.participantCount)})`
    } else {
      controls.roomName
    }
  | VoiceEngine.Reconnecting => "Reconnecting..."
  | VoiceEngine.Failed(msg) => `Failed: ${msg}`
  }

/// Network quality colour (hex int).
let networkQualityColor = (quality: networkQuality): int =>
  switch quality {
  | Excellent => 0x44ff44
  | Good => 0xaaff44
  | Fair => 0xffaa44
  | Poor => 0xff4444
  | Disconnected => 0x666666
  }
