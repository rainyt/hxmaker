package hx.particle;

class GroupFourAttribute {
	/**
	 * 初始化时使用的参数
	 */
	public var start:FourAttribute;

	/**
	 * 过渡参数
	 */
	public var tween:FourTweenAttribute = new FourTweenAttribute();

	/**
	 * 结束时使用的参数
	 */
	public var end:FourAttribute;

	public function new(start:FourAttribute, end:FourAttribute) {
		this.start = start;
		this.end = end;
	}

	public function get_type():String {
		return "four-group";
	}

	public var type(get, never):String;

	/**
	 * 存在过渡值
	 * @return Bool
	 */
	public function hasTween():Bool {
		return tween.attributes.length > 0;
	}

	/**
	 * 更新过渡值
	 * @param aliveTimeScale 存活时间比例
	 */
	public function update(aliveTimeScale:Float):Void {
		tween.update(aliveTimeScale, start, end);
	}
}
