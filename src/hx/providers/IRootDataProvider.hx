package hx.providers;

interface IRootDataProvider<T> {
	/**
	 * 根渲染显示对象，不同的引擎中对应的显示对象
	 */
	public var root(get, set):T;
}
