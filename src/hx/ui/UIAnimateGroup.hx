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
	public function addAnimate(animate:UIAnimate):Void {
		animates.push(animate);
	}

	override public function stop():Void {
		super.stop();
		for (animate in animates) {
			animate.stop();
		}
	}

	override public function play(setStartOption:Bool = false, isReverse:Bool = false):Void {
		this.stop();
		for (animate in animates) {
			animate.play(setStartOption, isReverse);
		}
	}

	override public function updateOption():Void {
		for (animate in animates) {
			animate.updateOption();
		}
	}

	/** 组内所有片段共用时间原点；组自身的时间参数沿用原有的不参与调度语义。 */
	override private function get_totalDuration():Float {
		var total:Float = 0;
		for (animate in animates)
			total = Math.max(total, animate.totalDuration);
		return total;
	}

	override private function collectSeekTracks(tracks:Array<UIAnimate>):Void {
		for (animate in animates)
			animate.collectSeekTracks(tracks);
	}
}
