package hx.particle;

import hx.geom.ColorTransform;
import hx.display.BitmapData;
import hx.display.Image;
import hx.display.Particle;
import VectorMath;
import hx.geom.Point;

@:access(hx.particle.Particle)
class ParticleChild {
	public var id:Int;

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

	public function reset():Void {
		this.image.blendMode = particle.blendMode;
		var vx = 0.;
		var vy = 0.;
		var ax = 0.;
		var ay = 0.;
		var tx = 0.;
		var ty = 0.;
		var angle = 0.;
		// 点与中心的角度
		var posAngle = 0.;
		if (particle.dynamicEmitPoint) {
			// var stagePos = particle.parent.localToGlobal(new Point(particle.x, particle.y));
			posX = Math.random() * particle.widthRange * 2 - particle.widthRange + particle.x / particle.scaleX;
			posY = Math.random() * particle.heightRange * 2 - particle.heightRange + particle.y / particle.scaleY;
		} else {
			posX = Math.random() * particle.widthRange * 2 - particle.widthRange;
			posY = Math.random() * particle.heightRange * 2 - particle.heightRange;
		}
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
	}

	public function dispose():Void {
		particle = null;
	}

	public var time:Float = 0;

	/**
	 * 颜色变换
	 */
	private static var mathColorTransform:ColorTransform = new ColorTransform();

	private var __localX:Float = 0;
	private var __localY:Float = 0;

	public function update(dt:Float) {
		time += dt;
		var timeScale = aliveTime / life;

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

		this.particle.scaleXAttribute.update(timeScale, outlife);
		this.particle.scaleYAttribute.update(timeScale, outlife);
		var startScaleX:Float = particle.scaleXAttribute.tween.start.getValue();
		var endScaleX:Float = particle.scaleXAttribute.tween.end.getValue();
		var startScaleY:Float = particle.scaleYAttribute.tween.start.getValue();
		var endScaleY:Float = particle.scaleYAttribute.tween.end.getValue();
		var scaleXlife = particle.scaleXAttribute.leftTime;
		var scaleYlife = particle.scaleYAttribute.leftTime;
		var sx:Float = startScaleX + (endScaleX - startScaleX) * scaleXlife;
		var sy:Float = startScaleY + (endScaleY - startScaleY) * scaleYlife;
		this.image.scaleX = sx;
		this.image.scaleY = sy;

		this.particle.rotaionAttribute.update(timeScale, outlife);
		var startRotation = particle.rotaionAttribute.tween.start.getValue();
		var endRotation:Float = particle.rotaionAttribute.tween.end.getValue();
		var rotation:Float = startRotation + (endRotation - startRotation) * particle.rotaionAttribute.leftTime;
		this.image.rotation = rotation;

		this.image.x = posX + velocityX * aliveTime + (gravityX + accelerationX + tangentialX) * aliveTime * aliveTime;
		this.image.y = posY + velocityY * aliveTime + (gravityY + accelerationY + tangentialY) * aliveTime * aliveTime;
		this.__localX = this.image.x;
		this.__localY = this.image.y;

		this.updatePosition();

		// 更新颜色处理
		this.particle.colorAttribute.update(timeScale, outlife);
		var startColor = this.particle.colorAttribute.tween.start.asFourAttribute();
		var endColor = this.particle.colorAttribute.tween.end.asFourAttribute();
		mathColorTransform.redMultiplier = startColor.x.getValue() + (endColor.x.getValue() - startColor.x.getValue()) * this.particle.colorAttribute.leftTime;
		mathColorTransform.greenMultiplier = startColor.y.getValue()
			+ (endColor.y.getValue() - startColor.y.getValue()) * this.particle.colorAttribute.leftTime;
		mathColorTransform.blueMultiplier = startColor.z.getValue()
			+ (endColor.z.getValue() - startColor.z.getValue()) * this.particle.colorAttribute.leftTime;
		mathColorTransform.alphaMultiplier = startColor.w.getValue()
			+ (endColor.w.getValue() - startColor.w.getValue()) * this.particle.colorAttribute.leftTime;
		this.image.alpha = mathColorTransform.alphaMultiplier;
		this.image.colorTransform = mathColorTransform;
	}

	public function updatePosition():Void {
		if (particle.dynamicEmitPoint) {
			this.image.x = this.__localX - particle.x / particle.scaleX;
			this.image.y = this.__localY - particle.y / particle.scaleY;
		}
	}
}
