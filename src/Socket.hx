import sys.thread.Deque;
import sys.thread.EventLoop;
import haxe.io.Bytes;
import sys.net.Host;
import sys.thread.Thread;

private enum abstract SocketFlags(Int) from Int to Int {
	var CLOSED = 0x001;
	var READING = 0x002;
	var LISTENING = 0x004;
	var READABLE = 0x008;
	var WRITABLE = 0x010;
	var CONNECTED = 0x020;

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

class Socket {
	private inline function run(f:Void->Void):Void {
		thread.events.run(f);
	}

	private inline function promise():Void {
		mainThread.events.promise();
	}

	private inline function runMain(f:Void->Void, promised:Bool = false):Void {
		if (promised)
			mainThread.events.runPromised(f)
		else
			mainThread.events.run(f);
	}

	private final socket:sys.net.Socket;
	private var flags:SocketFlags = 0;
	private final thread:sys.thread.Thread;
	private final mainThread:sys.thread.Thread;
	private final acceptQueue = new Deque();
	private var onReadCallback:Null<Bytes->Void>;
	private var listenCallback:Null<() -> Void>;
	private var event:Null<EventHandler>;

	public function new(?socket:sys.net.Socket,secure = false):Void {
		mainThread = Thread.current();
		this.socket = socket == null ? (secure ? new sys.ssl.Socket() : new sys.net.Socket()) : socket;
		thread = sys.thread.Thread.createWithEventLoop(thread_func);
	}

	public function readStart(cb:Bytes->Void):Void {
		onReadCallback = cb;
		flags.add(READING);
	}

	public function readStop():Void {
		flags.remove(READING);
		onReadCallback = null;
	}

	public function write(bytes:haxe.io.Bytes, cb:(success:Bool) -> Void):Void {
		promise();
		run(() -> {
			var r = try sys.net.Socket.select([], [socket], [], 0.05) catch (_) null;
			if (r == null || r.read == null || r.read.length < 0) {
				runMain(() -> cb(false));
			} else {
				var l = try socket.output.writeBytes(bytes, 0, bytes.length) catch (e) -1;
				runMain(() -> cb(l == bytes.length), true);
			}
		});
	}

	public function connect(host:Host, port:Int, cb:(success:Bool) -> Void):Void {
		promise();
		run(() -> try {
			socket.connect(host, port);
			flags.add(CONNECTED);
			runMain(() -> cb(true), true);
		} catch (e) {
			runMain(() -> cb(false), true);
		});
	}

	public function accept() {
		return new Socket(acceptQueue.pop(true));
	}

	public function listen(n:Int, cb:() -> Void):Void {
		socket.listen(n);
		listenCallback = cb;
		flags.add(LISTENING);
	}

	public function bind(host:Host, port:Int):Void {
		socket.bind(host, port);
	}

	public function close():Void {
		socket.close();
		listenCallback = null;
		onReadCallback = null;

		if (event != null) {
			thread.events.cancel(event);
		}
	}

	private function thread_func():Void {
		final buf = haxe.io.Bytes.alloc(1024);
		event = thread.events.repeat(() -> {
			if (flags.has(LISTENING) && listenCallback != null) {
				if (flags.has(READING))
					throw "Cannot listen and read at the same time!";
				final a = socket.accept();
				acceptQueue.push(a);
				runMain(listenCallback);
			} else if (flags.has(READING) && onReadCallback != null) {
				var r = try sys.net.Socket.select([socket], [], []) catch (_) null;
				if (r == null || r.read == null || r.read.length < 1)
					return;
				final bbuf = new haxe.io.BytesBuffer();
				while (true) {
					final l = try socket.input.readBytes(buf, 0, buf.length) catch (_) break;
					if (l > 0) {
						bbuf.addBytes(buf, 0, l);
						if (l < buf.length)
							break;
					} else {
						break;
					}
				}
				if (bbuf.length > 0) {
					flags.remove(READING);
					runMain(() -> {
						onReadCallback(bbuf.getBytes());
						flags.add(READING);
					});
				}
			}
		}, 50);
	}
}
