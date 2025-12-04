package hx.ui;

/**
 * 动画组
 */
class UIAnimateGroup extends UIAnimate {
	/**
	 * 动画列表
	 */
	public var animates:Array<UIAnimate> = [];

	/**
	 * 添加动画
	 */
	public function addAnimate(animate:UIAnimate) {
		animates.push(animate);
	}

	override function play(setStartOption:Bool = false, isReverse:Bool = false) {
		for (animate in animates) {
			animate.play(setStartOption, isReverse);
		}
	}

	override function updateOption() {
		for (animate in animates) {
			animate.updateOption();
		}
	}
}
