package hx.controls3d;

import hx.display.Camera3D;
import hx.geom.Vector3D;
import hx.render3d.Math3D;

/** 显式 update(dt) 驱动的世界坐标环绕相机；不注册输入和帧回调。 */
class OrbitCameraController3D {
	/** 借用的透视相机，控制器仅管理其姿态。 */
	public var camera(default, null):Camera3D;

	/** 环绕中心的世界坐标；构造时复制，之后可直接修改该向量。 */
	public var target:Vector3D;

	/** 是否启用；关闭后停止本组件的主动处理。 */
	public var enabled:Bool = true;

	/** 是否已经销毁；销毁后不得继续修改或更新。 */
	public var isDisposed(default, null):Bool = false;

	/** 目标水平角，单位为度，绕世界 Y 轴旋转。 */
	public var yaw:Float = 0;

	/** 目标俯仰角，单位为度，在 minPitch 与 maxPitch 之间限制。 */
	public var pitch:Float = 20;

	/** 目标相机距离，单位为世界单位，受最小与最大距离限制。 */
	public var distance:Float = 6;

	/** 允许的最小观察距离，默认 0.2，必须大于零。 */
	public var minDistance:Float = 0.2;

	/** 允许的最大观察距离，默认 100，不得小于最小距离。 */
	public var maxDistance:Float = 100;

	/** 允许的最小俯仰角，默认 -80 度，须大于 -90 度。 */
	public var minPitch:Float = -80;

	/** 允许的最大俯仰角，默认 80 度，须小于 90 度。 */
	public var maxPitch:Float = 80;

	/** 指数趋近速率，单位为每秒；零表示直接应用目标。 */
	public var damping:Float = 12;

	private var ready:Bool = false;
	private var currentTarget:Vector3D = new Vector3D();
	private var currentYaw:Float = 0;
	private var currentPitch:Float = 20;
	private var currentDistance:Float = 6;

	/** 借用相机并复制可选世界观察中心；不绑定输入或帧回调。 */
	public function new(camera:Camera3D, target:Vector3D = null) {
		if (camera == null || camera.isDisposed)
			throw "相机控制器需要有效相机";
		this.camera = camera;
		this.target = target == null ? new Vector3D() : target.clone();
		syncFromCamera();
	}

	/** 以角度增量调整目标水平角和俯仰角，由后续 update 应用平滑。 */
	public function rotate(deltaYaw:Float, deltaPitch:Float):Void {
		validateState();
		if (!Math3D.finite(deltaYaw) || !Math3D.finite(deltaPitch))
			throw "相机旋转增量必须是有限数值";
		yaw = wrapYaw(yaw + deltaYaw % 360);
		pitch = Math.max(minPitch, Math.min(maxPitch, pitch + deltaPitch));
	}

	/** 大于 1 拉远，小于 1 拉近，距离最终限制在配置范围内。 */
	public function zoomBy(factor:Float):Void {
		validateState();
		if (!Math3D.finite(factor) || factor <= 0)
			throw "相机缩放倍率必须是正有限数值";
		distance = factor >= maxDistance / distance ? maxDistance : Math.max(minDistance, distance * factor);
	}

	/** 从当前相机位置推导环绕参数，切换控制器时可显式同步。 */
	public function syncFromCamera():Void {
		validateState();
		var delta = camera.getWorldPosition().subtract(target),
			length = delta.length;
		if (!Math3D.finite(length))
			throw "相机距离超出有限范围";
		if (length < 1e-10) {
			ready = false;
			return;
		}
		yaw = Math.atan2(delta.x, delta.z) * 180 / Math.PI;
		pitch = Math.max(minPitch, Math.min(maxPitch, Math.asin(Math.max(-1, Math.min(1, delta.y / length))) * 180 / Math.PI));
		distance = Math.max(minDistance, Math.min(maxDistance, length));
		copyTarget();
		currentYaw = yaw;
		currentPitch = pitch;
		currentDistance = distance;
		ready = true;
	}

	/** 直接对齐，不依赖 dt；也用于恢复或切换目标后的主动重置。 */
	public function snap():Void {
		validateState();
		clampSettings();
		copyTarget();
		currentYaw = yaw;
		currentPitch = pitch;
		currentDistance = distance;
		ready = true;
		applyCamera();
	}

	/** 按非负秒数推进相机平滑；目标固定时使用指数阻尼，禁用后不移动。 */
	public function update(dt:Float):Void {
		if (isDisposed)
			return;
		if (!Math3D.finite(dt) || dt < 0)
			throw "相机时间步长必须是非负有限数值";
		if (!enabled)
			return;
		validateState();
		clampSettings();
		if (!ready) {
			snap();
			return;
		}
		if (dt == 0)
			return;
		var weight = damping == 0 ? 1 : 1 - Math.exp(-damping * dt);
		currentTarget.x = approach(currentTarget.x, target.x, weight);
		currentTarget.y = approach(currentTarget.y, target.y, weight);
		currentTarget.z = approach(currentTarget.z, target.z, weight);
		var delta = wrapYaw(yaw - currentYaw + 180) - 180;
		currentYaw = wrapYaw(currentYaw + approach(0, delta, weight));
		currentPitch = approach(currentPitch, pitch, weight);
		currentDistance = approach(currentDistance, distance, weight);
		applyCamera();
	}

	private function applyCamera():Void {
		var azimuth = currentYaw * Math.PI / 180,
			elevation = currentPitch * Math.PI / 180,
			horizontal = Math.cos(elevation) * currentDistance;
		camera.lookFrom(new Vector3D(currentTarget.x
			+ Math.sin(azimuth) * horizontal, currentTarget.y
			+ Math.sin(elevation) * currentDistance,
			currentTarget.z
			+ Math.cos(azimuth) * horizontal),
			currentTarget);
	}

	private function copyTarget():Void {
		currentTarget.setTo(target.x, target.y, target.z);
	}

	private function clampSettings():Void {
		yaw = wrapYaw(yaw);
		pitch = Math.max(minPitch, Math.min(maxPitch, pitch));
		distance = Math.max(minDistance, Math.min(maxDistance, distance));
	}

	private function validateState():Void {
		if (isDisposed || camera == null || camera.isDisposed || target == null)
			throw "相机控制器已经失效";
		for (value in [
			yaw,
			pitch,
			distance,
			minDistance,
			maxDistance,
			minPitch,
			maxPitch,
			damping,
			target.x,
			target.y,
			target.z
		])
			if (!Math3D.finite(value))
				throw "相机控制参数必须是有限数值";
		if (minDistance <= 0 || maxDistance < minDistance || distance <= 0 || minPitch <= -90 || maxPitch >= 90 || minPitch > maxPitch || damping < 0)
			throw "相机控制参数范围无效";
	}

	private static function wrapYaw(value:Float):Float {
		return (value % 360 + 360) % 360;
	}

	private static function approach(from:Float, to:Float, weight:Float):Float {
		return Math.abs(to - from) < 1e-7 ? to : from * (1 - weight) + to * weight;
	}

	/** 幂等停止控制并解除相机引用，不销毁相机。 */
	public function dispose():Void {
		if (isDisposed)
			return;
		isDisposed = true;
		enabled = false;
		camera = null;
	}
}
