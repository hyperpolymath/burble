// SPDX-License-Identifier: PMPL-1.0-or-later
//
// Burble REST API — V-lang implementation.
// Provides a formally verified interface to the audio coprocessor.

module main

import veb
import burble

struct App {
	veb.Context
}

struct AudioRequest {
	pcm         []u8
	sample_rate int
	channels    int
}

// encode_handler handles Opus encoding requests.
pub fn (mut app App) encode(req AudioRequest) veb.Result {
	config := burble.AudioConfig{
		sample_rate: match req.sample_rate {
			8000 { burble.SampleRate.rate_8000 }
			16000 { burble.SampleRate.rate_16000 }
			else { burble.SampleRate.rate_48000 }
		}
		channels: req.channels
		buffer_size: req.pcm.len
	}

	if !burble.is_valid_buffer_size(config.buffer_size) {
		return app.error('Invalid buffer size: must be power of 2')
	}

	encoded := burble.encode_opus(req.pcm, config) or {
		return app.error(err.msg())
	}

	return app.json(encoded)
}

fn main() {
	mut app := App{}
	veb.run(app, 4021)
}
