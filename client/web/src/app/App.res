// SPDX-License-Identifier: PMPL-1.0-or-later
//
// App — Burble web client application root.
//
// Manages top-level state and route handling.
// Framework-agnostic core — the rendering layer is separate.
//
// State hierarchy:
//   App
//   ├── AuthState (login/guest/anonymous)
//   ├── Routes (current page via cadre-router)
//   ├── VoiceEngine (WebRTC connection to SFU)
//   ├── VoiceControls (mute/deafen/PTT UI state)
//   └── RoomState (current room participants, messages)

/// Top-level application state.
type t = {
  auth: AuthState.t,
  voiceEngine: VoiceEngine.t,
  voiceControls: VoiceControls.t,
  mutable currentRoute: Routes.route,
  mutable currentRoom: option<RoomState.t>,
  mutable serverList: array<serverInfo>,
}

/// Server info for the server list sidebar.
and serverInfo = {
  id: string,
  name: string,
  iconUrl: option<string>,
  roomCount: int,
  memberCount: int,
}

/// Create the application state.
let make = (): t => {
  let initialRoute = Routes.parse(
    %raw(`window.location.pathname`)
  )

  {
    auth: AuthState.make(),
    voiceEngine: VoiceEngine.make(),
    voiceControls: VoiceControls.make(),
    currentRoute: initialRoute,
    currentRoom: None,
    serverList: [],
  }
}

/// Navigate to a route. Handles auth guards via cadre-router integration.
let navigate = (app: t, route: Routes.route): unit => {
  // Auth guard: redirect to login if route requires auth and user isn't logged in
  if Routes.requiresAuth(route) && !AuthState.isLoggedIn(app.auth) {
    app.currentRoute = Routes.Login
    let _ = %raw(`window.history.pushState(null, "", "/login")`)
  } else if Routes.requiresAdmin(route) && !AuthState.isAdmin(app.auth) {
    // Admin guard: redirect to server view if not admin
    app.currentRoute = Routes.NotFound
  } else {
    app.currentRoute = route
    let path = Routes.toString(route)
    let pageTitle = Routes.title(route)
    let _ = %raw(`window.history.pushState(null, "", path)`)
    let _ = %raw(`document.title = pageTitle`)
  }
}

/// Join a voice room. Connects voice engine and creates room state.
let joinVoiceRoom = (app: t, ~serverId: string, ~roomId: string, ~roomName: string): unit => {
  // Create room state
  let room = RoomState.make(~roomId, ~roomName, ~serverId)
  app.currentRoom = Some(room)

  // Connect voice engine
  let token = AuthState.token(app.auth)->Option.getOr("")
  VoiceEngine.connect(app.voiceEngine, ~roomId, ~token)

  // Update voice controls
  app.voiceControls.roomName = roomName

  // Navigate to room view
  navigate(app, Room(serverId, roomId))
}

/// Leave the current voice room.
let leaveVoiceRoom = (app: t): unit => {
  VoiceEngine.disconnect(app.voiceEngine)
  app.currentRoom = None
  app.voiceControls.roomName = ""
  app.voiceControls.participantCount = 0
}

/// Handle URL change (browser back/forward).
let handleUrlChange = (app: t, path: string): unit => {
  let route = Routes.parse(path)
  navigate(app, route)
}

/// Guest join flow — create guest session and join server.
let guestJoin = (app: t, ~displayName: string, ~serverId: string): unit => {
  AuthState.setGuest(app.auth, {guestId: "guest_" ++ serverId, displayName})
  navigate(app, Server(serverId))
}

/// Toggle mute and sync to server.
let toggleMute = (app: t): unit => {
  let newState = VoiceEngine.toggleMute(app.voiceEngine)
  ignore(newState)
  VoiceControls.syncFromEngine(app.voiceControls, app.voiceEngine)
}

/// Toggle deafen and sync to server.
let toggleDeafen = (app: t): unit => {
  let newState = VoiceEngine.toggleDeafen(app.voiceEngine)
  ignore(newState)
  VoiceControls.syncFromEngine(app.voiceControls, app.voiceEngine)
}
