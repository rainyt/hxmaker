package hx.display3d;

import hx.effect3d.BillboardGeometry3D;
import hx.effect3d.TrailSettings3D;
import hx.geom.Vector3D;
import hx.material.Material3D;

/** 面向镜头的弹道拖尾；世界空间历史不随目标或父节点移动。 */
class Trail3D extends Ribbon3D {
	/** 借用跟随节点；为空时记录拖尾节点自己的世界原点。 */
	public var target:Node3D;

	public function new(material:Material3D, settings:TrailSettings3D = null) {
		super(material, settings);
	}

	override private function capture(camera:Camera3D):Void {
		if (target != null && target.isDisposed)
			throw "拖尾跟随节点已经销毁";
		var center = target == null ? getWorldPosition() : target.getWorldPosition();
		addSection(center, center);
	}

	override public function update(dt:Float, camera:Camera3D = null):Void {
		if (camera == null || camera.isDisposed)
			throw "面向镜头的拖尾需要有效相机";
		super.update(dt, camera);
	}

	override private function edgePoints(index:Int, camera:Camera3D):Array<Vector3D> {
		var section = sections[index];
		var previous = index > 0 && !section.broken ? sections[index - 1].center : section.center;
		var next = index + 1 < sections.length && !sections[index + 1].broken ? sections[index + 1].center : section.center;
		var tangent = next.subtract(previous),
			towardCamera = camera.getWorldPosition().subtract(section.center);
		var side = tangent.crossProduct(towardCamera);
		// 镜头沿着轨迹观察或截面重合时，退回相机右方向，避免归一化零向量。
		if (side.normalize() < 1e-8)
			side = BillboardGeometry3D.axes(camera)[0];
		side.scaleBy(0.5);
		return [section.center.subtract(side), section.center.add(side)];
	}

	override public function dispose():Void {
		target = null;
		super.dispose();
	}
}
