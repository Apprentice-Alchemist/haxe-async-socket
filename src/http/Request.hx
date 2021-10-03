package http;

import haxe.io.Eof;
import haxe.http.HttpMethod;
import haxe.io.BytesInput;
import haxe.io.Bytes;

@:structInit
class Request {
	public final method:HttpMethod;
	public final path:String;
	public final httpVersion:String;
	public final headers:Map<String, String>;

	public final content:Null<Bytes>;

	public static function fromBytes(b:Bytes):Request {
		var i = new BytesInput(b);
		var f = i.readLine().split(" ");
		var method = f[0];
		var path = f[1];
		var httpVersion = f[2];
		var headers = new Map<String, String>();
		var content = null;
		var l:String;
		while (true) {
			try {
				l = i.readLine();
				if (l == "")
					break;
				var t = l.indexOf(":");
				headers.set(l.substring(0, t), l.substring(t + 1, l.length));
			} catch (e:Eof)
				break;
		}
		if (headers.exists("Content-Length")) {
			final length = Std.parseInt(headers.get("Content-Length"));
			content = i.read(length);
		}

		return {
			path: path,
			method: method,
			httpVersion: httpVersion,
			headers: headers,
			content: content
		};
	}
}
