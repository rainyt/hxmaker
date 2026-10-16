package hx.render3d;

import hx.display.Scene3D;

/** 二维后端可选实现的场景接入能力，不改变现有 IRender 接口。 */
interface IScene3DRenderer {
	public function renderScene3D(scene:Scene3D):Void;
}
