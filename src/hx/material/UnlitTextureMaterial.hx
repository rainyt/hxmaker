package hx.material;

import hx.display.BitmapData;

/** 无光照贴图材质，默认参与多纹理合批。 */
class UnlitTextureMaterial extends Material3D {
	public function new(texture:BitmapData = null, color:Int = 0xffffff) {
		super(); this.texture = texture; this.color = color;
	}
}
