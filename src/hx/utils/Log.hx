package hx.utils;

import haxe.ValueException;
import haxe.Exception;
#if js
import js.html.Console;
#end
import haxe.PosInfos;

class Log {
	/**
	 * 常规日志输出
	 * @param v 
	 * @param infos 
	 */
	public static function log(v:Dynamic, ?infos:PosInfos):Void {
		var str = haxe.Log.formatOutput(v, infos);
		#if js
		Console.log(str);
		#elseif sys
		Sys.println(str);
		#end
	}

	/**
	 * 错误日志输出
	 * @param v 
	 * @param infos 
	 */
	public static function error(v:Dynamic, ?infos:PosInfos):Void {
		var str = haxe.Log.formatOutput(v, infos);
		#if js
		Console.error(str);
		#elseif sys
		Sys.println(str);
		#end
	}

	/**
	 * 将`Exception`输出
	 * @param e 
	 */
	public static function exception(e:Exception, ?infos:PosInfos):String {
		var message = e.message + "\n" + e.stack.toString();
		var str = haxe.Log.formatOutput(message, infos);
		error(str, infos);
		return str;
	}

	/**
	 * 警告日志输出
	 * @param v 
	 * @param infos 
	 */
	public static function warring(v:Dynamic, ?infos:PosInfos):Void {
		var str = haxe.Log.formatOutput(v, infos);
		#if js
		Console.warn(str);
		#elseif sys
		Sys.println(str);
		#end
	}

	/**
	 * 异常的hscript错误输出，请定义`hscriptPos`启动此功能
	 * @param e 
	 * @param script 
	 * @param infos 
	 */
	public static function exceptionHscirpt(e:ValueException, fileName:String, functionName:String, script:String, ?infos:PosInfos):Void {
		var message:String = e.message;
		var logs = [];
		if (message.indexOf("hscript:") != -1) {
			var valueException:ValueException = cast e;
			var error:Dynamic = valueException.value;
			var code = script;

			var pmin:Int = error.pmin;
			var pmax:Int = error.pmax;
			var outCode = code.substr(0, pmin);
			var outCodes = outCode.split("\n");
			var endLine = outCodes[outCodes.length - 1];

			logs = code.split("\n");
			var index = 0;
			logs = logs.map(function(line) {
				return "hscript:" + index++ + ": " + line;
			});
			var lineAt:Int = error.line;
			lineAt--;
			var errorNoneLine = endLine.split("").map((s) -> {
				return switch (s) {
					case "\t":
						return s;
					default:
						" ";
				}
			}).join("");

			var max = (pmax - pmin) + 1;

			logs.insert(lineAt + 1, "^^^^^^^:" + lineAt + ": " + errorNoneLine + [
				for (i in 0...max) {
					"^";
				}
			].join(""));
			logs.insert(lineAt + 2, "        " + [
				for (_ in 0...Std.string(lineAt).length) {
					" ";
				}
			].join("")
				+ "  "
				+ errorNoneLine
				+ fileName
				+ ".hx:"
				+ functionName
				+ ":"
				+ lineAt
				+ ":"
				+ errorNoneLine.length
				+ ": "
				+ message.substr(message.indexOf(":", 8) + 1));

			// 保留上下5行
			var min = lineAt - 5;
			if (min < 0)
				min = 0;
			var max = lineAt + 5;
			if (max >= logs.length) {
				max = logs.length - 1;
			}
			logs = logs.slice(min, max);
		} else {
			logs = [message];
		}
		error("Script error:" + "\n" + logs.join("\n"));
	}
}
