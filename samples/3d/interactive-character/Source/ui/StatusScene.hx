package ui;

import hx.display.Label;

/** 加载与错误状态共用的轻量界面。 */
class StatusScene extends SampleScene {
	private var title:String;
	private var actions:Array<{text:String,action:Void->Void}>;
	private var message:String = "";
	private var messageLabel:Label;
	public function new(title:String, actions:Array<{text:String,action:Void->Void}>) { super(); this.title = title; this.actions = actions; }
	override public function onStageInit():Void {
		super.onStageInit(); label(title,36,60,28,0xffffff);
		messageLabel = label(message,36,132,18);
		messageLabel.width = 1048; messageLabel.height = 170;
		for (i in 0...actions.length) action(actions[i].text,36,330+i*52,actions[i].action);
	}
	public function setMessage(value:String):Void { message = value; if (messageLabel != null) messageLabel.data = value; }
}
