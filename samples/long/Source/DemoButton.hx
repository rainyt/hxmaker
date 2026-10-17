package;

import hx.display.Label;
import hx.display.Quad;
import hx.display.Sprite;
import hx.events.MouseEvent;

/** 简单色块按钮，使用 hxmaker 显示对象与输入事件。 */
class DemoButton extends Sprite {
    private var buttonBackground:Quad;
    private var label:Label;
    private var available:Bool = true;

    public var caption(get, set):String;

    public function new(text:String, width:Float, callback:Void->Void) {
        super();
        mouseChildren = false;
        buttonBackground = new Quad(width, 36, 0x263c40);
        addChild(buttonBackground);
        label = new Label(text);
        label.fontSize = 15;
        label.color = 0xe1eee7;
        label.wordWrap = false;
        label.x = 12;
        label.y = 8;
        addChild(label);
        addEventListener(MouseEvent.CLICK, function(_) {
            if (available) callback();
        });
    }

    private function get_caption():String return label.data;
    private function set_caption(value:String):String return label.data = value;

    public function setActive(value:Bool):Void {
        buttonBackground.data = value ? 0x406e55 : 0x263c40;
        label.color = value ? 0xffffff : 0xe1eee7;
    }

    public function setAvailable(value:Bool):Void {
        available = value;
        mouseEnabled = value;
        alpha = value ? 1 : 0.4;
    }
}
