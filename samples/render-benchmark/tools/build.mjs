import fs from 'node:fs/promises';
import { spawnSync } from 'node:child_process';

/** 只在基准产物中使用旧 Render 源码覆盖，不给生产后端增加模式开关。 */
function compile(file) {
  const result = spawnSync('haxe', [file], { stdio: 'inherit' });
  if (result.status !== 0) throw new Error(`Haxe 编译失败：${file}`);
}
if (!process.argv.includes('--reuse')) {
  const generated = spawnSync('haxelib', ['run', 'openfl', 'build', 'project.xml', 'html5'], { encoding: 'utf8' });
  process.stdout.write(generated.stdout || '');
  process.stderr.write(generated.stderr || '');
  // 某些本机 Lime 工具会在成功生成 HXML 后因 Neko 架构不匹配而退出，随后独立编译仍需成功。
  if (generated.status !== 0 && !(generated.stderr || '').includes('NekoAPI') && !(generated.stderr || '').includes('incompatible architecture')) {
    throw new Error('OpenFL 项目生成失败');
  }
}
const filename = 'Export/html5/haxe/release.hxml';
const original = await fs.readFile(filename, 'utf8');
compile(filename);
const baseline = original.replace('-js Export/html5/bin/render-benchmark.js', '-js Export/html5/bin/baseline.js')
  + '\n-cp baseline\n-D benchmark_graphics_baseline\n';
await fs.writeFile('Export/html5/haxe/baseline.hxml', baseline);
compile('Export/html5/haxe/baseline.hxml');
const html = await fs.readFile('Export/html5/bin/index.html', 'utf8');
await fs.writeFile('Export/html5/bin/baseline.html', html.replace('render-benchmark.js', 'baseline.js'));
console.log('默认直接渲染与独立 Graphics 基线均已编译。');
