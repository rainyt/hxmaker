package;

class Cases {
	public static function make(id:String,label:String,kind:String,count:Int,dense:Bool = false,multi:Bool = true,shadow:Bool = false):CaseSpec {
		return {id:id,label:label,kind:kind,count:count,dense:dense,animated:kind == "actors",multi:multi,shadow:shadow,
			shadowSize:1024,cached:false,nestedMask:false,secondView:false,textureSwap:false,renderScale:1.};
	}
	public static function suite():Array<CaseSpec> {
		var result = [make("empty","空场景开销","empty",0),
			make("boxes-multi","256 方块 / 20 贴图 / 多纹理","boxes",256),
			make("boxes-single","256 方块 / 20 贴图 / 单纹理","boxes",256,false,false),
			make("actors-10","低模角色 ×10","actors",10),
			make("actors-30-multi","低模角色 ×30 / 多纹理","actors",30),
			make("actors-30-single","低模角色 ×30 / 单纹理","actors",30,false,false),
			make("dense-1","全双权重高密度角色 ×1","actors",1,true),
			make("dense-4","全双权重高密度角色 ×4","actors",4,true),
			make("dense-shadow-1024","高密度角色 ×4 / 阴影 1024","actors",4,true,true,true)];
		var small = make("dense-shadow-512","高密度角色 ×4 / 阴影 512","actors",4,true,true,true); small.shadowSize = 512; result.push(small);
		var staticActors = make("static-redraw","静止角色 ×30 / 每帧重绘","actors",30); staticActors.animated = false; result.push(staticActors);
		var cached = make("static-cached","静止角色 ×30 / 静态复用","actors",30); cached.animated = false; cached.cached = true; result.push(cached);
		var views = make("two-views","双 Scene3D / 角色合计 ×12","actors",10); views.secondView = true; result.push(views);
		var masks = make("nested-mask","嵌套二维遮罩 / 贴图切换","actors",10); masks.nestedMask = true; masks.textureSwap = true; result.push(masks);
		return result;
	}
}
