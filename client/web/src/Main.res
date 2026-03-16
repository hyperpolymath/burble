// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Main — Entry point for the Grumble web client.
//
// Initialises the application state, sets up routing, and
// starts the render loop.

// Initialise application
let app = App.make()

// Log startup
Console.log("[Grumble] Web client initialised")
Console.log2("[Grumble] Route:", Routes.toString(app.currentRoute))
Console.log2("[Grumble] Auth:", AuthState.displayName(app.auth))

// Listen for browser back/forward navigation
@val @scope("window")
external addPopStateListener: (@as("popstate") _, 'a => unit) => unit = "addEventListener"

addPopStateListener(_ => {
  let path: string = %raw(`window.location.pathname`)
  App.handleUrlChange(app, path)
})

// Set initial page title
let _ = %raw(`document.title = "${Routes.title(app.currentRoute)}"`)

Console.log("[Grumble] Voice first. Friction last. Complexity optional.")
