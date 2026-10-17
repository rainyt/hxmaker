package hx.display3d;

import hx.effect3d.BillboardGeometry3D;
import hx.effect3d.TrailSettings3D;
import hx.events.Event;
import hx.geom.Vector3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.render3d.Math3D;

/** 记录世界空间双端截面的刀光带；端点可绑定骨骼节点或显式 addSection。 */
class Ribbon3D extends MeshObject {
	/** 借用节点，不接管生命周期；必须同时设置两端才会自动采样。 */
	public var startNode:Node3D;

	public var endNode:Node3D;
	public var settings(default, null):TrailSettings3D;
	public var playing(default, null):Bool = false;
	public var emitting(default, null):Bool = false;
	public var paused:Bool = false;
	public var sectionCount(get, never):Int;

	private function get_sectionCount():Int {
		return sections.length;
	}

	private var sections:Array<RibbonSection3D> = [];
	private var ownedGeometry:Geometry3D;
	private var clock:Float = 0;
	private var distance:Float = 0;

	public function new(material:Material3D, settings:TrailSettings3D = null) {
		super(createGeometry(settings), material);
		this.settings = settings == null ? new TrailSettings3D() : settings;
		this.settings.validate();
		ownedGeometry = geometry;
		pickable = false;
		receiveShadow = false;
	}

	/** 先校验配置再引用材质，避免构造失败后留下外部资源引用。 */
	private static function createGeometry(settings:TrailSettings3D):Geometry3D {
		if (settings != null)
			settings.validate();
		return new Geometry3D([], [], []);
	}

	/** 重播清空历史；先绑定父节点和端点，再在每帧 update 中采样。 */
	public function play():Void {
		if (isDisposed)
			throw "刀光带已经销毁";
		settings.validate();
		clear();
		clock = 0;
		distance = 0;
		paused = false;
		playing = emitting = true;
	}

	/** 停止采样后仍需 update，等待历史截面自然消失。 */
	public function stop(clearSections:Bool = false):Void {
		if (isDisposed)
			return;
		emitting = false;
		if (clearSections)
			clear();
		finishIfEmpty();
	}

	private function clear():Void {
		sections.resize(0);
		BillboardGeometry3D.clear(ownedGeometry);
		ownedGeometry.invalidate();
	}

	/** 输入世界坐标，只在采样状态记录；稍后调用 update 重建网格。 */
	public function addSection(start:Vector3D, end:Vector3D):Void {
		if (isDisposed)
			throw "刀光带已经销毁";
		if (!playing || !emitting || paused)
			return;
		settings.validate();
		validatePoint(start);
		validatePoint(end);
		var center = new Vector3D((start.x + end.x) * 0.5, (start.y + end.y) * 0.5, (start.z + end.z) * 0.5);
		var broken = false;
		if (sections.length > 0) {
			var previous = sections[sections.length - 1];
			var movement = Math.max(start.subtract(previous.start).length, end.subtract(previous.end).length);
			if (movement <= Math.max(1e-8, settings.minDistance))
				return;
			broken = settings.breakDistance > 0 && movement > settings.breakDistance;
			if (!broken)
				distance += center.subtract(previous.center).length;
		}
		sections.push({
			start: start.clone(),
			end: end.clone(),
			center: center,
			birth: clock,
			distance: distance,
			broken: broken
		});
		while (sections.length > settings.maxSections)
			sections.shift();
	}

	/** 可覆盖的自动采样入口，先推进时钟，再记录本帧世界位置。 */
	private function capture(camera:Camera3D):Void {
		if (startNode == null && endNode == null)
			return;
		if (startNode == null || endNode == null || startNode.isDisposed || endNode.isDisposed)
			throw "刀光带两端节点必须有效";
		addSection(startNode.getWorldPosition(), endNode.getWorldPosition());
	}

	/** 相机仅供 Trail3D 使用；暂停时仍可重建面向相机的轨迹。 */
	public function update(dt:Float, camera:Camera3D = null):Void {
		if (isDisposed || !Math3D.finite(dt) || dt < 0 || !Math3D.finite(clock + dt))
			throw "拖尾更新时间无效";
		settings.validate();
		if (playing && !paused) {
			clock += dt;
			while (sections.length > 0 && clock - sections[0].birth >= settings.lifetime)
				sections.shift();
			while (sections.length > settings.maxSections)
				sections.shift();
			if (emitting)
				capture(camera);
		}
		rebuild(camera);
		finishIfEmpty();
	}

	/** 子类可根据镜头生成截面两端；返回世界坐标。 */
	private function edgePoints(index:Int, camera:Camera3D):Array<Vector3D> {
		return [sections[index].start, sections[index].end];
	}

	private function rebuild(camera:Camera3D):Void {
		BillboardGeometry3D.clear(ownedGeometry);
		var inverse = getWorldMatrix();
		if (sections.length < 2 || !inverse.invert()) {
			ownedGeometry.invalidate();
			return;
		}
		var first = sections[0].distance,
			last = sections[sections.length - 1].distance;
		for (i in 0...sections.length) {
			var section = sections[i],
				t = (clock - section.birth) / settings.lifetime;
			var ends = edgePoints(i, camera),
				middle = new Vector3D((ends[0].x + ends[1].x) * 0.5, (ends[0].y + ends[1].y) * 0.5, (ends[0].z + ends[1].z) * 0.5);
			var width = Math.max(0, settings.width * settings.widthOverLife.evaluate(t));
			var u = settings.textureRepeatLength > 0 ? section.distance / settings.textureRepeatLength : (last
				- first > 1e-8 ? (section.distance - first) / (last - first) : i / (sections.length - 1));
			for (side in 0...2) {
				var edge = ends[side].subtract(middle);
				edge.scaleBy(width);
				var p = inverse.transformVector(middle.add(edge));
				ownedGeometry.positions.push(p.x);
				ownedGeometry.positions.push(p.y);
				ownedGeometry.positions.push(p.z);
				ownedGeometry.uvs.push(u);
				ownedGeometry.uvs.push(side * 1.);
				for (value in [
					unit(settings.red.evaluate(t)),
					unit(settings.green.evaluate(t)),
					unit(settings.blue.evaluate(t)),
					unit(settings.alpha.evaluate(t))
				])
					ownedGeometry.colors.push(value);
			}
			if (i > 0 && !section.broken) {
				var base = (i - 1) * 2;
				for (index in [base, base + 1, base + 2, base + 1, base + 3, base + 2])
					ownedGeometry.indices.push(index);
			}
		}
		ownedGeometry.invalidate();
	}

	private function finishIfEmpty():Void {
		if (playing && !emitting && sections.length == 0) {
			playing = false;
			dispatchEvent(new Event(Event.COMPLETE));
		}
	}

	private static function validatePoint(p:Vector3D):Void {
		if (p == null || !Math3D.finite(p.x) || !Math3D.finite(p.y) || !Math3D.finite(p.z))
			throw "拖尾截面坐标必须有限";
	}

	private static function unit(value:Float):Float {
		return Math.max(0, Math.min(1, value));
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		playing = emitting = false;
		sections = [];
		startNode = endNode = null;
		super.dispose();
		if (ownedGeometry.referenceCount == 0)
			ownedGeometry.dispose();
	}
}

private typedef RibbonSection3D = {
	var start:Vector3D;
	var end:Vector3D;
	var center:Vector3D;
	var birth:Float;
	var distance:Float;

	/** 与上一截面断开，但可与下一截面形成新轨迹。 */
	var broken:Bool;
}
