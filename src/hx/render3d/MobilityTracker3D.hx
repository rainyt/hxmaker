package hx.render3d;

import hx.display.Scene3D;
import hx.display3d.Node3D;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import haxe.ds.ObjectMap;

private typedef MobilityRecord3D = {
	var snapshot:Array<Dynamic>;
	var changedAt:Float;
	var changedEpoch:Int;
}

/** 主场景与所有阴影级联共用的活动记录；不依赖重绘次数，不比较逐顶点内容。 */
class MobilityTracker3D {
	private var records:ObjectMap<Node3D, MobilityRecord3D> = new ObjectMap();
	private var epoch:Int = 0;
	public function new() {}
	/** 每个场景 UPDATE 推进一次，防止同一帧多次同步过早转静态。 */
	public function advance():Void { epoch++; }
	public static function owner(mesh:MeshObject):Node3D {
		var node = mesh.parent;
		while (node != null) { if (Std.isOfType(node, Model3D)) return node; node = node.parent; }
		return mesh;
	}
	public function update(scene:Scene3D):Void {
		var now = haxe.Timer.stamp(), groups:ObjectMap<Node3D, Array<MeshObject>> = new ObjectMap();
		function visit(node:Node3D):Void {
			if (node.isDisposed) return;
			if (Std.isOfType(node, MeshObject)) {
				var mesh:MeshObject = cast node;
				if (mesh.geometryMobility == GeometryMobility3D.AUTO || mesh.shadowMobility == ShadowMobility3D.AUTO) {
					var root = owner(mesh);
					if (!groups.exists(root)) groups.set(root, []);
					groups.get(root).push(mesh);
				}
			}
			for (child in node.children) visit(child);
		}
		visit(scene.root);
		for (root in [for (root in records.keys()) root]) if (!groups.exists(root)) records.remove(root);
		var staticCount = 0, dynamicCount = 0;
		for (root in groups.keys()) {
			var meshes = groups.get(root), snapshot:Array<Dynamic> = [];
			if (Std.isOfType(root, Model3D)) { var model:Model3D = cast root; snapshot.push(model.animationActivityVersion); }
			for (mesh in meshes) {
				snapshot.push(mesh); snapshot.push(mesh.geometry);
				snapshot.push(mesh.geometry == null ? -1 : mesh.geometry.version);
				// invalidate 也可能来自材质变化，只有实际矩阵变化才算运动。
				for (value in mesh.getWorldMatrix().rawData) snapshot.push(value);
			}
			var record = records.get(root), changed = record == null || record.snapshot.length != snapshot.length;
			if (!changed) for (i in 0...snapshot.length) if (snapshot[i] != record.snapshot[i]) { changed = true; break; }
			if (record == null) { record = {snapshot:snapshot, changedAt:now, changedEpoch:epoch}; records.set(root, record); }
			else { record.snapshot = snapshot; if (changed) { record.changedAt = now; record.changedEpoch = epoch; } }
			var settled = epoch > record.changedEpoch && now - record.changedAt >= scene.autoStaticDelay;
			for (mesh in meshes) {
				if (mesh.__autoStatic != settled) { mesh.__autoStatic = settled; scene.stats.autoMobilityTransitions++; scene.requestRender(); }
				if (settled) staticCount++; else dynamicCount++;
			}
		}
		scene.stats.autoStaticMeshes = staticCount; scene.stats.autoDynamicMeshes = dynamicCount;
	}
	public function clear():Void { records = new ObjectMap(); }
}
