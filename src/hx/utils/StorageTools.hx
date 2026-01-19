package hx.utils;

/**
 * 本地存储工具类
 */
class StorageTools {
	/**
	 * 单例实例
	 */
	private static var __instance:StorageTools = null;

	/**
	 * 获取单例实例
	 */
	public static function getInstance():StorageTools {
		if (__instance == null) {
			__instance = new StorageTools();
		}
		return __instance;
	}

	public function new() {}

	private var __saveId:String = "default";

	private var __storage:Storage = new Storage();

	/**
	 * 设置保存ID，建议针对不同的用户提供不同的saveId，避免数据冲突，如果不提供，默认为`default`
	 * @param saveId 保存ID
	 */
	public function setSaveId(saveId:String):Void {
		this.__saveId = saveId;
		__storage.setSaveId(saveId);
	}

	/**
	 * 设置键值对
	 * @param key 键
	 * @param value 值
	 */
	public function setKeyValue(key:String, value:Dynamic):Void {
		__storage.setKeyValue(key, value);
	}

	/**
	 * 获取键对应的值
	 * @param key 键
	 * @param defaultValue 默认值
	 * @return 值
	 */
	public function getKeyValue(key:String, ?defaultValue:Dynamic):Dynamic {
		return __storage.getKeyValue(key, defaultValue);
	}
}
