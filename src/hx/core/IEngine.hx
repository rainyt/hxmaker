package hx.core;

import hx.display.IRender;
import hx.geom.Matrix;
import hx.display.DisplayObjectContainer;
import hx.display.Stage;

/**
 * 引擎接口
 */
interface IEngine {
	/**
	 * 渲染
	 */
	public var renderer:IRender;

	/**
	 * 舞台列表
	 */
	public var stages:Array<Stage>;

	/**
	 * 触摸坐标X
	 */
	public var touchX:Float;

	/**
	 * 触摸坐标Y
	 */
	public var touchY:Float;

	/**
	 * 时间间隔
	 */
	public var dt:Float;

	/**
	 * 添加舞台
	 * @param stage 
	 */
	public function addToStage(stage:Stage):Void;

	/**
	 * 移除舞台
	 * @param stage 
	 */
	public function removeToStage(stage:Stage):Void;

	public var stageWidth(get, never):Float;

	public var stageHeight(get, never):Float;

	/**
	 * 初始化引擎
	 * @param stageWidth 
	 * @param stageHeight 
	 */
	public function init(stageWidth:Int, stageHeight:Int):Void;

	/**
	 * 释放引擎
	 */
	public function dispose():Void;

	/**
	 * 引擎渲染逻辑
	 * @param display 
	 * @param parentMatrix
	 */
	public function render(display:DisplayObjectContainer, ?parentMatrix:Matrix):Void;
}
