package test;

import http.Response;
import http.Request;
import sys.thread.Thread;

function main() {
	final host = Server.host;
	final port = Server.port;

	var totalTime = 0.0;
	var max = 0.0;
	var min = 0.0;
	var connections = 0;

	Thread.current().events.repeat(() -> {
		var t = Sys.time();
		var s = TcpStream.connect(host, port);
		s.write(({
			method: "GET",
			path: "/",
			httpVersion: "1.1",
			headers: ["Host" => '$host:$port', "User-Agent" => "Haxe", "Accept" => "text/plain"],
			content: null
		} : Request).toBytes(), succes -> {
			s.readStart((bytes) -> {
				Response.fromBytes(bytes);
			});
			// s.close();
			// var t = Sys.time() - t;
			// max = Math.max(max, t);
			// min = min == 0 ? t : Math.min(t, min);
			// totalTime += t;
			// connections += 1;
			// var average = totalTime / connections;
			// Sys.print('\033[2K\raverage: $average, min: $min, max: $max');
			// Sys.stdout().flush();
		});
	}, 50);
}
