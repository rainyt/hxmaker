import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { createHash } from 'node:crypto';

// 工作目录固定为示例，避免 HXML 中的相对路径随调用目录改变。
const sample=path.resolve(fileURLToPath(new URL('..',import.meta.url)));
process.chdir(sample);
const core=path.resolve(sample,'../../..');
const backend=process.env.HXMAKER_OPENFL_SOURCE;
const std=process.env.HAXE_STD_PATH || '/usr/local/lib/haxe/std';
const haxe=process.env.HAXE_BIN || '/usr/local/bin/haxe';
const env={...process.env,HAXE_STD_PATH:std};
function run(command,args) { return spawnSync(command,args,{encoding:'utf8',env,cwd:sample}); }
function git(directory,args) { const r=run('git',['-C',directory,...args]);return r.status===0?r.stdout.trim():null; }
const wechat=process.argv.includes('--wechat');
const base=wechat?'Export/wechat/html5':'Export/html5';
const project=wechat?'project-wechat.xml':'project.xml';
const hxml=`${base}/haxe/release.hxml`;
if(!process.argv.includes('--reuse')) {
  const result=run('haxelib',['run','openfl','build',project,'html5']);
  if(result.status!==0 && !`${result.stdout}${result.stderr}`.includes('NekoAPI')) throw new Error(`${result.stdout}${result.stderr}`);
}
let source=await fs.readFile(hxml,'utf8');
if(process.argv.includes('--astc'))source+='\n-lib hx-astcenc\n-D hx_astcenc\n';
if(backend) source+=`\n-cp ${path.resolve(backend)}\n`;
source+='\n-debug\n-D source-map-content\n';
const dependencies={hxmaker:core};
const paths=[...source.matchAll(/^-cp (.+)$/gm)].map(x=>x[1].trim());
for(const name of ['hxmaker-openfl','openfl','lime','hx-astcenc']) {
  const found=paths.filter(x=>path.basename(path.dirname(x))===name && path.basename(x)==='src').at(-1);
  if(found)dependencies[name]=path.dirname(found);
}
if(backend)dependencies['hxmaker-openfl']=path.dirname(path.resolve(backend));
if(process.argv.includes('--astc')) { const entries=run('haxelib',['path','hx-astcenc']).stdout.trim().split('\n');const entry=entries.find(x=>!x.startsWith('-')&&x.endsWith('/src/'));if(entry)dependencies['hx-astcenc']=path.dirname(entry.replace(/\/$/,'')); }
const manifest={builtAt:new Date().toISOString(),flags:source.split('\n').filter(x=>x.startsWith('-D ')||x==='-debug'),dependencies:{},assetManifest:'程序生成色块，无外部清单'};
const fingerprint=createHash('sha256');
for(const [name,directory] of Object.entries(dependencies)) {
  const revision=git(directory,['rev-parse','HEAD']);
  const diff=git(directory,['diff','HEAD','--','src']);
  const files=git(directory,['ls-files','--others','--exclude-standard','src']);
  fingerprint.update(name);fingerprint.update(revision||'');fingerprint.update(diff||'');
  for(const file of (files||'').split('\n').filter(Boolean).sort())fingerprint.update(await fs.readFile(path.join(directory,file)));
  manifest.dependencies[name]={revision,dirty:Boolean(diff||files)};
}
for(const file of (await fs.readdir("Source")).sort())fingerprint.update(await fs.readFile(path.join("Source",file)));
for(const file of (await fs.readdir('Assets')).sort())fingerprint.update(await fs.readFile(path.join('Assets',file)));
fingerprint.update(source);
manifest.buildId=fingerprint.digest('hex').slice(0,20);
source+=`\n-D hxmaker_build_id=${manifest.buildId}\n`;
await fs.writeFile(`${base}/haxe/stability.hxml`,source);
const compiled=run(haxe,[`${base}/haxe/stability.hxml`]);
if(compiled.status!==0)throw new Error(`${compiled.stdout}${compiled.stderr}`);
if(wechat) {
  // 某些旧适配库的模板条件在项目合并前求值；复制原始适配器，不修改导出的引擎 JS。
  const sdkSource=paths.find(x=>path.basename(path.dirname(x))==='wechat-zygame-dom'&&path.basename(x)==='src');
  if(!sdkSource)throw new Error('微信适配库源码路径缺失');
  const adapter=path.join(path.dirname(sdkSource),'adapter/zygameui-dom.js');
  await fs.copyFile(adapter,`${base}/bin/zygameui-dom.js`);
  for(const file of ['game.js','game.json','project.config.json','index.js','zygameui-dom.js'])await fs.access(`${base}/bin/${file}`);
  const configFile=`${base}/bin/project.config.json`;
  const config=JSON.parse(await fs.readFile(configFile,'utf8'));
  config.packOptions=config.packOptions||{};
  config.packOptions.ignore=config.packOptions.ignore||[];
  for(const file of ['RenderStability.js.map','index.html'])if(!config.packOptions.ignore.some(x=>x.type==='file'&&x.value===file))config.packOptions.ignore.push({type:'file',value:file});
  await fs.writeFile(configFile,JSON.stringify(config,null,2));
  manifest.dependencies['wechat-zygame-dom']={revision:git(path.dirname(sdkSource),['rev-parse','HEAD']),dirty:Boolean(git(path.dirname(sdkSource),['status','--porcelain']))};
}
const binary=await fs.readFile(`${base}/bin/RenderStability.js`);
manifest.javascriptSha256=createHash('sha256').update(binary).digest('hex');
manifest.sourceMap='RenderStability.js.map';
await fs.writeFile(`${base}/bin/build-info.json`,JSON.stringify(manifest,null,2));
await fs.writeFile(wechat?'results/wechat-build-info.json':'results/build-info.json',JSON.stringify(manifest,null,2));
console.log(JSON.stringify(manifest));
