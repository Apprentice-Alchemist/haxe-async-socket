package test;

import haxe.io.Bytes;
import http.Response;
import http.Request;

final host = new sys.net.Host("127.0.0.1");
final port = 6600;

function main() {
	trace(host + ":" + port);
	TcpListener.listen(host, port, (s) -> try {
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
				// if(!success) {
					trace("write");
				// }
				s.readStop();
				s.close();
			});
		});
	} catch (e) trace(e.details()));
}
