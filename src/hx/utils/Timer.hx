package hx.utils;

/**
 * 定时器
 */
class Timer {
	private static var __instances:Map<String, Timer> = [];

	public static function run(dt:Float):Void {
		for (timer in __instances) {
			timer.update(dt);
		}
	}

	/**
	 * 获得指定ID的定时器
	 * @param id 
	 * @return Timer
	 */
	public static function getInstance(id:String = "default"):Timer {
		if (__instances.exists(id)) {
			return __instances.get(id);
		}
		var t = new Timer();
		__instances.set(id, t);
		return t;
	}

	public var uid:Int = 0;

	public var timerChildren:Array<TimerChild> = [];

	public function new():Void {}

	/**
	 * 下一帧调用运行
	 * @param cb 
	 */
	public function nextFrame(cb:Dynamic, ...args:Dynamic):Int {
		return setTimeout(cb, 0, args.toArray());
	}

	/**
	 * 设置定时器调用
	 * @param cb 
	 * @param duration 
	 */
	public function setTimeout(cb:Dynamic, duration:Float, ?args:Array<Dynamic>):Int {
		uid++;
		var t = new TimerChild(uid, duration, cb, args);
		timerChildren.push(t);
		return t.id;
	}

	/**
	 * 更新所有定时器
	 * @param dt 
	 */
	public function update(dt:Float):Void {
		var i = timerChildren.length;
		while (i-- > 0) {
			var t = timerChildren[i];
			t.update(dt);
			ContextStats.statsTimeTaskCount();
			if (t.duration <= 0) {
				timerChildren.splice(i, 1);
			}
		}
	}
}

class TimerChild {
	public var id:Int = 0;

	public var duration:Float = 0;

	public var closure:Dynamic;

	public var args:Array<Dynamic>;

	/**
	 * 定时器子对象
	 * @param id 
	 * @param time 
	 * @param closure 
	 * @param ...args 
	 */
	public function new(id:Int, duration:Float, closure:Dynamic, args:Array<Dynamic>) {
		this.id = id;
		this.duration = duration;
		this.closure = closure;
		this.args = args;
	}

	/**
	 * 更新定时器
	 * @param dt 
	 */
	public function update(dt:Float):Void {
		duration -= dt;
		if (duration <= 0) {
			Reflect.callMethod(this.closure, this.closure, this.args == null ? [] : this.args);
		}
	}
}
