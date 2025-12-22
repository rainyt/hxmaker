package hx.utils;

#if html5
typedef TextInputUtils = hx.utils.inputs.HTML5TextInputUtils;
#else
import hx.display.InputLabel;

class TextInputUtils {
	public static function openInput(input:InputLabel):Void {}
}
#end
