package hx.animation3d;

/** 实例独立的 TRS 姿态缓冲；采样与混合复用数组，不保存播放状态。 */
class AnimationPose3D {
	/** 按导入节点索引排列的局部平移三元组，由姿态缓冲持有。 */
	public var translations(default, null):Array<Array<Float>>;

	/** 按导入节点索引排列的局部四元数，顺序为 x/y/z/w。 */
	public var rotations(default, null):Array<Array<Float>>;

	/** 按导入节点索引排列的局部缩放三元组。 */
	public var scales(default, null):Array<Array<Float>>;

	/** 深拷贝输入 TRS 数组，创建独立的实例姿态缓冲。 */
	public function new(translations:Array<Array<Float>>, rotations:Array<Array<Float>>, scales:Array<Array<Float>>) {
		this.translations = [for (value in translations) value.copy()];
		this.rotations = [for (value in rotations) value.copy()];
		this.scales = [for (value in scales) value.copy()];
	}

	/** 深拷贝当前全部 TRS 数据，返回独立姿态。 */
	public function clone():AnimationPose3D {
		return new AnimationPose3D(translations, rotations, scales);
	}

	/** 将同布局源姿态复制进当前可复用缓冲。 */
	public function copyFrom(source:AnimationPose3D):Void {
		for (i in 0...translations.length) {
			for (j in 0...3) {
				translations[i][j] = source.translations[i][j];
				scales[i][j] = source.scales[i][j];
			}
			for (j in 0...4)
				rotations[i][j] = source.rotations[i][j];
		}
	}

	/** 每次从初始姿态采样，未包含的轨道不会残留上一个动作的值。 */
	public function sample(rest:AnimationPose3D, clip:AnimationClip3D, time:Float):Void {
		copyFrom(rest);
		if (clip == null)
			return;
		for (track in clip.tracks) {
			var output = switch (track.path) {
				case "translation": translations[track.node];
				case "rotation": rotations[track.node];
				default: scales[track.node];
			};
			AnimationClip3D.sample(track, time, output);
		}
	}

	/** 按 0 至 1 的权重混合两个同布局姿态，平移缩放线性插值、旋转取最短路径。 */
	public function blend(from:AnimationPose3D, to:AnimationPose3D, weight:Float):Void {
		for (i in 0...translations.length) {
			for (j in 0...3) {
				translations[i][j] = from.translations[i][j] * (1 - weight) + to.translations[i][j] * weight;
				scales[i][j] = from.scales[i][j] * (1 - weight) + to.scales[i][j] * weight;
			}
			AnimationClip3D.blendRotation(from.rotations[i], 0, to.rotations[i], 0, weight, rotations[i]);
		}
	}
}
