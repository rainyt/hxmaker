package hx.display3d;

import hx.effect3d.BillboardGeometry3D;
import hx.effect3d.ParticleSettings3D;
import hx.events.Event;
import hx.geom.Matrix3D;
import hx.geom.Vector3D;
import hx.geometry.Geometry3D;
import hx.material.Material3D;
import hx.render3d.Math3D;

/** CPU 模拟、单个动态网格的粒子发射器；显式 update，时间单位为秒。 */
class ParticleSystem3D extends MeshObject {
	public var settings(default, null):ParticleSettings3D;
	public var playing(default, null):Bool = false;
	public var emitting(default, null):Bool = false;
	public var paused:Bool = false;
	public var particleCount(get, never):Int;
	private function get_particleCount():Int { return particles.length; }
	private var particles:Array<ParticleState3D> = [];
	private var pool:Array<ParticleState3D> = [];
	private var elapsed:Float = 0;
	private var remainder:Float = 0;
	private var worldSpace:Bool = true;
	private var ownedGeometry:Geometry3D;
	private var serial:Int = 0;

	public function new(material:Material3D, settings:ParticleSettings3D = null) {
		super(new Geometry3D([], [], []), material);
		this.settings = settings == null ? new ParticleSettings3D() : settings;
		this.settings.validate(); ownedGeometry = geometry;
		pickable = false; receiveShadow = false;
	}

	/** 从头播放，清除旧粒子并锁定模拟空间；需先挂到正确的父节点。 */
	public function play():Void {
		if (isDisposed) throw "粒子系统已经销毁";
		settings.validate(); clear(); elapsed = 0; remainder = 0;
		worldSpace = settings.worldSpace; paused = false; playing = emitting = true;
		emit(settings.burst);
	}

	/** 停止发射，默认等待粒子自然结束；clearParticles=true 立即清空。 */
	public function stop(clearParticles:Bool = false):Void {
		if (isDisposed) return;
		emitting = false;
		if (clearParticles) clear();
		finishIfEmpty();
	}

	private function clear():Void {
		for (p in particles) pool.push(p);
		particles.resize(0);
		BillboardGeometry3D.clear(ownedGeometry); ownedGeometry.invalidate();
	}

	/** 立即爆发；不改变持续发射状态，支持运行中的额外命中爆发。 */
	public function emit(count:Int):Void {
		if (isDisposed || count < 0) throw "粒子系统或爆发数量无效";
		settings.validate();
		if (!playing) { worldSpace = settings.worldSpace; playing = true; }
		var matrix = getWorldMatrix();
		for (_ in 0...Std.int(Math.min(count, Math.max(0, settings.maxParticles - particles.length)))) spawn(matrix, 0);
	}

	private function spawn(matrix:Matrix3D, age:Float):Void {
		var lifetime = randomRange(settings.lifetimeMin, settings.lifetimeMax);
		if (age >= lifetime) return;
		var p = pool.length == 0 ? new ParticleState3D() : pool.pop();
		var z = Math.random() * 2 - 1, a = Math.random() * Math.PI * 2;
		var r = settings.radius * Math.pow(Math.random(), 1 / 3), radial = Math.sqrt(Math.max(0, 1 - z * z));
		p.position.setTo(radial * Math.cos(a) * r, z * r, radial * Math.sin(a) * r);
		var y = 1 - Math.random() * (1 - Math.cos(settings.coneAngle * Math.PI / 180));
		a = Math.random() * Math.PI * 2; radial = Math.sqrt(Math.max(0, 1 - y * y));
		var speed = randomRange(settings.speedMin, settings.speedMax);
		p.velocity.setTo(radial * Math.cos(a) * speed, y * speed, radial * Math.sin(a) * speed);
		if (worldSpace) {
			p.position = matrix.transformVector(p.position);
			p.velocity = matrix.deltaTransformVector(p.velocity);
		}
		p.age = 0; p.lifetime = lifetime; p.serial = serial++;
		p.size = randomRange(settings.sizeMin, settings.sizeMax);
		p.rotation = randomRange(settings.rotationMin, settings.rotationMax) * Math.PI / 180;
		advance(p, age); particles.push(p);
	}

	private function advance(p:ParticleState3D, dt:Float):Void {
		var g = settings.gravity;
		p.position.x += p.velocity.x * dt + g.x * dt * dt * 0.5;
		p.position.y += p.velocity.y * dt + g.y * dt * dt * 0.5;
		p.position.z += p.velocity.z * dt + g.z * dt * dt * 0.5;
		p.velocity.x += g.x * dt; p.velocity.y += g.y * dt; p.velocity.z += g.z * dt;
		p.rotation += settings.angularVelocity * Math.PI / 180 * dt; p.age += dt;
	}

	/** 暂停时仍重建相机朝向；无相机时继续模拟，但不保留旧网格。 */
	public function update(dt:Float, camera:Camera3D):Void {
		if (isDisposed || !Math3D.finite(dt) || dt < 0) throw "粒子更新时间或状态无效";
		settings.validate();
		if (playing && !paused) {
			var survivors:Array<ParticleState3D> = [];
			for (p in particles) {
				advance(p, dt);
				if (p.age >= p.lifetime || survivors.length >= settings.maxParticles) pool.push(p); else survivors.push(p);
			}
			particles = survivors;
			if (emitting) {
				var active = settings.duration == 0 ? dt : Math.max(0, Math.min(dt, settings.duration - elapsed));
				var previous = remainder, total = previous + active * settings.emissionRate;
				if (!Math3D.finite(total)) throw "粒子发射数量溢出";
				var count = Math.floor(total); remainder = total - count;
				var available = Std.int(Math.min(count, Math.max(0, settings.maxParticles - particles.length)));
				var matrix = getWorldMatrix();
				// 仅处理最近的有限次发射，防止大时间步或高发射率产生无界循环。
				for (i in 0...available) {
					var birth = (count - available + i + 1 - previous) / settings.emissionRate;
					spawn(matrix, Math.max(0, dt - birth));
				}
				elapsed += dt;
				if (settings.duration > 0 && elapsed >= settings.duration) emitting = false;
			}
		}
		rebuild(camera); finishIfEmpty();
	}

	private function rebuild(camera:Camera3D):Void {
		BillboardGeometry3D.clear(ownedGeometry);
		var world = getWorldMatrix(), inverse = world.clone();
		if (camera != null && !camera.isDisposed && particles.length > 0 && inverse.invert()) {
			var view = camera.getViewMatrix(), axes = BillboardGeometry3D.axes(camera);
			for (p in particles) {
				p.center = worldSpace ? p.position : world.transformVector(p.position);
				p.depth = -view.transformVector(p.center).z;
			}
			particles.sort(function(a, b) { return a.depth == b.depth ? a.serial - b.serial : (a.depth > b.depth ? -1 : 1); });
			for (p in particles) {
				var t = p.age / p.lifetime, size = Math.max(0, p.size * settings.size.evaluate(t));
				BillboardGeometry3D.append(ownedGeometry, inverse, p.center, axes, size, size, p.rotation,
					settings.sheet.frameUV(settings.sheet.lifeFrame(t)),
					[unit(settings.red.evaluate(t)), unit(settings.green.evaluate(t)), unit(settings.blue.evaluate(t)), unit(settings.alpha.evaluate(t))]);
			}
		}
		ownedGeometry.invalidate();
	}

	private function finishIfEmpty():Void {
		if (playing && !emitting && particles.length == 0) { playing = false; dispatchEvent(new Event(Event.COMPLETE)); }
	}
	private static function randomRange(a:Float, b:Float):Float { return a + Math.random() * (b - a); }
	private static function unit(v:Float):Float { return Math.max(0, Math.min(1, v)); }

	override public function dispose():Void {
		if (isDisposed) return;
		playing = emitting = false; particles = []; pool = [];
		super.dispose();
		if (ownedGeometry.referenceCount == 0) ownedGeometry.dispose();
	}
}

/** 仅由所属发射器复用的粒子状态。 */
private class ParticleState3D {
	public var position:Vector3D = new Vector3D();
	public var velocity:Vector3D = new Vector3D();
	public var center:Vector3D;
	public var depth:Float = 0;
	public var age:Float = 0;
	public var lifetime:Float = 1;
	public var size:Float = 1;
	public var rotation:Float = 0;
	public var serial:Int = 0;
	public function new() {}
}
