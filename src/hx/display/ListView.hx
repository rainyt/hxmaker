package hx.display;

/**
 * 数据列表渲染器
 */
class ListView extends Scroll implements IDataProider<ArrayCollection> {
	/**
	 * 数据列表
	 */
	public var data(get, set):ArrayCollection;

	/**
	 * Item渲染器
	 */
	public var itemRendererRecycler(default, set):DisplayObjectRecycler<Dynamic>;

	private function set_itemRendererRecycler(value:DisplayObjectRecycler<Dynamic>):DisplayObjectRecycler<Dynamic> {
		this.itemRendererRecycler = value;
		this.__dataDirty = true;
		return value;
	}

	private var __data:ArrayCollection;

	private var __dataDirty:Bool = false;

	public function set_data(value:ArrayCollection):ArrayCollection {
		this.__data = value;
		this.__dataDirty = true;
		return value;
	}

	public function get_data():ArrayCollection {
		return __data;
	}

	override function onInit() {
		super.onInit();
		this.itemRendererRecycler = DisplayObjectRecycler.withClass(DefaultItemRenderer);
		this.layout = new hx.layout.VerticalLayout();
	}

	override function onUpdate(dt:Float) {
		super.onUpdate(dt);
		if (this.__dataDirty) {
			// 删除所有容器
			var i = this.children.length;
			while (i-- > 0) {
				var child = this.children[i];
				child.parent.removeChild(child);
				itemRendererRecycler.release(child);
			}
			// 重新创建所有容器
			if (__data != null) {
				for (i in 0...__data.source.length) {
					var itemRenderer = itemRendererRecycler.create();
					if (itemRenderer is IDataProider) {
						var proider:IDataProider<Dynamic> = cast itemRenderer;
						proider.data = __data.source[i];
					}
					this.addChild(itemRenderer);
				}
			}
			this.__dataDirty = false;
		}
	}
}

/**
 * 默认的ItemRenderer渲染器
 */
class DefaultItemRenderer extends ItemRenderer {
	public var label:Label = new Label();

	override function setData(value:Dynamic) {
		super.setData(value);
		this.label.data = Std.string(value);
	}

	override function onInit() {
		super.onInit();
		this.label.data = "ItemRenderer";
		this.addChild(this.label);
	}
}
