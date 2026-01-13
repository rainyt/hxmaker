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
	 * 获取过渡值
	 * @param aliveTimeScale 
	 */
	public function getStartAndEndTweenColor(aliveTimeScale:Float):{
		id:Int,
		startoffest:Float,
		endoffest:Float,
		start:FourAttribute,
		end:FourAttribute
	} {
		for (index => value in tween.attributes) {
			if (value.aliveTimeScale >= aliveTimeScale) {
				if (index == 0)
					return {
						id: index,
						startoffest: 0,
						endoffest: value.asFourAttribute().aliveTimeScale,
						start: start,
						end: value.asFourAttribute().attribute
					};
				else
					return {
						id: index,
						startoffest: tween.attributes[index - 1].asFourAttribute().aliveTimeScale,
						endoffest: value.asFourAttribute().aliveTimeScale,
						start: tween.attributes[index - 1].asFourAttribute().attribute,
						end: value.asFourAttribute().attribute
					};
			}
		}
		return {
			id: -1,
			startoffest: 0,
			endoffest: 1,
			start: start,
			end: end
		};
	}
}
