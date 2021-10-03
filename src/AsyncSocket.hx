import sys.thread.Deque;
import sys.thread.EventLoop;
import haxe.io.Bytes;
import sys.net.Host;
import sys.thread.Thread;

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

class AsyncSocket {
	private static var thread:sys.thread.Thread;
	private static var mutex = new sys.thread.Mutex();
	private static var mainThread:sys.thread.Thread;
	private static var activeSockets:Array<AsyncSocket> = [];

	private static function __init__() {
		mainThread = Thread.current();
		thread = Thread.createWithEventLoop(() -> Thread.current().events.repeat(thread_func, 50));
	}

	private static function thread_func() {
		var readSockets = [];
		var writeSockets = [];
		var otherSockets = [];
		for (socket in activeSockets) {
			if (socket.flags.has(READING))
				readSockets.push(socket.socket);
			else if (socket.writes.length > 0)
				writeSockets.push(socket.socket)
			else if (socket.flags.has(LISTENING))
				otherSockets.push(socket.socket);
		}
		final buf = haxe.io.Bytes.alloc(1024);
		final result = sys.net.Socket.select(readSockets, writeSockets, otherSockets);
		for (socket in result.read) {
			final s:AsyncSocket = socket.custom;
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
		}
		for (socket in result.write) {
			final s:AsyncSocket = socket.custom;
			for (write in s.writes) {
				final l = socket.output.writeBytes(write.bytes, 0, write.bytes.length);
				write.cb(l == write.bytes.length);
			}
		}
		for (socket in result.others) {
			final s:AsyncSocket = socket.custom;
			try {
				final a = socket.accept();
				if (a != null && s.listenCallback != null) {
					s.listenCallback(new AsyncSocket(a));
				}
			} catch (_) {}
		}
	}

	private inline function run(f:Void->Void):Void {
		thread.events.run(f);
	}

	private inline function promise():Void {
		mainThread.events.promise();
	}

	private static function runMain(f:Void->Void, promised:Bool = false):Void {
		if (promised)
			mainThread.events.runPromised(f)
		else
			mainThread.events.run(f);
	}

	private final socket:sys.net.Socket;
	private var flags:SocketFlags = 0;
	final writes:Array<{bytes:Bytes, cb:Bool->Void}> = [];
	// private final thread:sys.thread.Thread;
	private final acceptQueue = new Deque();
	private var onReadCallback:Null<Bytes->Void>;
	private var listenCallback:Null<(s:AsyncSocket) -> Void>;
	private var event:Null<EventHandler>;

	public function new(?socket:sys.net.Socket, secure = false):Void {
		mainThread = Thread.current();
		this.socket = socket == null ? (secure ? new sys.ssl.Socket() : new sys.net.Socket()) : socket;
		this.socket.setBlocking(false);
		this.socket.custom = this;
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
		mutex.acquire();
		writes.push({bytes: bytes, cb: cb});
		mutex.release();
		// promise();
		// run(() -> {
		// 	var r = try sys.net.Socket.select([], [socket], [], 0.05) catch (_) null;
		// 	if (r == null || r.read == null || r.read.length < 0) {
		// 		runMain(() -> cb(false));
		// 	} else {
		// 		#if log
		// 		trace("writeBytes");
		// 		#end
		// 		var l = try socket.output.writeBytes(bytes, 0, bytes.length) catch (e) -1;
		// 		runMain(() -> cb(l == bytes.length), true);
		// 	}
		// });
	}

	public function connect(host:Host, port:Int, cb:(success:Bool) -> Void):Void {
		promise();
		run(() -> try {
			#if log
			trace("connect");
			#end
			socket.connect(host, port);
			runMain(() -> cb(true), true);
		} catch (e) {
			runMain(() -> cb(false), true);
		});
	}

	public function accept() {
		return new AsyncSocket(acceptQueue.pop(true));
	}

	public function listen(n:Int, cb:(s:AsyncSocket) -> Void):Void {
		#if log
		trace("listen");
		#end
		socket.listen(n);
		listenCallback = cb;
		flags.add(LISTENING);
	}

	public function bind(host:Host, port:Int):Void {
		socket.bind(host, port);
	}

	public function close():Void {
		#if log
		trace("close");
		#end
		socket.close();
		listenCallback = null;
		onReadCallback = null;
		socket.custom = null;
	}

	// private static function thread_func():Void {
	// 	// 	final buf = haxe.io.Bytes.alloc(1024);
	// 	// 	event = thread.events.repeat(() -> {
	// 	// 		if (flags.has(LISTENING) && listenCallback != null) {
	// 	// 			if (flags.has(READING))
	// 	// 				throw "Cannot listen and read at the same time!";
	// 	// 			final a = try socket.accept() catch (_) null;
	// 	// 			if (a != null) {
	// 	// 				#if log
	// 	// 				trace("socket accepted");
	// 	// 				#end
	// 	// 				acceptQueue.push(a);
	// 	// 				runMain(listenCallback);
	// 	// 			}
	// 	// 		} else if (flags.has(READING) && onReadCallback != null) {
	// 	// 			var r = sys.net.Socket.select([socket], [], []);
	// 	// 			if (r == null || r.read == null || r.read.length < 1)
	// 	// 				return;
	// 	// 			final bbuf = new haxe.io.BytesBuffer();
	// 	// 			while (true) {
	// 	// 				final l = socket.input.readBytes(buf, 0, buf.length);
	// 	// 				if (l > 0) {
	// 	// 					bbuf.addBytes(buf, 0, l);
	// 	// 					if (l < buf.length)
	// 	// 						break;
	// 	// 				} else {
	// 	// 					break;
	// 	// 				}
	// 	// 			}
	// 	// 			if (bbuf.length > 0) {
	// 	// 				trace("some data read");
	// 	// 				flags.remove(READING);
	// 	// 				runMain(() -> {
	// 	// 					onReadCallback(bbuf.getBytes());
	// 	// 					flags.add(READING);
	// 	// 				});
	// 	// 			}
	// 	// 		}
	// 	// 	}, 50);
	// }
}
