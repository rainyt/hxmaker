package hx.display3d;

import hx.effect3d.BillboardGeometry3D;
import hx.effect3d.SpriteSheet3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.render3d.Math3D;

/** 手动 update(camera) 的广告牌；不接管调用者的材质。 */
class Billboard3D extends MeshObject {
	/** 宽高使用世界单位，不随父节点缩放改变；位置仍继承父节点。 */
	public var billboardWidth:Float = 1;
	public var billboardHeight:Float = 1;
	public var lockY:Bool = false;
	/** 面内旋转，单位为度。 */
	public var billboardRotation:Float = 0;
	public var sheet:SpriteSheet3D = new SpriteSheet3D();
	public var frame:Int = 0;
	private var ownedGeometry:Geometry3D;

	public function new(material:Material3D) {
		super(new Geometry3D([], [], []), material);
		ownedGeometry = geometry; pickable = false; receiveShadow = false;
	}

	/** 相机或父节点变换后也需调用；不自动订阅主循环。 */
	public function update(camera:Camera3D):Void {
		if (isDisposed || camera == null || camera.isDisposed || sheet == null) throw "广告牌、相机或图集无效";
		for (value in [billboardWidth, billboardHeight, billboardRotation])
			if (!Math3D.finite(value)) throw "广告牌参数必须有限";
		if (billboardWidth < 0 || billboardHeight < 0) throw "广告牌尺寸不能为负";
		var inverse = getWorldMatrix();
		BillboardGeometry3D.clear(ownedGeometry);
		if (inverse.invert()) BillboardGeometry3D.append(ownedGeometry, inverse, getWorldPosition(),
			BillboardGeometry3D.axes(camera, lockY), billboardWidth, billboardHeight,
			billboardRotation * Math.PI / 180, sheet.frameUV(frame), [1., 1., 1., 1.]);
		ownedGeometry.invalidate();
	}

	override public function dispose():Void {
		if (isDisposed) return;
		super.dispose();
		if (ownedGeometry.referenceCount == 0) ownedGeometry.dispose();
	}
}
