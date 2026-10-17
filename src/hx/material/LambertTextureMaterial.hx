package hx.material;

import hx.display.BitmapData;

/** 环境光与场景多光源的漫反射材质，沿用多纹理与透明模式。 */
class LambertTextureMaterial extends Material3D {
	/** 创建启用漫反射的贴图材质；贴图为借用引用，缺省使用白色基础色。 */
	public function new(texture:BitmapData = null, color:Int = 0xffffff) {
		super();
		this.texture = texture;
		this.color = color;
		lightingEnabled = true;
	}
}
