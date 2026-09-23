package hx.layout;

/**
 * 虚拟布局的公共计算
 */
class VirtualLayoutUtils {
	/**
	 * 计算可见的数据索引区间（含缓冲）
	 * @param slotSize 单个槽位的尺寸
	 * @param total 数据总量
	 * @param offset 主轴方向上已经滚动的距离
	 * @param viewport 主轴方向上可视区域的尺寸
	 * @param bufferCount 可视区域前后额外渲染的Item数量
	 * @param data 输出的索引区间，`last`小于`first`时表示没有数据
	 */
	public static function getVisibleRange(slotSize:Float, total:Int, offset:Float, viewport:Float, bufferCount:Int,
			data:{first:Int, last:Int}):Void {
		var first = 0;
		var last = -1;
		if (total > 0) {
			// 槽位尺寸不合法时避免除零，退化为按1像素计算
			var slot = slotSize > 0 ? slotSize : 1;
			var buffer = bufferCount * slot;
			first = Std.int((offset - buffer) / slot);
			if (first < 0)
				first = 0;
			last = Std.int((offset + viewport + buffer) / slot);
			if (last > total - 1)
				last = total - 1;
		}
		data.first = first;
		data.last = last;
	}
}
