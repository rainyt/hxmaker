package hx.core;

import hx.display.Scene3D;
import hx.render3d.IScene3DRenderer;
import hx.render3d.openfl.Scene3DDisplay;
import haxe.ds.ObjectMap;
import hx.shader.MultiTextureFastShader;
import hx.filters.StageBitmapData;
import openfl.display.Bitmap;
import hx.shader.MultiTextureShader;
import openfl.geom.Rectangle;
import openfl.display.Shape;
import hx.render.CustomDisplayObjectRender;
import hx.display.CustomDisplayObject;
import hx.utils.ContextStats;
import hx.render.GraphicRender;
import hx.display.Graphics;
import hx.render.TextFieldRender;
import hx.render.ImageBufferData;
import hx.render.ImageRender;
import openfl.display.ShaderInput;
import openfl.display.BitmapData;
import openfl.display.ShaderParameter;
import openfl.display.Shader;
import hx.display.DisplayObject;
import openfl.geom.Matrix;
import hx.display.Quad;
import openfl.text.TextFormat;
import hx.display.Label;
import openfl.utils.ObjectPool;
import hx.display.Image;
import hx.display.DisplayObjectContainer;
import openfl.display.Sprite;
import hx.display.IRender;

using Reflect;

/**
 * OpenFL的渲染器支持
 */
@:keep
@:access(hx.display.DisplayObject)
@:access(openfl.geom.Matrix)
class Render implements IRender implements IScene3DRenderer {
	/** 兼容升级后的引擎销毁入口；基线没有新增的持久 GL 资源。 */
	public function dispose():Void {}
	private var __scene3DDisplays:ObjectMap<Scene3D, Scene3DDisplay> = new ObjectMap();
	private var __contextGeneration:Int = 0;
	/** 离屏与 MakerDisplay 渲染器也按需追随引擎设备代次，不用全局强引用登记表。 */
	private function prepareContext():Void {
		if (Hxmaker.engine is Engine) {
			var generation = cast(Hxmaker.engine, Engine).contextGeneration;
			if (generation != __contextGeneration) onContextRestored(generation);
		}
	}
	public function onContextRestored(generation:Int):Void {
		__contextGeneration = generation;
		currentShader = null; imageBufferData = []; drawImageBuffDataIndex = 0;
		if (__cacheBitmap != null) {
			if (__cacheBitmap.bitmapData != null) __cacheBitmap.bitmapData.dispose();
			__cacheBitmap.bitmapData = null;
			this.cacheAsBitmap = __cacheAsBitmap;
		}
	}

	/**
	 * 启动多纹理渲染，默认为`true`，但如果后端平台不支持时，那么这个属性会为`false`，同时即使设置成`true`也不会起作用。
	 */
	public var multiTextureEnabled(get, set):Bool;

	private var __multiTextureEnabled:Bool = true;

	private function get_multiTextureEnabled():Bool {
		return __multiTextureEnabled;
	}

	private function set_multiTextureEnabled(value:Bool):Bool {
		__multiTextureEnabled = value;
		MultiTextureShader.multiTextureEnabled = value;
		return value;
	}

	/**
	 * 默认的着色器支持
	 */
	public static var defaultShader:Shader;

	/**
	 * 默认的快速着色器支持
	 */
	public static var defaultFastShader:Shader;

	/**
	 * 默认的无平滑着色器支持
	 */
	public static var defaultUnSmoothingShader:Shader;

	/**
	 * 默认的无平滑快速着色器支持
	 */
	public static var defaultUnSmootingFastShader:Shader;

	/**
	 * 当前渲染的着色器
	 */
	public var currentShader:Shader;

	/**
	 * 图片的缓存数据
	 */
	public var imageBufferData:Array<ImageBufferData> = [];

	/**
	 * 是否为核心渲染器
	 */
	public var isCoreRender(get, never):Bool;

	private function get_isCoreRender():Bool {
		return Hxmaker.engine.renderer == this;
	}

	/**
	 * 当前图片的缓存数据索引
	 */
	public var drawImageBuffDataIndex:Int = 0;

	/**
	 * 是否将渲染结果缓存为位图
	 */
	public var cacheAsBitmap(get, set):Bool;

	private var __cacheAsBitmap:Bool = false;

	/**
	 * 是否开启高分辨率支持，该属性仅在`cacheAsBitmap`为`true`时生效，默认值为`true`。
	 */
	public var highDpi(get, set):Bool;

	private var __highDpi:Bool = true;

	private function get_highDpi():Bool {
		return __highDpi;
	}

	private function set_highDpi(value:Bool):Bool {
		this.__highDpi = value;
		this.cacheAsBitmap = cacheAsBitmap;
		return value;
	}

	private function get_cacheAsBitmap():Bool {
		return __cacheAsBitmap;
	}

	private function set_cacheAsBitmap(value:Bool):Bool {
		__cacheAsBitmap = value;
		if (value) {
			if (__cacheBitmap == null) {
				__cacheBitmap = new Bitmap();
			}
			if (highDpi) {
				__cacheBitmap.scaleX = 0.5;
				__cacheBitmap.scaleY = 0.5;
			} else {
				__cacheBitmap.scaleX = 1;
				__cacheBitmap.scaleY = 1;
			}
			var sizeWidth = highDpi ? Std.int(Hxmaker.engine.stageWidth) * 2 : Std.int(Hxmaker.engine.stageWidth);
			var sizeHeight = highDpi ? Std.int(Hxmaker.engine.stageHeight) * 2 : Std.int(Hxmaker.engine.stageHeight);
			if (__cacheBitmap.bitmapData == null
				|| __cacheBitmap.bitmapData.width != sizeWidth
				|| __cacheBitmap.bitmapData.height != sizeHeight) {
				if (__cacheBitmap.bitmapData != null)
					__cacheBitmap.bitmapData.dispose();
				__cacheBitmap.bitmapData = new BitmapData(sizeWidth, sizeHeight, true, 0x0);
				__cacheBitmap.bitmapData.disposeImage();
			}
		} else {
			if (__cacheBitmap != null) {
				__cacheBitmap.bitmapData.dispose();
				__cacheBitmap = null;
			}
		}
		return __cacheAsBitmap;
	}

	private var __cacheBitmap:Bitmap;

	public function onStageSizeChange():Void {
		if (cacheAsBitmap && __cacheBitmap != null) {
			this.cacheAsBitmap = true;
		}
	}

	/**
	 * 绘制图片缓存数据
	 * @param data 
	 */
	public function renderImageBuffData(data:ImageBufferData):Sprite {
		if (data.index > 0) {
			// 图形绘制
			data.endFill();
			var shape:Sprite = __pool.get();
			shape.graphics.clear();
			var isDefaultShader:Bool = currentShader == null || currentShader == defaultShader || currentShader == defaultFastShader;
			if (isDefaultShader) {
				currentShader = !data.enabledColorTransform ? defaultFastShader : defaultShader;
				if (!data.smoothing) {
					currentShader = !data.enabledColorTransform ? defaultUnSmootingFastShader : defaultUnSmoothingShader;
				}
			}
			var openfl_TextureId:ShaderParameter<Float> = currentShader.data.openfl_TextureId;
			var openfl_Alpha:ShaderParameter<Float> = currentShader.data.openfl_Alpha_multi;
			var openfl_ColorMultiplier:ShaderParameter<Float> = currentShader.data.openfl_ColorMultiplier_muti;
			var openfl_ColorOffer:ShaderParameter<Float> = currentShader.data.openfl_ColorOffset_muti;
			var openfl_HasColorTransform:ShaderParameter<Float> = currentShader.data.openfl_HasColorTransform_muti;
			var openfl_blendMode_add:ShaderParameter<Float> = currentShader.data.openfl_blendMode_add;
			var offests:Array<Float> = [];
			var mapIds:Map<BitmapData, Int> = [];
			for (index => data2 in data.bitmapDatas) {
				mapIds.set(data2, index);
				var sampler:ShaderInput<BitmapData> = currentShader.data.getProperty('uSampler$index');
				sampler.input = data2;
				sampler.filter = data.smoothing ? LINEAR : NEAREST;
			}
			if (openfl_ColorOffer != null)
				openfl_ColorOffer.value = data.colorOffset;
			if (openfl_ColorMultiplier != null)
				openfl_ColorMultiplier.value = data.colorMultiplier;
			if (openfl_HasColorTransform != null)
				openfl_HasColorTransform.value = data.hasColorTransform;
			openfl_TextureId.value = data.ids;
			openfl_Alpha.value = data.alphas;
			openfl_blendMode_add.value = data.addBlendModes;
			// 图形尺寸，暂永远设定为舞台大小
			var openfl_TextureSize:ShaderParameter<Float> = currentShader.data.openfl_TextureSize;
			openfl_TextureSize.value = [Hxmaker.engine.stageWidth, Hxmaker.engine.stageHeight];
			// 开始渲染图形
			shape.graphics.beginShaderFill(currentShader);
			shape.graphics.drawTriangles(data.vertices, data.indices, data.uvtData);
			shape.graphics.endFill();
			drawImageBuffDataIndex++;
			createImageBufferData(drawImageBuffDataIndex);
			ContextStats.statsVertexCount(data.indices.length);
			this.statsDrawCall();
			switch data.blendMode {
				case ADD:
					// shape.blendMode = ADD;
				case NORMAL:
					shape.blendMode = NORMAL;
				case SCREEN:
					shape.blendMode = SCREEN;
				default:
			}

			if (cacheAsBitmap) {
				if (__maskSprite != null) {
					__maskSprite.addChild(shape);
				} else {
					__drawMatrix.identity();
					if (highDpi)
						__drawMatrix.scale(2, 2);
					__cacheBitmap.bitmapData.draw(shape, __drawMatrix, null, null, null, true);
					releaseSprite(cast shape);
				}
			} else {
				stage.addChild(shape);
			}
			// if (currentShader == defaultUnSmoothingShader) {
			currentShader = null;
			// }
			return shape;
		}
		return null;
	}

	private var __drawMatrix:Matrix = new Matrix();

	private var __drawCallCount:Int = 0;

	private function statsDrawCall(counts:Int = 1) {
		ContextStats.statsDrawCall(counts);
		__drawCallCount += counts;
	}

	/**
	 * 获得当前渲染的绘制调用次数
	 */
	public var drawCall(get, never):Int;

	private function get_drawCall():Int {
		return __drawCallCount;
	}

	/**
	 * 在OpenFL中渲染的舞台对象
	 */
	@:noCompletion private var __stage:Sprite = new Sprite();

	@:noCompletion private var __maskSprite:EngineSprite;

	/** 当前正在绘制的遮罩栈，内层结束后恢复外层。 */
	private var __maskStack:Array<EngineSprite> = [];

	@:noCompletion private var __cacheSprite:Sprite = new Sprite();

	/**
	 * 设置遮罩行为
	 * @param isMask 
	 */
	public function setMask(isMask:Bool):Void {
		if (isMask) {
			var sprite = __pool.get();
			sprite.graphics.clear();
			if (__maskSprite != null)
				__maskSprite.addChild(sprite);
			else if (!cacheAsBitmap)
				__stage.addChild(sprite);
			__maskStack.push(sprite);
			__maskSprite = sprite;
		} else {
			var sprite = __maskStack.pop();
			__maskSprite = __maskStack.length == 0 ? null : __maskStack[__maskStack.length - 1];
			// 位图模式只在最外层遮罩结束后绘制，保留内层裁剪与外层裁剪的交集。
			if (cacheAsBitmap && sprite != null && __maskSprite == null) {
				this.__cacheSprite.addChild(sprite);
				__drawMatrix.identity();
				if (highDpi)
					__drawMatrix.scale(2, 2);
				__cacheBitmap.bitmapData.draw(__cacheSprite, __drawMatrix, null, null, null, true);
				releaseSprite(sprite);
			}
		}
	}

	/** 完整拆离并清理旧引用后，才允许绘制容器重新进入对象池。 */
	private function releaseSprite(sprite:EngineSprite):Void {
		var parent = sprite.parent;
		if (parent != null)
			parent.removeChild(sprite);
		var sprites:Array<EngineSprite> = [];
		collectSpritesForRelease(sprite, sprites);
		finishSpriteRelease(sprites, parent);
	}

	/** 按子对象优先的顺序收集，拆离期间不归还对象池。 */
	private function collectSpritesForRelease(sprite:EngineSprite, sprites:Array<EngineSprite>):Void {
		while (sprite.numChildren > 0) {
			var child = sprite.removeChildAt(sprite.numChildren - 1);
			if (child is EngineSprite)
				collectSpritesForRelease(cast child, sprites);
		}
		sprites.push(sprite);
	}

	/** 先清理所有延迟队列及原父容器，再统一归还，避免新旧层级交叉引用。 */
	private function finishSpriteRelease(sprites:Array<EngineSprite>, parent:openfl.display.DisplayObjectContainer):Void {
		for (sprite in sprites)
			EngineSprite.cleanupRemovedChildren(sprite);
		if (parent != null)
			EngineSprite.cleanupRemovedChildren(parent);
		for (sprite in sprites) {
			if (sprite.isPool)
				__pool.release(sprite);
		}
	}

	public var stage(get, never):Sprite;

	private function get_stage():Sprite {
		if (__maskSprite != null) {
			return __maskSprite;
		}
		return __stage;
	}

	private var __pool:ObjectPool<EngineSprite> = new ObjectPool<EngineSprite>(() -> {
		return new EngineSprite();
	}, (sprite) -> {
		sprite.x = 0;
		sprite.y = 0;
		sprite.scrollRect = null;
		sprite.blendMode = NORMAL;
	});

	/**
	 * 游戏引擎对象
	 */
	// public var engine:Engine;

	public function new() {
		this.__stage.mouseChildren = this.__stage.mouseEnabled = false;
		// 使用多纹理支持
		if (defaultShader == null) {
			defaultShader = new MultiTextureShader();
		}
		if (defaultFastShader == null) {
			defaultFastShader = new MultiTextureFastShader();
		}
		if (defaultUnSmoothingShader == null) {
			defaultUnSmoothingShader = new MultiTextureShader();
		}
		if (defaultUnSmootingFastShader == null) {
			defaultUnSmootingFastShader = new MultiTextureFastShader();
		}
	}

	public function clear():Void {
		prepareContext();
		// 先拆离整棵绘制树，防止仍在旧容器延迟队列中的对象提前被复用。
		var sprites:Array<EngineSprite> = [];
		while (__stage.numChildren > 0) {
			var display = __stage.removeChildAt(__stage.numChildren - 1);
			if (display is EngineSprite)
				collectSpritesForRelease(cast display, sprites);
		}
		finishSpriteRelease(sprites, __stage);
		__maskStack.resize(0);
		__maskSprite = null;
		__drawCallCount = 0;
		drawImageBuffDataIndex = 0;
		this.createImageBufferData(0);
		if (cacheAsBitmap) {
			__stage.addChild(__cacheBitmap);
			__cacheBitmap.bitmapData.fillRect(__cacheBitmap.bitmapData.rect, 0x0);
		}
		if (isCoreRender) {
			StageBitmapData.resetPool();
		}
	}

	/**
	 * 创建图片缓存数据
	 * @param index 
	 * @return ImageBufferData
	 */
	public function createImageBufferData(index:Int):ImageBufferData {
		if (imageBufferData[index] == null) {
			var data = new ImageBufferData();
			imageBufferData[index] = data;
			return data;
		}
		var data = imageBufferData[index];
		data.reset();
		return data;
	}

	/**
	 * 是否启用渲染滤镜
	 */
	public var enableRenderFilterDisplayObject:DisplayObject = null;

	public function renderDisplayObject(object:DisplayObject):Void {
		prepareContext();
		if (object is Scene3D) {
			var ancestor = object;
			while (ancestor != null) {
				if (cacheAsBitmap || ancestor.shader != null || ancestor.blendMode != NORMAL || (ancestor.filters != null && ancestor.filters.length > 0))
					throw "Scene3D 及其祖先首版暂不支持位图缓存、二维 Shader、滤镜或特殊合成混合模式";
				ancestor = ancestor.parent;
			}
		}
		if (object.parent != null && object.parent.__transformDirty) {
			object.setTransformDirty();
		}
		// 过滤器渲染支持
		if (enableRenderFilterDisplayObject != object) {
			// 这是BlendMode的增强渲染处理
			var isRender = false;
			if (object.__blendFilter != null) {
				// this.endFillImageDataBuffer();
				object.__blendFilter.update(object, Hxmaker.engine.dt);
				// 统计混合模式滤镜绘制次数
				ContextStats.statsBlendModeFilterDrawCall();
				if (object.__blendFilter.render != null) {
					renderDisplayObject(object.__blendFilter.render);
				}
				isRender = true;
			}
			if (object.filters != null && object.filters.length > 0) {
				// this.endFillImageDataBuffer();
				var lastRender:DisplayObject = null;
				for (filter in object.filters) {
					filter.update(lastRender == null ? object : lastRender, Hxmaker.engine.dt);
					// 统计混合模式滤镜绘制次数
					ContextStats.statsBlendModeFilterDrawCall();
					if (filter.render != null) {
						lastRender = filter.render;
						renderDisplayObject(filter.render);
					}
				}
				isRender = true;
			}
			if (isRender) {
				return;
			}
		}
		// 自定义着色器支持
		var renderShader = currentShader;
		if (object.shader != null && object.shader != currentShader) {
			endFillImageDataBuffer();
			currentShader = object.shader;
		}
		// 如果存在遮罩时，需要结束掉之前的所有绘制
		if (object.maskRect != null) {
			endFillImageDataBuffer();
			this.setMask(true);
		}
		if (object is Scene3D) {
			renderScene3D(cast object);
		} else if (object is Image) {
			renderImage(cast object);
		} else if (object is DisplayObjectContainer) {
			renderDisplayObjectContainer(cast object);
		} else if (object is Label) {
			renderLabel(cast object);
		} else if (object is Graphics) {
			renderGraphics(cast object);
		} else if (object is CustomDisplayObject) {
			renderCustomDisplayObject(cast object);
		}
		if (object.maskRect != null) {
			var shape = endFillImageDataBuffer();
			// 遮罩
			__retRect.setTo(0, 0, 0, 0);
			object.maskRect.transform(__retRect, object.__worldTransform);
			__maskRect.setTo(__retRect.x, __retRect.y, __retRect.width, __retRect.height);
			if (__maskSprite != null) {
				__maskSprite.x = __retRect.x;
				__maskSprite.y = __retRect.y;
				__maskSprite.scrollRect = __maskRect;
			}
			this.setMask(false);
		}
		if (object.shader != null) {
			endFillImageDataBuffer();
			currentShader = renderShader;
		}
	}

	/** 三维场景作为显示树叶节点接入，GPU 提交在 OpenFL 的对象绘制回调中执行。 */
	public function renderScene3D(scene:Scene3D):Void {
		endFillImageDataBuffer();
		if (scene.isDisposed || scene.hide || !scene.visible || scene.width <= 0 || scene.height <= 0) return;
		var display = __scene3DDisplays.get(scene);
		if (display == null) {
			display = new Scene3DDisplay(scene, function(_) { __scene3DDisplays.remove(scene); });
			__scene3DDisplays.set(scene, display);
		}
		var matrix = scene.__worldTransform;
		display.transform.matrix = new Matrix(matrix.a, matrix.b, matrix.c, matrix.d, matrix.tx, matrix.ty);
		var color = scene.__colorTransform;
		display.transform.colorTransform = color == null ? new openfl.geom.ColorTransform() : new openfl.geom.ColorTransform(
			color.redMultiplier, color.greenMultiplier, color.blueMultiplier, color.alphaMultiplier,
			color.redOffset, color.greenOffset, color.blueOffset, color.alphaOffset);
		display.alpha = scene.__worldAlpha;
		if (__maskSprite != null) __maskSprite.addChild(display); else stage.addChild(display);
		scene.__dirty = false;
		ContextStats.statsVisibleDisplayCounts();
	}

	public function renderDisplayObjectContainer(container:DisplayObjectContainer) {
		for (object in container.children) {
			if (!object.visible || object.alpha == 0) {
				continue;
			}
			if (object.background != null) {
				renderDisplayObject(object.background);
			}
			renderDisplayObject(object);
		}
		container.__dirty = false;
	}

	private static var __retRect:hx.geom.Rectangle = new hx.geom.Rectangle();

	private static var __maskRect:Rectangle = new Rectangle();

	/**
	 * 渲染自定义对象
	 * @param displayObject 
	 */
	public function renderCustomDisplayObject(displayObject:CustomDisplayObject):Void {
		this.endFillImageDataBuffer();
		if (displayObject.root != null) {
			CustomDisplayObjectRender.render(displayObject, this);
		}
		ContextStats.statsVisibleDisplayCounts();
	}

	public function renderImage(image:Image):Void {
		if (image.scale9Grid != null || image.__repeat) {
			renderGraphics(image.getGraphic());
		} else {
			ImageRender.render(image, this);
		}
		ContextStats.statsVisibleDisplayCounts();
	}

	public function getMarix(display:DisplayObject):Matrix {
		var hm:hx.geom.Matrix = display.__worldTransform;
		var m = new Matrix(hm.a, hm.b, hm.c, hm.d, hm.tx, hm.ty);
		return m;
	}

	/**
	 * 渲染Label对象
	 * @param image 
	 */
	public function renderLabel(label:Label, offScreenRender:Bool = false):Void {
		TextFieldRender.render(label, offScreenRender ? null : this);
		ContextStats.statsVisibleDisplayCounts();
	}

	/**
	 * 渲染三角形图形
	 * @param graphics 
	 */
	public function renderGraphics(graphics:Graphics):Void {
		GraphicRender.render(graphics, this);
		ContextStats.statsVisibleDisplayCounts();
	}

	/**
	 * 最终写入图片缓冲区
	 */
	public function endFillImageDataBuffer():Sprite {
		return this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
	}

	/**
	 * 结束所有绘制调用
	 */
	public function endFill():Void {
		this.renderImageBuffData(this.imageBufferData[this.drawImageBuffDataIndex]);
		this.imageBufferData = this.imageBufferData.splice(0, this.drawImageBuffDataIndex + 1);
	}

	/**
	 * 将当前已渲染好的画面渲染到BitmapData
	 * @return 
	 */
	public function renderToBitmapData(bitmapData:hx.display.BitmapData):Void {
		this.endFillImageDataBuffer();
		var root:BitmapData = cast(bitmapData.data, OpenFlBitmapData).getTexture();
		if (root.readable) {
			root.disposeImage();
		}
		root.draw(this.stage);
		ContextStats.statsDrawCall(this.drawCall);
	}
}
