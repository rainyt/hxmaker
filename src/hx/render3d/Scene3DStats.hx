package hx.render3d;

/** 最近一次三维重绘的数据；最终合成次数在每次 GPU 回调更新。 */
class Scene3DStats {
	public var drawCalls:Int = 0;
	public var triangles:Int = 0;
	public var visibleMeshes:Int = 0;
	public var culledMeshes:Int = 0;
	public var uploadedBytes:Int = 0;
	public var textureSlots:Int = 0;
	public var compositeDrawCalls:Int = 0;
	public var targetBytes:Int = 0;
	public var shadowDrawCalls:Int = 0;
	public var shadowTriangles:Int = 0;
	public var shadowUploadedBytes:Int = 0;
	public var shadowMapBytes:Int = 0;
	public var shadowMapSize:Int = 0;
	public var shadowStatus:String = "关闭";
	public var splitReasons:Map<String, Int> = [];
	public function new() {}
	public function reset():Void {
		drawCalls = triangles = visibleMeshes = culledMeshes = uploadedBytes = textureSlots = compositeDrawCalls = 0;
		shadowDrawCalls = shadowTriangles = shadowUploadedBytes = shadowMapBytes = shadowMapSize = 0; shadowStatus = "关闭";
		splitReasons.clear();
	}
	public function split(reason:String):Void {
		var count = splitReasons.get(reason);
		splitReasons.set(reason, count == null ? 1 : count + 1);
	}
}
