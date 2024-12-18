package hx.utils;

import hx.utils.atlas.XmlAtlas;

#if openfl
typedef TextureAtlasFuture = hx.core.TextureAtlasFuture;
#else
class TextureAtlasFuture extends Future<XmlAtlas, Dynamic> {}
#end
