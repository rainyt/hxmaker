package hx.spine;

#if (spine_hx && spine_haxe)
#error "Spine 运行时冲突：spine-hx 与 spine-haxe 只能引入一个。"
#end

/** 按引入的库选择原生类型，避免接口、事件和资源加载混用不同运行时。 */
#if spine_hx
typedef SkeletonData = spine.SkeletonData;
typedef AttachmentColor = spine.support.graphics.Color;
typedef TrackEntry = spine.AnimationState.TrackEntry;
typedef AnimationState = spine.AnimationState;
typedef AnimationStateData = spine.AnimationStateData;
typedef SkeletonClipping = spine.utils.SkeletonClipping;
typedef TextureAtlasRegion = spine.support.graphics.TextureAtlas.AtlasRegion;
typedef TextureAtlasPage = spine.support.graphics.TextureAtlas.AtlasPage;
typedef TextureLoader = spine.support.graphics.TextureLoader;
typedef TextureAtlas = spine.support.graphics.TextureAtlas;
typedef NativeEvent = spine.Event;
#elseif spine_haxe
typedef SkeletonData = spine.SkeletonData;
typedef AttachmentColor = spine.Color;
typedef TrackEntry = spine.animation.TrackEntry;
typedef AnimationState = spine.animation.AnimationState;
typedef AnimationStateData = spine.animation.AnimationStateData;
typedef SkeletonClipping = spine.SkeletonClipping;
typedef TextureAtlasRegion = spine.atlas.TextureAtlasRegion;
typedef TextureAtlasPage = spine.atlas.TextureAtlasPage;
typedef TextureLoader = spine.atlas.TextureLoader;
typedef TextureAtlas = spine.atlas.TextureAtlas;
typedef NativeEvent = spine.Event;
#else
typedef SkeletonData = Dynamic;
typedef TrackEntry = Dynamic;
typedef NativeEvent = Dynamic;
#end
