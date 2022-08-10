import sys.thread.EventLoop;
import haxe.io.Eof;
import sys.net.Socket;
import sys.net.Host;
import sys.thread.Thread;

@:allow(TcpStream)
@:access(TcpStream)
class TcpListener {
	private static var thread:sys.thread.Thread;
	private static var mutex = new sys.thread.Mutex();
	private static var mainThread:sys.thread.Thread;
	private static var streams:Array<TcpStream> = [];

	private static function __init__() {
		mainThread = Thread.current();
		thread = Thread.createWithEventLoop(() -> Thread.current().events.repeat(thread_func, 50));
	}

	private static function thread_func() {
		if (mutex.tryAcquire()) {
			var readSockets = [];
			var writeSockets = [];
			var otherSockets = [];
			for (i in 0...streams.length) {
				var stream = streams[i];
				if (stream == null)
					continue;
				if (stream.flags.has(CLOSED)) {
					stream.socket.close();
					streams[i] = null;
				} else {
					if (stream.flags.has(READING))
						readSockets.push(stream.socket);
					if (stream.writes.length > 0)
						writeSockets.push(stream.socket);
				}
			}

			final buf = haxe.io.Bytes.alloc(1024);
			final result = sys.net.Socket.select(readSockets, writeSockets, otherSockets, 0.1);
			for (socket in result.read) {
				final s:TcpStream = socket.custom;
				try {
					final bbuf = new haxe.io.BytesBuffer();
					while (true) {
						final l = socket.input.readBytes(buf, 0, buf.length);
						if (l > 0) {
							bbuf.addBytes(buf, 0, l);
							if (l < buf.length)
								break;
						} else {
							break;
						}
					}
					if (s.onReadCallback != null && s.flags.has(READING)) {
						runMain(() -> s.onReadCallback(bbuf.getBytes()));
					}
				} catch (e:Eof) {
					break;
				}
			}
			for (socket in result.write) {
				final s:TcpStream = socket.custom;
				for (write in s.writes) {
					try {
						final l = socket.output.writeBytes(write.bytes, 0, write.bytes.length);
						write.cb(l == write.bytes.length);
					} catch (e:Eof) {}
				}
			}
			mutex.release();
		}
	}

	private static function runMain(f:Void->Void):Void {
		mainThread.events.run(f);
	}

	var socket:sys.net.Socket;
	final callback:TcpStream->Void;
	final sthread:Thread;
	var handler:EventHandler;

	function new(socket:sys.net.Socket, cb:TcpStream->Void):Void {
		mainThread = Thread.current();
		this.socket = socket;
		this.socket.custom = this;
		this.callback = cb;
		this.sthread = Thread.createWithEventLoop(() -> {
			this.handler = sthread.events.repeat(() -> {
				if (Thread.readMessage(false) != null) {
					socket.close();
					this.sthread.events.cancel(handler);
				}
				var a = socket.accept();
				var stream = new TcpStream(a);
				mainThread.events.run(() -> {
					cb(stream);
				});
			}, 10);
		});
	}

	public static function listen(host:Host, port:Int, cb:TcpStream->Void):TcpListener {
		var sock = new Socket();
		sock.bind(host, port);
		sock.listen(128);
		return new TcpListener(sock, cb);
	}

	public function close():Void {
		this.sthread.sendMessage(true);
	}
}
