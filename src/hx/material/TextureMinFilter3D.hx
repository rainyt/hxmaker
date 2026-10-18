package hx.material;

/** 完整保留 glTF 的缩小过滤语义；mipmap 由渲染后端按图片条件生成。 */
enum abstract TextureMinFilter3D(Int) from Int to Int {
	var NEAREST = 9728;
	var LINEAR = 9729;
	var NEAREST_MIPMAP_NEAREST = 9984;
	var LINEAR_MIPMAP_NEAREST = 9985;
	var NEAREST_MIPMAP_LINEAR = 9986;
	var LINEAR_MIPMAP_LINEAR = 9987;

	public static function validate(value:Int):Void {
		if ([9728, 9729, 9984, 9985, 9986, 9987].indexOf(value) < 0)
			throw "纹理缩小过滤模式无效";
	}

	/** 旧接口未指定完整过滤时，沿用基础层平滑设置。 */
	public static function resolve(value:Null<Int>, smoothing:Bool):Int {
		return value == null ? (smoothing ? 9729 : 9728) : value;
	}

	/** 不支持 mipmap 的图片仍保留层内过滤方式。 */
	public static function base(value:Int):Int {
		return value == 9729 || value == 9985 || value == 9987 ? 9729 : 9728;
	}
}
