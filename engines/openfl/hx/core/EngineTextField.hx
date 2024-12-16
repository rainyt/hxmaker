package hx.core;

import hx.providers.ITextFieldDataProvider;
import openfl.text.TextField;

class EngineTextField extends TextField implements ITextFieldDataProvider {
	public function getTextWidth():Float {
		return this.textWidth;
	}

	public function getTextHeight():Float {
		return this.textHeight;
	}
}
