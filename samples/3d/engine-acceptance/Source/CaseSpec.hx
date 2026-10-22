package;

/** 固定负载配置；报告完整保存配置，避免不同条件的数据混比。 */
typedef CaseSpec = {
	var id:String;
	var label:String;
	var kind:String;
	var count:Int;
	var dense:Bool;
	var animated:Bool;
	var multi:Bool;
	var shadow:Bool;
	var shadowSize:Int;
	var cached:Bool;
	var nestedMask:Bool;
	var secondView:Bool;
	var textureSwap:Bool;
	var renderScale:Float;
}
