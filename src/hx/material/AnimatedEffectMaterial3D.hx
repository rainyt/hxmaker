package hx.material;

import hx.display.BitmapData;
import hx.render3d.Math3D;

/** 支持 UV 滚动、遮罩、噪声扰动和溶解的特效材质；显式 update(dt) 更新参数。 */
class AnimatedEffectMaterial3D extends EffectMaterial3D {
	public var time(default, null):Float = 0;
	public var uvSpeedU:Float = 0;
	public var uvSpeedV:Float = 0;
	public var uvScaleU:Float = 1;
	public var uvScaleV:Float = 1;
	public var uvOffsetU:Float = 0;
	public var uvOffsetV:Float = 0;
	/** 在贴图区域内部重复，避免依赖硬件 REPEAT；序列帧图集不逐格重复。 */
	public var repeatUV:Bool = true;
	public var noiseScale:Float = 4;
	public var noiseSpeedU:Float = 0.13;
	public var noiseSpeedV:Float = 0.07;
	/** UV 扰动幅度，单位为贴图区域的归一化坐标。 */
	public var distortion:Float = 0;
	/** 零完全显示，一完全消失。 */
	public var dissolve:Float = 0;
	public var edgeWidth:Float = 0.08;
	public var edgeColor:Int = 0xffa030;
	public var edgeIntensity:Float = 1;
	/** 采用红通道乘 alpha；噪声为空时使用程序化连续噪声。 */
	public var maskTexture:BitmapData;
	public var noiseTexture:BitmapData;

	public function new(texture:BitmapData = null, blend:BlendMode3D = BlendMode3D.NORMAL, color:Int = 0xffffff) {
		super(texture, blend, color);
		setTextureUniform("uFxMask", null); setTextureUniform("uFxNoise", null);
		fragmentDeclarations = "uniform vec4 uFxUV;uniform vec2 uFxOffset;uniform vec4 uFxNoiseParams;"
			+ "uniform vec4 uFxSurface;uniform vec3 uFxEdge;uniform vec2 uFxFlags;"
			+ "float fxHash(vec2 p){p=mod(p,256.0);vec3 q=fract(vec3(p.xyx)*0.1031);q+=dot(q,q.yzx+33.33);return fract((q.x+q.y)*q.z);}"
			+ "float fxNoise(vec2 p){if(uFxFlags.y>0.5){vec2 uv=uFxNoiseRect.xy+fract(p)*uFxNoiseRect.zw;"
			+ "vec4 n=texture2D(uFxNoise,clamp(uv,uFxNoiseClamp.xy,uFxNoiseClamp.zw));return n.a>0.00001?n.r/n.a:0.0;}"
			+ "vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(fxHash(i),fxHash(i+vec2(1.0,0.0)),f.x),"
			+ "mix(fxHash(i+vec2(0.0,1.0)),fxHash(i+vec2(1.0,1.0)),f.x),f.y);}";
		fragmentUVCode = "vec2 fxOriginalUV=localUV;vec2 fxP=localUV*uFxNoiseParams.x+uFxNoiseParams.yz;"
			+ "float fxN=fxNoise(fxP);vec2 fxWarp=vec2(fxN,fxNoise(fxP+vec2(17.3,9.2)))-0.5;"
			+ "localUV=localUV*uFxUV.xy+uFxUV.zw+uFxOffset+fxWarp*uFxNoiseParams.w;"
			+ "localUV=uFxFlags.x>0.5?fract(localUV):clamp(localUV,0.0,1.0);";
		fragmentCode = "vec2 fxMaskUV=uFxMaskRect.xy+clamp(fxOriginalUV,0.0,1.0)*uFxMaskRect.zw;"
			+ "vec4 fxMask=texture2D(uFxMask,clamp(fxMaskUV,uFxMaskClamp.xy,uFxMaskClamp.zw));"
			+ "color.a*=fxMask.r;"
			+ "float fxKeep=1.0;if(uFxSurface.x>=1.0){fxKeep=0.0;}else if(uFxSurface.x>0.0){fxKeep=step(uFxSurface.x,fxN);}"
			+ "float fxEdge=fxKeep*(1.0-step(uFxSurface.y,fxN-uFxSurface.x))*step(0.00001,uFxSurface.x);"
			+ "color.rgb+=uFxEdge*fxEdge*uFxSurface.z;color.a*=fxKeep;";
		update(0);
	}

	/** 时间非负；重播可 resetTime，暂停传零，参数更改也由本方法提交。 */
	public function update(dt:Float):Void {
		if (isDisposed || !Math3D.finite(dt) || dt < 0 || !Math3D.finite(time + dt)) throw "特效材质时间无效";
		for (v in [uvSpeedU, uvSpeedV, uvScaleU, uvScaleV, uvOffsetU, uvOffsetV, noiseScale, noiseSpeedU, noiseSpeedV,
			distortion, dissolve, edgeWidth, edgeIntensity]) if (!Math3D.finite(v)) throw "特效材质参数必须有限";
		if (noiseScale <= 0 || distortion < 0 || dissolve < 0 || dissolve > 1 || edgeWidth < 0 || edgeWidth > 1 || edgeIntensity < 0)
			throw "特效材质噪声、扰动或溶解参数范围无效";
		time += dt;
		setTextureUniform("uFxMask", maskTexture); setTextureUniform("uFxNoise", noiseTexture);
		setUniform("uFxUV", [uvScaleU, uvScaleV, repeatUV ? fraction(time * uvSpeedU) : time * uvSpeedU, repeatUV ? fraction(time * uvSpeedV) : time * uvSpeedV]);
		setUniform("uFxOffset", [uvOffsetU, uvOffsetV]);
		setUniform("uFxNoiseParams", [noiseScale, phase(time * noiseSpeedU), phase(time * noiseSpeedV), distortion]);
		setUniform("uFxSurface", [dissolve, edgeWidth, edgeIntensity, 0.]);
		setUniform("uFxEdge", [((edgeColor >> 16) & 255) / 255., ((edgeColor >> 8) & 255) / 255., (edgeColor & 255) / 255.]);
		setUniform("uFxFlags", [repeatUV ? 1. : 0., noiseTexture == null ? 0. : 1.]);
	}

	public function resetTime(value:Float = 0):Void {
		if (!Math3D.finite(value) || value < 0) throw "特效材质时间必须是非负有限值";
		time = value; update(0);
	}

	override public function dispose():Void {
		super.dispose(); maskTexture = noiseTexture = null;
	}

	private static function phase(value:Float):Float { return (value % 256 + 256) % 256; }
	private static function fraction(value:Float):Float { return (value % 1 + 1) % 1; }
}
