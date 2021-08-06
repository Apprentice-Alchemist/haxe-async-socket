import Server.Response;
import Server.Request;
import eval.luv.Loop;
import eval.luv.Buffer;
import eval.luv.Stream;
import eval.luv.SockAddr;
import haxe.io.Bytes;
import sys.net.Host;
import sys.thread.Thread;

function main() {
	var a = new Socket(null,true);
	final host = new sys.net.Host("127.0.0.1");
	final port = 8080;
	trace(host + ":" + port);
	a.bind(new sys.net.Host("127.0.0.1"), 8080);
	a.listen(100, () -> {
		final s = a.accept();
		s.readStart(b -> {
			trace(b.toString());
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
			// trace(r.toBytes().toString());
			// trace("HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=UTF-8\r\nConnection: close\r\n\r\n" + Date.now()
			// 	.toString() + "\r\n");
			s.write(r.toBytes(), success -> {
				// trace("success : " + success);
				s.close();
			});
		});
	});
	Thread.current().events.repeat(() -> {}, 50);
}
