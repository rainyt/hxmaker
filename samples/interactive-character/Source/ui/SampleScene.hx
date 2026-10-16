package ui;

import hx.display.Label;
import hx.display.Scene;
import hx.events.MouseEvent;

/** 示例 UI 只使用 hxmaker 组件；场景随流程退出统一释放。 */
class SampleScene extends Scene {
	override public function onStageInit():Void { super.onStageInit(); sceneBackground.data = 0x172033; sceneBackground.alpha = 1; }
	public function label(text:String,x:Float,y:Float,size:Int = 18,color:Int = 0xd7e3fc):Label {
		var value = new Label(text); value.x = x; value.y = y; value.fontSize = size; value.color = color; value.mouseEnabled = false; addChild(value); return value;
	}
	public function action(text:String,x:Float,y:Float,callback:Void->Void):Label {
		var value = label(text,x,y,18,0x8ed6ff); value.mouseEnabled = true;
		value.addEventListener(MouseEvent.CLICK,function(event:MouseEvent) { callback(); event.preventDefault(); }); return value;
	}
}
