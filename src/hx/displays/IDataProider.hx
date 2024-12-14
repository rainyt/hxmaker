package hx.displays;

interface IDataProider<T> {
	/**
	 * 数据源传递
	 */
	public var data(get, set):T;
}
