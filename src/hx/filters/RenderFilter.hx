package hx.filters;

import hx.display.DisplayObject;

/**
 * 渲染滤镜基类，可以在渲染时为渲染对象进行滤镜自定义渲染处理
 */
@:access(hx.display.DisplayObject)
class RenderFilter {
	/**
	 * 自定义的渲染对象，请注意它可以是任何DisplayObject类型的对象，滤镜处理结束后，应该将它设置到渲染对象上
	 */
	public var render:DisplayObject;

	public function new() {
		this.init();
	}

	private var __dirty:Bool = true;

	/**
	 * 是否是舞台渲染滤镜，默认值为false
	 */
	public var isStageRenderFilter = false;

	/** dispose 后必须显式 init 才能重新挂载，避免半销毁状态。 */
	public var isDisposed(default, null):Bool = false;
	public function init():Void { isDisposed = false; __dirty = true; }

	public var nowTime:Float = 0;

	public function update(display:DisplayObject, dt:Float):Void {
		if (isDisposed) throw "已经销毁的滤镜需要先 init 才能重新挂载";
		nowTime += dt;
	}

	public function updateTransform(display:DisplayObject):Void {
		if (render != null) {
			this.render.__worldAlpha = display.__worldAlpha;
			this.render.__worldTransform.copyFrom(display.__worldTransform);
		}
	}

	/**
	 * 使滤镜失效，需要在滤镜处理完成后调用，以通知渲染器需要重新渲染
	 */
	public function invalidate():Void {
		__dirty = true;
	}

	public function dispose():Void {
		isDisposed = true;
		render = null;
	}

	/**
	 * 更新舞台尺寸，需要在舞台尺寸变化时调用，以通知滤镜处理舞台尺寸变化
	 */
	public function updateStageSize():Void {
		this.invalidate();
	}
}
