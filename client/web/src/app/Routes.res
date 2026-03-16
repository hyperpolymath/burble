// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Routes — Type-safe route definitions for the Grumble web client.
//
// Uses cadre-router for variant-based routing. Every route is a typed
// variant — no string matching, no runtime route errors.
//
// Route groups:
//   - Public: join flow, login, register
//   - Server: server view, room list, settings
//   - Room: active voice room, text channel
//   - Settings: audio, privacy, account
//   - Admin: server admin, moderation, audit log

/// All routes in the Grumble web client.
type route =
  // ── Public ──
  | /// Landing / home page
  Home
  | /// Join via invite link: /join/:token
  JoinInvite(string)
  | /// Login page
  Login
  | /// Register page
  Register
  | /// Guest join (no account): /guest/:serverId
  GuestJoin(string)
  // ── Server ──
  | /// Server view with room list: /server/:id
  Server(string)
  | /// Server settings (admin): /server/:id/settings
  ServerSettings(string)
  | /// Server members list: /server/:id/members
  ServerMembers(string)
  | /// Server audit log (admin): /server/:id/audit
  ServerAudit(string)
  // ── Room ──
  | /// Active voice room: /server/:serverId/room/:roomId
  Room(string, string)
  | /// Text channel view: /server/:serverId/text/:channelId
  TextChannel(string, string)
  // ── Settings ──
  | /// User settings hub
  Settings
  | /// Audio device settings
  AudioSettings
  | /// Privacy settings (privacy mode, E2EE toggle)
  PrivacySettings
  | /// Account settings (email, password, MFA)
  AccountSettings
  // ── Fallback ──
  | /// 404
  NotFound

/// Parse a URL path into a route.
let parse = (path: string): route => {
  let segments = path
    ->String.split("/")
    ->Array.filter(s => s != "")

  switch segments {
  | [] => Home
  | ["join", token] => JoinInvite(token)
  | ["login"] => Login
  | ["register"] => Register
  | ["guest", serverId] => GuestJoin(serverId)
  | ["server", id] => Server(id)
  | ["server", id, "settings"] => ServerSettings(id)
  | ["server", id, "members"] => ServerMembers(id)
  | ["server", id, "audit"] => ServerAudit(id)
  | ["server", serverId, "room", roomId] => Room(serverId, roomId)
  | ["server", serverId, "text", channelId] => TextChannel(serverId, channelId)
  | ["settings"] => Settings
  | ["settings", "audio"] => AudioSettings
  | ["settings", "privacy"] => PrivacySettings
  | ["settings", "account"] => AccountSettings
  | _ => NotFound
  }
}

/// Serialise a route back to a URL path (bidirectional).
let toString = (route: route): string =>
  switch route {
  | Home => "/"
  | JoinInvite(token) => `/join/${token}`
  | Login => "/login"
  | Register => "/register"
  | GuestJoin(serverId) => `/guest/${serverId}`
  | Server(id) => `/server/${id}`
  | ServerSettings(id) => `/server/${id}/settings`
  | ServerMembers(id) => `/server/${id}/members`
  | ServerAudit(id) => `/server/${id}/audit`
  | Room(serverId, roomId) => `/server/${serverId}/room/${roomId}`
  | TextChannel(serverId, channelId) => `/server/${serverId}/text/${channelId}`
  | Settings => "/settings"
  | AudioSettings => "/settings/audio"
  | PrivacySettings => "/settings/privacy"
  | AccountSettings => "/settings/account"
  | NotFound => "/404"
  }

/// Page title for the browser tab.
let title = (route: route): string =>
  switch route {
  | Home => "Grumble"
  | JoinInvite(_) => "Join Server — Grumble"
  | Login => "Login — Grumble"
  | Register => "Register — Grumble"
  | GuestJoin(_) => "Guest Join — Grumble"
  | Server(_) => "Server — Grumble"
  | ServerSettings(_) => "Server Settings — Grumble"
  | ServerMembers(_) => "Members — Grumble"
  | ServerAudit(_) => "Audit Log — Grumble"
  | Room(_, _) => "Voice Room — Grumble"
  | TextChannel(_, _) => "Text Channel — Grumble"
  | Settings => "Settings — Grumble"
  | AudioSettings => "Audio Settings — Grumble"
  | PrivacySettings => "Privacy Settings — Grumble"
  | AccountSettings => "Account Settings — Grumble"
  | NotFound => "Not Found — Grumble"
  }

/// Whether a route requires authentication.
let requiresAuth = (route: route): bool =>
  switch route {
  | Home | JoinInvite(_) | Login | Register | GuestJoin(_) | NotFound => false
  | _ => true
  }

/// Whether a route requires admin permissions.
let requiresAdmin = (route: route): bool =>
  switch route {
  | ServerSettings(_) | ServerAudit(_) => true
  | _ => false
  }
