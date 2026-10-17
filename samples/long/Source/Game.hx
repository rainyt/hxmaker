package;

import hx.display.Stage;

/** 舞台负责创建恐龙展示场景。 */
class Game extends Stage {
    override public function onStageInit():Void {
        super.onStageInit();
        addChild(new DinosaurScene());
    }
}
