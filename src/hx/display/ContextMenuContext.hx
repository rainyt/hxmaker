package hx.display;

/** 本次右键打开的上下文。业务回调应捕获本次的数据，不依赖之后的选择或渲染器。 */
typedef ContextMenuContext = {
	var owner:DisplayObject;
	var target:DisplayObject;
	var stageX:Float;
	var stageY:Float;
}
