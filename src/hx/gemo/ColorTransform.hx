package hx.gemo;

import hx.utils.ObjectPool;

/**
 * 颜色转换器
 */
class ColorTransform {
	/**
		A decimal value that is multiplied with the alpha transparency channel
		value.

		If you set the alpha transparency value of a display object directly by
		using the `alpha` property of the DisplayObject instance, it
		affects the value of the `alphaMultiplier` property of that
		display object's `transform.colorTransform` property.
	**/
	public var alphaMultiplier:Float;

	/**
		A number from -255 to 255 that is added to the alpha transparency channel
		value after it has been multiplied by the `alphaMultiplier`
		value.
	**/
	public var alphaOffset:Float;

	/**
		A decimal value that is multiplied with the blue channel value.
	**/
	public var blueMultiplier:Float;

	/**
		A number from -255 to 255 that is added to the blue channel value after it
		has been multiplied by the `blueMultiplier` value.
	**/
	public var blueOffset:Float;

	/**
		A decimal value that is multiplied with the green channel value.
	**/
	public var greenMultiplier:Float;

	/**
		A number from -255 to 255 that is added to the green channel value after
		it has been multiplied by the `greenMultiplier` value.
	**/
	public var greenOffset:Float;

	/**
		A decimal value that is multiplied with the red channel value.
	**/
	public var redMultiplier:Float;

	/**
		A number from -255 to 255 that is added to the red channel value after it
		has been multiplied by the `redMultiplier` value.
	**/
	public var redOffset:Float;

	/**
		Creates a ColorTransform object for a display object with the specified
		color channel values and alpha values.

		@param redMultiplier   The value for the red multiplier, in the range from
							   0 to 1.
		@param greenMultiplier The value for the green multiplier, in the range
							   from 0 to 1.
		@param blueMultiplier  The value for the blue multiplier, in the range
							   from 0 to 1.
		@param alphaMultiplier The value for the alpha transparency multiplier, in
							   the range from 0 to 1.
		@param redOffset       The offset value for the red color channel, in the
							   range from -255 to 255.
		@param greenOffset     The offset value for the green color channel, in
							   the range from -255 to 255.
		@param blueOffset      The offset for the blue color channel value, in the
							   range from -255 to 255.
		@param alphaOffset     The offset for alpha transparency channel value, in
							   the range from -255 to 255.
	**/
	public function new(redMultiplier:Float = 1, greenMultiplier:Float = 1, blueMultiplier:Float = 1, alphaMultiplier:Float = 1, redOffset:Float = 0,
			greenOffset:Float = 0, blueOffset:Float = 0, alphaOffset:Float = 0):Void {
		this.redMultiplier = redMultiplier;
		this.greenMultiplier = greenMultiplier;
		this.blueMultiplier = blueMultiplier;
		this.alphaMultiplier = alphaMultiplier;
		this.redOffset = redOffset;
		this.greenOffset = greenOffset;
		this.blueOffset = blueOffset;
		this.alphaOffset = alphaOffset;
	}

	public function clone():ColorTransform {
		return new ColorTransform(redMultiplier, greenMultiplier, blueMultiplier, alphaMultiplier, redOffset, greenOffset, blueOffset, alphaOffset);
	}

	public function setTo(color:ColorTransform):Void {
		redMultiplier = color.redMultiplier;
		greenMultiplier = color.greenMultiplier;
		blueMultiplier = color.blueMultiplier;
		alphaMultiplier = color.alphaMultiplier;
		redOffset = color.redOffset;
		greenOffset = color.greenOffset;
		blueOffset = color.blueOffset;
		alphaOffset = color.alphaOffset;
	}
}
