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
	 * 是否设置发射点为动态，默认为false，当为true时，将会随着x,y的坐标发生变化而改编发射点
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
	public var colorAttribute:GroupFourAttribute = new GroupFourAttribute(new FourAttribute(), new FourAttribute());

	/**
	 * 粒子存活数量
	 */
	public var particleLiveCounts:Int;

	/**
	 * 纹理列表
	 */
	public var textures:Array<BitmapData> = [];

	public function new(?json:Dynamic, ?texture:BitmapData) {
		super();
		textures.push(texture);
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
		var curtime = time + dt;
		var lifetime = (life + lifeVariance);
		if (curtime > lifetime * 2) {
			curtime = lifetime + (curtime % lifetime);
		}
		this.time = curtime;
		particleLiveCounts = 0;
		// var updateAttr:UpdateParams = new UpdateParams();
		for (value in childs) {
			if (!value.isDie()) {
				particleLiveCounts++;
			}
			if (value.onReset()) {
				if (forceReset || dynamicEmitPoint || colorAttribute.hasTween()) {
					value.reset();
					// updateAttr.push(value);
				}
			} else {
				if (colorAttribute.hasTween()) {
					// 存在过渡
					if (value.updateTweenColor()) {
						// updateAttr.push(value);
					}
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
		this.colorAttribute.tween.updateWeight();
		this.scaleXAttribute.tween.updateWeight();
		this.scaleYAttribute.tween.updateWeight();
		this.rotaionAttribute.tween.updateWeight();
		childs = [];
		for (i in 0...counts) {
			var child = new ParticleChild(this, i);
			child.texture = texture;
			childs.push(child);
			this.addChild(child.image);
			child.reset();
		}
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
}
