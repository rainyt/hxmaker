package;

import hx.assets.Assets;
import hx.controls3d.OrbitCameraController3D;
import hx.controls3d.Scene3DInput;
import hx.display.Label;
import hx.display.Quad;
import hx.display.Scene;
import hx.display.Scene3D;
import hx.display.Stage;
import hx.display3d.Camera3D;
import hx.display3d.MeshObject;
import hx.display3d.Model3D;
import hx.events.Event;
import hx.events.KeyboardEvent;
import hx.events.Scene3DInputEvent;
import hx.geom.Vector3D;
import hx.geometry.BoxGeometry;
import hx.geometry.Geometry3D;
import hx.geometry.PlaneGeometry;
import hx.light.DirectionalLight3D;
import hx.material.LambertTextureMaterial;
import hx.material.Material3D;

/** 加载恐龙、播放两个动作，并提供平滑环绕镜头。 */
class DinosaurScene extends Scene {
    private static inline var MODEL_URL:String = "assets/dinosaur.glb";
    private static inline var SWITCH_SECONDS:Float = 8;
    private static inline var FADE_SECONDS:Float = 0.25;

    private var view:Scene3D;
    private var camera:Camera3D;
    private var orbit:OrbitCameraController3D;
    private var input:Scene3DInput;
    private var inputStage:Stage;
    private var assets:Assets;
    private var model:Model3D;
    private var geometries:Array<Geometry3D> = [];
    private var materials:Array<Material3D> = [];
    private var idleName:String;
    private var runName:String;
    private var idleButton:DemoButton;
    private var runButton:DemoButton;
    private var pauseButton:DemoButton;
    private var sequenceButton:DemoButton;
    private var orbitButton:DemoButton;
    private var speedButton:DemoButton;
    private var status:Label;
    private var detail:Label;
    private var progress:Quad;
    private var loading:Bool = false;
    private var loadVersion:Int = 0;
    private var automaticSequence:Bool = true;
    private var automaticOrbit:Bool = true;
    private var sequenceTime:Float = 0;
    private var statusTime:Float = 0;
    private var speeds:Array<Float> = [0.5, 1.0, 1.5];
    private var speedIndex:Int = 1;
    private var framedDistance:Float = 9;
    private var pressedKeys:Map<Int, Bool> = [];

    override public function onStageInit():Void {
        super.onStageInit();
        updateEnabled = true;
        sceneBackground.data = 0x101c20;
        sceneBackground.alpha = 1;
        createView();
        createInterface();
        inputStage = stage;
        inputStage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
        inputStage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);
        inputStage.addEventListener(Event.DEACTIVATE, onDeactivate);
        loadModel();
    }

    private function createView():Void {
        view = new Scene3D(1052, 492);
        view.x = 24;
        view.y = 146;
        view.backgroundColor = 0x1d3237;
        view.backgroundAlpha = 1;
        view.ambientIntensity = 0.48;
        addChild(view);

        camera = new Camera3D();
        camera.fieldOfView = 42;
        camera.near = 0.05;
        camera.far = 100;
        view.root.addChild(camera);
        view.camera = camera;
        orbit = new OrbitCameraController3D(camera, new Vector3D(0, 1.7, 0));
        orbit.minDistance = 4;
        orbit.maxDistance = 24;
        orbit.minPitch = 6;
        orbit.maxPitch = 65;
        orbit.damping = 10;
        resetCamera();
        input = new Scene3DInput(view, orbit);
        input.addEventListener(Scene3DInputEvent.DRAG_BEGIN, function(_) {
            automaticOrbit = false;
            updateButtons();
        });

        var light = new DirectionalLight3D(0xfff4dd, 0.85);
        light.direction = new Vector3D(-1, -2, -1);
        light.shadowEnabled = true;
        light.shadowMapSize = 1024;
        view.root.addChild(light);
        view.light = light;
        ownedMesh(PlaneGeometry.create(18, 18), 0x263c40, -0.11);
        ownedMesh(BoxGeometry.create(7.4, 0.10, 3.8), 0x3b554a, -0.05);
    }

    private function ownedMesh(geometry:Geometry3D, color:Int, y:Float):Void {
        var material = new LambertTextureMaterial(null, color);
        geometries.push(geometry);
        materials.push(material);
        var mesh = new MeshObject(geometry, material);
        mesh.y = y;
        mesh.castShadow = false;
        mesh.receiveShadow = true;
        mesh.pickable = false;
        view.root.addChild(mesh);
    }

    private function createInterface():Void {
        label("低多边形恐龙 · 动作展示", 24, 22, 27, 0xf1f5eb);
        label("待机与奔跑自动轮播，也可以手动选择动作。", 24, 62, 15, 0x9cb6b2);
        idleButton = button("待机", 24, 90, function() { selectAnimation(idleName, true); });
        runButton = button("奔跑", 124, 90, function() { selectAnimation(runName, true); });
        pauseButton = button("暂停", 224, 100, togglePause);
        sequenceButton = button("自动切换：开", 334, 150, function() {
            automaticSequence = !automaticSequence;
            sequenceTime = 0;
            updateButtons();
        });
        orbitButton = button("镜头环绕：开", 494, 150, function() {
            automaticOrbit = !automaticOrbit;
            updateButtons();
        });
        button("重置镜头", 654, 120, resetCamera);
        speedButton = button("速度：1 倍", 784, 140, function() {
            speedIndex = (speedIndex + 1) % speeds.length;
            if (model != null) model.animation.speed = speeds[speedIndex];
            updateButtons();
        });
        button("重新加载", 934, 142, loadModel);

        var track = new Quad(1052, 4, 0x30494c);
        track.x = 24;
        track.y = 652;
        track.mouseEnabled = false;
        addChild(track);
        progress = new Quad(0, 4, 0x9ecb83);
        progress.x = 24;
        progress.y = 652;
        progress.mouseEnabled = false;
        addChild(progress);
        status = label("正在准备资源……", 24, 670, 16, 0xd9e8de);
        detail = label("", 24, 699, 14, 0x9cb6b2);
        detail.width = 1052;
        label("拖动转镜头 · 滚轮缩放 · 1 待机 · 2 奔跑 · 空格暂停 · R 重置镜头", 24, 731, 13, 0x8ba4a0);
        updateButtons();
    }

    private function label(text:String, x:Float, y:Float, size:Int, color:Int):Label {
        var value = new Label(text);
        value.x = x;
        value.y = y;
        value.fontSize = size;
        value.color = color;
        value.mouseEnabled = false;
        value.wordWrap = false;
        addChild(value);
        return value;
    }

    private function button(text:String, x:Float, width:Float, callback:Void->Void):DemoButton {
        var value = new DemoButton(text, width, callback);
        value.x = x;
        value.y = 98;
        addChild(value);
        return value;
    }

    private function loadModel():Void {
        if (loading || isDisposed) return;
        loading = true;
        var version = ++loadVersion;
        input.cancel("reload");
        if (model != null) {
            model.dispose();
            model = null;
        }
        if (assets != null) {
            assets.stop();
            assets.clean();
        }
        idleName = runName = null;
        sequenceTime = 0;
        progress.width = 0;
        status.color = 0xd9e8de;
        status.data = "模型加载中：0%";
        detail.data = "";
        updateButtons();
        var request = new Assets();
        assets = request;
        request.tryLoadTimes = 0;
        request.loadModel(MODEL_URL);
        request.onProgress(value -> {
            if (isDisposed || version != loadVersion) return;
            status.data = "模型加载中：" + Math.round(value * 100) + "%";
            progress.width = 1052 * value;
        });
        request.onError(error -> {
            request.stop();
            request.clean();
            if (isDisposed || version != loadVersion) return;
            loading = false;
            status.color = 0xffac96;
            status.data = "模型加载失败";
            detail.data = error.error;
            trace(error.toString());
            updateButtons();
        });
        request.onComplete(_ -> {
            if (isDisposed || version != loadVersion) {
                request.clean();
                return;
            }
            try {
                var asset = request.getModel("dinosaur");
                model = asset.createInstance(-1, {lightingEnabled: true});
                view.root.addChild(model);
                for (mesh in model.meshes) {
                    mesh.castShadow = true;
                    mesh.receiveShadow = true;
                }
                var names = model.animation.names;
                idleName = resolveClip(names, ["idle", "待机"]);
                runName = resolveClip(names, ["run", "奔跑"]);
                if (idleName == null && names.length > 0) idleName = names[0];
                if (runName == null) {
                    for (name in names) if (name != idleName) { runName = name; break; }
                }
                model.animation.speed = speeds[speedIndex];
                if (idleName != null) model.animation.play(idleName, true);
                fitModel();
                loading = false;
                if (idleName == null || runName == null) {
                    automaticSequence = false;
                    detail.data = "资源仅包含 " + names.length + " 个动作；请导出两个动作后重新加载。";
                } else {
                    detail.data = "已加载两个动作，每 8 秒自动切换；手动选择动作后停止轮播。";
                }
                status.color = 0xd9e8de;
                for (warning in asset.warnings) trace("模型提示：" + warning);
                updateStatus();
                updateButtons();
            } catch (error:Dynamic) {
                if (model != null) { model.dispose(); model = null; }
                loading = false;
                status.color = 0xffac96;
                status.data = "模型实例化失败";
                detail.data = Std.string(error);
                trace(error);
                updateButtons();
            }
        });
        request.start();
    }

    private function resolveClip(names:Array<String>, keywords:Array<String>):String {
        for (name in names) {
            var lower = name.toLowerCase();
            for (keyword in keywords) if (lower.indexOf(keyword) >= 0) return name;
        }
        return null;
    }

    private function selectAnimation(name:String, manual:Bool):Void {
        if (model == null || name == null) return;
        if (manual) automaticSequence = false;
        sequenceTime = 0;
        if (model.animation.currentName != name) model.animation.crossFade(name, FADE_SECONDS, true);
        model.animation.resume();
        updateButtons();
        updateStatus();
        if (manual) detail.data = "已手动选择动作；打开“自动切换”可恢复轮播。";
    }

    private function togglePause():Void {
        if (model == null || model.animation.currentName == null) return;
        if (model.animation.playing) model.animation.pause(); else model.animation.resume();
        updateButtons();
        updateStatus();
    }

    private function fitModel():Void {
        if (model == null) return;
        var bounds = model.getBounds();
        if (bounds.isEmpty()) return;
        var center = bounds.center();
        var sizeX = bounds.max.x - bounds.min.x;
        var sizeY = bounds.max.y - bounds.min.y;
        var sizeZ = bounds.max.z - bounds.min.z;
        model.setPosition(-center.x, -bounds.min.y, -center.z);
        var radius = Math.max(0.1, Math.sqrt(sizeX * sizeX + sizeY * sizeY + sizeZ * sizeZ) / 2);
        var vertical = camera.fieldOfView * Math.PI / 360;
        var horizontal = Math.atan(Math.tan(vertical) * view.width / view.height);
        framedDistance = (Math.max(sizeY / (2 * Math.tan(vertical)), Math.sqrt(sizeX * sizeX + sizeZ * sizeZ) / (2 * Math.tan(horizontal))) + radius * 0.65) * 1.12;
        orbit.target.setTo(0, sizeY * 0.48, 0);
        orbit.minDistance = radius * 1.1;
        orbit.maxDistance = framedDistance * 3;
        camera.far = Math.max(60, orbit.maxDistance + radius * 4);
        resetCamera();
    }

    private function resetCamera():Void {
        if (orbit == null) return;
        if (input != null) input.cancel("resetCamera");
        orbit.yaw = 38;
        orbit.pitch = 18;
        orbit.distance = framedDistance;
        orbit.snap();
    }

    override public function onUpdate(dt:Float):Void {
        super.onUpdate(dt);
        if (isDisposed || orbit == null) return;
        var step = Math.max(0, Math.min(dt, 0.1));
        // 每个业务更新只推进一次模型动画，绘制与阴影不重复推进。
        if (model != null) {
            model.update(step);
            if (automaticSequence && idleName != null && runName != null && model.animation.playing) {
                sequenceTime += step;
                if (sequenceTime >= SWITCH_SECONDS) {
                    selectAnimation(model.animation.currentName == idleName ? runName : idleName, false);
                }
            }
        }
        if (automaticOrbit && !input.capturing) orbit.rotate(8 * step, 0);
        orbit.update(step);
        statusTime += step;
        if (statusTime >= 0.1) {
            statusTime = 0;
            updateStatus();
        }
    }

    private function updateStatus():Void {
        if (model == null || loading) return;
        var animation = model.animation;
        var name = animation.currentName == null ? "无" : animation.currentName == idleName ? "待机" : animation.currentName == runName ? "奔跑" : animation.currentName;
        status.data = "当前动作：" + name + "　" + (animation.playing ? "播放中" : "已暂停")
            + "　" + decimal(animation.time) + " / " + decimal(animation.duration) + " 秒"
            + (animation.transitioning ? "　平滑切换中" : "");
        progress.width = animation.duration > 0 ? 1052 * Math.min(1, animation.time / animation.duration) : 0;
    }

    private function updateButtons():Void {
        if (idleButton == null) return;
        var ready = model != null && !loading;
        var playing = ready && model.animation.playing;
        idleButton.setAvailable(ready && idleName != null);
        runButton.setAvailable(ready && runName != null);
        pauseButton.setAvailable(ready && model.animation.currentName != null);
        sequenceButton.setAvailable(ready && idleName != null && runName != null);
        speedButton.setAvailable(ready);
        idleButton.setActive(ready && model.animation.currentName == idleName);
        runButton.setActive(ready && model.animation.currentName == runName);
        sequenceButton.setActive(automaticSequence);
        orbitButton.setActive(automaticOrbit);
        pauseButton.caption = playing ? "暂停" : "继续";
        sequenceButton.caption = "自动切换：" + (automaticSequence ? "开" : "关");
        orbitButton.caption = "镜头环绕：" + (automaticOrbit ? "开" : "关");
        speedButton.caption = "速度：" + speeds[speedIndex] + " 倍";
    }

    private function onKeyDown(event:KeyboardEvent):Void {
        if (pressedKeys.exists(event.keyCode)) return;
        pressedKeys.set(event.keyCode, true);
        switch (event.keyCode) {
            case 49: selectAnimation(idleName, true);
            case 50: selectAnimation(runName, true);
            case 32: event.preventDefault(); togglePause();
            case 82: resetCamera();
            default:
        }
    }

    private function onKeyUp(event:KeyboardEvent):Void {
        pressedKeys.remove(event.keyCode);
    }

    private function onDeactivate(event:Event):Void {
        pressedKeys.clear();
    }

    private function decimal(value:Float):String {
        return Std.string(Math.round(value * 100) / 100);
    }

    override public function dispose():Void {
        if (isDisposed) return;
        loadVersion++;
        if (inputStage != null) {
            inputStage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
            inputStage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
            inputStage.removeEventListener(Event.DEACTIVATE, onDeactivate);
        }
        if (input != null) input.dispose();
        if (orbit != null) orbit.dispose();
        if (model != null) { model.dispose(); model = null; }
        if (assets != null) { assets.stop(); assets.clean(); assets = null; }
        super.dispose();
        for (geometry in geometries) geometry.dispose();
        for (material in materials) material.dispose();
        geometries = [];
        materials = [];
    }
}
