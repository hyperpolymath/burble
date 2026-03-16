// SPDX-License-Identifier: PMPL-1.0-or-later
//
// VoiceEngine — WebRTC voice connection to Burble SFU.
//
// Handles the client side of the voice pipeline:
//   1. getUserMedia for microphone access
//   2. RTCPeerConnection to the Burble SFU
//   3. Server sends sdp_offer, client sends sdp_answer
//   4. ICE candidate exchange (TURN-only in privacy mode)
//   5. Opus audio encoding/decoding (browser-native)
//   6. Audio level monitoring (for speaking indicators)
//   7. Push-to-talk / VAD switching
//   8. Per-user volume control (on received streams)
//
// The voice engine is framework-agnostic — it manages WebRTC state
// and exposes callbacks. The UI layer subscribes to state changes.

/// Voice connection state.
type connectionState =
  | Disconnected
  | Connecting
  | Connected
  | Reconnecting
  | Failed(string)

/// Voice input mode.
type inputMode =
  | VoiceActivity
  | PushToTalk

/// Voice state (mirrors server-side).
type voiceState =
  | Active
  | Muted
  | Deafened

/// Audio device info.
type audioDevice = {
  deviceId: string,
  label: string,
  kind: string,
}

/// Voice engine configuration.
type config = {
  inputMode: inputMode,
  pttKeyCode: string,
  vadThreshold: float,
  e2eeEnabled: bool,
  privacyMode: string,
  noiseSuppression: bool,
  echoCancellation: bool,
  autoGainControl: bool,
}

/// Default configuration.
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
  /// WebRTC PeerConnection (opaque browser object).
  mutable peerConnection: option<{..}>,
  /// Local MediaStream from getUserMedia.
  mutable localStream: option<{..}>,
  /// AudioContext for level monitoring.
  mutable audioContext: option<{..}>,
  mutable analyserNode: option<{..}>,
  mutable levelIntervalId: option<Nullable.t<float>>,
  /// Per-peer volumes.
  peerVolumes: Dict.t<string, float>,
  /// Callbacks.
  mutable onStateChange: option<connectionState => unit>,
  mutable onSpeakingChange: option<bool => unit>,
  mutable onAudioLevel: option<float => unit>,
  mutable onPeerSpeaking: option<(string, bool) => unit>,
  /// Channel for signaling (set externally by App/PhoenixSocket).
  mutable sendSdpAnswer: option<string => unit>,
  mutable sendIceCandidate: option<string => unit>,
}

// ---------------------------------------------------------------------------
// External bindings
// ---------------------------------------------------------------------------

@val external getUserMedia: {..} => promise<{..}> = "navigator.mediaDevices.getUserMedia"
@new external makeRTCPeerConnection: {..} => {..} = "RTCPeerConnection"
@new external makeAudioContext: unit => {..} = "AudioContext"

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------

let make = (~config: config=defaultConfig): t => {
  state: Disconnected,
  voiceState: Active,
  config,
  isSpeaking: false,
  audioLevel: 0.0,
  peerConnection: None,
  localStream: None,
  audioContext: None,
  analyserNode: None,
  levelIntervalId: None,
  peerVolumes: Dict.make(),
  onStateChange: None,
  onSpeakingChange: None,
  onAudioLevel: None,
  onPeerSpeaking: None,
  sendSdpAnswer: None,
  sendIceCandidate: None,
}

// ---------------------------------------------------------------------------
// Connection lifecycle
// ---------------------------------------------------------------------------

/// Connect to the SFU. Call after joining the Phoenix channel.
/// The channel should set `sendSdpAnswer` and `sendIceCandidate` before calling this.
let connect = async (engine: t): result<unit, string> => {
  engine.state = Connecting
  notifyState(engine)

  // 1. Get microphone access.
  let constraints = {
    "audio": {
      "autoGainControl": engine.config.autoGainControl,
      "noiseSuppression": engine.config.noiseSuppression,
      "echoCancellation": engine.config.echoCancellation,
      "channelCount": 1,
      "sampleRate": 48000,
    },
    "video": false,
  }

  try {
    let stream = await getUserMedia(constraints)
    engine.localStream = Some(stream)

    // 2. Create PeerConnection with ICE config.
    let iceConfig = switch engine.config.privacyMode {
    | "standard" => {"iceServers": [{"urls": "stun:stun.l.google.com:19302"}]}
    | _ => {
        "iceServers": [{"urls": "stun:stun.l.google.com:19302"}],
        "iceTransportPolicy": "relay", // TURN-only for privacy modes.
      }
    }

    let pc = makeRTCPeerConnection(iceConfig)
    engine.peerConnection = Some(pc)

    // 3. Add local audio tracks to the PeerConnection.
    let tracks: array<{..}> = stream["getAudioTracks"]()
    tracks->Array.forEach(track => {
      pc["addTrack"](track, stream)
    })

    // 4. Handle ICE candidates — send to server.
    pc["onicecandidate"] = (event: {..}) => {
      let candidate = event["candidate"]
      if !Nullable.isNullable(Nullable.make(candidate)) {
        let json: string = %raw(`JSON.stringify(event.candidate.toJSON())`)
        switch engine.sendIceCandidate {
        | Some(send) => send(json)
        | None => ()
        }
      }
    }

    // 5. Handle incoming tracks (audio from other peers).
    pc["ontrack"] = (event: {..}) => {
      let remoteStreams: array<{..}> = event["streams"]
      // Create audio element for playback.
      if Array.length(remoteStreams) > 0 {
        let audio: {..} = %raw(`new Audio()`)
        audio["srcObject"] = remoteStreams[0]
        audio["autoplay"] = true
      }
    }

    // 6. Handle connection state changes.
    pc["onconnectionstatechange"] = (_: {..}) => {
      let pcState: string = pc["connectionState"]
      switch pcState {
      | "connected" =>
        engine.state = Connected
        notifyState(engine)
        startAudioLevelMonitoring(engine)
      | "disconnected" | "failed" =>
        engine.state = Failed(pcState)
        notifyState(engine)
      | _ => ()
      }
    }

    Ok()
  } catch {
  | exn =>
    let msg = exn->Exn.message->Option.getOr("WebRTC connection failed")
    engine.state = Failed(msg)
    notifyState(engine)
    Error(msg)
  }
}

/// Handle an SDP offer from the server.
/// Called by the Phoenix channel when it receives "sdp_offer".
let handleSdpOffer = async (engine: t, sdp: string): unit => {
  switch engine.peerConnection {
  | Some(pc) =>
    try {
      let _: unit = await %raw(`(async () => {
        await pc.setRemoteDescription(new RTCSessionDescription({type: 'offer', sdp: sdp}));
        const answer = await pc.createAnswer();
        await pc.setLocalDescription(answer);
        return answer.sdp;
      })()`)

      let answerSdp: string = pc["localDescription"]["sdp"]

      switch engine.sendSdpAnswer {
      | Some(send) => send(answerSdp)
      | None => ()
      }
    } catch {
    | _exn => ()
    }
  | None => ()
  }
}

/// Handle an ICE candidate from the server.
/// Called by the Phoenix channel when it receives "ice_candidate".
let handleIceCandidate = async (engine: t, candidateJson: string): unit => {
  switch engine.peerConnection {
  | Some(pc) =>
    try {
      let _: unit = await %raw(`pc.addIceCandidate(new RTCIceCandidate(JSON.parse(candidateJson)))`)
      ignore(pc)
    } catch {
    | _exn => ()
    }
  | None => ()
  }
}

/// Disconnect from voice.
let disconnect = (engine: t): unit => {
  // Stop audio level monitoring.
  switch engine.levelIntervalId {
  | Some(id) => %raw(`clearInterval(id)`)
  | None => ()
  }

  // Stop local media tracks.
  switch engine.localStream {
  | Some(stream) =>
    let tracks: array<{..}> = stream["getTracks"]()
    tracks->Array.forEach(track => track["stop"]())
  | None => ()
  }

  // Close PeerConnection.
  switch engine.peerConnection {
  | Some(pc) => pc["close"]()
  | None => ()
  }

  // Close AudioContext.
  switch engine.audioContext {
  | Some(ctx) => ctx["close"]()
  | None => ()
  }

  engine.peerConnection = None
  engine.localStream = None
  engine.audioContext = None
  engine.analyserNode = None
  engine.levelIntervalId = None
  engine.state = Disconnected
  engine.isSpeaking = false
  notifyState(engine)
}

// ---------------------------------------------------------------------------
// Voice controls
// ---------------------------------------------------------------------------

let toggleMute = (engine: t): voiceState => {
  engine.voiceState = switch engine.voiceState {
  | Active => Muted
  | Muted => Active
  | Deafened => Active
  }

  // Mute/unmute local audio tracks.
  switch engine.localStream {
  | Some(stream) =>
    let tracks: array<{..}> = stream["getAudioTracks"]()
    let enabled = engine.voiceState == Active
    tracks->Array.forEach(track => { track["enabled"] = enabled })
  | None => ()
  }

  engine.voiceState
}

let toggleDeafen = (engine: t): voiceState => {
  engine.voiceState = switch engine.voiceState {
  | Deafened => Active
  | _ => Deafened
  }
  engine.voiceState
}

let setInputMode = (engine: t, mode: inputMode): unit => {
  engine.config = {...engine.config, inputMode: mode}
}

let setPeerVolume = (engine: t, ~peerId: string, ~volume: float): unit => {
  let clamped = Math.max(0.0, Math.min(2.0, volume))
  engine.peerVolumes->Dict.set(peerId, clamped)
}

let getAudioDevices = async (): array<audioDevice> => {
  try {
    let devices: array<{..}> = await %raw(`navigator.mediaDevices.enumerateDevices()`)
    devices->Array.filterMap(d => {
      let kind: string = d["kind"]
      if kind == "audioinput" || kind == "audiooutput" {
        Some({deviceId: d["deviceId"], label: d["label"], kind})
      } else {
        None
      }
    })
  } catch {
  | _ => []
  }
}

// ---------------------------------------------------------------------------
// Getters
// ---------------------------------------------------------------------------

let getState = (engine: t): connectionState => engine.state
let getVoiceState = (engine: t): voiceState => engine.voiceState
let isSpeaking = (engine: t): bool => engine.isSpeaking
let getAudioLevel = (engine: t): float => engine.audioLevel

// ---------------------------------------------------------------------------
// Private
// ---------------------------------------------------------------------------

let notifyState = (engine: t): unit => {
  switch engine.onStateChange {
  | Some(cb) => cb(engine.state)
  | None => ()
  }
}

let startAudioLevelMonitoring = (engine: t): unit => {
  switch engine.localStream {
  | Some(stream) =>
    let ctx = makeAudioContext()
    let source = ctx["createMediaStreamSource"](stream)
    let analyser = ctx["createAnalyser"]()
    analyser["fftSize"] = 256
    source["connect"](analyser)

    engine.audioContext = Some(ctx)
    engine.analyserNode = Some(analyser)

    // Poll audio level every 50ms.
    let intervalId = %raw(`setInterval(() => {
      const data = new Uint8Array(analyser.frequencyBinCount);
      analyser.getByteFrequencyData(data);
      let sum = 0;
      for (let i = 0; i < data.length; i++) sum += data[i];
      const avg = sum / data.length / 255.0;
      engine.audioLevel = avg;
      const wasSpeaking = engine.isSpeaking;
      engine.isSpeaking = avg > engine.config.vadThreshold;
      if (engine.isSpeaking !== wasSpeaking && engine.onSpeakingChange) {
        engine.onSpeakingChange(engine.isSpeaking);
      }
      if (engine.onAudioLevel) {
        engine.onAudioLevel(avg);
      }
    }, 50)`)

    engine.levelIntervalId = Some(intervalId)
  | None => ()
  }
}
