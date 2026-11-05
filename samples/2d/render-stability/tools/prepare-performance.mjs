import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

// 基线从指定提交导出，不切换或覆盖用户的开发分支。
const sample=path.resolve(fileURLToPath(new URL('..',import.meta.url)));
const core=path.resolve(sample,'../../..');
const backend=process.env.HXMAKER_OPENFL_SOURCE?path.dirname(path.resolve(process.env.HXMAKER_OPENFL_SOURCE)):path.resolve(core,'../hxmaker-openfl');
const benchmark=path.join(core,'samples/render-benchmark');
const temporary=await fs.mkdtemp(path.join(os.tmpdir(),'hxmaker-render-baseline-'));
const env={...process.env,HAXE_STD_PATH:process.env.HAXE_STD_PATH||'/usr/local/lib/haxe/std'};
function run(command,args,options={}){const result=spawnSync(command,args,{cwd:benchmark,env,maxBuffer:67108864,...options});if(result.status!==0)throw new Error(String(result.stderr||result.stdout));return result;}
for(const [name,repository,revision] of [['core',core,'f879909'],['backend',backend,'caac7ba']]){
 const destination=path.join(temporary,name);await fs.mkdir(destination);
 const archive=run('git',['-C',repository,'archive',revision,'src']);run('tar',['-xf','-','-C',destination],{input:archive.stdout});
}
const generated=spawnSync('haxelib',['run','openfl','build','project.xml','html5'],{cwd:benchmark,env,encoding:'utf8'});
if(generated.status!==0&&!`${generated.stdout}${generated.stderr}`.includes('NekoAPI'))throw new Error(`${generated.stdout}${generated.stderr}`);
const original=await fs.readFile(path.join(benchmark,'Export/html5/haxe/release.hxml'),'utf8');
const html=await fs.readFile(path.join(benchmark,'Export/html5/bin/index.html'),'utf8');
await fs.mkdir(path.join(sample,'Export/html5/bin'),{recursive:true});
for(const mode of ['before','after']){
 let source=original.replace('-js Export/html5/bin/render-benchmark.js',`-js ${sample}/Export/html5/bin/benchmark-${mode}.js`);
 source+=mode==='before'?`\n-cp ${temporary}/core/src\n-cp ${temporary}/backend/src\n`:`\n-cp ${core}/src\n-cp ${backend}/src\n`;
 const filename=path.join(temporary,`${mode}.hxml`);await fs.writeFile(filename,source);
 run(process.env.HAXE_BIN||'/usr/local/bin/haxe',[filename]);
 await fs.writeFile(path.join(sample,`Export/html5/bin/benchmark-${mode}.html`),html.replace('render-benchmark.js',`benchmark-${mode}.js`));
}
console.log('修复前后的同一 JS 基准场景已生成，可执行 performance.mjs。');
