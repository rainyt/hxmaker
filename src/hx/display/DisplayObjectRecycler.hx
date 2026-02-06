package hx.display;

import hx.utils.ObjectPool;

/**
 * 显示对象回收器，用于管理显示对象的创建和回收，提高性能
 * @param T 显示对象类型
 */
@:keep
class DisplayObjectRecycler<T> {
	/**
	 * 创建一个带有指定类的显示对象回收器
	 * @param c 显示对象类
	 * @return DisplayObjectRecycler<T> 显示对象回收器实例
	 */
	public static function withClass<T>(c:Class<T>):DisplayObjectRecycler<T> {
		var recycler = new DisplayObjectRecycler(c);
		return recycler;
	}

	/**
	 * 创建一个带有指定类和参数的显示对象回收器
	 * @param c 显示对象类
	 * @param args 构造函数参数
	 * @return DisplayObjectRecycler<T> 显示对象回收器实例
	 */
	public static function withClassWithArgs<T>(c:Class<T>, ...args):DisplayObjectRecycler<T> {
		var recycler = new DisplayObjectRecycler(c);
		recycler.args = args.toArray();
		return recycler;
	}

	/**
	 * 构造函数参数数组
	 */
	public var args:Array<Dynamic> = [];

	/**
	 * 对象池实例
	 */
	public var pool:ObjectPool<T>;

	private var __class:Class<T>;

	/**
	 * 创建一个新的显示对象回收器
	 * @param c 显示对象类
	 */
	public function new(c:Class<T>) {
		this.__class = c;
		this.pool = new ObjectPool(() -> {
			return Type.createInstance(this.__class, args);
		}, (obj) -> {});
	}

	/**
	 * 创建一个新的显示对象实例
	 * @return T 显示对象实例
	 */
	public function create():T {
		return pool.get();
	}

	/**
	 * 释放一个显示对象实例到回收池
	 * @param obj 显示对象实例
	 */
	public function release(obj:T):Void {
		pool.release(obj);
	}
}
