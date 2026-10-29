import hx.display.Stage;
import hx.display.Quad;
import hx.display.Label;
import hx.display.TextFormat;
import hx.events.MouseEvent;
import hx.core.Hxmaker;

class GameStage extends Stage {
	override public function onStageInit():Void {
		super.onStageInit();
		var panel:Quad = new Quad(600, 240, 0x17243a);
		panel.x = 24; panel.y = 24; panel.alpha = 0.85; addChild(panel);
		var title:Label = new Label("::project_name:: · Unity 后端", new TextFormat(null, 30, 0xffffff));
		title.x = 48; title.y = 48; addChild(title);
		var button:Label = new Label("点击切换多纹理", new TextFormat(null, 26, 0x80deea));
		button.x = 48; button.y = 120; button.mouseEnabled = true; addChild(button);
		button.addEventListener(MouseEvent.CLICK, (_:MouseEvent) -> {
			Hxmaker.engine.renderer.multiTextureEnabled = !Hxmaker.engine.renderer.multiTextureEnabled;
		});
	}
}
