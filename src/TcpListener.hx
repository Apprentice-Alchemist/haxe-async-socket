import sys.thread.Mutex;
import sys.thread.EventLoop;
import haxe.io.Eof;
import sys.net.Socket;
import sys.net.Host;
import sys.thread.Thread;

@:access(TcpListener)
@:access(TcpStream)
private class Worker {
	public final streams = [];
	public final mutex = new Mutex();
	public final thread:Thread;

	public function new() {
		thread = Thread.create(() -> {
			while (true) {
				mutex.acquire();
				thread_func(streams);
				mutex.release();
				Sys.sleep(0.001);
			}
		});
	}

	private static function thread_func(streams:Array<TcpStream>) {
		try {
			if (streams.length == 0) {
				return;
			}
			var readSockets = [];
			var writeSockets = [];
			var otherSockets = [];
			for (i in 0...streams.length) {
				var stream = streams[i];
				if (stream == null)
					continue;
				if (stream.onReadCallback != null)
					readSockets.push(stream.socket);
				if (stream.writes.length > 0)
					writeSockets.push(stream.socket);
			}

			final buf = haxe.io.Bytes.alloc(1024);
			final result = sys.net.Socket.select(readSockets, writeSockets, otherSockets, 0.0001);
			for (socket in result.read) {
				final s:TcpStream = socket.custom;
				final bbuf = new haxe.io.BytesBuffer();
				try {
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

					var bytes = bbuf.getBytes();
					TcpListener.runMain(() -> if (s.onReadCallback != null) s.onReadCallback(bytes));
				} catch (e:Eof) {
					if (bbuf.length > 0) {
						trace(bbuf.getBytes().toString());
					}
					break;
				}
			}
			for (socket in result.write) {
				final s:TcpStream = socket.custom;
				for (write in s.writes) {
					try {
						final l = socket.output.writeBytes(write.bytes, 0, write.bytes.length);
						var success = true;
						var cb = write.cb;

						TcpListener.runMain(() -> cb(success));
					} catch (e:Eof) {}
				}
			}
		} catch (e) {
			trace(e.details());
		}
	}
}

@:allow(TcpStream)
@:access(TcpStream)
class TcpListener {
	private static var mainThread:sys.thread.Thread = Thread.current();
	private static var i = 0;
	private static var workers = [for (i in 0...4) new Worker()];

	@:allow(TcpStream)
	static function addStream(s:TcpStream) {
		var index = i++ % workers.length;
		var worker = workers[index];
		worker.mutex.acquire();
		worker.streams.push(s);
		worker.mutex.release();
		return index;
	}

	@:allow(TcpStream)
	static function removeStream(s:TcpStream) {
		var worker = workers[s.streamIndex];
		worker.mutex.acquire();
		worker.streams.remove(s);
		worker.mutex.release();
	}

	private static function runMain(f:Void->Void):Void {
		mainThread.events.run(f);
	}

	var socket:sys.net.Socket;
	final callback:TcpStream->Void;
	final sthread:Thread;
	final smutex:Mutex;
	var handler:EventHandler;
	final keepAlive:EventHandler;

	function new(socket:sys.net.Socket, cb:TcpStream->Void):Void {
		mainThread = Thread.current();
		this.socket = socket;
		this.socket.custom = this;
		this.callback = cb;
		this.smutex = new Mutex();
		this.sthread = Thread.createWithEventLoop(() -> {
			this.handler = sthread.events.repeat(() -> {
				smutex.acquire();
				var a = socket.accept();
				mainThread.events.run(() -> {
					cb(new TcpStream(a));
				});
				smutex.release();
			}, 0);
		});
		this.keepAlive = mainThread.events.repeat(() -> {}, 1000);
	}

	public static function listen(host:Host, port:Int, cb:TcpStream->Void):TcpListener {
		var sock = new Socket();
		sock.bind(host, port);
		sock.listen(128);
		return new TcpListener(sock, cb);
	}

	public function close():Void {
		this.smutex.acquire();
		this.sthread.events.cancel(this.handler);
		this.socket.close();
		mainThread.events.cancel(this.keepAlive);
		this.smutex.release();
	}
}
