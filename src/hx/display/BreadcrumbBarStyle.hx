package hx.display;

/** 面包屑外观。修改后重新赋值给 BreadcrumbBar.appearance，使布局与显示同步更新。 */
class BreadcrumbBarStyle {
	public var currentColor:Int = 0xffffff;
	public var disabledColor:Int = 0x777777;
	public var separatorColor:Int = 0x888888;
	public var hoverColor:Int = 0xffffff;
	public var hoverAlpha:Float = 0.10;
	public var padding:Float = 4;
	public var itemPadding:Float = 5;
	public var separatorWidth:Float = 12;
	public var ellipsisWidth:Float = 24;
	/** 当前项至少保留的空间；再窄时改为单个省略入口。 */
	public var minimumCurrentWidth:Float = 24;

	public function new() {}

	public function clone():BreadcrumbBarStyle {
		var result = new BreadcrumbBarStyle();
		result.currentColor = currentColor;
		result.disabledColor = disabledColor;
		result.separatorColor = separatorColor;
		result.hoverColor = hoverColor;
		result.hoverAlpha = hoverAlpha;
		result.padding = padding;
		result.itemPadding = itemPadding;
		result.separatorWidth = separatorWidth;
		result.ellipsisWidth = ellipsisWidth;
		result.minimumCurrentWidth = minimumCurrentWidth;
		return result;
	}
}
