import haxe.io.BytesOutput;
import haxe.io.Output;
import haxe.http.HttpMethod;
import haxe.io.Eof;
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

@:structInit
class Response {
	public final code:Int;
	public final message:String;
	public final headers:Map<String, String>;
	public final content:Null<Bytes>;

	public function toBytes() {
		var out = new BytesOutput();
		out.writeString("HTTP/1.1 " + code + " " + message + "\r\n");
		for(k => v in headers) out.writeString(k + ": " + v + "\r\n");
		if(content != null && !headers.exists("Content-Length")) out.writeString('Content-Length: ${content.length}\r\n');
		out.writeString("\r\n");
		if(content != null) {
			out.write(content);
			out.writeString("\r\n");
		}
		out.writeString("\r\n");
		return out.getBytes();
	}
}

class Server {}
