package hx.utils;

interface IStorage {
	/**
	 * 设置保存ID，建议针对不同的用户提供不同的saveId，避免数据冲突，如果不提供，默认为`default`
	 * @param saveId 保存ID
	 */
	function setSaveId(saveId:String):Void;

	/**
	 * 设置键值对
	 * @param key 键
	 * @param value 值
	 */
	function setKeyValue(key:String, value:Dynamic):Void;

	/**
	 * 获取键对应的值
	 * @param key 键
	 * @param defaultValue 默认值
	 * @return 值
	 */
	function getKeyValue(key:String, defaultValue:Dynamic):Dynamic;
}
