package hx.macro;

import haxe.io.Path;
import haxe.macro.TypeTools;
import haxe.Exception;
import haxe.macro.Context;
import haxe.macro.Expr;
#if macro
import sys.io.File;
#end
import haxe.Json;

/**
 * 自动构造JSON的属性访问关系
 */
class JSONData {
	/**
	 * 创建一个自定义JSON类型：{data:[obj,obj,obj]}，会自动解析第一层，以及数组的第二层数据
	 * @param jsonPath json文件路径
	 * @param indexNames 索引名，支持多索引名，可用于快速查找
	 * @param typeNames 类型名，可用于索引分类，一般用于相同ID的类型使用
	 * @param embed 数据是否嵌入，默认为true，如果为false，则data会为null，需要主动为data赋值
	 */
	public macro static function create(jsonPath:String, indexNames:Array<String> = null, typeNames:Array<String> = null, embed:Bool = true) {
		var rootJsonPath = UIBuilder.moudle != null ? Path.join([UIBuilder.moudle.uibuildPath, jsonPath]) : jsonPath;
		jsonPath = rootJsonPath;
		var data:Dynamic = haxe.Json.parse(File.getContent(jsonPath));
		var name = Path.withoutDirectory(Path.withoutExtension(jsonPath));
		var className = name.charAt(0).toUpperCase() + name.substr(1).toLowerCase();
		name = "AutoJson" + className;
		var c = macro class $name {
			// /**
			//  * 数据验证器
			//  */
			public var validate:Dynamic;

			public function new() {}
		}
		var t:ComplexType = null;
		// doc文档
		var doc = Reflect.getProperty(data, "doc");
		var keys = Reflect.fields(data);
		for (index => value in keys) {
			if (value == "doc") // doc为动态文档，可过滤
				continue;
			var keyValue = Reflect.getProperty(data, value);
			var newField = null;
			if (Std.isOfType(keyValue, Array)) {
				var isDynamicArray:Bool = false;
				var arr:Array<Dynamic> = cast keyValue;
				for (index => value in arr) {
					if (!Std.isOfType(value, String)) {
						isDynamicArray = true;
						break;
					}
				}
				var bindData = embed ? keyValue : null;
				if (!isDynamicArray) {
					newField = {
						name: value,
						doc: null,
						meta: [],
						access: [APublic],
						kind: FVar(macro :Array<String>, macro $v{bindData}),
						pos: Context.currentPos()
					};
				} else {
					if (t == null) {
						var getData:Dynamic = keyValue[0];
						t = getType(getData, Context.currentPos(), doc);
					}
					// var t2 = haxe.macro.Type.TType({
					// 	name: "Test1",
					// 	pack: [],
					// 	params: [],
					// 	fields: t,
					// 	pos: Context.currentPos()
					// });
					// 将数组储存
					newField = {
						name: value,
						doc: null,
						meta: [],
						access: [APublic],
						kind: FVar(macro :Array<$t>, macro $v{bindData}),
						pos: Context.currentPos()
					};
					// 新增get{value}At(index)的方法，进行获取
					var funcName = "get" + value.charAt(0).toUpperCase() + value.substr(1).toLowerCase();
					// 通过索引获取，格式：get{属性名}By{索引名}
					if (indexNames != null) {
						for (indexName in indexNames) {
							var mapName = value + "_" + indexName + "_Maps";
							var getIndexMap = {
								name: mapName,
								doc: null,
								meta: [],
								access: [APrivate],
								kind: FVar(macro :Map<String, Dynamic>),
								pos: Context.currentPos()
							};
							c.fields.push(getIndexMap);
							var callName = funcName + "By" + indexName.charAt(0).toUpperCase() + indexName.substr(1).toLowerCase();
							var getIndexNamCall = {
								name: callName,
								doc: "根据" + indexName + "索引获取数据",
								meta: [],
								access: [APublic],
								kind: FFun({
									args: [{name: "name", type: macro :Dynamic}],
									ret: t,
									expr: macro {
										if (this.$mapName == null) {
											this.$mapName = [];
											var array:Array<Dynamic> = cast this.$value;
											for (item in array) {
												this.$mapName.set(Std.string(Reflect.getProperty(item, $v{indexName})), item);
											}
										}
										// 验证器
										if (this.validate != null && this.validate.allowGetDataValidate) {
											var item = this.$mapName.get(Std.string(name));
											if (item == null)
												return null;
											if (this.validate.validateObject(item)) {
												return item;
											} else {
												return null;
											}
										}
										return this.$mapName.get(Std.string(name));
									}
								}),
								pos: Context.currentPos()
							};
							c.fields.push(getIndexNamCall);
						}
					}

					// 通过类型索引获取，格式：get{属性名}sBy{索引名}
					if (typeNames != null) {
						for (typeName in typeNames) {
							var mapName = value + "_" + typeName + "_TypeMaps";
							var getIndexMap = {
								name: mapName,
								doc: "根据" + typeName + "索引获取相同的数据列表",
								meta: [],
								access: [APrivate],
								kind: FVar(macro :Map<String, Array<$t>>),
								pos: Context.currentPos()
							};
							c.fields.push(getIndexMap);
							var callName = funcName + "ArrayBy" + typeName.charAt(0).toUpperCase() + typeName.substr(1).toLowerCase();
							var getIndexNamCall = {
								name: callName,
								doc: null,
								meta: [],
								access: [APublic],
								kind: FFun({
									args: [{name: "name", type: macro :Dynamic}],
									ret: macro :Array<$t>,
									expr: macro {
										if (this.$mapName == null) {
											this.$mapName = [];
											var array:Array<Dynamic> = cast this.$value;
											for (item in array) {
												var type:String = Reflect.getProperty(item, $v{typeName});
												var array:Array<$t> = this.$mapName.get(type);
												if (array == null) {
													array = [];
													this.$mapName.set(Std.string(type), array);
												}
												array.push(item);
											}
										}
										// 验证器
										if (this.validate != null && this.validate.allowGetDataListValidate) {
											var items = this.$mapName.get(Std.string(name));
											if (items == null)
												return null;
											for (item in items) {
												if (!this.validate.validateObject(item)) {
													return null;
												}
											}
										}
										return this.$mapName.get(Std.string(name));
									}
								}),
								pos: Context.currentPos()
							};
							c.fields.push(getIndexNamCall);
						}
					}
				}
			} else {
				newField = {
					name: value,
					doc: null,
					meta: [],
					access: [APublic],
					kind: FVar(getType(keyValue, Context.currentPos(), doc), macro $v{keyValue}),
					pos: Context.currentPos()
				};
			}
			if (newField != null)
				c.fields.push(newField);
		}
		var ofTypeField = {
			name: "ofType",
			doc: null,
			meta: [],
			access: [APublic],
			kind: FFun({
				args: [{name: "data", type: macro :Dynamic}],
				ret: t,
				expr: macro {
					return data;
				}
			}),
			pos: Context.currentPos()
		};
		c.fields.push(ofTypeField);
		Context.defineType(c);
		var cls = {
			pack: [],
			name: name
		};
		return macro new $cls();
	}

	/**
	 * 获取类型
	 * @param value 
	 * @param pos 
	 * @return Dynamic
	 */
	static function getType(value:Dynamic, pos:Dynamic, doc:Dynamic):Dynamic {
		if (Std.isOfType(value, Bool))
			return macro :Bool;
		if (Std.isOfType(value, Int) || Std.isOfType(value, Float))
			return macro :Float;
		else if (Std.isOfType(value, Array)) {
			var v = value[0];
			var t = getType(v, pos, doc);
			return macro :Array<$t>;
		} else if (Std.isOfType(value, String))
			return macro :String;
		var args:Array<Field> = [];
		var keys = Reflect.fields(value);
		for (key in keys) {
			var kvalue = Reflect.getProperty(value, key);
			args.push({
				name: key,
				doc: doc != null ? Reflect.getProperty(doc, key) : null,
				meta: [],
				access: [APublic],
				kind: FVar(getType(kvalue, pos, doc)),
				pos: pos
			});
		}
		var t = TAnonymous(args);
		return macro :$t;
	}
}
