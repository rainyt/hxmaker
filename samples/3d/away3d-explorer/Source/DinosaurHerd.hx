package;

import hx.assets.ModelAsset;
import hx.display3d.Model3D;
import hx.display3d.Node3D;

private typedef DinosaurAgent = {
	var model:Model3D;
	var targetX:Float;
	var targetZ:Float;
	var speed:Float;
	var remaining:Float;
}

/** 简单游走与性能对照；每只龙使用独立动画实例，共享同一个源资产。 */
class DinosaurHerd {
	public var root(default,null):Node3D = new Node3D();
	public var mode(default,null):Int = 0;
	public var animationEnabled(default,null):Bool = true;
	public var shadowsEnabled(default,null):Bool = true;
	public var count(get,never):Int;
	public var isDisposed(default,null):Bool = false;
	private var agents:Array<DinosaurAgent> = [];
	private var obstacles:Array<Dynamic>;
	private var seed:Int = 73129;
	private function get_count():Int { return agents.length; }

	public function new(asset:ModelAsset, colliders:Array<Dynamic>) {
		obstacles=[for(box in colliders) if(box.position[1]+box.size[1]/2>0.1 && box.position[1]-box.size[1]/2<2.5)box];
		root.name="霸王龙群";
		try {
			for(i in 0...20) {
				var model=asset.createInstance(-1,{pbrEnabled:true,gpuSkinning:true});root.addChild(model);
				model.name="霸王龙 "+(i+1);model.setScale(.65,.65,.65);model.y=.04;
				for(mesh in model.meshes){mesh.shadowMobility=hx.render3d.ShadowMobility3D.AUTO;mesh.geometryMobility=hx.render3d.GeometryMobility3D.AUTO;mesh.castShadow=true;mesh.receiveShadow=true;}
				var x=0.,z=0.;
				for(attempt in 0...500){x=-21+random()*42;z=6+random()*15;if(clear(x,z)&&spaced(x,z))break;if(attempt==499)throw "无法放置霸王龙";}
				model.x=x;model.z=z;
				model.animation.play("Run",true);model.animation.speed=.75+random()*.3;model.animation.seek(i*.097);
				var agent:DinosaurAgent={model:model,targetX:x,targetZ:z,speed:1.2+random()*.7,remaining:0};agents.push(agent);chooseTarget(agent);
			}
		}catch(error:Dynamic){dispose();throw error;}
	}
	private function random():Float { seed=(seed*1664525+1013904223)|0;return (seed>>>1)/2147483648.; }
	private function clear(x:Float,z:Float):Bool {
		if(x < -24||x>24||z<4||z>23)return false;
		for(box in obstacles)if(Math.abs(x-box.position[0])<box.size[0]/2+1.7&&Math.abs(z-box.position[2])<box.size[2]/2+1.7)return false;
		return true;
	}
	private function spaced(x:Float,z:Float,exclude:DinosaurAgent=null):Bool {
		for(other in agents)if(other!=exclude){var dx=x-other.model.x,dz=z-other.model.z;if(dx*dx+dz*dz<9)return false;}
		return true;
	}
	private function chooseTarget(agent:DinosaurAgent):Void {
		for(attempt in 0...50){var x=-22+random()*44,z=5+random()*17;if(clear(x,z)){agent.targetX=x;agent.targetZ=z;break;}}
		agent.remaining=3+random()*5;
	}
	public function update(dt:Float):Void {
		if(isDisposed||mode!=0)return;
		for(agent in agents) {
			agent.remaining-=dt;
			var model=agent.model,dx=agent.targetX-model.x,dz=agent.targetZ-model.z,distance=Math.sqrt(dx*dx+dz*dz);
			if(distance<.6||agent.remaining<=0){chooseTarget(agent);dx=agent.targetX-model.x;dz=agent.targetZ-model.z;distance=Math.sqrt(dx*dx+dz*dz);}
			if(distance>.001) {
				var step=Math.min(distance,dt*agent.speed),x=model.x+dx/distance*step,z=model.z+dz/distance*step;
				if(clear(x,z)&&spaced(x,z,agent)){model.x=x;model.z=z;model.rotationY=-Math.atan2(dz,dx)*180/Math.PI;}
				else agent.remaining=0;
			}
			if(animationEnabled)model.update(dt);
		}
	}
	public function cycleMode():Void { mode=(mode+1)%3;root.visible=mode!=2; }
	public function toggleAnimation():Void { animationEnabled=!animationEnabled; }
	public function toggleShadows():Void { shadowsEnabled=!shadowsEnabled;for(agent in agents)for(mesh in agent.model.meshes)mesh.castShadow=shadowsEnabled; }
	public function modeName():String { return mode==0?"行走":mode==1?"定格":"隐藏"; }
	#if hxmaker_explorer_checks
	public function snapshot():Dynamic {
		return {count:count,mode:mode,animation:animationEnabled,shadows:shadowsEnabled,disposed:isDisposed,
			positions:[for(agent in agents)[agent.model.x,agent.model.y,agent.model.z]],
			times:[for(agent in agents)agent.model.animation.time],
			valid:[for(agent in agents)clear(agent.model.x,agent.model.z)],
			triangles:[for(agent in agents)agent.model.triangleCount]};
	}
	#end
	public function dispose():Void {
		if(isDisposed)return;isDisposed=true;root.dispose();agents=[];obstacles=[];
	}
}
