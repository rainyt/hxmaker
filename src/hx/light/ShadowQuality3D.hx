package hx.light;

/** 阴影预算与自动配置档位；各项显式覆盖优先于档位。 */
enum abstract ShadowQuality3D(Int) from Int to Int {
	/** 保留旧的固定覆盖距离、两级取景和归一化偏差。 */
	var LEGACY = 0;
	/** 较低分辨率、单级与硬采样，自动附件预算不超过 8 MiB。 */
	var PERFORMANCE = 1;
	/** 自动紧凑单级或局部两级，PCF4，自动附件预算不超过 32 MiB。 */
	var BALANCED = 2;
	/** 较高分辨率与 PCF9，自动附件预算不超过 64 MiB。 */
	var HIGH = 3;
}
