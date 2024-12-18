package hx.core;

import openfl.Vector;
import openfl.display.BitmapData;
import openfl.display.Bitmap;

/**
 * 批处理位图渲染支持
 */
class BatchBitmapState {
	/**
	 * 纹理ID顶点列表
	 */
	public var ids:Array<Float> = [];

	/**
	 * 透明度渲染
	 */
	public var alphas:Array<Float> = [];

	/**
	 * 纹理顶点坐标
	 */
	public var vertices:Vector<Float> = new Vector();

	/**
	 * 纹理顶点索引
	 */
	public var indices:Vector<Int> = new Vector();

	/**
	 * 纹理顶点UV
	 */
	public var uvtData:Vector<Float> = new Vector();

	/**
	 * 待渲染的位图数据列表
	 */
	public var bitmaps:Array<Bitmap> = [];

	/**
	 * 待渲染纹理
	 */
	public var bitmapDatas:Array<BitmapData> = [];

	/**
	 * 纹理ID映射表
	 */
	public var mapIds:Map<BitmapData, Int> = [];

	/**
	 * 顶点偏移
	 */
	public var indicesOffset:Int = 0;

	/**
	 * 顶点坐标偏移
	 */
	public var dataPerVertex:Int = 0;

	/**
	 * 顶点数据偏移
	 */
	public var dataPerIndices:Int = 0;

	/**
	 * 位图索引
	 */
	public var bitmapIndex:Int = 0;

	public var render:Render;

	public function new(render:Render) {
		this.render = render;
	}

	/**
	 * 重置，仅重置数据索引
	 */
	public function reset():Void {
		this.cut();
		indicesOffset = 0;
		dataPerIndices = 0;
		dataPerVertex = 0;
		bitmapIndex = 0;
		bitmapDatas = [];
		mapIds = [];
	}

	/**
	 * 清理，跟重置不同，会将所有已缓存的数据清理
	 */
	public function clean():Void {
		bitmaps = [];
		ids = [];
		alphas = [];
		vertices = new Vector();
		indices = new Vector();
		uvtData = new Vector();
	}

	/**
	 * 数据剪切
	 */
	public function cut():Void {
		if (bitmapIndex < bitmaps.length)
			bitmaps = bitmaps.splice(0, bitmapIndex);
		if (dataPerVertex < vertices.length)
			vertices = vertices.splice(0, dataPerVertex);
		if (dataPerIndices < indices.length)
			indices = indices.splice(0, dataPerIndices);
		if (dataPerIndices < ids.length)
			ids = ids.splice(0, dataPerIndices);
		if (dataPerIndices < alphas.length)
			alphas = alphas.splice(0, dataPerIndices);
		if (dataPerVertex < uvtData.length)
			uvtData = uvtData.splice(0, dataPerVertex);
	}

	/**
	 * 如果使用的资产是相同的，则追加成功
	 * @param bitmap 
	 * @return Bool
	 */
	public function push(bitmap:Bitmap):Bool {
		if (checkState(bitmap)) {
			var oldBitmap = bitmaps[bitmapIndex];
			var isNull = oldBitmap == null;
			bitmaps[bitmapIndex] = bitmap;
			#if custom_render
			#else
			var id = mapIds.get(bitmap.bitmapData);
			ids[dataPerIndices] = id;
			ids[dataPerIndices + 1] = id;
			ids[dataPerIndices + 2] = id;
			ids[dataPerIndices + 3] = id;
			ids[dataPerIndices + 4] = id;
			ids[dataPerIndices + 5] = id;
			alphas[dataPerIndices] = bitmap.alpha;
			alphas[dataPerIndices + 1] = bitmap.alpha;
			alphas[dataPerIndices + 2] = bitmap.alpha;
			alphas[dataPerIndices + 3] = bitmap.alpha;
			alphas[dataPerIndices + 4] = bitmap.alpha;
			alphas[dataPerIndices + 5] = bitmap.alpha;
			// transform
			var tileWidth:Float = bitmap.scrollRect != null ? bitmap.scrollRect.width : bitmap.bitmapData.width;
			var tileHeight:Float = bitmap.scrollRect != null ? bitmap.scrollRect.height : bitmap.bitmapData.height;
			var tileTransform = @:privateAccess bitmap.__transform;
			var x = @:privateAccess tileTransform.__transformX(0, 0);
			var y = @:privateAccess tileTransform.__transformY(0, 0);
			var x2 = @:privateAccess tileTransform.__transformX(tileWidth, 0);
			var y2 = @:privateAccess tileTransform.__transformY(tileWidth, 0);
			var x3 = @:privateAccess tileTransform.__transformX(0, tileHeight);
			var y3 = @:privateAccess tileTransform.__transformY(0, tileHeight);
			var x4 = @:privateAccess tileTransform.__transformX(tileWidth, tileHeight);
			var y4 = @:privateAccess tileTransform.__transformY(tileWidth, tileHeight);
			vertices[dataPerVertex] = x;
			vertices[dataPerVertex + 1] = y;
			vertices[dataPerVertex + 2] = (x2);
			vertices[dataPerVertex + 3] = (y2);
			vertices[dataPerVertex + 4] = (x3);
			vertices[dataPerVertex + 5] = (y3);
			vertices[dataPerVertex + 6] = (x4);
			vertices[dataPerVertex + 7] = (y4);
			if (isNull) {
				// indices
				indices[dataPerIndices] = (indicesOffset);
				indices[dataPerIndices + 1] = (indicesOffset + 1);
				indices[dataPerIndices + 2] = (indicesOffset + 2);
				indices[dataPerIndices + 3] = (indicesOffset + 1);
				indices[dataPerIndices + 4] = (indicesOffset + 2);
				indices[dataPerIndices + 5] = (indicesOffset + 3);
			}
			// UVs
			if (bitmap.scrollRect != null) {
				var uvX = bitmap.scrollRect.x / bitmap.bitmapData.width;
				var uvY = bitmap.scrollRect.y / bitmap.bitmapData.height;
				var uvW = (bitmap.scrollRect.x + bitmap.scrollRect.width) / bitmap.bitmapData.width;
				var uvH = (bitmap.scrollRect.y + bitmap.scrollRect.height) / bitmap.bitmapData.height;
				uvtData[dataPerVertex] = (uvX);
				uvtData[dataPerVertex + 1] = (uvY);
				uvtData[dataPerVertex + 2] = (uvW);
				uvtData[dataPerVertex + 3] = (uvY);
				uvtData[dataPerVertex + 4] = (uvX);
				uvtData[dataPerVertex + 5] = (uvH);
				uvtData[dataPerVertex + 6] = (uvW);
				uvtData[dataPerVertex + 7] = (uvH);
			} else {
				uvtData[dataPerVertex] = (0);
				uvtData[dataPerVertex + 1] = (0);
				uvtData[dataPerVertex + 2] = (1);
				uvtData[dataPerVertex + 3] = (0);
				uvtData[dataPerVertex + 4] = (0);
				uvtData[dataPerVertex + 5] = (1);
				uvtData[dataPerVertex + 6] = (1);
				uvtData[dataPerVertex + 7] = (1);
			}
			indicesOffset += 4;
			dataPerIndices += 6;
			dataPerVertex += 8;
			#end
			bitmapIndex++;
			return true;
		}
		return false;
	}

	/**
	 * 检查状态是否可以合并
	 * @param bitmap 
	 * @return Bool
	 */
	public function checkState(bitmap:Bitmap):Bool {
		if (bitmaps.length == 0 || bitmapDatas.indexOf(bitmap.bitmapData) == -1) {
			// 多纹理支持，如果承载的多纹理数量允许，则可以继续添加
			if (bitmapDatas.length >= render.supportedMultiTextureUnits) {
				return false;
			} else {
				bitmapDatas.push(bitmap.bitmapData);
				mapIds.set(bitmap.bitmapData, bitmapDatas.length - 1);
			}
		} else {
			var lastBitmap = bitmaps[bitmaps.length - 1];
			if (lastBitmap.smoothing != bitmap.smoothing) {
				return false;
			}
		}
		return true;
	}
}
