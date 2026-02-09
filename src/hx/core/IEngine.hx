package hx.core;

import hx.display.IEventDispatcher;
import hx.display.IRender;
import hx.geom.Matrix;
import hx.display.DisplayObjectContainer;
import hx.display.Stage;

/**
 * 引擎接口，定义了游戏引擎的核心功能和方法
 * 任何具体的引擎实现都必须实现此接口
 */
interface IEngine extends IEventDispatcher {
	/**
	 * 渲染器实例，负责实际的渲染操作
	 * 通过此渲染器可以控制渲染相关的设置和操作
	 */
	public var renderer:IRender;

	/**
	 * 舞台列表，存储所有添加到引擎的舞台对象
	 * 每个舞台可以包含多个显示对象，构成显示树
	 */
	public var stages:Array<Stage>;

	/**
	 * 当前触摸事件的X坐标
	 * 相对于舞台左上角的坐标值
	 */
	public var touchX:Float;

	/**
	 * 当前触摸事件的Y坐标
	 * 相对于舞台左上角的坐标值
	 */
	public var touchY:Float;

	/**
	 * 每帧的时间间隔，单位为秒
	 * 用于基于时间的动画和物理计算
	 */
	public var dt:Float;

	/**
	 * 添加舞台到引擎
	 * @param stage 要添加的舞台对象
	 */
	public function addToStage(stage:Stage):Void;

	/**
	 * 从引擎中移除舞台
	 * @param stage 要移除的舞台对象
	 */
	public function removeToStage(stage:Stage):Void;

	/**
	 * 舞台宽度，只读属性
	 * @return 舞台的当前宽度
	 */
	public var stageWidth(get, never):Float;

	/**
	 * 舞台高度，只读属性
	 * @return 舞台的当前高度
	 */
	public var stageHeight(get, never):Float;

	/**
	 * 初始化引擎
	 * @param stageWidth 舞台宽度，0表示使用默认宽度
	 * @param stageHeight 舞台高度，0表示使用默认高度
	 * @param lockLandscape 是否锁定横屏模式
	 */
	public function init(stageWidth:Int, stageHeight:Int, lockLandscape:Bool = false):Void;

	/**
	 * 释放引擎资源
	 * 当游戏结束或引擎不再需要时调用
	 */
	public function dispose():Void;

	/**
	 * 引擎渲染逻辑
	 * 负责渲染指定的显示对象容器及其子对象
	 * @param display 要渲染的显示对象容器
	 * @param parentMatrix 父容器的变换矩阵，可选参数
	 */
	public function render(display:DisplayObjectContainer, ?parentMatrix:Matrix):Void;

	/**
	 * 引擎帧率，默认为机器动态帧率，一般不会低于60FPS，可自定义帧率
	 */
	public var frameRate(get, set):Int;
}
