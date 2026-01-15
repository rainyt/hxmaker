package hx.display;

import hx.utils.ObjectPool;
import hx.events.Event;
import hx.particle.*;

/**
 * 粒子系统
 */
class Particle extends Box {
	/**
	 * 粒子池
	 */
	private var __pool:ObjectPool<Image> = new ObjectPool<Image>(() -> {
		return new Image();
	}, (img:Image) -> {});

	/**
	 * 通过JSON解析粒子
	 * @param json 
	 */
	public static function fromJson(json:Dynamic, texture:BitmapData = null):Particle {
		return new Particle(json, texture);
	}

	/**
	 * 是否正在播放
	 */
	public var isPlay(get, never):Bool;

	private var _isPlay:Bool = false;

	/**
	 * 子粒子
	 */
	public var childs:Array<ParticleChild>;

	/**
	 * 随机生命指数
	 */
	public var randomLife:Attribute = new RandomTwoAttribute(0, 1);

	/**
	 * 是否设置发射点为动态，默认为`false`，当为`true`时，将会随着`x`，`y`的坐标发生变化而改编发射点
	 */
	public var dynamicEmitPoint:Bool = false;

	/**
	 * 强制重置，开启后，当粒子在生命最后一刻结束后，会进行重置，默认为false
	 */
	public var forceReset:Bool = false;

	/**
	 * 纹理
	 */
	public var texture(get, never):BitmapData;

	/**
	 * 获取当前纹理
	 */
	private function get_texture():BitmapData {
		return textures[0];
	}

	/**
	 * 发射模式
	 */
	public var emitMode:ParticleEmitMode = Point;

	/**
	 * 粒子数量
	 */
	public var counts:Int = 1;

	/**
	 * 当前时间，可设置当前时间来更新粒子
	 */
	public var time:Float = 0;

	/**
	 * 宽度范围
	 */
	public var widthRange:Float = 200;

	/**
	 * 
	 */
	public var heightRange:Float = 200;

	/**
	 * 粒子生命
	 */
	public var life:Float = 1;

	/**
	 * 粒子生命方差
	 */
	public var lifeVariance:Float = 0;

	/**
	 * 整个粒子系统生命持续时长，-1为无限循环
	 */
	public var duration:Float = -1;

	/**
	 * 是否循环
	 */
	public var loop(get, never):Bool;

	/**
	 * 发射角度
	 */
	public var emitRotation:Attribute = new OneAttribute(0);

	/**
	 * 发射方向范围
	 */
	public var velocity:TwoAttribute = new TwoAttribute();

	/**
	 * 重力
	 */
	public var gravity:TwoAttribute = new TwoAttribute();

	/**
	 * 加速力
	 */
	public var acceleration:TwoAttribute = new TwoAttribute();

	/**
	 * 切向加速力
	 */
	public var tangential:TwoAttribute = new TwoAttribute();

	/**
	 * 缩放属性ScaleX
	 */
	public var scaleXAttribute:GroupAttribute = new GroupAttribute(new OneAttribute(1), new OneAttribute(1));

	/**
	 * 缩放属性ScaleY
	 */
	public var scaleYAttribute:GroupAttribute = new GroupAttribute(new OneAttribute(1), new OneAttribute(1));

	/**
	 * 旋转属性
	 */
	public var rotaionAttribute:GroupAttribute = new GroupAttribute(new OneAttribute(0), new OneAttribute(0));

	/**
	 * 颜色过渡参数
	 */
	public var colorAttribute:GroupAttribute = new GroupAttribute(new FourAttribute(), new FourAttribute());

	/**
	 * 粒子存活数量
	 */
	public var particleLiveCounts:Int = 0;

	/**
	 * 纹理列表
	 */
	public var textures:Array<BitmapData> = [];

	public function new(?json:JSONParticleData, ?texture:BitmapData) {
		super();
		textures.push(texture);
		if (json != null) {
			this.applyJsonData(json);
		}
		this.width = this.height = 1;
	}

	/**
	 * 应用XML数据
	 * @param data 
	 */
	public function applyXmlData(data:Xml):Void {
		// 解析XML数据
		for (key in data.attributes()) {
			if (Reflect.hasField(this, key)) {
				if (key == "counts")
					counts = Std.parseInt(data.get(key));
				else
					Reflect.setProperty(this, key, Std.parseFloat(data.get(key)));
			}
		}
		for (item in data.elements()) {
			var array = this.getAttributeArray(item);
			switch item.nodeName {
				case "particle-velocity":
					this.velocity.x = this.createAttribute(array[0]);
					this.velocity.y = this.createAttribute(array[1]);
				case "particle-emit-rotation":
					this.emitRotation = this.createAttribute(array[0]);
				case "particle-gravity":
					this.gravity.x = this.createAttribute(array[0]);
					this.gravity.y = this.createAttribute(array[1]);
				case "particle-acceleration":
					this.acceleration.x = this.createAttribute(array[0]);
					this.acceleration.y = this.createAttribute(array[1]);
				case "particle-tangential":
					this.tangential.x = this.createAttribute(array[0]);
					this.tangential.y = this.createAttribute(array[1]);
				case "particle-group-scale":
					if (array.length > 2) {
						this.scaleXAttribute.start = this.createAttribute(array[0]);
						this.scaleYAttribute.start = this.createAttribute(array[0]);
						for (i in 1...array.length) {
							this.scaleXAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1,
								this.createAttribute(array[i]));
							this.scaleYAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1,
								this.createAttribute(array[i]));
						}
					} else {
						this.scaleXAttribute.start = this.createAttribute(array[0]);
						this.scaleXAttribute.end = this.createAttribute(array[1]);
						this.scaleYAttribute.start = this.createAttribute(array[0]);
						this.scaleYAttribute.end = this.createAttribute(array[1]);
					}
				case "particle-group-scale-x":
					if (array.length > 2) {
						this.scaleXAttribute.start = this.createAttribute(array[0]);
						for (i in 1...array.length) {
							var attribute = this.createAttribute(array[i]);
							this.scaleXAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1, attribute);
						}
					} else {
						this.scaleXAttribute.start = this.createAttribute(array[0]);
						this.scaleXAttribute.end = this.createAttribute(array[1]);
					}
				case "particle-group-scale-y":
					if (array.length > 2) {
						this.scaleYAttribute.start = this.createAttribute(array[0]);
						for (i in 1...array.length) {
							var attribute = this.createAttribute(array[i]);
							this.scaleYAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1, attribute);
						}
					} else {
						this.scaleYAttribute.start = this.createAttribute(array[0]);
						this.scaleYAttribute.end = this.createAttribute(array[1]);
					}
				case "particle-group-rotation":
					if (array.length > 2) {
						this.rotaionAttribute.start = this.createAttribute(array[0]);
						for (i in 1...array.length) {
							var attribute = this.createAttribute(array[i]);
							this.rotaionAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1, attribute);
						}
					} else {
						this.rotaionAttribute.start = this.createAttribute(array[0]);
						this.rotaionAttribute.end = this.createAttribute(array[1]);
					}
				case "particle-group-color":
					if (array.length > 2) {
						this.colorAttribute.start = this.createFourAttribute(array[0]);
						for (i in 1...array.length) {
							var fourAttribute = this.createFourAttribute(array[i]);
							this.colorAttribute.tween.pushAttribute(array[i].exists("weight") ? Std.parseFloat(array[i].get("weight")) : 1, fourAttribute);
						}
					} else {
						this.colorAttribute.start = this.createFourAttribute(array[0]);
						this.colorAttribute.end = this.createFourAttribute(array[1]);
					}
			}
		}
		this.forceReset = true;
	}

	private function getAttributeArray(xml:Xml):Array<Xml> {
		var array:Array<Xml> = [];
		for (item in xml.elements()) {
			array.push(item);
		}
		return array;
	}

	private function createAttribute(xml:Xml):Attribute {
		switch xml.nodeName {
			case "particle-one-attribute":
				return new OneAttribute(Std.parseFloat(xml.get("value")));
			case "particle-random-two-attribute":
				return new RandomTwoAttribute(Std.parseFloat(xml.get("min")), Std.parseFloat(xml.get("max")));
			default:
				throw "Invalid particle attribute type `" + xml.nodeName + "`";
		}
	}

	private function createFourAttribute(xml:Xml):FourAttribute {
		return new FourAttribute(Std.parseFloat(xml.get("x")), Std.parseFloat(xml.get("y")), Std.parseFloat(xml.get("z")), Std.parseFloat(xml.get("w")));
	}

	/**
	 * 应用JSON数据
	 * @param json 
	 */
	public function applyJsonData(data:JSONParticleData):Void {
		// 系统持续时长
		this.duration = data.duration;
		var random = new RandomTwoAttribute(0., 1);
		// 设置开始颜色
		this.colorAttribute.start.asFourAttribute().x = new RandomTwoAttribute(data.startColorRed, data.startColorRed + data.startColorVarianceRed);
		this.colorAttribute.start.asFourAttribute().y = new RandomTwoAttribute(data.startColorGreen, data.startColorGreen + data.startColorVarianceGreen);
		this.colorAttribute.start.asFourAttribute().z = new RandomTwoAttribute(data.startColorBlue, data.startColorBlue + data.startColorVarianceBlue);
		this.colorAttribute.start.asFourAttribute().w = new RandomTwoAttribute(data.startColorAlpha, data.startColorAlpha + data.startColorVarianceAlpha);
		// 设置结束颜色
		this.colorAttribute.end.asFourAttribute().x = new RandomTwoAttribute(data.finishColorRed, data.finishColorRed + data.finishColorVarianceRed);
		this.colorAttribute.end.asFourAttribute().y = new RandomTwoAttribute(data.finishColorGreen, data.finishColorGreen + data.finishColorVarianceGreen);
		this.colorAttribute.end.asFourAttribute().z = new RandomTwoAttribute(data.finishColorBlue, data.finishColorBlue + data.finishColorVarianceBlue);
		this.colorAttribute.end.asFourAttribute().w = new RandomTwoAttribute(data.finishColorAlpha, data.finishColorAlpha + data.finishColorVarianceAlpha);
		// 设置粒子数量
		this.counts = data.maxParticles;
		// 设置粒子生命
		this.life = data.particleLifespan;
		this.lifeVariance = data.particleLifespanVariance;
		// 设置粒子发射类型
		switch (data.emitterType) {
			case 0:
				// 以点发射
				this.emitMode = ParticleEmitMode.Point;
		}
		// 设置粒子位置方差
		this.widthRange = data.sourcePositionVariancex;
		this.heightRange = data.sourcePositionVariancey;
		// 设置粒子向量
		this.velocity.y.asOneAttribute().value = 0;
		this.velocity.x = new RandomTwoAttribute(data.speed, data.speed + data.speedVariance);
		this.acceleration.x = new RandomTwoAttribute(data.radialAcceleration, data.radialAcceleration + data.radialAccelVariance);
		this.acceleration.y.asOneAttribute().value = 0;
		this.tangential.x = new RandomTwoAttribute(data.tangentialAcceleration, data.tangentialAcceleration + data.tangentialAccelVariance);
		this.tangential.y.asOneAttribute().value = 0;
		this.gravity.x.asOneAttribute().value = data.gravityx * 0.5;
		this.gravity.y.asOneAttribute().value = -data.gravityy * 0.5;
		// 设置粒子的开始角度
		this.rotaionAttribute.start = new RandomTwoAttribute(data.rotationStart, data.rotationStart + data.rotationStartVariance);
		this.rotaionAttribute.end = new RandomTwoAttribute(data.rotationEnd, data.rotationEnd + data.rotationEndVariance);
		// 设置粒子发射方向
		this.emitRotation = new RandomTwoAttribute(data.angle - data.angleVariance, data.angle + data.angleVariance);
		this.forceReset = true;
	}

	/**
	 * 重置粒子
	 */
	public function reset() {
		// todo
	}

	/**
	 * 开始发射粒子
	 */
	public function start() {
		this._init();
		_isPlay = true;
		this.updateEnabled = true;
	}

	public function stop() {
		_isPlay = false;
		this.updateEnabled = false;
	}

	override public function onUpdate(dt:Float) {
		if (!_isPlay || childs == null)
			return;
		this.time += dt;
		particleLiveCounts = 0;
		for (value in childs) {
			if (!value.isDie()) {
				particleLiveCounts++;
			}
			if (value.onReset()) {
				if (forceReset || dynamicEmitPoint || colorAttribute.hasTween()) {
					value.reset();
				}
			}
			value.update(dt);
		}
		this.invalidate();
		if (this.duration != -1 && particleLiveCounts == 0) {
			this.time = 0;
			this.stop();
			this.dispatchEvent(new Event(Event.COMPLETE));
		}
	}

	/**
	 * 初始化所有粒子
	 */
	private function _init() {
		if (texture == null)
			return;
		this.dispose();
		this.updateWeight();
		childs = [];
		for (i in 0...counts) {
			var child = new ParticleChild(this, i);
			child.texture = texture;
			childs.push(child);
			this.addChild(child.image);
			child.reset();
		}
	}

	/**
	 * 更新权重
	 */
	public function updateWeight() {
		this.colorAttribute.tween.updateWeight();
		this.scaleXAttribute.tween.updateWeight();
		this.scaleYAttribute.tween.updateWeight();
		this.rotaionAttribute.tween.updateWeight();
	}

	function get_loop():Bool {
		return duration == -1;
	}

	function get_isPlay():Bool {
		return _isPlay;
	}

	override public function dispose():Void {
		if (childs != null)
			for (index => value in this.childs) {
				value.dispose();
			}
		this.childs = null;
	}

	private var __particleBlendMode:BlendMode = BlendMode.ADD;

	override function set_blendMode(value:BlendMode):BlendMode {
		__particleBlendMode = value;
		return value;
	}

	override function get_blendMode():BlendMode {
		return __particleBlendMode;
	}
}
