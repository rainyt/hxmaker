package hx.layout;

/**
 * 分割布局数据
 * 用于声明面板在`SplitterLayout`中的尺寸规则：
 * - 设置了`size`的面板使用固定尺寸
 * - 设置了`percentSize`的面板按百分比分配尺寸
 * - 两者都未设置的面板作为弹性面板，均分剩余空间
 */
class SplitterLayoutData extends LayoutData {
	/**
	 * 固定尺寸，沿排列轴的像素值
	 */
	public var size:Null<Float> = null;

	/**
	 * 百分比尺寸，取值`0~100`，相对于排列轴的可用总长（不包含分割条占位与间距）
	 */
	public var percentSize:Null<Float> = null;

	/**
	 * @param size 固定尺寸
	 * @param percentSize 百分比尺寸
	 */
	public function new(?size:Float, ?percentSize:Float) {
		super();
		this.size = size;
		this.percentSize = percentSize;
	}
}
