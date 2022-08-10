package;

import haxe.io.Bytes;
import sys.thread.EventLoop;
import sys.net.Socket;
import sys.net.Host;

private enum abstract SocketFlags(Int) from Int to Int {
	var CLOSED = 0x001;
	var READING = 0x002;
	var LISTENING = 0x004;
	var WRITING = 0x008;

	@:op(A | B) private static function or(a:SocketFlags, b:SocketFlags):SocketFlags;

	@:op(A & B) private static function and(a:SocketFlags, b:SocketFlags):SocketFlags;

	@:op(~x) private static function not(x:SocketFlags):SocketFlags;

	public inline function add(f:SocketFlags) {
		// this = this OR x
		this |= f;
	}

	@:pure public inline function has(x:SocketFlags):Bool {
		// this AND x EQUALS X
		return this & x == x;
	}

	public inline function remove(x:SocketFlags):Void {
		// this = this AND NOT x
		this = this & ~x;
	}
}

class TcpStream {
	public static function connect(host:Host, port:Int):TcpStream {
		var sock = new sys.net.Socket();
		sock.connect(host, port);
		return new TcpStream(sock);
	}

	final socket:Socket;
	private var flags:SocketFlags = 0;
	final writes:Array<{bytes:Bytes, cb:Bool->Void}> = [];
	private var onReadCallback:Null<Bytes->Void>;

	function new(sock:sys.net.Socket) {
		this.socket = sock;
		this.socket.custom = this;
		TcpListener.mutex.acquire();
		TcpListener.streams.push(this);
		TcpListener.mutex.release();
	}

	public function readStart(cb:Bytes->Void):Void {
		TcpListener.mutex.acquire();
		onReadCallback = cb;
		flags.add(READING);
		TcpListener.mutex.release();
	}

	public function readStop():Void {
		TcpListener.mutex.acquire();
		flags.remove(READING);
		onReadCallback = null;
		TcpListener.mutex.release();
	}

	public function write(bytes:haxe.io.Bytes, cb:(success:Bool) -> Void):Void {
		TcpListener.mutex.acquire();
		writes.push({bytes: bytes, cb: cb});
		TcpListener.mutex.release();
	}

	public function close() {
		TcpListener.mutex.acquire();
		flags = CLOSED;
		TcpListener.mutex.release();
	}
}
