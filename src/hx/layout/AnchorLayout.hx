package hx.layout;

import hx.display.DisplayObject;

/**
 * 
 */
class AnchorLayout extends Layout {
	override function update(children:Array<DisplayObject>) {
		super.update(children);
		if (children.length == 0)
			return;
		var parent = children[0].parent;
		// 父节点的宽度
		var parentWidth = parent.width;
		// 父节点的高度
		var parentHeight = parent.height;
		for (object in children) {
			if (object.layoutData != null && object.layoutData is AnchorLayoutData) {
				var layoutData:AnchorLayoutData = cast object.layoutData;

				// 百分比宽高兼容
				if (layoutData.percentWidth != null) {
					object.width = parentWidth * layoutData.percentWidth / 100;
				}
				if (layoutData.percentHeight != null) {
					object.height = parentHeight * layoutData.percentHeight / 100;
				}

				if (layoutData.left != null && layoutData.right != null) {
					// 左右拉伸
					object.x = layoutData.left;
					object.width = parentWidth - layoutData.left - layoutData.right;
				} else if (layoutData.left != null && layoutData.horizontalCenter != null) {
					// 左中拉伸
					object.x = layoutData.left;
					object.width = parentWidth / 2 + layoutData.horizontalCenter - layoutData.left;
				} else if (layoutData.right != null && layoutData.horizontalCenter != null) {
					// 右中拉伸
					object.x = parentWidth / 2 + layoutData.horizontalCenter;
					object.width = parentWidth / 2 - layoutData.horizontalCenter - layoutData.right;
				} else if (layoutData.left != null) {
					// 左位移
					object.x = layoutData.left;
				} else if (layoutData.right != null) {
					// 右位移
					object.x = parentWidth - object.width - layoutData.right;
				} else if (layoutData.horizontalCenter != null) {
					object.x = parentWidth / 2 - object.width / 2 + layoutData.horizontalCenter;
				}

				// 上下的逻辑处理
				if (layoutData.top != null && layoutData.bottom != null) {
					// 上下拉伸
					object.y = layoutData.top;
					object.height = parentHeight - layoutData.top - layoutData.bottom;
				} else if (layoutData.top != null && layoutData.verticalCenter != null) {
					// 上中拉伸
					object.y = layoutData.top;
					object.height = parentHeight / 2 + layoutData.verticalCenter - layoutData.top;
				} else if (layoutData.bottom != null && layoutData.verticalCenter != null) {
					// 下中拉伸
					object.y = parentHeight / 2 + layoutData.verticalCenter;
					object.height = parentHeight / 2 - layoutData.verticalCenter - layoutData.bottom;
				} else if (layoutData.top != null) {
					// 上位移
					object.y = layoutData.top;
				} else if (layoutData.bottom != null) {
					if (object.name == "hbox") {
						trace(parentHeight, object.height, layoutData.bottom);
					}
					object.y = parentHeight - object.height - layoutData.bottom;
				} else if (layoutData.verticalCenter != null) {
					object.y = parentHeight / 2 - object.height / 2 + layoutData.verticalCenter;
				}
			}
		}
	}
}
