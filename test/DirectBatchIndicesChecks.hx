package;

import hx.render2d.openfl.DirectBatchDisplay;
import lime.utils.UInt16Array;

/** 检查通用网格与固定四边形之间的索引复用，不创建 GPU 上下文。 */
class DirectBatchIndicesChecks {
	static function check(value:Bool, message:String):Void {
		if (!value) throw message;
	}

	static function topology(data:UInt16Array):Void {
		check(data.length % 6 == 0, "有效固定索引必须由完整四边形组成");
		var corners = [0, 1, 2, 1, 2, 3];
		for (i in 0...data.length) {
			var quad = Std.int(i / 6);
			check(data[i] == quad * 4 + corners[i % 6], "固定索引连接了其他四边形的顶点：" + i);
		}
	}

	static function main():Void {
		// 仅检查索引缓存，不执行 Sprite 初始化或 begin 中的舞台尺寸读取。
		var batch = Type.createEmptyInstance(DirectBatchDisplay);
		var generic = new UInt16Array(4096);
		for (i in 0...generic.length) generic[i] = 3000;
		batch.indices = generic;

		// 旧实现只填充 384 项，却将旧数组的 4096 项全部记作 GPU 有效容量。
		var first = batch.prepareFixedIndices(64);
		check(first != generic, "固定索引不能与通用网格共用数组");
		check(first.length == 384, "不能把通用网格的预留空间视为有效固定索引");
		topology(first);
		check(generic[0] == 3000, "生成固定索引不能覆盖通用网格快照");

		var grown = batch.prepareFixedIndices(128);
		check(grown.length == 768, "固定批次增长后必须生成完整的新索引范围");
		topology(grown);
		check(first.length == 384, "扩容不能改变旧索引快照");

		// 切回通用网格并覆写全部索引，再切回较小的固定批次。
		batch.indices = new UInt16Array(8192);
		for (i in 0...batch.indices.length) batch.indices[i] = 5000;
		var reused = batch.prepareFixedIndices(32);
		check(reused == grown, "已生成的固定索引应当复用");
		topology(reused);

		var largest = batch.prepareFixedIndices(DirectBatchDisplay.MAX_QUADS);
		topology(largest);
		check(largest[largest.length - 1] == DirectBatchDisplay.MAX_QUADS * 4 - 1,
			"最大固定批次的索引不能发生 16 位截断");
		var rejected = false;
		try batch.prepareFixedIndices(DirectBatchDisplay.MAX_QUADS + 1)
		catch (_:Dynamic) rejected = true;
		check(rejected, "超过单批上限时必须拒绝生成索引");
		trace("直接渲染批次索引检查完成");
	}
}
