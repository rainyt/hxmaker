package hx.display;

import hx.events.Event;
import hx.events.MouseEvent;
import hx.geom.Point;
import hx.geom.Rectangle;

/**
 * 单行面包屑导航。最后一项为当前位置，NAVIGATE 只表达请求，不修改路径。
 * 字体、颜色与间距设置后自动重新布局；业务数据始终由调用方持有。
 */
@:keep
class BreadcrumbBar extends Box {
	public static inline var NAVIGATE:String = "breadcrumbNavigate";
	public var items(get, set):Array<BreadcrumbItem>;
	public var emptyText(get, set):String;
	public var disabled(get, set):Bool;
	public var textFormat(get, set):TextFormat;
	/** 外观按值复制，修改返回值后需要重新赋值。 */
	public var appearance(get, set):BreadcrumbBarStyle;

	private var __items:Array<BreadcrumbItem> = [];
	private var __emptyText:String = "";
	private var __disabled:Bool = false;
	private var __format:TextFormat = new TextFormat(null, 14, 0xcccccc);
	private var __appearance:BreadcrumbBarStyle = new BreadcrumbBarStyle();
	private var __entries:Array<BreadcrumbEntry> = [];
	private var __separators:Array<Graphics> = [];
	private var __ellipsis:BreadcrumbEntry;
	private var __placeholder:BreadcrumbLabel;
	private var __placeholderMeasure:BreadcrumbLabel;
	private var __placeholderWidth:Float = -1;
	private var __measure:BreadcrumbLabel;
	private var __hidden:Array<Int> = [];
	private var __menu:ContextMenu;
	private var __tooltip:Box;
	private var __tooltipLabel:BreadcrumbLabel;
	private var __tooltipHost:Stage;
	private var __hover:BreadcrumbEntry;
	private var __host:Stage;
	private var __generation:Int = 0;
	private var __needsLayout:Bool = true;
	private var __layingOut:Bool = false;

	public function new() {
		super();
		width = 240;
		height = 24;
		maskRect = new Rectangle();
		mouseClickEnabled = true;
		updateEnabled = true;
		__placeholder = new BreadcrumbLabel();
		__placeholder.mouseEnabled = false;
		addChild(__placeholder);
		__placeholderMeasure = new BreadcrumbLabel();
		__placeholderMeasure.hide = true;
		addChild(__placeholderMeasure);
		__measure = new BreadcrumbLabel();
		__measure.hide = true;
		addChild(__measure);
		__ellipsis = new BreadcrumbEntry("…");
		__ellipsis.activate = () -> openMenu();
		__ellipsis.over = () -> onEntryOver(__ellipsis);
		__ellipsis.out = () -> onEntryOut(__ellipsis);
		addChild(__ellipsis);
		// 消费内部点击，避免业务父容器把同一次点击再次解释为导航。
		addEventListener(MouseEvent.CLICK, consumeClick);
	}

	private function consumeClick(event:MouseEvent):Void {
		event.bubbling = false;
		event.preventDefault();
	}
	private function get_items():Array<BreadcrumbItem> return [for (item in __items) {label: item.label, data: item.data}];
	private function set_items(value:Array<BreadcrumbItem>):Array<BreadcrumbItem> {
		if (isDisposed)
			return value;
		++__generation;
		invalidateContent();
		for (entry in __entries) {
			removeChild(entry);
			entry.dispose();
		}
		__entries = [];
		__items = value == null ? [] : [for (item in value) {
			label: item == null || item.label == null ? "" : item.label,
			data: item == null ? null : item.data
		}];
		var generation = __generation;
		for (index in 0...__items.length) {
			var entry = new BreadcrumbEntry(singleLine(__items[index].label));
			var itemIndex = index;
			entry.activate = () -> {
				if (generation == __generation && !entry.hide)
					navigate(itemIndex, generation);
			};
			entry.over = () -> onEntryOver(entry);
			entry.out = () -> onEntryOut(entry);
			__entries.push(entry);
			addChild(entry);
		}
		while (__separators.length < __items.length) {
			var separator = new Graphics();
			separator.mouseEnabled = false;
			separator.includeInLayout = false;
			__separators.push(separator);
			addChild(separator);
		}
		while (__separators.length > __items.length) {
			var separator = __separators.pop();
			removeChild(separator);
			separator.dispose();
		}
		applyStyle();
		return value;
	}

	private function get_emptyText():String return __emptyText;
	private function set_emptyText(value:String):String {
		__emptyText = value == null ? "" : value;
		if (__placeholderMeasure != null)
			__placeholderMeasure.data = singleLine(__emptyText);
		invalidateContent();
		return __emptyText;
	}
	private function get_disabled():Bool return __disabled;
	private function set_disabled(value:Bool):Bool {
		if (__disabled != value) {
			__disabled = value;
			invalidateContent();
			applyStyle();
		}
		return value;
	}
	private function get_textFormat():TextFormat return __format.clone();
	private function set_textFormat(value:TextFormat):TextFormat {
		__format = value == null ? new TextFormat(null, 14, 0xcccccc) : value.clone();
		if (__format.size <= 0)
			__format.size = 14;
		invalidateContent();
		applyStyle();
		return value;
	}
	private function get_appearance():BreadcrumbBarStyle return __appearance.clone();
	private function set_appearance(value:BreadcrumbBarStyle):BreadcrumbBarStyle {
		__appearance = value == null ? new BreadcrumbBarStyle() : value.clone();
		__appearance.padding = finiteSize(__appearance.padding);
		__appearance.itemPadding = finiteSize(__appearance.itemPadding);
		__appearance.separatorWidth = finiteSize(__appearance.separatorWidth);
		__appearance.ellipsisWidth = Math.max(1, finiteSize(__appearance.ellipsisWidth));
		__appearance.minimumCurrentWidth = Math.max(1, finiteSize(__appearance.minimumCurrentWidth));
		__appearance.hoverAlpha = Math.min(1, finiteSize(__appearance.hoverAlpha));
		invalidateContent();
		applyStyle();
		return value;
	}

	private static function finiteSize(value:Float):Float return Math.isFinite(value) ? Math.max(0, value) : 0;
	private static function singleLine(value:String):String {
		return StringTools.replace(StringTools.replace(value, "\r", " "), "\n", " ");
	}

	private function applyStyle():Void {
		if (__placeholder == null || isDisposed)
			return;
		var format = __format.clone();
		format.color = __disabled ? __appearance.disabledColor : __format.color;
		__placeholder.textFormat = format;
		__placeholderMeasure.textFormat = __format;
		__measure.textFormat = __format;
		__ellipsis.applyStyle(format, __appearance, !__disabled);
		for (index in 0...__entries.length) {
			var current = index == __entries.length - 1;
			var entryFormat = __format.clone();
			entryFormat.color = __disabled ? __appearance.disabledColor : (current ? __appearance.currentColor : __format.color);
			__entries[index].applyStyle(entryFormat, __appearance, !__disabled && !current);
		}
	}

	/** 立即清理旧交互，实际文字测量延迟到组件在舞台上时执行。 */
	private function invalidateContent():Void {
		closeMenu();
		clearHover();
		__needsLayout = true;
		__layoutDirty = true;
		invalidate();
	}

	/** 外部字体资源就绪后可主动刷新；普通数据、尺寸和样式赋值无需调用。 */
	public function refresh():Void {
		if (isDisposed)
			return;
		invalidateContent();
		applyStyle();
	}

	override function set_width(value:Float):Float {
		value = finiteSize(value);
		if (__width != value)
			invalidateContent();
		return super.set_width(value);
	}
	override function set_height(value:Float):Float {
		value = finiteSize(value);
		if (__height != value)
			invalidateContent();
		return super.set_height(value);
	}

	override public function onAddToStage():Void {
		super.onAddToStage();
		__host = stage;
		invalidateContent();
		applyStyle();
	}
	override public function onRemoveToStage():Void {
		__host = null;
		invalidateContent();
		super.onRemoveToStage();
	}

	override public function onUpdate(dt:Float):Void {
		super.onUpdate(dt);
		if (isDisposed || __host == null)
			return;
		// 测量对象保留在舞台队列中；字形图集就绪或重建后能察觉实际宽度变化。
		var changed = false;
		for (entry in __entries)
			if (entry.refreshMeasurement())
				changed = true;
		if (__entries.length == 0 && __placeholderMeasure.getTextWidth() != __placeholderWidth)
			changed = true;
		if (changed)
			invalidateContent();
		if (__needsLayout)
			updateLayout();
	}

	override public function updateLayout():Void {
		if (isDisposed || __layingOut)
			return;
		maskRect.setTo(0, 0, finiteSize(__width), finiteSize(__height));
		if (!__needsLayout || __host == null)
			return;
		__layingOut = true;
		try {
			layoutEntries();
		} catch (error:Dynamic) {
			__layingOut = false;
			throw error;
		}
		__needsLayout = false;
		__layoutDirty = false;
		__layingOut = false;
	}

	private function layoutEntries():Void {
		for (entry in __entries) {
			entry.hide = true;
			entry.refreshMeasurement();
		}
		for (separator in __separators)
			separator.hide = true;
		__ellipsis.hide = true;
		__hidden = [];
		// 宽度不足以容纳入口时让出外边距，剩余部分由组件边界裁剪。
		var padding = __width < __appearance.ellipsisWidth + 2 * __appearance.padding ? 0 : __appearance.padding;
		var available = Math.max(0, __width - 2 * padding);
		var barHeight:Float = __height;
		var count = __entries.length;
		__placeholder.hide = count != 0;
		if (count == 0) {
			__placeholderWidth = __placeholderMeasure.getTextWidth();
			__placeholder.x = padding;
			__placeholder.width = available;
			__placeholder.height = barHeight;
			__placeholder.verticalAlign = MIDDLE;
			__placeholder.data = fitText(singleLine(__emptyText), available);
			return;
		}
		var widths = [for (entry in __entries) entry.measuredWidth + 2 * __appearance.itemPadding];
		var gap = __appearance.separatorWidth;
		var total:Float = gap * (count - 1);
		for (value in widths)
			total += value;
		var visible:Array<Int> = [];
		var currentWidth = widths[count - 1];
		if (total <= available) {
			visible = [for (index in 0...count) index];
		} else if (count == 1 && available >= Math.min(currentWidth, __appearance.minimumCurrentWidth)) {
			visible = [0];
			currentWidth = available;
		} else {
			var minimum = Math.min(currentWidth, __appearance.minimumCurrentWidth);
			var ellipsisWidth = __appearance.ellipsisWidth;
			if (count == 1 || available < ellipsisWidth + gap + minimum) {
				visible = [-1];
				__hidden = [for (index in 0...count) index];
			} else {
				var keepRoot = count > 2 && widths[0] + ellipsisWidth + 2 * gap + minimum <= available;
				var firstHidden = keepRoot ? 1 : 0;
				var suffix = count - 1;
				var used = ellipsisWidth + gap + (keepRoot ? widths[0] + gap : 0);
				currentWidth = Math.min(currentWidth, available - used);
				used += currentWidth;
				// 连续保留最靠近当前位置的祖先，剩余部分仍是单一连续区间。
				while (suffix > firstHidden + 1 && used + gap + widths[suffix - 1] <= available) {
					--suffix;
					used += gap + widths[suffix];
				}
				if (keepRoot)
					visible.push(0);
				visible.push(-1);
				for (index in firstHidden...suffix)
					__hidden.push(index);
				for (index in suffix...count)
					visible.push(index);
			}
		}
		var x = padding;
		for (position in 0...visible.length) {
			if (position > 0) {
				var separator = __separators[position - 1];
				separator.hide = false;
				separator.x = x;
				separator.clear();
				var size = Math.min(3, Math.min(gap / 4, barHeight / 4));
				if (size > 0) {
					separator.beginLineStyle(__disabled ? __appearance.disabledColor : __appearance.separatorColor, 1);
					separator.moveTo(gap / 2 - size / 2, barHeight / 2 - size);
					separator.lineTo(gap / 2 + size / 2, barHeight / 2);
					separator.lineTo(gap / 2 - size / 2, barHeight / 2 + size);
				}
				x += gap;
			}
			var index = visible[position];
			var entry = index < 0 ? __ellipsis : __entries[index];
			var entryWidth = index < 0 ? __appearance.ellipsisWidth : (index == count - 1 ? currentWidth : widths[index]);
			entryWidth = Math.max(0, Math.min(entryWidth, __width - padding - x));
			entry.hide = false;
			entry.x = x;
			entry.width = entryWidth;
			entry.height = barHeight;
			var itemPadding = index < 0 ? Math.min(__appearance.itemPadding, entryWidth / 4) : __appearance.itemPadding;
			var textWidth = Math.max(0, entryWidth - 2 * itemPadding);
			var text = index < 0 ? "…" : (entry.measuredWidth <= textWidth ? entry.fullText : fitText(entry.fullText, textWidth));
			entry.arrange(text, itemPadding);
			x += entryWidth;
		}
	}

	/** 使用真实文字测量进行二分截断，保留 Unicode 码点边界。 */
	private function fitText(text:String, available:Float):String {
		if (available <= 0 || text.length == 0)
			return "";
		__measure.data = text;
		if (__measure.getTextWidth() <= available)
			return text;
		__measure.data = "…";
		if (__measure.getTextWidth() > available)
			return "";
		var chars = new haxe.iterators.StringIteratorUnicode(text);
		var points:Array<Int> = [];
		while (chars.hasNext())
			points.push(chars.next());
		var low = 0;
		var high = points.length;
		var prefix = (length:Int) -> {
			var buffer = new StringBuf();
			for (index in 0...length) {
				var point = points[index];
				#if utf16
				if (point > 0xffff) {
					buffer.addChar(0xd800 + ((point - 0x10000) >> 10));
					buffer.addChar(0xdc00 + ((point - 0x10000) & 0x3ff));
				} else
				#end
				buffer.addChar(point);
			}
			return buffer.toString();
		};
		while (low < high) {
			var middle = Std.int((low + high + 1) / 2);
			__measure.data = prefix(middle) + "…";
			if (__measure.getTextWidth() <= available)
				low = middle;
			else
				high = middle - 1;
		}
		return prefix(low) + "…";
	}

	private function navigate(index:Int, generation:Int):Void {
		if (isDisposed || __disabled || __host == null || generation != __generation || index < 0 || index >= __items.length - 1)
			return;
		var item = __items[index];
		var data:BreadcrumbNavigateEventData = {index: index, item: {label: item.label, data: item.data}};
		closeMenu();
		clearHover();
		if (isDisposed || __disabled || __host == null || generation != __generation)
			return;
		// 分发后不再访问内部显示项，允许业务回调立刻替换数据或销毁组件。
		dispatchEvent(new Event(NAVIGATE, false, false, data));
	}

	private function openMenu():Void {
		if (isDisposed || __disabled || __host == null)
			return;
		if (__menu != null) {
			closeMenu();
			return;
		}
		updateLayout();
		if (__hidden.length == 0)
			return;
		clearHover();
		var menu = new ContextMenu();
		__menu = menu;
		var generation = __generation;
		var prefix:Array<String> = [];
		for (index in 0...__items.length) {
			prefix.push(singleLine(__items[index].label));
			if (__hidden.indexOf(index) < 0)
				continue;
			var itemIndex = index;
			var text = (index + 1) + ". " + prefix.join(" / ");
			if (index == __items.length - 1)
				text += "（当前位置）";
			var row = new BreadcrumbMenuItem(text, _ -> {
				if (__menu == menu && menu.isOpen && generation == __generation)
					navigate(itemIndex, generation);
			});
			row.label.textFormat = __format;
			row.width = Math.max(180, row.label.getTextWidth() + 16);
			row.height = Math.max(28, __format.size + 12);
			row.enabled = index < __items.length - 1;
			menu.addItem(row);
		}
		menu.addEventListener(ContextMenu.CLOSED, _ -> {
			if (__menu == menu) {
				__menu = null;
				menu.dispose();
			}
		});
		var point = __host.globalToLocal(__ellipsis.localToGlobal(new Point(0, __height)));
		menu.show(this, point.x, point.y, __ellipsis);
		if (__menu == menu && !menu.isOpen)
			closeMenu();
	}

	private function closeMenu():Void {
		var menu = __menu;
		__menu = null;
		if (menu != null)
			menu.dispose();
	}

	private function onEntryOver(entry:BreadcrumbEntry):Void {
		if (isDisposed || __disabled || __host == null || entry.hide)
			return;
		clearHover();
		__hover = entry;
		entry.setHover(true);
		if (entry != __ellipsis && entry.truncated && __menu == null) {
			var index = __entries.indexOf(entry);
			if (index >= 0)
				showTooltip(__items[index].label, entry);
		}
	}
	private function onEntryOut(entry:BreadcrumbEntry):Void {
		entry.setHover(false);
		if (__hover == entry)
			clearHover();
	}
	private function clearHover():Void {
		if (__hover != null)
			__hover.setHover(false);
		__hover = null;
		closeTooltip();
	}

	private function showTooltip(text:String, entry:BreadcrumbEntry):Void {
		if (__host.stageWidth <= 0 || __host.stageHeight <= 0)
			return;
		__tooltip = new Box();
		__tooltip.mouseEnabled = false;
		__tooltip.mouseChildren = false;
		__tooltip.includeInLayout = false;
		__tooltipLabel = new BreadcrumbLabel(text, __format);
		__tooltipLabel.color = 0xffffff;
		__tooltipLabel.wordWrap = true;
		__tooltipLabel.x = __tooltipLabel.y = 4;
		__tooltip.width = Math.min(__host.stageWidth, __tooltipLabel.getTextWidth() + 8);
		__tooltipLabel.width = Math.max(0, __tooltip.width - 8);
		__tooltip.height = Math.min(__host.stageHeight, __tooltipLabel.getTextHeight() + 8);
		__tooltip.background = new Quad(__tooltip.width, __tooltip.height, 0x333333);
		__tooltip.maskRect = new Rectangle(0, 0, __tooltip.width, __tooltip.height);
		__tooltip.addChild(__tooltipLabel);
		var point = __host.globalToLocal(entry.localToGlobal(new Point(0, __height)));
		__tooltip.x = Math.max(0, Math.min(point.x, __host.stageWidth - __tooltip.width));
		__tooltip.y = Math.max(0, Math.min(point.y + 2, __host.stageHeight - __tooltip.height));
		__host.addChild(__tooltip);
		__tooltipHost = __host;
		__host.addEventListener(Event.RESIZE, onTooltipClose);
		__host.addEventListener(Event.DEACTIVATE, onTooltipClose);
	}
	private function onTooltipClose(event:Event):Void closeTooltip();
	private function closeTooltip():Void {
		if (__tooltip == null)
			return;
		var tooltip = __tooltip;
		__tooltip = null;
		if (__tooltipHost != null) {
			__tooltipHost.removeEventListener(Event.RESIZE, onTooltipClose);
			__tooltipHost.removeEventListener(Event.DEACTIVATE, onTooltipClose);
		}
		__tooltipHost = null;
		if (tooltip.parent != null)
			tooltip.parent.removeChild(tooltip);
		if (tooltip.background != null)
			tooltip.background.dispose();
		tooltip.dispose();
		__tooltipLabel = null;
	}

	override public function dispose():Void {
		if (isDisposed)
			return;
		isDisposed = true;
		++__generation;
		closeMenu();
		clearHover();
		__host = null;
		__items = [];
		super.dispose();
		removeChildren();
		__entries = [];
		__separators = [];
		__hidden = [];
	}
}

/** 组件独占的文字对象，销毁时同时释放测量缓存与舞台队列引用。 */
private class BreadcrumbLabel extends Label {
	public function new(text:String = "", ?format:TextFormat) {
		super(text, format);
		wordWrap = false;
		includeInLayout = false;
	}
	override public function dispose():Void {
		if (isDisposed)
			return;
		onRemoveToStage();
		if (root != null) {
			root.release();
			root = null;
		}
		super.dispose();
	}
}

/** 每个条目独立命中，测量文字保留完整内容，显示文字允许截断。 */
private class BreadcrumbEntry extends Box {
	public var fullText(default, null):String;
	public var measuredWidth(default, null):Float = -1;
	public var truncated(default, null):Bool = false;
	public var activate:Void->Void;
	public var over:Void->Void;
	public var out:Void->Void;
	private var __label:BreadcrumbLabel;
	private var __measurement:BreadcrumbLabel;
	private var __highlight:Quad;
	private var __interactive:Bool = false;

	public function new(text:String) {
		super();
		fullText = text;
		mouseClickEnabled = true;
		mouseChildren = false;
		includeInLayout = false;
		__highlight = new Quad();
		__highlight.mouseEnabled = false;
		__highlight.hide = true;
		addChild(__highlight);
		__label = new BreadcrumbLabel(text);
		__label.mouseEnabled = false;
		__label.verticalAlign = MIDDLE;
		addChild(__label);
		__measurement = new BreadcrumbLabel(text);
		__measurement.hide = true;
		addChild(__measurement);
		addEventListener(MouseEvent.CLICK, onClick);
		addEventListener(MouseEvent.MOUSE_OVER, onOver);
		addEventListener(MouseEvent.MOUSE_OUT, onOut);
	}
	public function applyStyle(format:TextFormat, style:BreadcrumbBarStyle, interactive:Bool):Void {
		__label.textFormat = format;
		__measurement.textFormat = format;
		__highlight.data = style.hoverColor;
		__highlight.alpha = style.hoverAlpha;
		__interactive = interactive;
		setHover(false);
	}
	public function refreshMeasurement():Bool {
		var measured = __measurement.getTextWidth();
		if (measured == measuredWidth)
			return false;
		measuredWidth = measured;
		return true;
	}
	public function arrange(text:String, padding:Float):Void {
		truncated = text != fullText;
		__label.data = text;
		__label.x = Math.min(padding, width);
		__label.width = Math.max(0, width - 2 * padding);
		__label.height = height;
		__highlight.width = width;
		__highlight.height = height;
	}
	public function setHover(value:Bool):Void __highlight.hide = !value || !__interactive;
	private function onClick(event:MouseEvent):Void {
		event.bubbling = false;
		event.preventDefault();
		if (!isDisposed && activate != null)
			activate();
	}
	private function onOver(event:MouseEvent):Void {
		if (!isDisposed && over != null)
			over();
	}
	private function onOut(event:MouseEvent):Void {
		if (out != null)
			out();
	}
	override public function dispose():Void {
		activate = over = out = null;
		super.dispose();
	}
}

/** 临时菜单项的文字缓存同样由面包屑管理。 */
private class BreadcrumbMenuItem extends ContextMenuItem {
	public function new(text:String, callback:ContextMenuContext->Void) {
		super(text, callback);
		label.wordWrap = false;
	}
	override function onClick(event:MouseEvent):Void {
		event.bubbling = false;
		event.preventDefault();
		super.onClick(event);
	}
	override public function dispose():Void {
		if (isDisposed)
			return;
		label.onRemoveToStage();
		if (label.root != null) {
			label.root.release();
			label.root = null;
		}
		super.dispose();
	}
}
