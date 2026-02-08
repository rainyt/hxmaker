package hx.utils.inputs;

import hx.events.Event;
import hx.display.InputLabel;

/**
 * 微信文本输入框工具类
 */
class WechatTextInputUtils {
	/**
	 * 当前焦点输入组件
	 */
	public static var zinput:InputLabel;
	
	/**
	 * 输入值
	 */
	public static var inputValue:String;
	
	/**
	 * 是否已注册事件监听器
	 */
	private static var isEventRegistered:Bool = false;

	/**
	 * 打开输入
	 */
	public static function openInput(input:InputLabel):Void {
		zinput = input;
		inputValue = input.data;
		
		// 防止重复注册事件监听器
		if (!isEventRegistered) {
			// 监听键盘输入事件
			Wx.onKeyboardInput(onKeyboardInput);
			
			// 监听用户点击键盘Confirm按钮时的事件
			Wx.onKeyboardConfirm(onKeyboardConfirm);
			
			// 监听键盘收起的事件
			Wx.onKeyboardComplete(onKeyboardComplete);
			
			isEventRegistered = true;
		}
		
		// 显示文字输入键盘
		Wx.showKeyboard({
			defaultValue: input.data,
			placeholder: "",
			success: function(res) {
				// 键盘显示成功
			},
			fail: function(res) {
				trace("显示键盘失败:", res);
			}
		});
	}

	/**
	 * 关闭输入
	 */
	public static function closeInput(label:InputLabel):Void {
		if (label == zinput) {
			zinput = null;
			
			// 隐藏文字输入键盘
			Wx.hideKeyboard({
				success: function(res) {
					// 键盘隐藏成功
				},
				fail: function(res) {
					trace("隐藏键盘失败:", res);
				}
			});
			
			// 移除事件监听并重置标志
			if (isEventRegistered) {
				Wx.offKeyboardInput(onKeyboardInput);
				Wx.offKeyboardConfirm(onKeyboardConfirm);
				Wx.offKeyboardComplete(onKeyboardComplete);
				isEventRegistered = false;
			}
		}
	}

	/**
	 * 监听键盘输入事件
	 */
	public static function onKeyboardInput(res:Dynamic):Void {
		if (zinput == null) {
			return;
		}
		
		inputValue = res.value;
		zinput.data = inputValue.substr(0, 9999);
		zinput.getTextWidth();
		zinput.dispatchEvent(new Event(Event.CHANGE));
	}

	/**
	 * 监听用户点击键盘Confirm按钮时的事件
	 */
	public static function onKeyboardConfirm(res:Dynamic):Void {
		if (zinput == null) {
			return;
		}
		
		inputValue = res.value;
		zinput.data = inputValue.substr(0, 9999);
		zinput.getTextWidth();
		zinput.dispatchEvent(new Event(Event.CHANGE));
	}

	/**
	 * 监听键盘收起的事件
	 */
	public static function onKeyboardComplete(res:Dynamic):Void {
		// 键盘收起时的处理
	}
}

/**
 * 微信小游戏API桥接
 */
@:native("wx")
extern class Wx {
	/**
	 * 显示文字输入键盘
	 */
	public static function showKeyboard(options:Dynamic):Void;
	
	/**
	 * 隐藏文字输入键盘
	 */
	public static function hideKeyboard(options:Dynamic):Void;
	
	/**
	 * 监听键盘输入事件
	 */
	public static function onKeyboardInput(callback:Dynamic->Void):Void;
	
	/**
	 * 取消监听键盘输入事件
	 */
	public static function offKeyboardInput(callback:Dynamic->Void):Void;
	
	/**
	 * 监听用户点击键盘Confirm按钮时的事件
	 */
	public static function onKeyboardConfirm(callback:Dynamic->Void):Void;
	
	/**
	 * 取消监听用户点击键盘Confirm按钮时的事件
	 */
	public static function offKeyboardConfirm(callback:Dynamic->Void):Void;
	
	/**
	 * 监听键盘收起的事件
	 */
	public static function onKeyboardComplete(callback:Dynamic->Void):Void;
	
	/**
	 * 取消监听键盘收起的事件
	 */
	public static function offKeyboardComplete(callback:Dynamic->Void):Void;
}
