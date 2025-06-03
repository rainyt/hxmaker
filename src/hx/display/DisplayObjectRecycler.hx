package hx.display;

import hx.utils.ObjectPool;

@:keep
class DisplayObjectRecycler<T> {
	public static function withClass<T>(c:Class<T>):DisplayObjectRecycler<T> {
		var recycler = new DisplayObjectRecycler(c);
		return recycler;
	}

	public var pool:ObjectPool<T>;

	private var __class:Class<T>;

	public function new(c:Class<T>) {
		this.__class = c;
		this.pool = new ObjectPool(() -> {
			return Type.createInstance(this.__class, []);
		}, (obj) -> {});
	}

	public function create():T {
		return pool.get();
	}

	public function release(obj:T):Void {
		pool.release(obj);
	}
}
