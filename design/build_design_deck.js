// ZapWise design chart v0.1
const pptxgen = require('pptxgenjs');
const { applyTheme } = require('/mnt/skills/public/pptx/scripts/apply_theme.js');
const SIZES = require('./out/sizes.json');

const OUT = 'ZapWise_디자인차트_v0.1.pptx';
const F = 'Malgun Gothic';
const THEME = {
  name: 'ZapWise',
  headFontFace: F, bodyFontFace: F,
  colors: {
    dk1: '4B2E39', lt1: 'FFFFFF', dk2: '8A5F6C', lt2: 'FDE9E7',
    accent1: 'E0607A', accent2: '5FAF95', accent3: 'B23A57', accent4: 'F59BAA', accent5: 'FFE3A3', accent6: 'A8DCC6',
    hlink: 'B23A57', folHlink: '8A5F6C',
  },
};
const HEX = { milk: 'FDE9E7', cocoa: '4B2E39', cocoa2: '8A5F6C', rose: 'E0607A', deep: 'B23A57', straw: 'F59BAA', blush: 'FBC9CF', butter: 'FFE3A3', mint: 'A8DCC6', peach: 'FFC4A3', sky: 'C6E6F3', shade: 'E9C3C2' };

const pres = new pptxgen();
pres.layout = 'LAYOUT_WIDE';
pres.title = 'ZapWise 디자인 차트 v0.1';
pres.theme = { headFontFace: F, bodyFontFace: F };
const C = pres.SchemeColor;
const SH = pres.shapes;

function T(o) { return Object.assign({ fontFace: F, lang: 'ko-KR', color: C.text1, fontSize: 12, margin: 0 }, o || {}); }
function R(text, o) { return { text, options: T(o) }; }
function txt(s, text, o) { s.addText(text, T(Object.assign({ isTextBox: true, valign: 'top' }, o))); }
function img(s, path, o) {
  const [pw, ph] = SIZES[path];
  let { x, y, w, h } = o;
  if (w && !h) h = w * ph / pw;
  if (h && !w) w = h * pw / ph;
  s.addImage({ path, x, y, w, h });
  return { x, y, w, h };
}
function card(s, x, y, w, h, o) {
  o = o || {};
  s.addShape(SH.ROUNDED_RECTANGLE, {
    x, y, w, h, rectRadius: o.r || 0.18, fill: { color: o.fill || C.background1 }, line: { color: o.line || C.background1, width: 0.5 },
    shadow: o.flat ? undefined : { type: 'outer', color: HEX.shade, blur: 8, offset: 3, angle: 45, opacity: 0.7 },
  });
}

pres.defineSlideMaster({
  title: 'COVER', background: { color: C.background2 },
  objects: [{ placeholder: { options: { name: 'title', type: 'title', x: 0.8, y: 3.1, w: 6.2, h: 0.8, fontFace: F, fontSize: 30, bold: true, color: C.text1, align: 'left', valign: 'middle', margin: 0 }, text: '' } }],
});
pres.defineSlideMaster({
  title: 'CONTENT', background: { color: C.background2 }, margin: [0.5, 0.5, 0.5, 0.5],
  objects: [
    { placeholder: { options: { name: 'title', type: 'title', x: 0.5, y: 0.3, w: 10.5, h: 0.55, fontFace: F, fontSize: 24, bold: true, color: C.text1, align: 'left', valign: 'middle', margin: 0 }, text: '' } },
    { text: { text: 'ZapWise 디자인 차트 v0.1', options: { x: 0.5, y: 7.08, w: 5, h: 0.25, fontFace: F, lang: 'ko-KR', fontSize: 9, color: '8A5F6C', margin: 0 } } },
  ],
  slideNumber: { x: 12.3, y: 7.06, w: 0.53, h: 0.26, fontFace: F, fontSize: 9, color: '8A5F6C', align: 'right' },
});
function slide(section, title, sub) {
  const s = pres.addSlide({ masterName: 'CONTENT', sectionTitle: section });
  s.addText(title, { placeholder: 'title', fontFace: F, lang: 'ko-KR' });
  if (sub) txt(s, sub, { x: 0.5, y: 0.88, w: 12.3, h: 0.32, fontSize: 12, color: C.text2 });
  return s;
}

// =============================================================== 1 cover
pres.addSection({ title: '개요' });
{
  const s = pres.addSlide({ masterName: 'COVER', sectionTitle: '개요' });
  img(s, 'out/brand/zapwise_wordmark@8x.png', { x: 0.8, y: 1.3, w: 5.2 });
  s.addText('디자인 차트 v0.1', { placeholder: 'title', fontFace: F, lang: 'ko-KR' });
  txt(s, '앱 이름, 분위기, 색, 글꼴, 픽셀 규칙, 마스코트, 에셋, 컴포넌트, 화면 무드', { x: 0.8, y: 3.95, w: 6.0, h: 0.6, fontSize: 14, color: C.text2 });
  txt(s, 'Scan before you heat', { x: 0.8, y: 4.75, w: 6.0, h: 0.4, fontSize: 16, bold: true, color: C.accent3 });
  txt(s, 'Congressional App Challenge 2026 출품 준비   |   2026.10.12', { x: 0.8, y: 6.6, w: 6.5, h: 0.3, fontSize: 11, color: C.text2 });
  card(s, 7.4, 0.55, 5.53, 6.05);
  img(s, 'out/scene/kitchen_clean@6x.png', { x: 7.6, y: 0.75, h: 5.65 });
}

// =============================================================== 2 direction
{
  const s = slide('개요', '디자인 방향', '픽셀 아트로 그린 주방을 홈으로 두고, 정보는 부드러운 소프트 UI 카드에 담는다. 메인 색은 웜 파스텔 핑크이다.');
  const P = [
    ['out/icons/kitchen@8x.png', '사물은 픽셀로, 담는 그릇은 소프트 UI로', '주방 장면, 마스코트, 아이콘처럼 물건을 나타내는 것은 픽셀 아트로 그린다. 카드, 버튼, 입력칸처럼 내용을 담는 것은 소프트 UI로 만든다. 한 요소 안에서 두 방식을 섞지 않는다.'],
    ['out/icons/star@8x.png', '빛은 왼쪽 위에서 온다', '픽셀 아트의 밝은 면과 그림자, 소프트 UI의 흰 그림자와 분홍 그림자가 모두 같은 방향의 빛을 따른다. 두 스타일이 한 화면에서 어긋나지 않게 하는 규칙이다.'],
    ['out/icons/camera@8x.png', '화면마다 크게 눈에 띄는 것은 하나', '외곽선과 딱딱한 그림자가 있는 픽셀 버튼은 화면에 하나만 둔다. 나머지 선택지는 소프트 버튼으로 낮춘다.'],
    ['out/icons/check@8x.png', '결과는 색만으로 전하지 않는다', '노출 구간은 색, 아이콘, 단어, Zappy 표정을 함께 보여 준다. 색을 구분하기 어려운 사용자도 같은 정보를 얻는다.'],
  ];
  P.forEach((p, i) => {
    const x = 0.5 + (i % 2) * 6.25, y = 1.45 + Math.floor(i / 2) * 1.72, w = 6.0, h = 1.5;
    card(s, x, y, w, h);
    img(s, p[0], { x: x + 0.3, y: y + 0.3, w: 0.62 });
    txt(s, p[1], { x: x + 1.15, y: y + 0.22, w: w - 1.4, h: 0.35, fontSize: 15, bold: true });
    txt(s, p[2], { x: x + 1.15, y: y + 0.6, w: w - 1.4, h: 0.85, fontSize: 11.5, color: C.text2 });
  });
  card(s, 0.5, 5.0, 12.33, 1.85, { flat: true, fill: 'FBC9CF', line: 'FBC9CF' });
  txt(s, '참고 이미지에서 가져온 것', { x: 0.75, y: 5.15, w: 5, h: 0.3, fontSize: 13, bold: true });
  const refs = [
    ['소프트 UI 시안', '같은 색의 카드에 빛과 그림자를 주는 방식, 눌린 상태의 안쪽 그림자'],
    ['Focustown', '홈 가운데에 꾸며진 장면을 두고 아래에 큰 시작 버튼을 두는 배치'],
    ['Moodee', '장면 위에 떠 있는 퀘스트 배너와 완료 버튼'],
    ['Coffee & Sweets', '파스텔 핑크 바탕의 픽셀 소품과 짙은 외곽선'],
  ];
  refs.forEach((r, i) => {
    const x = 0.75 + i * 3.05;
    txt(s, [R(r[0], { bold: true, fontSize: 11.5, breakLine: true }), R(r[1], { fontSize: 10.5, color: C.text2 })], { x, y: 5.55, w: 2.85, h: 0.9 });
  });
  txt(s, '캐릭터, 그림, 로고는 가져오지 않았다. 주방과 소품, Zappy는 모두 새로 그렸다.', { x: 0.75, y: 6.45, w: 11.8, h: 0.3, fontSize: 10.5, color: C.accent3 });
}

// =============================================================== 3 name & logo
pres.addSection({ title: '브랜드' });
{
  const s = slide('브랜드', '이름과 로고', 'zap은 미국 구어로 전자레인지에 데운다는 뜻이다. 데우기 전에 한 번 더 생각하자는 뜻으로 wise를 붙였다.');
  card(s, 0.5, 1.4, 7.3, 3.2);
  img(s, 'out/brand/zapwise_wordmark@8x.png', { x: 1.1, y: 2.0, w: 6.1 });
  txt(s, 'i의 점은 번개로 바꿨다. 글자는 9px 높이 격자에 2px 획으로 그렸다.', { x: 0.8, y: 4.05, w: 6.8, h: 0.3, fontSize: 10.5, color: C.text2 });
  card(s, 8.1, 1.4, 4.73, 3.2);
  const ic = 'out/brand/app_icon_1024.png';
  img(s, ic, { x: 8.4, y: 1.75, w: 1.9 });
  img(s, ic, { x: 10.55, y: 2.45, w: 0.95 });
  img(s, ic, { x: 11.8, y: 2.85, w: 0.5 });
  txt(s, '1024 px\n앱스토어', { x: 8.4, y: 3.75, w: 1.9, h: 0.5, fontSize: 10, color: C.text2, align: 'center' });
  txt(s, '180 px\n홈 화면', { x: 10.3, y: 3.75, w: 1.45, h: 0.5, fontSize: 10, color: C.text2, align: 'center' });
  txt(s, '60 px\n설정', { x: 11.6, y: 3.75, w: 0.9, h: 0.5, fontSize: 10, color: C.text2, align: 'center' });
  const rules = [
    ['슬로건', 'Scan before you heat\nEscanea antes de calentar'],
    ['키우기', '원본 픽셀의 정수배로만 키운다. 4.5배처럼 끊어지는 배율은 픽셀이 뭉개진다.'],
    ['여백과 바탕', '로고 둘레에 글자 높이(9px)만큼 비운다. 바탕은 Strawberry Milk나 흰색만 쓴다.'],
    ['최소 크기', '원본 1배(71×21px)를 앱 화면에서는 2배 이상으로 보여 준다.'],
  ];
  rules.forEach((r, i) => {
    const x = 0.5 + i * 3.1;
    card(s, x, 4.9, 2.9, 1.75);
    txt(s, r[0], { x: x + 0.22, y: 5.08, w: 2.5, h: 0.3, fontSize: 13, bold: true });
    txt(s, r[1], { x: x + 0.22, y: 5.45, w: 2.5, h: 1.1, fontSize: 12, color: C.text2 });
  });
}

// =============================================================== 4 UI colors
{
  const s = slide('브랜드', '색 체계(UI)', '바탕과 글자는 Strawberry Milk와 Cocoa 두 색이 맡는다. 명암비는 Strawberry Milk 바탕 기준으로 계산하였다.');
  const tokens = [
    ['Strawberry Milk', 'FDE9E7', '앱 바탕, 소프트 표면', '기준 바탕'],
    ['Cocoa', '4B2E39', '본문 글자, 픽셀 외곽선', '10.3 : 1'],
    ['Cocoa 2', '8A5F6C', '보조 글자', '4.6 : 1'],
    ['Zap Rose', 'E0607A', '로고, 강조 그래픽', '2.9 : 1, 글자에 쓰지 않음'],
    ['Deep Rose', 'B23A57', '링크, 선택된 탭 글자', '5.0 : 1'],
    ['Strawberry', 'F59BAA', '픽셀 버튼 바탕', 'Cocoa 글자 5.8 : 1'],
    ['Blush', 'FBC9CF', '선택 상태 바탕, 버튼 광택', '장식'],
    ['Butter', 'FFE3A3', '퀘스트 진행, 중간 구간', 'Cocoa 글자 9.6 : 1'],
    ['Mint', 'A8DCC6', '낮음 구간, 완료', 'Cocoa 글자 7.8 : 1'],
    ['Peach', 'FFC4A3', '높음 구간, 가열', 'Cocoa 글자 7.8 : 1'],
  ];
  tokens.forEach((t, i) => {
    const x = 0.5 + (i % 5) * 2.49, y = 1.4 + Math.floor(i / 5) * 2.38, w = 2.3, h = 2.18;
    card(s, x, y, w, h);
    s.addShape(SH.ROUNDED_RECTANGLE, { x: x + 0.15, y: y + 0.15, w: w - 0.3, h: 0.95, rectRadius: 0.1, fill: { color: t[1] }, line: { color: t[1] === 'FDE9E7' ? 'E9C3C2' : t[1], width: 0.75 } });
    txt(s, [R(t[0], { bold: true, fontSize: 12.5, breakLine: true }), R('#' + t[1], { fontSize: 10.5, color: C.text2 })], { x: x + 0.18, y: y + 1.18, w: w - 0.3, h: 0.45 });
    txt(s, [R(t[2], { fontSize: 10.5, breakLine: true }), R(t[3], { fontSize: 10, color: C.accent3 })], { x: x + 0.18, y: y + 1.62, w: w - 0.3, h: 0.5 });
  });
  // proportion bar
  txt(s, '화면 면적 비율', { x: 0.5, y: 6.25, w: 2, h: 0.3, fontSize: 11, bold: true });
  const seg = [['FDE9E7', 0.62, 'Strawberry Milk 62%'], ['F59BAA', 0.14, '분홍 계열 14%'], ['4B2E39', 0.1, 'Cocoa 10%'], ['FFE3A3', 0.06, '파스텔 6%'], ['A8DCC6', 0.04, ''], ['E0607A', 0.04, 'Rose 4%']];
  let bx = 2.3;
  const bw = 10.5;
  seg.forEach((g) => {
    s.addShape(SH.RECTANGLE, { x: bx, y: 6.27, w: bw * g[1], h: 0.28, fill: { color: g[0] }, line: { color: 'E9C3C2', width: 0.5 } });
    if (g[2]) { const lw = Math.max(bw * g[1], 1.2); const lx = Math.min(bx, 12.83 - lw); txt(s, g[2], { x: lx, y: 6.6, w: lw, h: 0.25, fontSize: 9.5, color: C.text2, align: lx < bx ? 'right' : 'left' }); }
    bx += bw * g[1];
  });
}

// =============================================================== 5 pixel palette
{
  const s = slide('브랜드', '픽셀 팔레트 25색', '픽셀 아트에는 이 25색만 쓴다. 영문 한 글자는 스프라이트 코드에서 색을 부르는 이름이다.');
  const pal = [
    ['o', '4B2E39', 'Cocoa', '외곽선'], ['O', '7A4A5A', 'Plum', '진한 그림자, 다리'], ['d', '5A3646', 'Glass', '전자레인지 유리'], ['k', '3A2A33', 'Tray Black', 'CPET 트레이'], ['K', '5E4653', 'Tray Shade', '트레이 칸막이'],
    ['r', 'E0607A', 'Zap Rose', '로고, 하트'], ['R', 'B23A57', 'Deep Rose', '진한 강조'], ['p', 'F59BAA', 'Strawberry', 'Zappy 몸체, 수납장'], ['P', 'E27C8F', 'Strawberry Shade', '분홍 그림자'], ['l', 'FBC9CF', 'Blush', '분홍 밝은 면'],
    ['b', 'FDE9E7', 'Strawberry Milk', '벽, 바탕'], ['w', 'FFFFFF', 'White', '반사광, 눈'], ['c', 'FFF6F1', 'Porcelain', '접시, 타일'], ['g', 'D8CCD6', 'Steam', '금속 밝은 면'], ['G', 'A897A8', 'Pewter', '금속 그림자'],
    ['e', 'FFC4A3', 'Peach', '에어프라이어, 화분'], ['E', 'F29672', 'Apricot', '불꽃, 당근'], ['y', 'FFE3A3', 'Butter', '번개, 조리대'], ['Y', 'E8B85A', 'Honey', 'Zappy 안경, 손잡이'], ['n', 'D9A07E', 'Maple', '선반 나무'],
    ['N', 'B07657', 'Walnut', '나무 그림자'], ['m', 'A8DCC6', 'Mint', '냉장고, 용기 뚜껑'], ['M', '5FAF95', 'Sage', '잎, 채소'], ['s', 'C6E6F3', 'Sky', '유리 용기, 하늘'], ['S', '8CC4DE', 'Deep Sky', '유리 그림자'],
  ];
  pal.forEach((p, i) => {
    const col = i % 5, row = Math.floor(i / 5);
    const x = 0.5 + col * 2.49, y = 1.35 + row * 1.12;
    card(s, x, y, 2.33, 0.98, { flat: true });
    s.addShape(SH.RECTANGLE, { x: x + 0.12, y: y + 0.14, w: 0.7, h: 0.7, fill: { color: p[1] }, line: { color: '4B2E39', width: 1.5 } });
    txt(s, [R(p[0] + '  ' + p[2], { bold: true, fontSize: 11, breakLine: true }), R('#' + p[1], { fontSize: 9.5, color: C.text2, breakLine: true }), R(p[3], { fontSize: 9.5, color: C.text2 })], { x: x + 0.95, y: y + 0.12, w: 1.35, h: 0.78 });
  });
}

// =============================================================== 6 type
{
  const s = slide('브랜드', '글꼴', '픽셀 글꼴은 숫자와 제목에만 쓰고, 읽어야 하는 문장은 둥근 고딕으로 쓴다. 세 글꼴 모두 SIL Open Font License이다.');
  const fonts = [
    ['Pixelify Sans', '큰 숫자, 화면 제목, 소제목', '격자형 글꼴이라 픽셀 장면과 어울린다. 숫자 결과를 크게 보여 줄 때 쓴다.'],
    ['Nunito', '본문, 질문, 버튼, 안내', '획 끝이 둥글어 픽셀 요소와 함께 써도 딱딱하지 않다. 스페인어 악센트를 모두 지원한다.'],
    ['Galmuri11', '한국어 자료, 한국어판', '한글 픽셀 글꼴이다. 앱은 영어와 스페인어가 기본이므로 한국어 발표 자료에만 쓴다.'],
  ];
  fonts.forEach((f, i) => {
    const y = 1.4 + i * 1.22;
    card(s, 0.5, y, 5.2, 1.08);
    txt(s, [R(f[0], { bold: true, fontSize: 14, breakLine: true }), R(f[1], { fontSize: 11, color: C.accent3, breakLine: true }), R(f[2], { fontSize: 10.5, color: C.text2 })], { x: 0.72, y: y + 0.1, w: 4.8, h: 0.9 });
  });
  card(s, 5.95, 1.4, 6.88, 3.5);
  img(s, 'out/screens/comp_type.png', { x: 6.1, y: 1.55, w: 6.55 });
  const head = ['역할', '글꼴', '크기/줄 높이(pt)', '굵기'].map((t) => ({ text: t, options: { bold: true, color: 'FFFFFF', fill: { color: '4B2E39' }, fontFace: F, fontSize: 10 } }));
  const rows = [
    ['큰 숫자', 'Pixelify Sans', '40 / 44', '600'], ['화면 제목', 'Pixelify Sans', '22 / 26', '600'], ['소제목', 'Pixelify Sans', '17 / 20', '600'],
    ['질문, 버튼', 'Nunito', '17~18 / 24', '800'], ['본문', 'Nunito', '15 / 22', '600'], ['보조 설명', 'Nunito', '12.5 / 18', '700'],
  ].map((r, i) => r.map((c) => ({ text: c, options: { fontFace: F, fontSize: 10, color: '4B2E39', fill: { color: i % 2 ? 'FDE9E7' : 'FFFFFF' } } })));
  s.addTable([head, ...rows], { x: 0.5, y: 5.08, w: 8.2, colW: [1.8, 2.4, 2.4, 1.6], rowH: 0.25, border: { type: 'solid', pt: 0.5, color: 'E9C3C2' }, margin: [0.02, 0.06, 0.02, 0.06] });
  card(s, 8.95, 5.08, 3.88, 1.75, { fill: 'FBC9CF', line: 'FBC9CF', flat: true });
  txt(s, [R('쓰지 않는 것', { bold: true, fontSize: 12, breakLine: true }), R('모두 대문자로 쓴 라벨, 문장 전체를 픽셀 글꼴로 쓰는 것, 숫자와 단위를 다른 줄로 나누는 것', { fontSize: 10.5, color: C.text2 })], { x: 9.15, y: 5.3, w: 3.5, h: 1.45 });
}

// =============================================================== 7 pixel rules
pres.addSection({ title: '픽셀 아트' });
{
  const s = slide('픽셀 아트', '픽셀 규칙(격자, 배율, 빛)', '모든 픽셀 에셋은 같은 규칙으로 그렸다. 규칙이 같아야 나중에 학생이 직접 그린 소품도 주방에 섞여 보인다.');
  card(s, 0.5, 1.4, 5.3, 5.45);
  img(s, 'out/deck/zappy_grid.png', { x: 0.75, y: 1.62, w: 4.8 });
  txt(s, 'Zappy 34×34 격자, 굵은 선은 8px 간격', { x: 0.75, y: 6.5, w: 4.8, h: 0.25, fontSize: 10, color: C.text2, align: 'center' });
  const rules = [
    ['격자 크기', '아이콘 16×16, 소품 16~40px, 마스코트 34×34, 주방 장면 196×216.'],
    ['배율', '정수배로만 키운다. 앱 화면에서는 CSS 2배(기기 4배), 확대할 때는 최근접 보간을 쓴다.'],
    ['외곽선', '바깥쪽 1px을 Cocoa로 두른다. 순수한 검정은 쓰지 않는다.'],
    ['빛', '왼쪽 위 가장자리 1px을 밝게, 오른쪽 아래 1px을 어둡게 칠한다.'],
    ['소프트 UI 그림자', '흰 그림자는 왼쪽 위(−6, −6, 흐림 14), 분홍 그림자 #E9C3C2는 오른쪽 아래(6, 6, 흐림 14). 픽셀의 빛과 방향이 같다.'],
  ];
  rules.forEach((r, i) => {
    const y = 1.4 + i * 0.82;
    card(s, 6.1, y, 6.73, 0.7, { flat: true });
    txt(s, r[0], { x: 6.3, y: y + 0.12, w: 1.7, h: 0.45, fontSize: 12, bold: true, valign: 'middle' });
    txt(s, r[1], { x: 8.0, y: y + 0.1, w: 4.7, h: 0.52, fontSize: 10.5, color: C.text2, valign: 'middle' });
  });
  card(s, 6.1, 5.6, 6.73, 1.25, { flat: true });
  img(s, 'out/deck/scale_good.png', { x: 6.35, y: 5.75, h: 0.95 });
  txt(s, '정수배(6배)', { x: 8.0, y: 5.95, w: 1.3, h: 0.5, fontSize: 10.5, bold: true, valign: 'middle' });
  img(s, 'out/deck/scale_bad.png', { x: 9.45, y: 5.75, h: 0.95 });
  txt(s, '4.5배 후 확대, 경계가 번진다', { x: 11.1, y: 5.85, w: 1.65, h: 0.75, fontSize: 10.5, color: C.accent3, valign: 'middle' });
}

// =============================================================== 8 mascot
{
  const s = slide('픽셀 아트', '마스코트 Zappy', '안경을 쓴 분홍 전자레인지이다. 안경은 wise, 머리 위 번개는 zap을 뜻한다.');
  const ex = [
    ['neutral', '기본', '홈 주방, 중간 구간 결과'],
    ['happy', '웃음', '낮음 구간, 접시로 옮겼을 때'],
    ['thinking', '생각', '제품 인식과 계산 중'],
    ['worried', '걱정', '높음 구간, 사용 한계 온도 초과'],
    ['celebrate', '축하', '주방 퀘스트 달성'],
    ['sleepy', '졸림', '며칠 기록이 없을 때 홈'],
  ];
  ex.forEach((e, i) => {
    const x = 0.5 + (i % 3) * 2.75, y = 1.4 + Math.floor(i / 3) * 2.75, w = 2.55, h = 2.55;
    card(s, x, y, w, h);
    const p = `out/mascot/zappy_${e[0]}@8x.png`;
    const [pw, ph] = SIZES[p];
    const ih = 1.45 * ph / 272; // Zappy body height is 34 px = 272 px at 8x
    const iw = ih * pw / ph;
    s.addImage({ path: p, x: x + (w - iw) / 2, y: y + 0.2 + (1.5 - ih), w: iw, h: ih });
    txt(s, [R(e[1] + '  ' + e[0], { bold: true, fontSize: 12.5, breakLine: true }), R(e[2], { fontSize: 10.5, color: C.text2 })], { x: x + 0.2, y: y + 1.85, w: w - 0.35, h: 0.62, align: 'center' });
  });
  card(s, 8.85, 1.4, 3.98, 5.3, { fill: 'FBC9CF', line: 'FBC9CF', flat: true });
  txt(s, [
    R('성격과 말투', { bold: true, fontSize: 14, breakLine: true }),
    R('데우기 전에 한 번 같이 확인해 주는 친구이다. 말은 짧고 다정하게 한다.', { fontSize: 12, color: C.text2, breakLine: true }),
    R(' ', { fontSize: 6, breakLine: true }),
    R('하지 않는 것', { bold: true, fontSize: 14, breakLine: true }),
    R('사용자를 혼내거나 겁주지 않는다. 걱정 표정은 쓰지만 화난 표정과 우는 표정은 만들지 않는다.', { fontSize: 12, color: C.text2, breakLine: true }),
    R(' ', { fontSize: 6, breakLine: true }),
    R('표정과 결과 구간', { bold: true, fontSize: 14, breakLine: true }),
    R('결과 화면의 표정은 낮음, 중간, 높음 구간에 하나씩 맞춘다. 표정만 보고도 구간을 알 수 있게 하되, 칩의 단어와 아이콘을 항상 함께 보여 준다.', { fontSize: 12, color: C.text2, breakLine: true }),
    R(' ', { fontSize: 6, breakLine: true }),
    R('주방 안에서', { bold: true, fontSize: 14, breakLine: true }),
    R('Zappy는 조리대 위 전자레인지 자리에 산다. 누르면 전자레인지 출력 등록이 열린다.', { fontSize: 12, color: C.text2 }),
  ], { x: 9.08, y: 1.6, w: 3.55, h: 5.0, paraSpaceAfter: 2 });
}

// =============================================================== 9 objects
{
  const s = slide('픽셀 아트', '주방 소품과 용기 에셋', '장비와 용기는 앱에서 등록하는 대상이고, 장식 소품은 주방 꾸미기 보상으로 쓴다.');
  const groups = [
    ['장비', [['ZAPPY', '전자레인지(Zappy)'], ['stove', '가스레인지'], ['pot', '냄비'], ['air_fryer', '에어프라이어'], ['fridge', '냉장고']]],
    ['용기', [['glass_box', '유리 용기'], ['plates', '도자기 접시'], ['cpet_tray', 'CPET 트레이'], ['pp_cup', 'PP 컵'], ['foam_box', '발포 용기'], ['meal_box', '냉동 도시락']]],
    ['장식', [['window', '창문'], ['plant', '화분'], ['shelf', '선반'], ['lamp', '조명'], ['wall_clock', '시계'], ['sparkle', '터치 힌트']]],
  ];
  const PX = 0.03; // inches per sprite pixel on this slide
  let y = 1.35;
  groups.forEach((g) => {
    const rowH = g[0] === '장비' ? 2.45 : 1.55;
    card(s, 0.5, y, 12.33, rowH - 0.15, { flat: true });
    txt(s, g[0], { x: 0.75, y: y + 0.15, w: 1.0, h: 0.35, fontSize: 14, bold: true });
    let x = 1.85;
    g[1].forEach((o) => {
      const p = o[0] === 'ZAPPY' ? 'out/mascot/zappy_neutral@8x.png' : `out/objects/${o[0]}@8x.png`;
      const [pw, ph] = SIZES[p];
      let w = (pw / 8) * PX * (g[0] === '장비' ? 1.0 : 1.25), h = w * ph / pw;
      const maxH = rowH - 0.65;
      if (h > maxH) { h = maxH; w = h * pw / ph; }
      const slotW = Math.max(w, 1.15) + 0.35;
      s.addImage({ path: p, x: x + (slotW - w) / 2, y: y + 0.12 + (maxH - h), w, h });
      txt(s, o[1], { x, y: y + rowH - 0.47, w: slotW, h: 0.25, fontSize: 10.5, color: C.text2, align: 'center' });
      x += slotW + 0.15;
    });
    y += rowH;
  });
}

// =============================================================== 10 home map
{
  const s = slide('픽셀 아트', '주방 홈 터치 영역 맵', '주방의 물건을 누르면 등록이 열리고, 계산은 아래쪽 픽셀 버튼으로만 시작한다.');
  card(s, 0.5, 1.35, 5.4, 5.55);
  const sw = 4.75, sx = 0.5 + (5.4 - 4.75) / 2, sy = 1.5;
  const k = sw / 196;
  img(s, 'out/scene/kitchen_clean@6x.png', { x: sx, y: sy, w: sw });
  const hs = [
    ['1', 'zappy', '전자레인지(Zappy)', '장비 등록, 문 안쪽 라벨을 찍어 출력(W) 인식'],
    ['2', 'air_fryer', '에어프라이어', '장비 등록, 가열 방법 선택지에 추가'],
    ['3', 'add_slot', '빈 자리', '새 장비 추가'],
    ['4', 'stove', '가스레인지와 냄비', '장비 등록, 냄비로 옮겨 데우기 선택지'],
    ['5', 'shelf', '용기 선반', '용기 등록(F4), 등록한 용기 목록'],
    ['6', 'fridge', '냉장고 메모', '이번 주 주방 퀘스트와 보상'],
  ];
  const HOT = { zappy: [46, 120, 34, 34], air_fryer: [88, 129, 22, 25], add_slot: [117, 131, 28, 22], stove: [152, 156, 34, 38], shelf: [120, 74, 72, 56], fridge: [2, 124, 38, 72] };
  hs.forEach((h, i) => {
    const [hx, hy, hw, hh] = HOT[h[1]];
    s.addShape(SH.ROUNDED_RECTANGLE, { x: sx + hx * k, y: sy + hy * k, w: hw * k, h: hh * k, rectRadius: 0.05, fill: { color: 'FFFFFF', transparency: 100 }, line: { color: 'B23A57', width: 2, dashType: 'dash' } });
    s.addText(h[0], T({ shape: SH.OVAL, x: sx + hx * k - 0.14, y: sy + hy * k - 0.14, w: 0.3, h: 0.3, fill: { color: 'B23A57' }, line: { color: 'FFFFFF', width: 1 }, color: 'FFFFFF', bold: true, fontSize: 10, align: 'center', valign: 'middle' }));
    const y = 1.35 + i * 0.74;
    card(s, 6.2, y, 6.63, 0.62, { flat: true });
    s.addText(h[0], T({ shape: SH.OVAL, x: 6.35, y: y + 0.16, w: 0.3, h: 0.3, fill: { color: 'B23A57' }, line: { color: 'B23A57', width: 1 }, color: 'FFFFFF', bold: true, fontSize: 10, align: 'center', valign: 'middle' }));
    txt(s, h[2], { x: 6.8, y: y + 0.08, w: 2.2, h: 0.46, fontSize: 12, bold: true, valign: 'middle' });
    txt(s, h[3], { x: 9.0, y: y + 0.08, w: 3.7, h: 0.46, fontSize: 10.5, color: C.text2, valign: 'middle' });
  });
  card(s, 6.2, 5.85, 6.63, 1.05, { fill: 'FBC9CF', line: 'FBC9CF', flat: true });
  txt(s, [R('장면 밖', { bold: true, fontSize: 12, breakLine: true }), R('위쪽 퀘스트 배너와 별 개수, 아래쪽 "Scan before you heat" 버튼(F1 시작), 하단 탭 4개. 반짝이 표시는 처음 며칠만 보이는 터치 힌트이다.', { fontSize: 10.5, color: C.text2 })], { x: 6.4, y: 5.95, w: 6.3, h: 0.9 });
}

// =============================================================== 11 icons
{
  const s = slide('픽셀 아트', '아이콘 16종', '16×16 격자, 파스텔 바탕에 Cocoa 외곽선. 탭과 버튼에서는 32pt(2배)로 쓴다.');
  const icons = [
    ['kitchen', '주방', '탭'], ['log', '기록', '탭'], ['learn', '배우기', '탭'], ['me', '내 정보', '탭'],
    ['camera', '촬영', '시작 버튼'], ['plate', '접시', '옮겨 담기'], ['container', '용기', '선반 용기'], ['swap', '바꾸기', '조건 변경, 젓기'],
    ['timer', '시간', '조리 시간'], ['flame', '불', '가스레인지, 가열'], ['info', '정보', '중간 구간, 안내'], ['alert', '주의', '높음 구간, 한계 온도'],
    ['check', '완료', '낮음 구간, 완료'], ['star', '별', '퀘스트 보상'], ['quest', '깃발', '주방 퀘스트'], ['heart', '하트', '가족 프로필'],
  ];
  icons.forEach((ic, i) => {
    const x = 0.5 + (i % 8) * 1.555, y = 1.45 + Math.floor(i / 8) * 2.6;
    card(s, x, y, 1.4, 2.35);
    img(s, `out/icons/${ic[0]}@8x.png`, { x: x + 0.3, y: y + 0.25, w: 0.8 });
    img(s, `out/icons/${ic[0]}@8x.png`, { x: x + 0.55, y: y + 1.17, w: 0.3 });
    txt(s, [R(ic[1], { bold: true, fontSize: 11.5, breakLine: true }), R(ic[2], { fontSize: 9.5, color: C.text2 })], { x: x + 0.08, y: y + 1.62, w: 1.24, h: 0.65, align: 'center' });
  });
}

// =============================================================== 12 components
pres.addSection({ title: '컴포넌트' });
{
  const s = slide('컴포넌트', '소프트 UI 컴포넌트', '표면은 볼록한 카드와 오목한 칸 두 가지이다. 누른 상태는 안쪽 그림자로, 선택된 상태는 Deep Rose 글자로 보여 준다.');
  const items = [
    ['out/screens/comp_surfaces.png', '표면과 말풍선', '볼록 카드(반경 24), 오목 칸(반경 18). 말풍선은 Zappy가 말할 때만 쓰는 픽셀 스타일이다.', 0.5, 1.3, 6.1],
    ['out/screens/comp_controls.png', '소프트 버튼, 토글, 진행 막대', '나머지 선택지는 소프트 버튼으로 낮춘다. 진행 막대는 오목 칸 위에 Butter를 채운다.', 6.75, 1.3, 6.08],
    ['out/screens/comp_ctas.png', '픽셀 버튼(기본, 누름, 비활성)', '3pt Cocoa 테두리, 아래로 5pt 딱딱한 그림자. 누르면 5pt 내려간다. 화면당 하나만 둔다.', 0.5, 3.2, 6.1],
    ['out/screens/comp_chips.png', '구간 칩과 Zappy 표정', '낮음은 Mint와 체크, 중간은 Butter와 정보, 높음은 Peach와 주의 아이콘을 쓴다.', 6.75, 3.2, 6.08],
    ['out/screens/comp_tabs.png', '하단 탭', '선택된 탭은 오목하게 들어가고 글자가 Deep Rose로 바뀐다.', 0.5, 5.1, 4.2],
  ];
  items.forEach((it) => {
    const [p, t, d, x, y, w] = it;
    card(s, x, y, w, 1.75, { fill: 'FDE9E7', line: 'F0D2D1' });
    const [pw, ph] = SIZES[p];
    let iw = w - 0.3, ih = iw * ph / pw;
    if (ih > 1.0) { ih = 1.0; iw = ih * pw / ph; }
    s.addImage({ path: p, x: x + 0.15, y: y + 0.08, w: iw, h: ih });
    txt(s, [R(t, { bold: true, fontSize: 11.5, breakLine: true }), R(d, { fontSize: 10, color: C.text2 })], { x: x + 0.2, y: y + 1.1, w: w - 0.35, h: 0.62 });
  });
  card(s, 4.9, 5.1, 7.93, 1.75, { fill: 'FBC9CF', line: 'FBC9CF', flat: true });
  const tok = [['반경', '카드 24, 오목 칸 18, 버튼 16, 칩 999'], ['볼록 그림자', '6 6 14 #E9C3C2, −6 −6 14 #FFFFFF'], ['오목 그림자', 'inset 4 4 9 #E9C3C2, inset −4 −4 9 #FFFFFF'], ['여백', '화면 좌우 16, 카드 안 16, 요소 간 12'], ['터치 영역', '최소 44×44pt']];
  tok.forEach((t, i) => {
    txt(s, [R(t[0] + '  ', { bold: true, fontSize: 10.5 }), R(t[1], { fontSize: 10.5, color: C.text2 })], { x: 5.1, y: 5.22 + i * 0.31, w: 7.5, h: 0.3 });
  });
}

// =============================================================== 13 screens
{
  const s = slide('컴포넌트', '화면 무드 3종', '실제 화면 디자인 전의 분위기 시안이다. 숫자는 레이아웃 확인용 예시 값이다.');
  const scr = [
    ['out/screens/home.png', '내 주방(홈)', '퀘스트 배너, 픽셀 주방, 시작 버튼, 하단 탭'],
    ['out/screens/recipe.png', '조리법', '제조사 안내와 내 출력 환산 시간을 먼저 보여 주고 조건 변경 여부를 묻는다'],
    ['out/screens/result.png', '결과', '허용량 대비 %, 범위, 구간 칩, 가족 비교, 낮추는 방법'],
  ];
  scr.forEach((c, i) => {
    const x = 0.5 + i * 4.15;
    card(s, x, 1.35, 3.95, 5.6);
    img(s, c[0], { x: x + 0.2, y: 1.5, h: 5.3 });
    txt(s, [R(c[1], { bold: true, fontSize: 13, breakLine: true }), R(c[2], { fontSize: 10.5, color: C.text2 })], { x: x + 2.68, y: 1.6, w: 1.18, h: 3.5 });
  });
}

// =============================================================== 14 voice
{
  const s = slide('컴포넌트', '문구 원칙(영어, 스페인어 UI)', '버튼은 누르면 일어날 일을 동사로 쓰고, 결과는 추정임을 함께 밝힌다.');
  const head = ['원칙', '이렇게 쓴다', '이렇게 쓰지 않는다'].map((t) => ({ text: t, options: { bold: true, color: 'FFFFFF', fill: { color: '4B2E39' }, fontFace: F, fontSize: 12 } }));
  const rows = [
    ['동사로 짧게', 'Scan before you heat', 'Start analysis'],
    ['혼내지 않는다', 'Ways to lower it', 'Danger! Toxic level'],
    ['추정임을 밝힌다', 'This is an estimate, not a diagnosis.', 'Your food is safe.'],
    ['계산 범위를 밝힌다', 'Counts what moves from the container during heating only.', '(범위 설명 없이 숫자만)'],
    ['같은 행동은 같은 이름으로', 'Save how I heated it, 저장 후 알림 Saved', 'Submit, 저장 후 알림 Done'],
    ['스페인어도 같은 길이로', 'Escanea antes de calentar', '긴 설명형 문장'],
  ].map((r, i) => r.map((c, j) => ({ text: c, options: { fontFace: F, fontSize: 12, color: j === 2 ? 'B23A57' : '4B2E39', bold: j === 0, fill: { color: i % 2 ? 'FDE9E7' : 'FFFFFF' } } })));
  s.addTable([head, ...rows], { x: 0.5, y: 1.45, w: 12.33, colW: [2.6, 5.4, 4.33], rowH: 0.62, border: { type: 'solid', pt: 0.5, color: 'E9C3C2' }, margin: 0.1, valign: 'middle' });
  card(s, 0.5, 6.0, 12.33, 0.85, { fill: 'FBC9CF', line: 'FBC9CF', flat: true });
  txt(s, '구간 이름은 Lower, Middle, Higher(스페인어 Bajo, Medio, Alto)로 고정한다. Safe, Danger처럼 안전을 판정하는 단어는 쓰지 않는다.', { x: 0.75, y: 6.12, w: 11.9, h: 0.6, fontSize: 11.5, valign: 'middle' });
}

// =============================================================== 15 assets & next
pres.addSection({ title: '정리' });
{
  const s = slide('정리', '에셋 묶음과 다음 단계', '모든 픽셀 에셋은 코드로 격자를 찍어 만들었고, PNG 원본(1배), 확대본, SVG를 함께 넣었다.');
  card(s, 0.5, 1.4, 6.0, 5.45);
  txt(s, [
    R('ZapWise_assets', { bold: true, fontSize: 12, breakLine: true }),
    R('brand  워드마크, 앱 아이콘 1024px', { fontSize: 11, breakLine: true }),
    R('mascot  Zappy 표정 6종', { fontSize: 11, breakLine: true }),
    R('objects  장비, 용기, 장식 16종', { fontSize: 11, breakLine: true }),
    R('icons  UI 아이콘 16종(1, 2, 4, 8배)', { fontSize: 11, breakLine: true }),
    R('scene  주방 홈 장면, 터치 힌트 있음과 없음', { fontSize: 11, breakLine: true }),
    R('screens  컴포넌트와 화면 무드 캡처', { fontSize: 11, breakLine: true }),
    R('source  픽셀 엔진과 스프라이트 코드(Python), 화면 무드 HTML, CSS 토큰', { fontSize: 11, breakLine: true }),
    R(' ', { fontSize: 6, breakLine: true }),
    R('글꼴 라이선스', { bold: true, fontSize: 12, breakLine: true }),
    R('Pixelify Sans, Nunito, Galmuri11 모두 SIL Open Font License 1.1', { fontSize: 11, color: C.text2 }),
  ], { x: 0.75, y: 1.6, w: 5.6, h: 3.6, paraSpaceAfter: 4 });
  s.addShape(SH.ROUNDED_RECTANGLE, { x: 0.75, y: 5.2, w: 5.5, h: 1.4, rectRadius: 0.12, fill: { color: 'FDE9E7' }, line: { color: 'FDE9E7', width: 0.5 } });
  img(s, 'out/mascot/zappy_happy@8x.png', { x: 0.95, y: 5.35, h: 1.1 });
  ['plate', 'container', 'camera', 'star', 'learn'].forEach((n, i) => img(s, `out/icons/${n}@8x.png`, { x: 2.3 + i * 0.78, y: 5.6, w: 0.6 }));
  const nx = [
    ['화면 전체 디자인', 'F1 흐름을 따라 촬영, 제품 확인, 조리법, 조건 변경, 결과, 기록 화면과 등록 시트를 그린다.'],
    ['키 비주얼', '힉스필드가 연결되면 Zappy와 주방을 바탕으로 앱스토어 이미지와 발표 영상용 그림을 만든다.'],
    ['AI 사용 공개 목록', '이미지 생성 도구를 쓰면 쓴 도구와 결과물을 CAC 공개 목록에 적는다.'],
    ['구간 기준 확정', 'Lower, Middle, Higher를 나누는 % 기준은 민감도 분석 뒤 정한다.'],
  ];
  nx.forEach((n, i) => {
    const y = 1.4 + i * 1.38;
    card(s, 6.8, y, 6.03, 1.2);
    img(s, 'out/icons/quest@8x.png', { x: 7.0, y: y + 0.32, w: 0.5 });
    txt(s, [R(n[0], { bold: true, fontSize: 12.5, breakLine: true }), R(n[1], { fontSize: 10.5, color: C.text2 })], { x: 7.7, y: y + 0.15, w: 4.95, h: 0.95 });
  });
}

(async () => {
  await pres.writeFile({ fileName: OUT });
  await applyTheme(OUT, THEME);
  console.log('wrote', OUT);
})();
