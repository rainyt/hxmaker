# 动画系统

Hxmaker 提供了三种动画方式：`MovieClip`（帧动画）、`Spine`（骨骼动画）和 `Particle`（粒子系统）。

## MovieClip — 帧动画

`MovieClip` 通过逐帧切换纹理实现动画效果，类似于 GIF 或精灵表动画。

### 基本用法

```haxe
import hx.display.MovieClip;

var mc = new MovieClip();

// 添加帧：位图, 持续时间(秒), 音效ID(可选), 自定义数据(可选)
mc.addFrame(bitmapData1, 0.1);
mc.addFrame(bitmapData2, 0.1);
mc.addFrame(bitmapData3, 0.1);
mc.addFrame(bitmapData4, 0.1, "footstep");  // 带音效的帧

mc.x = 200;
mc.y = 300;
mc.loop = true;  // 循环播放

// 播放
mc.play();

this.addChild(mc);
```

### 批量设置帧

```haxe
var mc = new MovieClip();

// 一次性设置多个帧
mc.setBitmapDatas([bmp1, bmp2, bmp3, bmp4], 0.08);

mc.loop = true;
mc.play();
this.addChild(mc);
```

### 控制播放

```haxe
// 播放
mc.play();

// 暂停
mc.pause();

// 停止并重置到第一帧
mc.stopAt(0);
mc.reset();

// 跳转到指定帧
mc.stopAt(5);
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `loop` | Bool | 是否循环播放 |
| `playing` | Bool | 是否正在播放（只读） |
| `currentFrame` | Int | 当前帧索引（只读） |
| `totalFrame` | Int | 总帧数（只读） |
| `totalTime` | Float | 总播放时长（只读） |
| `enableSound` | Bool | 是否启用帧音效 |

## Spine — 骨骼动画

> **注意**：使用 Spine 需要安装 `spine-haxe` 或 `spine-hx` 运行时库。

`Spine` 用于播放 Spine 骨骼动画，支持骨骼绑定、皮肤切换和动画混合。

### 基本用法

```haxe
import hx.display.Spine;

// 从已加载的骨骼数据创建 Spine 对象
var spine = new Spine(skeletonData);
spine.x = 400;
spine.y = 300;

// 播放动画
spine.play("walk", true);  // 动画名称, 是否循环

this.addChild(spine);
```

### 常用操作

```haxe
var spine = new Spine(skeletonData);

// 播放动画
spine.play("idle", true);
spine.play("attack", false);

// 停止动画
spine.stop();

// 切换皮肤
spine.setSkinByName("armor_01");

// 设置渲染帧率（独立于游戏帧率）
spine.renderFps = 30;
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `renderFps` | Float | 骨骼动画渲染帧率 |
| `mustVisibleRender` | Bool | 是否必须在可见时才渲染 |

### 主要方法

| 方法 | 说明 |
|------|------|
| `play(name, loop)` | 播放指定动画 |
| `stop()` | 停止动画 |
| `setSkinByName(name)` | 切换皮肤 |

### Spine 事件

```haxe
spine.addEventListener(SpineEvent.START, function(event) {
    trace("动画开始");
});

spine.addEventListener(SpineEvent.END, function(event) {
    trace("动画结束");
});

spine.addEventListener(SpineEvent.EVENT, function(event) {
    var spineEvent = cast(event, SpineEvent);
    trace("骨骼事件：" + spineEvent.event);
});
```

## Particle — 粒子系统

`Particle` 是一个完整的粒子特效系统，支持 Cocos2d/Particle Designer 的 JSON 格式。

### 基本用法

```haxe
import hx.display.Particle;

var particle = new Particle();
particle.x = 400;
particle.y = 300;

// 配置粒子属性
particle.counts = 100;           // 粒子总数
particle.life = 1.0;             // 粒子生命周期（秒）
particle.lifeVariance = 0.5;     // 生命周期浮动
particle.duration = -1;          // 发射持续时间（-1 为无限）
particle.velocity = 200;         // 初始速度
particle.gravity = 50;           // 重力
particle.textures = [bmp1, bmp2]; // 粒子纹理

// 粒子缩放
particle.scaleXAttribute = new OneAttribute(1.0, 0.0);  // 从 1.0 缩小到 0.0

// 粒子旋转
particle.rotaionAttribute = new OneAttribute(0, 360);

// 粒子颜色渐变
particle.colorAttribute = new FourAttribute(1,1,1,1, 1,1,1,0);  // RGBA: 从白色到透明

// 开始发射
particle.start();

this.addChild(particle);
```

### 从 JSON 加载

```haxe
var jsonData = {
    maxParticles: 200,
    life: 1.5,
    lifeVariance: 0.3,
    duration: -1,
    speed: 250,
    speedVariance: 50,
    gravity: {x: 0, y: 100},
    sourcePosition: {x: 0, y: 0},
    sourcePositionVariance: {x: 20, y: 20},
    startColor: {r: 1, g: 0.5, b: 0, a: 1},
    finishColor: {r: 1, g: 1, b: 0, a: 0},
    startSize: 32,
    finishSize: 8,
    textureFileName: "particle_tex",
    // ...更多粒子参数
};

// 从 JSON 创建粒子
var particle = Particle.fromJson(jsonData);
particle.start();
this.addChild(particle);

// 或者对已有粒子应用 JSON 配置
var existingParticle = new Particle();
existingParticle.applyJsonData(jsonData);
```

### 控制粒子

```haxe
// 开始发射
particle.start();

// 停止发射（已存在的粒子继续播放直到消失）
particle.stop();

// 立即重置（清除所有粒子）
particle.reset();
```

### 发射模式

```haxe
// 发射模式
import hx.particle.ParticleEmitMode;
// POINT - 点状发射（默认）

// 创建模式
import hx.particle.ParticleCreateMode;
// RECT - 矩形区域创建
// CIRCLE - 圆形区域创建
```

### 粒子属性系统

粒子系统使用一套属性类来控制粒子在不同生命阶段的行为：

```haxe
// 单值属性 - 从 start 渐变到 end
new OneAttribute(startValue, endValue);

// 双值属性 - 独立的 X 和 Y
new TwoAttribute(xStart, xEnd, yStart, yEnd);

// 四值属性 - 如颜色 RGBA
new FourAttribute(r1,g1,b1,a1, r2,g2,b2,a2);

// 随机范围属性
new RandomTwoAttribute(min, max);

// 分组属性（带缓动权重的复合属性）
new GroupAttribute(start, end, tween);
```

### 主要属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `counts` | Int | 最大粒子数量 |
| `life` | Float | 粒子生命周期（秒） |
| `lifeVariance` | Float | 生命周期的随机浮动 |
| `duration` | Float | 发射持续时间（-1 为无限） |
| `velocity` | Float | 初始速度 |
| `gravity` | Float | 重力加速度 |
| `acceleration` | Float | 加速度 |
| `tangential` | Float | 切向加速度 |
| `textures` | Array<BitmapData> | 粒子纹理列表 |
| `scaleXAttribute` | Attribute | X 方向缩放属性 |
| `scaleYAttribute` | Attribute | Y 方向缩放属性 |
| `rotaionAttribute` | Attribute | 旋转属性 |
| `colorAttribute` | FourAttribute | 颜色渐变属性 |
| `emitMode` | ParticleEmitMode | 发射模式 |
| `createMode` | ParticleCreateMode | 创建模式 |
