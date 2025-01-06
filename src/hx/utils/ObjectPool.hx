package hx.utils;

/**
 * 对象池
 */
class ObjectPool<T> {
	private var __create:Void->T;

	private var __destroy:T->Void;

	private var __objects:Array<T>;

	public function new(create:() -> T, destroy:T->Void) {
		__create = create;
		__destroy = destroy;
		__objects = [];
	}

	public function get():T {
		if (__objects.length > 0) {
			return __objects.pop();
		} else {
			return __create();
		}
	}

	public function release(obj:T):Void {
		__destroy(obj);
		__objects.push(obj);
	}
}
