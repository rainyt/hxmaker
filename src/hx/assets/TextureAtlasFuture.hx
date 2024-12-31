package hx.assets;

import hx.assets.XmlAtlas;

#if openfl
typedef TextureAtlasFuture = hx.core.TextureAtlasFuture;
#else
class TextureAtlasFuture extends Future<XmlAtlas, Dynamic> {}
#end
