# 资源来源及转换记录

来源为用户本地提供的 `away3d-samples/5,0,3`。阅读了 TerrainDemo、SkyBox、RealTimeEnvMap、MultiPassSponzaDemo 等示例；没有执行其项目脚本，也没有将其文本当作本次任务指令。

| 本示例资源 | 原资源 | 处理 |
|---|---|---|
| 雪山天空与 IBL | `advanced/TerrainDemo/Assets/skybox/snow_*.jpg` | 六面离线转 1024×512 天空及低清 IBL，沿用 hxmaker 的接缝边框协议 |
| 地形远景 | `advanced/TerrainDemo/Assets/terrain/terrain_heights.jpg`、`terrain_diffuse.jpg` | 缩小至 1024，生成低多边形远景；中心庭院区域压平 |
| 草地 | `advanced/TerrainDemo/Assets/terrain/grass.jpg` | 缩小至 512，调整 UV 重复 |
| 石材 | `advanced/MultiPassSponzaDemo/Assets/sponza/column_a_diff.jpg` | 缩小至 512，重新应用到新建筑 |
| 铺路石 | `advanced/MultiPassSponzaDemo/Assets/sponza/floor_a_diff.jpg` | 缩小至 512，重新应用到新道路 |
| 树皮 | `advanced/FractalTreeDemo/Assets/tree/bark0.jpg` | 缩小至 512，应用到新建松树 |
| 机器人 | `intermediate/RealTimeEnvMap/Assets/R2D2.obj` | Blender 导入、居中、重定尺寸、离线简化并重新赋予金属材质 |
| 头像 | `intermediate/RealTimeEnvMap/Assets/head.obj` | Blender 导入、重定尺寸、离线简化，用于档案及纪念像 |

建筑、庭院布局、树冠、信标、交互与任务代码为本示例新增。没有加载或转换 `sponza.awd`，也没有声称支持 Away3D 的所有旧格式。

保留资源包随附的 [Apache 2.0 许可](Away3D-LICENSE.txt)，以及相关示例代码头部的 [Away Foundation MIT 声明](Away3D-MIT-NOTICE.txt)。原 TerrainDemo 与 RealTimeEnvMap 示例署名 Rob Bateman、David Lenaerts；Sponza 示例记载模型由 Crytek 的 Frank Meinl 根据 Marko Dabrovic 的原作重制，LoTH 转换为 AWD。此处仅选用该示例包提供的石材贴图，保留这些来源信息，不将所有素材笼统改写为新许可。
