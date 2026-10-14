// 只提供 OpenFL 静态初始化所需的画布；交互检查不运行渲染器。
const context = {
  fillRect() {}, clearRect() {},
  getImageData(x, y, width, height) { return { data: new Uint8ClampedArray(width * height * 4), width, height }; },
  createImageData(width, height) { return { data: new Uint8ClampedArray(width * height * 4), width, height }; },
  putImageData() {},
  measureText(text) { return { width: text.length * 8 }; }
};
global.window = { navigator: { userAgent: 'Chrome' }, document: { URL: '', createElement(name) {
  if (name !== 'canvas') throw new Error('意外的 DOM 操作：' + name);
  return { width: 0, height: 0, setAttribute() {}, getContext() { return context; } };
} } };
