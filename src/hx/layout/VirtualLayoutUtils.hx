package hx.layout;

/**
 * 虚拟布局的公共计算
 */
class VirtualLayoutUtils {
	/**
	 * 计算可见的数据索引区间（含缓冲）
	 *
	 * 数据按"行"推进：`columns`为`1`时即为逐项推进的纵向/横向列表，大于`1`时即为网格（流）布局。
	 * @param data 输出的索引区间，`last`小于`first`时表示没有数据
	 * @param total 数据总量
	 * @param columns 每行（列）的Item数量，至少为`1`
	 * @param slotSize 一行（列）占用的主轴尺寸
	 * @param offset 主轴方向上已经滚动的距离
	 * @param viewport 主轴方向上可视区域的尺寸
	 * @param bufferCount 可视区域前后额外渲染的行数
	 */
	public static function getVisibleRange(data:{first:Int, last:Int}, total:Int, columns:Int, slotSize:Float, offset:Float,
			viewport:Float, bufferCount:Int):Void {
		var first = 0;
		var last = -1;
		if (total > 0) {
			// 槽位尺寸不合法时避免除零，退化为按1像素计算
			var slot = slotSize > 0 ? slotSize : 1;
			var columnCount = columns > 0 ? columns : 1;
			var rowCount = Std.int((total + columnCount - 1) / columnCount);
			var buffer = bufferCount * slot;
			var firstRow = Std.int((offset - buffer) / slot);
			if (firstRow < 0)
				firstRow = 0;
			var lastRow = Std.int((offset + viewport + buffer) / slot);
			if (lastRow > rowCount - 1)
				lastRow = rowCount - 1;
			first = firstRow * columnCount;
			last = lastRow * columnCount + columnCount - 1;
			if (last > total - 1)
				last = total - 1;
		}
		data.first = first;
		data.last = last;
	}
}
