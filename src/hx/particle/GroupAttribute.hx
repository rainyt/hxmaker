package hx.particle;

/**
 * 属性组
 */
class GroupAttribute {
	/**
	 * 初始化时使用的参数
	 */
	public var start:Attribute;

	/**
	 * 过渡参数
	 */
	public var tween:OneTweenAttribute = new OneTweenAttribute();

	/**
	 * 结束时使用的参数
	 */
	public var end:Attribute;

	public function new(start:Attribute, end:Attribute) {
		this.start = start;
		this.end = end;
	}

	public function get_type():String {
		return "group";
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
	 * 剩余时间比例
	 */
	public var leftTime:Float = 0;

	/**
	 * 更新过渡值
	 * @param aliveTimeScale 存活时间比例
	 */
	public function update(aliveTimeScale:Float):Void {
		tween.update(aliveTimeScale, start, end);
		var tweenScale:Float = this.tween.endOffset - this.tween.startOffset;
		this.leftTime = (aliveTimeScale - this.tween.startOffset) / tweenScale;
	}
}
