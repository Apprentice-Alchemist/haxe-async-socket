package http;

import haxe.io.Bytes;
import haxe.io.BytesOutput;

@:structInit
class Response {
	public final code:Int;
	public final message:String;
	public final headers:Map<String, String>;
	public final content:Null<Bytes>;

	public function toBytes() {
		var out = new BytesOutput();
		out.writeString("HTTP/1.1 " + code + " " + message + "\r\n");
		for (k => v in headers)
			out.writeString(k + ": " + v + "\r\n");
		if (content != null && !headers.exists("Content-Length"))
			out.writeString('Content-Length: ${content.length}\r\n');
		out.writeString("\r\n");
		if (content != null) {
			out.write(content);
		} else {
			out.writeString("\r\n");
		}
		return out.getBytes();
	}
}
