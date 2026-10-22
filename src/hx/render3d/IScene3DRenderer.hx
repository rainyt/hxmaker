package hx.render3d;

import hx.display.Scene3D;

/** 二维后端可选实现的场景接入能力，不改变现有 IRender 接口。 */
interface IScene3DRenderer {
	/** 后端扩展入口：将三维视口绘入独立目标并合成回二维显示树。 */
	public function renderScene3D(scene:Scene3D):Void;
}
