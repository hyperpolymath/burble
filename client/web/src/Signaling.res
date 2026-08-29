// SPDX-License-Identifier: MPL-2.0
//
// Signaling.res — Relay and WebSocket signaling.

open WebRTC

type response
type requestInit = {
  method: string,
  body: string,
}

@val external fetch: string => promise<response> = "fetch"
@val external fetchWithInit: (string, requestInit) => promise<response> = "fetch"
@send external json: response => promise<'value> = "json"

module Relay = {
  let putOffer = (relay_url, room_id, sdp) => {
    let url = relay_url ++ "/room/" ++ room_id ++ "/offer"
    fetchWithInit(url, {
      method: "PUT",
      body: JSON.stringifyAny(sdp)->Option.getWithDefault(""),
    })
  }

  let getOffer = (relay_url, room_id) => {
    let url = relay_url ++ "/room/" ++ room_id ++ "/offer"
    fetch(url)->Promise.then(json)
  }

  let putAnswer = (relay_url, room_id, sdp) => {
    let url = relay_url ++ "/room/" ++ room_id ++ "/answer"
    fetchWithInit(url, {
      method: "PUT",
      body: JSON.stringifyAny(sdp)->Option.getWithDefault(""),
    })
  }

  let getAnswer = (relay_url, room_id) => {
    let url = relay_url ++ "/room/" ++ room_id ++ "/answer"
    fetch(url)->Promise.then(json)
  }
}

module Phoenix = {
  type socket
  type channel

  @new @module("phoenix")
  external createSocket: (string, 'opts) => socket = "Socket"
  @send external connectSocket: socket => unit = "connect"
  @send external channel: (socket, string, 'params) => channel = "channel"
  @send external joinChannel: channel => 'push = "join"
  @send external onChannel: (channel, string, 'msg => unit) => unit = "on"
  @send external pushChannel: (channel, string, 'payload) => 'push = "push"
}
