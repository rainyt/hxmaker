package hx.material;

import hx.display.BitmapData;

/** 基础无光照特效材质，保留深度遮挡、关闭深度写入、双面绘制。 */
class EffectMaterial3D extends UnlitTextureMaterial {
	public function new(texture:BitmapData = null, blend:BlendMode3D = BlendMode3D.NORMAL, color:Int = 0xffffff) {
		super(texture, color);
		alphaMode = AlphaMode3D.BLEND; blendMode = blend;
		depthWrite = false; cullMode = CullMode3D.NONE;
	}
}
