package test;

import http.Response;
import http.Request;
import sys.thread.Thread;

function dispatchRequest(host, port) {
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
			s.readStop();
			s.close();
			// var t = Sys.time() - t;
			// max = Math.max(max, t);
			// min = min == 0 ? t : Math.min(t, min);
			// totalTime += t;
			// connections += 1;
			// var average = totalTime / connections;
			// Sys.print('\033[2K\raverage: $average, min: $min, max: $max');
			// Sys.stdout().flush();
			// Response.fromBytes(bytes);
		});
	});
}

function main() {
	final host = Server.host;
	final port = Server.port;

	var totalTime = 0.0;
	var max = 0.0;
	var min = 0.0;
	var connections = 0;
	for (i in 0...8) {
		Thread.createWithEventLoop(() -> {}).events.repeat(() -> {
			dispatchRequest(host, port);
		}, 0);
	}
	Thread.current().events.repeat(() -> {}, 50);
}
