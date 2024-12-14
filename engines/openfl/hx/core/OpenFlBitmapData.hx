package hx.core;

import openfl.display.BitmapData;
import hx.displays.IBitmapData;

/**
 * OpenFL纹理
 */
class OpenFlBitmapData implements IBitmapData {
	private var __root:BitmapData;

	public function new(root:BitmapData) {
		this.__root = root;
	}

	public function getTexture():Dynamic {
		return __root;
	}
}