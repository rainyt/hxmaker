package hx.particle;

import hx.display.BitmapData;
import hx.display.Image;
import hx.display.Particle;
import VectorMath;

@:access(hx.particle.Particle)
class ParticleChild {
	public var id:Int;

	/**
	 * 过渡色ID
	 */
	public var tweenColorID:Int = -1;

	/**
	 * 生命周期
	 */
	public var life:Float = 0;

	/**
	 * 当前粒子的生命周期
	 */
	public var aliveTime:Float = 0;

	/**
	 * 最大生存
	 */
	public var maxlife:Float = 0;

	/**
	 * 随机粒子
	 */
	public var random:Float = 0;

	/**
	 * 上一次生命周期
	 */
	private var lastLife:Float = 0;

	/**
	 * 开始缩放X
	 */
	public var startScaleX:Float = 1;

	/**
	 * 开始缩放Y
	 */
	public var startScaleY:Float = 1;

	/**
	 * 结束缩放X
	 */
	public var endScaleX:Float = 1;

	/**
	 * 结束缩放Y
	 */
	public var endScaleY:Float = 1;

	/**
	 * 开始旋转角度
	 */
	public var startRotation:Float = 0;

	/**
	 * 结束旋转角度
	 */
	public var endRotation:Float = 0;

	/**
	 * 初始化位置X
	 */
	public var posX:Float = 0;

	/**
	 * 初始化位置Y
	 */
	public var posY:Float = 0;

	/**
	 * 初始化速度X
	 */
	public var velocityX:Float = 0;

	/**
	 * 初始化速度Y
	 */
	public var velocityY:Float = 0;

	/**
	 * 重力X
	 */
	public var gravityX:Float = 0;

	/**
	 * 重力Y
	 */
	public var gravityY:Float = 0;

	/**
	 * 加速度X
	 */
	public var accelerationX:Float = 0;

	/**
	 * 加速度Y
	 */
	public var accelerationY:Float = 0;

	/**
	 * 切线X
	 */
	public var tangentialX:Float = 0;

	/**
	 * 切线Y
	 */
	public var tangentialY:Float = 0;

	private var _init:Bool = false;

	public var particle:Particle;

	public var image:Image;

	public function new(parent:Particle, id:Int) {
		this.id = id;
		this.particle = parent;
		this.image = @:privateAccess parent.__pool.get();
	}

	public var texture(get, set):BitmapData;

	public function get_texture():BitmapData {
		return image.data;
	}

	public function set_texture(value:BitmapData):BitmapData {
		image.data = value;
		image.originX = -image.width / 2;
		image.originY = -image.height / 2;
		return value;
	}

	/**
	 * 该粒子是否已经死亡
	 * @return Bool
	 */
	public function isDie():Bool {
		return maxlife != -1 && this.particle.time >= maxlife + life;
	}

	/**
	 * 是否可以重置
	 * @return Bool
	 */
	public function onReset():Bool {
		var nowtime:Float = particle.time - life * random;
		if (_init) {
			aliveTime = mod(nowtime, life);
			aliveTime = aliveTime * step(0, nowtime);
			if (aliveTime > 0 && lastLife >= aliveTime) {
				lastLife = aliveTime;
				return true;
			}
			lastLife = aliveTime;
		} else if (nowtime > 0) {
			_init = true;
			return true;
		}
		return false;
	}

	/**
	 * 更新过渡颜色
	 */
	public function updateTweenColor():Bool {
		var tscale = aliveTime / life;
		var data = particle.colorAttribute.getStartAndEndTweenColor(tscale);
		if (data.id == tweenColorID) {
			return false;
		}

		var index2 = id * 12;
		var index4 = id * 24;

		tweenColorID = data.id;

		var start:FourAttribute = data.start;
		var end:FourAttribute = data.end;
		var startColor1 = start.x.getValue();
		var startColor2 = start.y.getValue();
		var startColor3 = start.z.getValue();
		var startColor4 = start.w.getValue();

		var endColor1 = end.x.getValue();
		var endColor2 = end.y.getValue();
		var endColor3 = end.z.getValue();
		var endColor4 = end.w.getValue();

		// 颜色过渡
		for (i in 0...6) {
			// 颜色过渡时差
			// particle._shader.a_rotaAndColorDToffest.value[index4 + 2] = data.startoffest;
			// particle._shader.a_rotaAndColorDToffest.value[index4 + 3] = data.endoffest;
			// 颜色
			// particle._shader.a_startColor.value[index4] = (startColor1);
			// particle._shader.a_startColor.value[index4 + 1] = (startColor2);
			// particle._shader.a_startColor.value[index4 + 2] = (startColor3);
			// particle._shader.a_startColor.value[index4 + 3] = (startColor4);
			// particle._shader.a_endColor.value[index4] = (endColor1);
			// particle._shader.a_endColor.value[index4 + 1] = (endColor2);
			// particle._shader.a_endColor.value[index4 + 2] = (endColor3);
			// particle._shader.a_endColor.value[index4 + 3] = (endColor4);
			index4 += 4;
			index2 += 2;
		}
		return true;
	}

	public function reset():Void {
		var vx = 0.;
		var vy = 0.;
		var ax = 0.;
		var ay = 0.;
		var tx = 0.;
		var ty = 0.;
		var angle = 0.;
		// 点与中心的角度
		var posAngle = 0.;
		posX = Math.random() * particle.widthRange * particle.scaleX * 2 - particle.widthRange * particle.scaleX;
		posY = Math.random() * particle.heightRange * particle.scaleY * 2 - particle.heightRange * particle.scaleY;
		posAngle = -Math.atan2((posY - 0), (posX - 0));
		var posAngle2 = Math.atan2((posX - 0), (posY - 0));
		// posAngle = -45 * 3.14 / 180;
		switch (particle.emitMode) {
			case Point:
				angle = particle.emitRotation.getValue() * Math.PI / 180;
				vx = particle.velocity.x.getValue();
				vy = particle.velocity.y.getValue();
				ax = particle.acceleration.x.getValue();
				ay = particle.acceleration.y.getValue();
				// tx = particle.tangential.x.getValue() * particle.scaleX;
				// ty = particle.tangential.y.getValue() * particle.scaleY;

				// vx = particle.velocity.x.getValue();
				// vy = particle.velocity.y.getValue();
				// ax = particle.acceleration.x.getValue();
				// ay = particle.acceleration.y.getValue();
				tx = particle.tangential.x.getValue();
				ty = particle.tangential.y.getValue();

			default:
				angle = particle.emitRotation.getValue() * Math.PI / 180;
				vx = particle.velocity.x.getValue();
				vy = particle.velocity.y.getValue();
				ax = particle.acceleration.x.getValue();
				ay = particle.acceleration.y.getValue();
		}

		// 方向力
		var vx1:Float = Math.cos(angle) * vx + Math.sin(angle) * vy;
		var vy1:Float = Math.cos(angle) * vy - Math.sin(angle) * vx;
		vx = vx1;
		vy = vy1;

		// 加速力
		var ax1:Float = Math.cos(posAngle) * ax + Math.sin(posAngle) * ay;
		var ay1:Float = Math.cos(posAngle) * ay - Math.sin(posAngle) * ax;
		ax = ax1;
		ay = ay1;

		ax = ax1;
		ay = ay1;

		// 切向力
		var tx1:Float = Math.cos(posAngle2) * tx + Math.sin(posAngle2) * ty;
		var ty1:Float = Math.cos(posAngle2) * ty - Math.sin(posAngle2) * tx;
		tx = tx1;
		ty = ty1;

		this.velocityX = vx;
		this.velocityY = vy;

		this.accelerationX = ax;
		this.accelerationY = ay;

		this.tangentialX = tx;
		this.tangentialY = ty;

		this.gravityX = particle.gravity.x.getValue();
		this.gravityY = particle.gravity.y.getValue();

		this.startScaleX = particle.scaleXAttribute.start.getValue();
		this.startScaleY = particle.scaleYAttribute.start == particle.scaleXAttribute.start ? this.startScaleY : particle.scaleYAttribute.start.getValue();
		this.endScaleX = particle.scaleXAttribute.end.getValue();
		this.endScaleY = particle.scaleYAttribute.end == particle.scaleXAttribute.end ? this.endScaleY : particle.scaleYAttribute.end.getValue();
		// scaleXstart *= particle.scaleX;
		// scaleYstart *= particle.scaleY;
		// scaleXend *= particle.scaleX;
		// scaleYend *= particle.scaleY;

		this.startRotation = particle.rotaionAttribute.start.getValue();
		this.endRotation = particle.rotaionAttribute.end.getValue();

		// 生命+生命方差实现
		if (this.life == 0) {
			var rlife = particle.life + Math.random() * particle.lifeVariance;
			this.life = rlife;
			var r = particle.randomLife.getValue();
			this.random = r;
		}

		// 最大生命周期
		if (particle.duration == -1) {
			this.maxlife = -1;
		} else {
			var dlife = Std.int(particle.duration / this.life) * this.life;
			this.maxlife = dlife;
			if (maxlife < life)
				maxlife = life;
		}

		var startColor1 = particle.colorAttribute.start.x.getValue();
		var startColor2 = particle.colorAttribute.start.y.getValue();
		var startColor3 = particle.colorAttribute.start.z.getValue();
		var startColor4 = particle.colorAttribute.start.w.getValue();

		var endColor1 = particle.colorAttribute.end.x.getValue();
		var endColor2 = particle.colorAttribute.end.y.getValue();
		var endColor3 = particle.colorAttribute.end.z.getValue();
		var endColor4 = particle.colorAttribute.end.w.getValue();

		var index1 = id * 6;
		var index2 = id * 12;
		var index3 = id * 18;
		var index4 = id * 24;

		for (i in 0...6) {
			// 颜色过渡时差
			// particle._shader.a_rotaAndColorDToffest.value[index4 + 2] = 0;
			// particle._shader.a_rotaAndColorDToffest.value[index4 + 3] = 1;
			// 颜色过渡
			// particle._shader.a_startColor.value[index4] = (startColor1);
			// particle._shader.a_startColor.value[index4 + 1] = (startColor2);
			// particle._shader.a_startColor.value[index4 + 2] = (startColor3);
			// particle._shader.a_startColor.value[index4 + 3] = (startColor4);
			// particle._shader.a_endColor.value[index4] = (endColor1);
			// particle._shader.a_endColor.value[index4 + 1] = (endColor2);
			// particle._shader.a_endColor.value[index4 + 2] = (endColor3);
			// particle._shader.a_endColor.value[index4 + 3] = (endColor4);
			// 角度
			// particle._shader.a_rotaAndColorDToffest.value[index4] = (startRotaion);
			// particle._shader.a_rotaAndColorDToffest.value[index4 + 1] = (endRotaion);
			// 随机值
			// particle._shader.a_random.value[index1] = (random);
			// 移动向量
			// particle._shader.a_velocity.value[index2] = (vx);
			// particle._shader.a_velocity.value[index2 + 1] = (vy);
			// 重力以及切向加速力
			// particle._shader.a_gravityxAndTangential.value[index4] = gx;
			// particle._shader.a_gravityxAndTangential.value[index4 + 1] = gy;
			// particle._shader.a_gravityxAndTangential.value[index4 + 2] = tx;
			// particle._shader.a_gravityxAndTangential.value[index4 + 3] = ty;
			// 加速力
			// particle._shader.a_acceleration.value[index2] = (ax);
			// particle._shader.a_acceleration.value[index2 + 1] = (ay);
			// 粒子生存时间
			// particle._shader.a_lifeAndDuration.value[index2] = (life);
			// particle._shader.a_lifeAndDuration.value[index2 + 1] = (maxlife);
			// 初始化位置
			// particle._shader.a_pos.value[index2] = (sx);
			// particle._shader.a_pos.value[index2 + 1] = (sy);
			// 缩放比例
			// particle._shader.a_scaleXXYY.value[index4] = (scaleXstart);
			// particle._shader.a_scaleXXYY.value[index4 + 1] = (scaleXend);
			// particle._shader.a_scaleXXYY.value[index4 + 2] = (scaleYstart);
			// particle._shader.a_scaleXXYY.value[index4 + 3] = (scaleYend);
			// 动态点
			if (particle.dynamicEmitPoint) {
				// particle._shader.a_dynamicPos.value[index3] = (particle.x);
				// particle._shader.a_dynamicPos.value[index3 + 1] = (particle.y);
				// particle._shader.a_dynamicPos.value[index3 + 2] = (1);
			} else {
				// particle._shader.a_dynamicPos.value[index3] = (0);
				// particle._shader.a_dynamicPos.value[index3 + 1] = (0);
				// particle._shader.a_dynamicPos.value[index3 + 2] = (0);
			}
			// index1++;
			// index2 += 2;
			// index3 += 3;
			// index4 += 4;
		}

		if (particle.colorAttribute.hasTween()) {
			updateTweenColor();
		}
	}

	public function dispose():Void {
		particle = null;
	}

	public var time:Float = 0;

	public function update(dt:Float) {
		time += dt;
		var nowtime:Float = time - life * random;
		if (particle.duration != -1 && nowtime > maxlife || nowtime < 0) {
			if (this.image.visible)
				this.image.visible = false;
			return;
		} else {
			if (!this.image.visible)
				this.image.visible = true;
		}
		var aliveTime:Float = mod(nowtime, life);
		aliveTime = aliveTime * step(0, nowtime);

		var outlife = (life - aliveTime) / life;
		var ooutlife:Float = 1 - outlife;
		var sx:Float = startScaleX * outlife + endScaleX * ooutlife;
		var sy:Float = startScaleY * outlife + endScaleY * ooutlife;
		this.image.scaleX = sx;
		this.image.scaleY = sy;

		var offsetRotation:Float = (endRotation - startRotation);
		var rotation:Float = startRotation + offsetRotation * outlife;
		this.image.rotation = rotation;

		this.image.x = posX + velocityX * aliveTime + (gravityX + accelerationX + tangentialX) * aliveTime * aliveTime;
		this.image.y = posY + velocityY * aliveTime + (gravityY + accelerationY + tangentialY) * aliveTime * aliveTime;
	}
}
