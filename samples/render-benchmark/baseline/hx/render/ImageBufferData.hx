package hx.render;

import hx.utils.ContextStats;
import hx.geom.Matrix3D;
import hx.shader.MultiTextureShader;
import hx.display.DisplayObject;
import hx.display.BlendMode;
import hx.core.OpenFlBitmapData;
import hx.geom.Matrix;
import hx.display.Graphics;
import hx.core.Render;
import hx.core.Hxmaker;
import openfl.display.BitmapData;
import hx.display.Image;
import openfl.Vector;

/**
 * 图片缓存数据
 */
@:access(hx.display.Image)
@:access(hx.display.Graphics)
@:access(hx.geom.Matrix)
class ImageBufferData {
	/**
	 * 只有1像素的位图
	 */
	public static var px1bitmapData(get, never):hx.display.BitmapData;

	private static var __px1bitmapData:hx.display.BitmapData;

	private static function get_px1bitmapData():hx.display.BitmapData {
		if (__px1bitmapData == null) {
			__px1bitmapData = hx.display.BitmapData.formData(new OpenFlBitmapData(new BitmapData(1, 1, false, 0xffffff)));
		}
		return __px1bitmapData;
	}

	/**
	 * 是否启用颜色转换
	 * TODO 这里需要优化，它的判断逻辑比较复杂，目前看起来不稳定
	 */
	public var enabledColorTransform:Bool = false;

	/**
	 * 纹理ID顶点列表
	 */
	public var ids:Array<Float> = [];

	/**
	 * 透明度渲染
	 */
	public var alphas:Array<Float> = [];

	/**
	 * 叠加渲染支持
	 */
	public var addBlendModes:Array<Float> = [];

	/**
	 * 是否包含颜色转换
	 */
	public var hasColorTransform:Array<Float> = [];

	/**
	 * 颜色相乘
	 */
	public var colorMultiplier:Array<Float> = [];

	/**
	 * 颜色偏移
	 */
	public var colorOffset:Array<Float> = [];

	/**
	 * 纹理顶点坐标
	 */
	public var vertices:Vector<Float> = new Vector();

	/**
	 * 纹理顶点索引
	 */
	public var indices:Vector<Int> = new Vector();

	/**
	 * 纹理顶点UV
	 */
	public var uvtData:Vector<Float> = new Vector();

	/**
	 * 待渲染纹理
	 */
	public var bitmapDatas:Array<BitmapData> = [];

	/**
	 * 渲染列表
	 */
	// public var drawDisplayList:Array<DisplayObject> = [];

	/**
	 * 纹理ID映射表
	 */
	public var mapIds:Map<BitmapData, Int> = [];

	/**
	 * 平滑
	 */
	public var smoothing:Bool = false;

	/**
	 * 渲染模式
	 */
	public var blendMode:BlendMode = null;

	/**
	 * 数据缓存是否已经损坏
	 */
	// public var isBad:Bool = false;

	/**
	 * 数据索引
	 */
	public var index = 0;

	private var dataPerVertex4 = 0;
	private var dataPerVertex6 = 0;
	private var dataPerVertex16 = 0;
	private var dataPerVertex = 0;
	private var indicesOffset = 0;

	public function new() {}

	public function reset() {
		enabledColorTransform = false;
		index = 0;
		dataPerVertex4 = 0;
		dataPerVertex6 = 0;
		dataPerVertex16 = 0;
		dataPerVertex = 0;
		indicesOffset = 0;

		// colorMultiplier.resize(0);
		// colorOffset.resize(0);
		// hasColorTransform.resize(0);
		// alphas.resize(0);
		// addBlendModes.resize(0);
		// ids.resize(0);

		bitmapDatas.resize(0);
		mapIds.clear();
		// isBad = false;
		blendMode = null;
	}

	public function endFill():Void {
		vertices.length = dataPerVertex;
		indices.length = dataPerVertex6;
		uvtData.length = dataPerVertex;

		if (enabledColorTransform) {
			colorMultiplier.resize(dataPerVertex16);
			colorOffset.resize(dataPerVertex16);
			hasColorTransform.resize(dataPerVertex4);
		} else {
			colorMultiplier.resize(0);
			colorOffset.resize(0);
			hasColorTransform.resize(0);
		}

		alphas.resize(dataPerVertex4);
		addBlendModes.resize(dataPerVertex4);
		ids.resize(dataPerVertex4);
	}

	/**
	 * 绘制图形
	 * @param graphic 
	 * @param render 
	 * @return Bool
	 */
	public function drawGraphic(graphic:Graphics, render:Render):Bool {
		var data = graphic.__graphicsDrawData;
		var len = data.draws.length;
		while (graphic.__graphicsDrawData.index < len) {
			var command = data.draws[data.index];
			if (command == null) {
				// 当命令为空时，则意味着渲染已结束
				break;
			}
			// 路径网格在最终屏幕变换下生成过渡带，复用原有三角形提交与着色器。
			var coverage:Array<Float> = null;
			switch command {
				case DRAW_PATH(mesh, alpha, colorTransform):
					var resolved = mesh;
					if (graphic.antialiasing) {
						var world:Matrix = graphic.__worldTransform;
						var root = render.stage.transform.concatenatedMatrix;
						var pixelRatio = Hxmaker.engine == null ? 1. : Hxmaker.engine.devicePixelRatio;
						if (!Math.isFinite(pixelRatio) || pixelRatio <= 0) pixelRatio = 1;
						resolved = mesh.getAntialiased(
							(world.a * root.a + world.b * root.c) * pixelRatio,
							(world.a * root.b + world.b * root.d) * pixelRatio,
							(world.c * root.a + world.d * root.c) * pixelRatio,
							(world.c * root.b + world.d * root.d) * pixelRatio,
							graphic.antialiasWidth);
					}
					coverage = resolved.coverage;
					command = DRAW_TRIANGLE(resolved.vertices, resolved.indices, resolved.uvs, alpha, colorTransform, false);
				default:
			}
			switch command {
				case DRAW_PATH(_, _, _):
					// 已在上面的归一化步骤转换为普通三角形命令。
				case BEGIN_FILL(color):
					data.currentBitmapData = px1bitmapData;
					data.smoothing = true;
				case BEGIN_BITMAP_DATA(bitmapData, smoothing):
					data.currentBitmapData = bitmapData;
					data.smoothing = smoothing;
				case DRAW_TRIANGLE(vertices, indices, uvs, alpha, colorTransform, applyBlendAddMode):
					// 开始绘制三角形
					if (data.currentBitmapData != null && data.currentBitmapData.data != null) {
						var texture = data.currentBitmapData.data.getTexture();
						if (index == 0 || !mapIds.exists(texture)) {
							if (bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
								return false;
							}
						}
						// 如果平滑值不同，则产生新的绘制
						if (index == 0) {
							smoothing = data.smoothing;
							blendMode = graphic.blendMode;
							enabledColorTransform = colorTransform != null
								|| graphic.colorTransform != null
								|| render.currentShader is MultiTextureShader;
						} else if (!enabledColorTransform && (graphic.colorTransform != null || colorTransform != null)) {
							return false;
						} else if (smoothing != data.smoothing) {
							return false;
						} else if (blendMode != graphic.blendMode) {
							if (blendMode == ADD || blendMode == NORMAL) {
								if (graphic.blendMode != ADD && graphic.blendMode != NORMAL) {
									return false;
								}
							} else {
								return false;
							}
						}
						if (!applyBlendAddMode && graphic.blendMode == ADD) {
							applyBlendAddMode = true;
						}
						// 可以绘制，记录纹理ID
						var id = mapIds.get(texture);
						if (id == null) {
							bitmapDatas.push(texture);
							id = bitmapDatas.length - 1;
							mapIds.set(texture, id);
						}
						// 根据顶点设置数据
						var len = Std.int(vertices.length / 2);
							if (dataPerVertex4 + len > 65532 && index > 0) return false;
						// 顶点坐标
						var tileTransform:Matrix = @:privateAccess graphic.__worldTransform;
						for (i in 0...len) {
							ids[dataPerVertex4 + i] = id;
							// 覆盖率在颜色变换之后生效，透明边缘同时衰减预乘颜色和透明度。
							alphas[dataPerVertex4 + i] = graphic.__worldAlpha * alpha * (coverage == null ? 1 : coverage[i]);
							addBlendModes[dataPerVertex4 + i] = applyBlendAddMode ? 1 : 0;
							if (enabledColorTransform) {
								if (colorTransform != null) {
									hasColorTransform[dataPerVertex4 + i] = 1;
									colorMultiplier[dataPerVertex16 + i * 4] = colorTransform.redMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] = colorTransform.greenMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] = colorTransform.blueMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] = colorTransform.alphaMultiplier;
									colorOffset[dataPerVertex16 + i * 4] = colorTransform.redOffset;
									colorOffset[dataPerVertex16 + i * 4 + 1] = colorTransform.greenOffset;
									colorOffset[dataPerVertex16 + i * 4 + 2] = colorTransform.blueOffset;
									colorOffset[dataPerVertex16 + i * 4 + 3] = colorTransform.alphaOffset;
								} else {
									hasColorTransform[dataPerVertex4 + i] = 0;
									colorMultiplier[dataPerVertex16 + i * 4] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] = 1;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] = 1;
									colorOffset[dataPerVertex16 + i * 4] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 1] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 2] = 0;
									colorOffset[dataPerVertex16 + i * 4 + 3] = 0;
								}
								if (graphic.colorTransform != null) {
									hasColorTransform[dataPerVertex4 + i] = 1;
									colorMultiplier[dataPerVertex16 + i * 4] *= graphic.colorTransform.redMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 1] *= graphic.colorTransform.greenMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 2] *= graphic.colorTransform.blueMultiplier;
									colorMultiplier[dataPerVertex16 + i * 4 + 3] *= graphic.colorTransform.alphaMultiplier;
									colorOffset[dataPerVertex16 + i * 4] += graphic.colorTransform.redOffset;
									colorOffset[dataPerVertex16 + i * 4 + 1] += graphic.colorTransform.greenOffset;
									colorOffset[dataPerVertex16 + i * 4 + 2] += graphic.colorTransform.blueOffset;
									colorOffset[dataPerVertex16 + i * 4 + 3] += graphic.colorTransform.alphaOffset;
								}
							}
							var x = vertices[i * 2];
							var y = vertices[i * 2 + 1];
							this.vertices[dataPerVertex + i * 2] = tileTransform.__transformX(x, y);
							this.vertices[dataPerVertex + i * 2 + 1] = tileTransform.__transformY(x, y);
							this.uvtData[dataPerVertex + i * 2] = uvs[i * 2];
							this.uvtData[dataPerVertex + i * 2 + 1] = uvs[i * 2 + 1];
						}
						for (i in 0...indices.length) {
							this.indices[dataPerVertex6 + i] = indicesOffset + indices[i];
						}
						dataPerVertex4 += len;
						dataPerVertex6 += indices.length;
						dataPerVertex16 += len * 4;
						dataPerVertex += vertices.length;
						this.indicesOffset = Std.int(dataPerVertex / 2);
						this.index++;
						// 写入
						// drawDisplayList[index] = graphic;
						graphic.__transformDirty = false;
						graphic.__colorTransformDirty = false;
						graphic.__uvsDirty = false;
						// this.isBad = true;
					}
			}
			data.index++;
		}
		graphic.__graphicsDrawData.index = 0;
		ContextStats.statsGraphicRenderCount();
		return true;
	}

	/**
	 * 绘制图片
	 * @param image 
	 */
	public function draw(image:Image, render:Render):Bool {
		// 16 位索引最多容纳 65532 个四边形顶点，超限前先提交已有批次。
		if (dataPerVertex4 + 4 > 65532) return false;
		var texture = image.data.data.getTexture();
		var id = mapIds.get(texture);
		if (id == null && bitmapDatas.length >= MultiTextureShader.supportedMultiTextureUnits) {
			return false;
		}
		// 如果平滑值不同，则产生新的绘制
		if (index == 0) {
			smoothing = image.smoothing;
			blendMode = image.blendMode;
			enabledColorTransform = image.__colorTransform != null || render.currentShader is MultiTextureShader;
		} else if (!enabledColorTransform && (image.__colorTransform != null)) {
			return false;
		} else if (smoothing != image.smoothing) {
			return false;
		} else if (blendMode != image.blendMode) {
			if (blendMode == ADD || blendMode == NORMAL) {
				if (image.blendMode != ADD && image.blendMode != NORMAL) {
					return false;
				}
			} else {
				return false;
			}
		}
		// 可以绘制，记录纹理ID
		if (id == null) {
			bitmapDatas.push(texture);
			id = bitmapDatas.length - 1;
			mapIds.set(texture, id);
		}

		// if (!isBad) {
		// 	var displayObject = drawDisplayList[index];
		// 	var isSame = displayObject == image;
		// 	if (!isSame)
		// 		isBad = true;
		// }
		// TODO 如果是一样的列表，只是设置visible，那么该脏检测不正确
		// TODO 同isUvsDirty，需要想办法优化解决所有可能发生的情况
		// var isColorDirty = isBad || image.__colorTransformDirty;
		// var isTransformDirty = isBad || image.__transformDirty;
		// var isUvsDirty = isBad || image.__uvsDirty;
		// var isUvsDirty = true;
		// var isColorDirty = true;

		// if (displayObject != image || image.__transformDirty) {
		// if (isColorDirty) {
		// 4个顶点数据
		for (i in 0...4) {
			ids[dataPerVertex4 + i] = id;
			alphas[dataPerVertex4 + i] = image.__worldAlpha;
			addBlendModes[dataPerVertex4 + i] = image.__addBlendMode;
			if (enabledColorTransform) {
				if (image.__colorTransform != null) {
					hasColorTransform[dataPerVertex4 + i] = 1;
					colorMultiplier[dataPerVertex16 + i * 4] = image.__colorTransform.redMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 1] = image.__colorTransform.greenMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 2] = image.__colorTransform.blueMultiplier;
					colorMultiplier[dataPerVertex16 + i * 4 + 3] = image.__colorTransform.alphaMultiplier;
					colorOffset[dataPerVertex16 + i * 4] = image.__colorTransform.redOffset;
					colorOffset[dataPerVertex16 + i * 4 + 1] = image.__colorTransform.greenOffset;
					colorOffset[dataPerVertex16 + i * 4 + 2] = image.__colorTransform.blueOffset;
					colorOffset[dataPerVertex16 + i * 4 + 3] = image.__colorTransform.alphaOffset;
				} else {
					hasColorTransform[dataPerVertex4 + i] = 0;
					colorMultiplier[dataPerVertex16 + i * 4] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 1] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 2] = 1;
					colorMultiplier[dataPerVertex16 + i * 4 + 3] = 1;
					colorOffset[dataPerVertex16 + i * 4] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 1] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 2] = 0;
					colorOffset[dataPerVertex16 + i * 4 + 3] = 0;
				}
			}
		}
		// }

		// if (isTransformDirty) {
		// 坐标顶点
		var tileWidth:Float = image.data.rect != null ? image.data.rect.width : image.data.data.getWidth();
		var tileHeight:Float = image.data.rect != null ? image.data.rect.height : image.data.data.getHeight();
		var tileTransform = @:privateAccess image.__worldTransform;
		var x = @:privateAccess tileTransform.__transformX(0, 0);
		var y = @:privateAccess tileTransform.__transformY(0, 0);
		var x2 = @:privateAccess tileTransform.__transformX(tileWidth, 0);
		var y2 = @:privateAccess tileTransform.__transformY(tileWidth, 0);
		var x3 = @:privateAccess tileTransform.__transformX(0, tileHeight);
		var y3 = @:privateAccess tileTransform.__transformY(0, tileHeight);
		var x4 = @:privateAccess tileTransform.__transformX(tileWidth, tileHeight);
		var y4 = @:privateAccess tileTransform.__transformY(tileWidth, tileHeight);

		// TODO 3D变化支持
		// var __transformMatrix3D = @:privateAccess image.__transformMatrix3D;
		// if (__transformMatrix3D.transform3D != null) {
		// 	var matrix3D = new Matrix3D();
		// 	matrix3D.identity();
		// 	matrix3D.appendTranslation(-tileTransform.tx, -tileTransform.ty, 0);
		// 	if (__transformMatrix3D.center3DVector != null)
		// 		matrix3D.appendTranslation(-__transformMatrix3D.center3DVector.x, -__transformMatrix3D.center3DVector.y, -__transformMatrix3D.center3DVector.z);
		// 	matrix3D.append(__transformMatrix3D.transform3D);

		// if (__transformMatrix3D.projectionMatrix3D != null) {
		// 	matrix3D.appendTranslation(image.stage.stageWidth / 2, 0, 400);
		// 	matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// }

		// if (__transformMatrix3D.projectionMatrix3D != null) {
		// matrix3D.appendTranslation(0, 0, 1000);
		// matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// }

		// if (__transformMatrix3D.center3DVector != null)
		// 	matrix3D.appendTranslation(__transformMatrix3D.center3DVector.x, __transformMatrix3D.center3DVector.y, __transformMatrix3D.center3DVector.z);
		// matrix3D.appendTranslation(tileTransform.tx, tileTransform.ty, 0);

		// if (__transformMatrix3D.projectionMatrix3D != null) {
		// 	matrix3D.appendTranslation(image.stage.stageWidth / 2, image.stage.stageHeight / 2, 1000);
		// 	matrix3D.append(__transformMatrix3D.projectionMatrix3D);
		// }

		// var array = [x, y, 0, x2, y2, 0, x3, y3, 0, x4, y4, 0];
		// var array = [0, 0, tileWidth, 0, 0, tileWidth, tileWidth, tileHeight];
		// var projected = [];
		// var uvt = [];
		// Utils3D.projectVectors2D(matrix3D, array, projected, uvt);
		// trace(projected);
		// x = projected[0];
		// y = projected[1];
		// x2 = projected[2];
		// y2 = projected[3];
		// x3 = projected[4];
		// y3 = projected[5];
		// x4 = projected[6];
		// y4 = projected[7];

		// x = @:privateAccess tileTransform.__transformX(x, y);
		// y = @:privateAccess tileTransform.__transformY(x, y);
		// x2 = @:privateAccess tileTransform.__transformX(x2, y2);
		// y2 = @:privateAccess tileTransform.__transformY(x2, y2);
		// x3 = @:privateAccess tileTransform.__transformX(x3, y3);
		// y3 = @:privateAccess tileTransform.__transformY(x3, y3);
		// x4 = @:privateAccess tileTransform.__transformX(x4, y4);
		// y4 = @:privateAccess tileTransform.__transformY(x4, y4);
		// }

		vertices[dataPerVertex] = x;
		vertices[dataPerVertex + 1] = y;
		vertices[dataPerVertex + 2] = (x2);
		vertices[dataPerVertex + 3] = (y2);
		vertices[dataPerVertex + 4] = (x3);
		vertices[dataPerVertex + 5] = (y3);
		vertices[dataPerVertex + 6] = (x4);
		vertices[dataPerVertex + 7] = (y4);

		// 顶点
		indices[dataPerVertex6] = (indicesOffset);
		indices[dataPerVertex6 + 1] = (indicesOffset + 1);
		indices[dataPerVertex6 + 2] = (indicesOffset + 2);
		indices[dataPerVertex6 + 3] = (indicesOffset + 1);
		indices[dataPerVertex6 + 4] = (indicesOffset + 2);
		indices[dataPerVertex6 + 5] = (indicesOffset + 3);
		// }

		// UVs
		// if (isUvsDirty) {
		if (image.data.rect != null) {
			var imageWidth = image.data.data.getWidth();
			var imageHeight = image.data.data.getHeight();
			var uvX = image.data.rect.x / imageWidth;
			var uvY = image.data.rect.y / imageHeight;
			var uvW = (image.data.rect.x + image.data.rect.width) / imageWidth;
			var uvH = (image.data.rect.y + image.data.rect.height) / imageHeight;
			uvtData[dataPerVertex] = (uvX);
			uvtData[dataPerVertex + 1] = (uvY);
			uvtData[dataPerVertex + 2] = (uvW);
			uvtData[dataPerVertex + 3] = (uvY);
			uvtData[dataPerVertex + 4] = (uvX);
			uvtData[dataPerVertex + 5] = (uvH);
			uvtData[dataPerVertex + 6] = (uvW);
			uvtData[dataPerVertex + 7] = (uvH);
		} else {
			uvtData[dataPerVertex] = (0);
			uvtData[dataPerVertex + 1] = (0);
			uvtData[dataPerVertex + 2] = (1);
			uvtData[dataPerVertex + 3] = (0);
			uvtData[dataPerVertex + 4] = (0);
			uvtData[dataPerVertex + 5] = (1);
			uvtData[dataPerVertex + 6] = (1);
			uvtData[dataPerVertex + 7] = (1);
		}
		// }
		// }
		// drawDisplayList[index] = image;
		image.__transformDirty = false;
		image.__colorTransformDirty = false;
		image.__uvsDirty = false;
		// 下一个
		index++;
		dataPerVertex4 += 4;
		dataPerVertex6 += 6;
		dataPerVertex16 += 16;
		dataPerVertex += 8;
		indicesOffset += 4;
		return true;
	}
}
