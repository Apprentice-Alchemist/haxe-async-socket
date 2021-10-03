import http.Response;
import http.Request;

import haxe.io.Bytes;
import sys.net.Host;
import sys.thread.Thread;

function main() {
	var a = new AsyncSocket(null, false);
	final host = new sys.net.Host("127.0.0.1");
	final port = 5500;
	trace(host + ":" + port);
	a.bind(host, port);
	a.listen(100, (s) -> {
		trace(s);
		s.readStart(b -> {
			var r = Request.fromBytes(b);
			final r:Response = if (r.path == "/") {
				code: 200,
				message: "OK",
				headers: ["Content-Type" => "text/plain; charset=UTF-8", "Connection" => "close"],
				content: Bytes.ofString(Date.now().toString())
			} else {
				message: "Not Found",
				headers: [],
				content: null,
				code: 404
			};

			s.write(r.toBytes(), success -> {
				s.close();
			});
		});
	});
	Thread.current().events.repeat(() -> {}, 50);
	// Sys.command('start $host:$port');
}
