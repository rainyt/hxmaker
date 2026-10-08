package hx.display;

import hx.events.MouseEvent;

/**
 * 树形列表的ItemRenderer
 *
 * 内置展开箭头、图标与文本标签，行内容为`disclosureHit`（箭头点击区）→`disclosure`（箭头）→`icon`（图标）→`label`（标签）的扁平结构，
 * 选中与悬停高亮分别由`selectedBackground`、`hoverBackground`承载，均为直接子对象，层级扁平利于合批渲染。
 *
 * `TreeView`在绑定数据时会写入：`treeNodeName`（显示名称）、`treeNodeIcon`（图标）、`treeNodeDepth`（层级深度）、
 * `treeNodeHasChildren`（是否拥有子级）、`treeNodeExpanded`（是否展开）、`rowHeight`（行高）、`indentSize`（每层缩进）与配色属性，
 * 子类通常只需覆盖`setData()`补充自定义内容。
 */
@:keep
class TreeItemRenderer extends ItemRenderer {
	/**
	 * 悬停高亮背景，只在未选中且鼠标悬停时显示
	 */
	public var hoverBackground(default, null):Quad;

	/**
	 * 选中高亮背景
	 */
	public var selectedBackground(default, null):Quad;

	/**
	 * 展开箭头（矢量绘制的角括号），收起时指向右，展开时指向下，没有子级时隐藏
	 */
	public var disclosure(default, null):Graphics;

	/**
	 * 图标，`treeNodeIcon`为`null`时隐藏，子类可替换为自定义图标渲染
	 */
	public var icon(default, null):Image;

	/**
	 * 文本标签，超出可用宽度时自动截断并显示省略号
	 */
	public var label(default, null):Label;

	/**
	 * 选中高亮颜色
	 */
	public var selectionColor(default, set):Int = 0x04395e;

	/**
	 * 悬停高亮颜色
	 */
	public var hoverColor(default, set):Int = 0x2a2d2e;

	/**
	 * 箭头颜色
	 */
	public var disclosureColor(default, set):Int = 0xcccccc;

	/**
	 * 标签文字颜色
	 */
	public var textColor(default, set):Int = 0xd4d4d4;

	/**
	 * 行高，由`TreeView.rowHeight`同步
	 */
	public var rowHeight(default, set):Float = 22;

	/**
	 * 每一层级的缩进尺寸，由`TreeView.indentSize`同步
	 */
	public var indentSize(default, set):Float = 8;

	/**
	 * 节点的显示名称，由`TreeView`解析后写入
	 */
	public var treeNodeName(default, set):String;

	/**
	 * 节点的图标，由`TreeView`解析后写入，`null`表示不显示图标
	 */
	public var treeNodeIcon(default, set):BitmapData;

	/**
	 * 节点的层级深度，根节点为`0`
	 */
	public var treeNodeDepth(default, set):Int = 0;

	/**
	 * 节点是否拥有子级，决定箭头是否显示
	 */
	public var treeNodeHasChildren(default, set):Bool = false;

	/**
	 * 节点是否处于展开状态
	 */
	public var treeNodeExpanded(default, set):Bool = false;

	/**
	 * 箭头区域的宽度
	 */
	public static inline var DISCLOSURE_SIZE:Float = 16;

	/**
	 * 图标区域的宽度
	 */
	public static inline var ICON_SIZE:Float = 16;

	/**
	 * 图标与标签的间距
	 */
	public static inline var ICON_GAP:Float = 4;

	override function onInit() {
		super.onInit();
		this.hoverBackground = new Quad(0, 0, this.hoverColor);
		this.hoverBackground.visible = false;
		this.addChild(this.hoverBackground);
		this.selectedBackground = new Quad(0, 0, this.selectionColor);
		this.addChild(this.selectedBackground);
		this.selectedBackground.visible = false;

		this.disclosure = new Graphics();
		// 箭头只负责显示，点击命中交给整块区域的disclosureHit，避免线条过细难以点击
		this.disclosure.mouseEnabled = false;
		this.addChild(this.disclosure);

		this.icon = new Image();
		this.icon.visible = false;
		this.addChild(this.icon);

		this.label = new Label();
		this.label.color = this.textColor;
		this.label.fontSize = 13;
		this.label.verticalAlign = VerticalAlign.MIDDLE;
		this.addChild(this.label);

		this.height = this.rowHeight;
		this.addEventListener(MouseEvent.MOUSE_OVER, onMouseOver);
		this.addEventListener(MouseEvent.MOUSE_OUT, onMouseOut);
	}

	private var __hovered:Bool = false;

	private function onMouseOver(e:MouseEvent):Void {
		this.__hovered = true;
		this.__updateHoverBackground();
	}

	private function onMouseOut(e:MouseEvent):Void {
		this.__hovered = false;
		this.__updateHoverBackground();
	}

	private function __updateHoverBackground():Void {
		// 选中行不再叠加悬停高亮
		this.hoverBackground.visible = this.__hovered && !this.__selected;
	}

	override function setData(value:Dynamic) {
		super.setData(value);
		// 回收复用后可能残留悬停状态，重新绑定时重置
		this.__hovered = false;
		this.__updateHoverBackground();
		this.__invalidateLabel();
		this.__layoutRow();
	}

	/**
	 * 标签文本变化后重置截断缓存，从完整名称重新计算
	 */
	private function __invalidateLabel():Void {
		this.__labelFullText = null;
		this.__labelAvailWidth = -1;
	}

	override function setSelected(selected:Bool):Void {
		this.selectedBackground.visible = selected;
		this.__updateHoverBackground();
	}

	override function set_width(value:Float):Float {
		// 虚拟布局每次updateLayout都会以相同宽度回写，避免重复触发行内重排
		if (this.__width == value) {
			return value;
		}
		var result = super.set_width(value);
		this.__layoutRow();
		return result;
	}

	private function set_rowHeight(value:Float):Float {
		if (this.rowHeight == value) {
			return value;
		}
		this.rowHeight = value;
		this.height = value;
		this.__layoutRow();
		return value;
	}

	private function set_indentSize(value:Float):Float {
		if (this.indentSize == value) {
			return value;
		}
		this.indentSize = value;
		this.__layoutRow();
		return value;
	}

	private function set_selectionColor(value:Int):Int {
		if (this.selectionColor == value) {
			return value;
		}
		this.selectionColor = value;
		this.selectedBackground.data = value;
		return value;
	}

	private function set_hoverColor(value:Int):Int {
		if (this.hoverColor == value) {
			return value;
		}
		this.hoverColor = value;
		this.hoverBackground.data = value;
		return value;
	}

	private function set_disclosureColor(value:Int):Int {
		if (this.disclosureColor == value) {
			return value;
		}
		this.disclosureColor = value;
		this.__drawDisclosure();
		return value;
	}

	private function set_textColor(value:Int):Int {
		if (this.textColor == value) {
			return value;
		}
		this.textColor = value;
		this.label.color = value;
		return value;
	}

	private function set_treeNodeName(value:String):String {
		this.treeNodeName = value;
		return value;
	}

	private function set_treeNodeIcon(value:BitmapData):BitmapData {
		if (this.treeNodeIcon == value) {
			return value;
		}
		this.treeNodeIcon = value;
		this.icon.data = value;
		this.icon.visible = value != null;
		this.__layoutRow();
		return value;
	}

	private function set_treeNodeDepth(value:Int):Int {
		if (this.treeNodeDepth == value) {
			return value;
		}
		this.treeNodeDepth = value;
		this.__layoutRow();
		return value;
	}

	private function set_treeNodeHasChildren(value:Bool):Bool {
		if (this.treeNodeHasChildren == value) {
			return value;
		}
		this.treeNodeHasChildren = value;
		this.__layoutRow();
		return value;
	}

	private function set_treeNodeExpanded(value:Bool):Bool {
		if (this.treeNodeExpanded == value) {
			return value;
		}
		this.treeNodeExpanded = value;
		this.__drawDisclosure();
		return value;
	}

	/**
	 * 判断舞台坐标是否命中展开箭头区域（行内缩进位置起`DISCLOSURE_SIZE`宽、整行高）
	 *
	 * 行渲染器没有缩放与旋转，直接用世界矩阵的平移量换算行内坐标即可
	 */
	public function hitDisclosure(stageX:Float, stageY:Float):Bool {
		if (!this.treeNodeHasChildren) {
			return false;
		}
		var world = this.__worldTransform;
		var localX = stageX - world.tx;
		var localY = stageY - world.ty;
		var start = this.treeNodeDepth * this.indentSize;
		return localX >= start && localX <= start + DISCLOSURE_SIZE && localY >= 0 && localY <= this.rowHeight;
	}

	/**
	 * 排列行内容，标签可用宽度在箭头与图标之后，剩余宽度截断显示
	 */
	private function __layoutRow():Void {
		var x = this.treeNodeDepth * this.indentSize;
		this.disclosure.x = x;
		this.disclosure.y = (this.rowHeight - DISCLOSURE_SIZE) / 2;
		x += DISCLOSURE_SIZE + 2;

		if (this.icon.visible) {
			this.icon.x = x + (ICON_SIZE - this.icon.width) / 2;
			this.icon.y = (this.rowHeight - this.icon.height) / 2;
			x += ICON_SIZE + ICON_GAP;
		}

		this.label.x = x;
		this.label.y = 0;
		this.label.height = this.rowHeight;
		this.label.width = Math.max(0, this.width - x);

		this.hoverBackground.width = this.width;
		this.hoverBackground.height = this.rowHeight;
		this.selectedBackground.width = this.width;
		this.selectedBackground.height = this.rowHeight;

		this.__updateLabelTruncate();
		this.__drawDisclosure();
	}

	/**
	 * 标签超出可用宽度时截断文本并追加省略号，始终以`treeNodeName`为完整文本重新计算，避免复用后二次截断
	 */
	private var __labelFullText:String = null;

	private var __labelAvailWidth:Float = -1;

	private function __updateLabelTruncate():Void {
		var full = this.treeNodeName != null ? this.treeNodeName : "";
		var availWidth = this.label.width;
		if (full == this.__labelFullText && availWidth == this.__labelAvailWidth) {
			return;
		}
		this.__labelFullText = full;
		this.__labelAvailWidth = availWidth;
		if (full == "" || availWidth <= 0) {
			this.label.data = full;
			return;
		}
		this.label.data = full;
		// 文本宽度依赖渲染上下文，不在舞台时root为空、测量结果为0，此时不截断
		if (this.label.root == null) {
			return;
		}
		if (this.label.getTextWidth() <= availWidth) {
			return;
		}
		var length = full.length;
		while (length > 1) {
			length--;
			var truncated = full.substr(0, length) + "…";
			this.label.data = truncated;
			if (this.label.getTextWidth() <= availWidth) {
				return;
			}
		}
		this.label.data = "…";
	}

	/**
	 * 绘制展开箭头，收起时指向右，展开时指向下
	 */
	private function __drawDisclosure():Void {
		var g = this.disclosure;
		if (g == null) {
			return;
		}
		g.clear();
		if (!this.treeNodeHasChildren) {
			return;
		}
		g.beginLineStyle(this.disclosureColor, 1.5);
		var cx = DISCLOSURE_SIZE / 2;
		var cy = (this.rowHeight - DISCLOSURE_SIZE) / 2 + DISCLOSURE_SIZE / 2;
		if (this.treeNodeExpanded) {
			g.moveTo(cx - 4, cy - 2);
			g.lineTo(cx, cy + 3);
			g.lineTo(cx + 4, cy - 2);
		} else {
			g.moveTo(cx - 2, cy - 4);
			g.lineTo(cx + 3, cy);
			g.lineTo(cx - 2, cy + 4);
		}
	}
}
