package;

import sys.thread.Mutex;
import haxe.io.Bytes;
import sys.net.Socket;
import sys.net.Host;

class TcpStream {
	public static function connect(host:Host, port:Int):TcpStream {
		var sock = new sys.net.Socket();
		sock.setBlocking(false);
		sock.connect(host, port);
		return new TcpStream(sock);
	}

	final socket:Socket;
	final writes:Array<{bytes:Bytes, cb:Bool->Void}> = [];
	final streamIndex:Int;
	private var onReadCallback:Null<Bytes->Void>;
	final mutex:Mutex;

	function new(sock:sys.net.Socket) {
		this.socket = sock;
		this.socket.custom = this;
		streamIndex = TcpListener.addStream(this);
		mutex = TcpListener.workers[streamIndex].mutex;
	}

	public function readStart(cb:Bytes->Void):Void {
		mutex.acquire();
		onReadCallback = cb;
		mutex.release();
	}

	public function readStop():Void {
		mutex.acquire();
		onReadCallback = null;
		mutex.release();
	}

	public function write(bytes:haxe.io.Bytes, cb:(success:Bool) -> Void):Void {
		mutex.acquire();
		writes.push({bytes: bytes, cb: cb});
		mutex.release();
	}

	public function close() {
		TcpListener.removeStream(this);
		socket.close();
	}
}
