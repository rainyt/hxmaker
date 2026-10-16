package;

import hx.utils.ContextStats;

/** 在下一次 UPDATE 读取上一轮已完成的 GPU 回调，与上一轮动画更新时间配对。 */
class FrameSampler {
	public var issue(default,null):String;
	public var lastFreshAt(default,null):Float;
	private var world:AcceptanceWorld;
	private var lastIds:Array<Int>;
	private var lastAt:Float;
	private var sizes:String;
	public function new(world:AcceptanceWorld) {
		this.world = world; lastIds = [for (scene in world.scenes) scene.stats.renderId];
		lastAt = lastFreshAt = MetricClock.now();
	}
	public function targets():Array<Dynamic> {
		return [for (scene in world.scenes) {width:scene.stats.targetWidth,height:scene.stats.targetHeight,
			shadowSize:scene.stats.shadowMapSize,shadowStatus:scene.stats.shadowStatus}];
	}
	public function read(now:Float):Dynamic {
		issue = null;
		for (i in 0...world.scenes.length) {
			var stats = world.scenes[i].stats;
			if (!stats.profileReady || stats.renderId == lastIds[i]) return null;
		}
		var key = [for (scene in world.scenes) scene.stats.targetWidth+"x"+scene.stats.targetHeight].join(":");
		if (sizes != null && key != sizes) issue = "实际离屏尺寸变化";
		sizes = key;
		var row:Dynamic = {frameIntervalMs:now-lastAt,animationCpuMs:world.lastAnimationMs,
			renderCpuMs:0.,shadowCpuMs:0.,mainCpuMs:0.,compositeCpuMs:0.,stateCpuMs:0.,
			mainDrawCalls:0,shadowDrawCalls:0,compositeDrawCalls:0,mainTriangles:0,shadowTriangles:0,
			mainUploadedBytes:0,shadowUploadedBytes:0,textureSlots:0,targetBytes:0,shadowMapBytes:0,visibleMeshes:0,culledMeshes:0,
			redrawnScenes:0,cacheReferences:ContextStats.totalRefCount,cacheEntries:ContextStats.totalCacheCount,jsHeapBytes:RuntimeInfo.heap()};
		for (i in 0...world.scenes.length) {
			var stats = world.scenes[i].stats;
			if (stats.renderId-lastIds[i] != 1) issue = "一次 UPDATE 间出现多个三维回调，当前配对方式不适用";
			lastIds[i] = stats.renderId;
			row.renderCpuMs += stats.renderCpuMs; row.shadowCpuMs += stats.shadowCpuMs; row.mainCpuMs += stats.mainCpuMs;
			row.compositeCpuMs += stats.compositeCpuMs; row.stateCpuMs += stats.stateCpuMs;
			row.compositeDrawCalls += stats.compositeDrawCalls; row.targetBytes += stats.targetBytes; row.shadowMapBytes += stats.shadowMapBytes;
			row.visibleMeshes += stats.visibleMeshes; row.culledMeshes += stats.culledMeshes;
			if (stats.redrawThisFrame) {
				row.redrawnScenes++; row.mainDrawCalls += stats.drawCalls; row.shadowDrawCalls += stats.shadowDrawCalls;
				row.mainTriangles += stats.triangles; row.shadowTriangles += stats.shadowTriangles;
				row.mainUploadedBytes += stats.uploadedBytes; row.shadowUploadedBytes += stats.shadowUploadedBytes;
				row.textureSlots = Std.int(Math.max(row.textureSlots,stats.textureSlots));
			}
		}
		row.animationAndRenderCpuMs = row.animationCpuMs+row.renderCpuMs;
		lastAt = lastFreshAt = now;
		return issue == null ? row : null;
	}
}
