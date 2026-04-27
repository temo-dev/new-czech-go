// Mock data for A2 Mluveni Sprint

const COURSES = [
  {
    id: 'a2-pobyt',
    title: 'Ôn thi A2 trvalý pobyt',
    sub: 'Modelový test A2 — NPI ČR',
    desc: 'Lộ trình 8 tuần luyện đủ 4 kỹ năng cho kỳ thi xin thẻ thường trú.',
    accent: T.brand, accentBg: '#FFE5D2', illoBg: '#FF8A4A',
    weeks: 8, modules: 8, learners: '2,140',
    progress: 0.32, badge: 'Đang học', emoji: '📝',
  },
  {
    id: 'a2-conv',
    title: 'Tiếng Séc giao tiếp hằng ngày',
    sub: 'Văn phòng • Bác sĩ • Cửa hàng',
    desc: 'Hội thoại thực tế với người Séc bản xứ trong các tình huống thường gặp.',
    accent: '#0F3D3A', accentBg: '#D9E5E3', illoBg: '#1F6E68',
    weeks: 6, modules: 6, learners: '1,308',
    progress: 0, badge: 'Chưa bắt đầu', emoji: '☕',
  },
  {
    id: 'b1-prep',
    title: 'Khởi động B1',
    sub: 'Tiếp nối sau A2',
    desc: 'Mở rộng vốn từ và ngữ pháp để chuẩn bị cho mục tiêu xa hơn.',
    accent: '#5C3A6E', accentBg: '#EBE0F0', illoBg: '#7A5089',
    weeks: 10, modules: 10, learners: '412',
    progress: 0, badge: 'Sắp ra mắt', locked: true, emoji: '🌱',
  },
];

const MODULES = [
  { n: 1, title: 'Bản thân & gia đình', skills: 6, status: 'done',     desc: 'Giới thiệu, kể về người thân, mô tả sinh hoạt.' },
  { n: 2, title: 'Công việc & nghề nghiệp', skills: 6, status: 'done', desc: 'Nói về công việc, mô tả ngày làm việc, đồng nghiệp.' },
  { n: 3, title: 'Nhà ở & khu vực sống', skills: 6, status: 'active', desc: 'Mô tả nhà, hàng xóm, dịch vụ trong khu phố.' },
  { n: 4, title: 'Sức khỏe & bác sĩ',    skills: 6, status: 'next',   desc: 'Đặt lịch, kể triệu chứng, hiểu lời khuyên y tế.' },
  { n: 5, title: 'Mua sắm & dịch vụ',    skills: 6, status: 'locked', desc: 'Cửa hàng, bưu điện, ngân hàng, ngân sách hằng ngày.' },
  { n: 6, title: 'Đi lại & giao thông',  skills: 6, status: 'locked', desc: 'Hỏi đường, mua vé, đặt taxi, lịch tàu xe.' },
  { n: 7, title: 'Thời tiết & du lịch',  skills: 6, status: 'locked', desc: 'Kế hoạch cuối tuần, kể chuyến đi đã trải qua.' },
  { n: 8, title: 'Ôn tập & Mock test',   skills: 4, status: 'locked', desc: 'Đề thi mô phỏng đầy đủ + nghe phản hồi tổng kết.' },
];

const SKILLS = [
  { id: 'speak',   name: 'Nói',      cz: 'Mluvení',     icon: 'mic',     active: true,  count: 12, accent: T.brand, soft: T.brandSoft, ink: T.brandInk },
  { id: 'listen',  name: 'Nghe',     cz: 'Poslech',     icon: 'ear',     active: false, count: 10, accent: '#2E5F4A', soft: '#DEEDE4', ink: '#173524' },
  { id: 'read',    name: 'Đọc',      cz: 'Čtení',       icon: 'book',    active: false, count: 14, accent: '#7A5A2E', soft: '#F1E8DA', ink: '#3F2F18' },
  { id: 'write',   name: 'Viết',     cz: 'Psaní',       icon: 'pencil',  active: false, count: 8,  accent: '#5C3A6E', soft: '#EBE0F0', ink: '#321F3D' },
  { id: 'vocab',   name: 'Từ vựng',  cz: 'Slovní zásoba', icon: 'word', active: false, count: 24, accent: '#A6502B', soft: '#F5E1D5', ink: '#4F2614' },
  { id: 'grammar', name: 'Ngữ pháp', cz: 'Gramatika',   icon: 'grammar', active: false, count: 18, accent: '#2A4F6E', soft: '#DDE7F0', ink: '#15293B' },
];

const EXERCISES = [
  { n: 1, title: 'Giới thiệu bản thân',  uloha: 'Úloha 1', dur: '1–2 phút', desc: 'Tên, tuổi, gia đình, công việc, sở thích.', done: true,  level: 'ready' },
  { n: 2, title: 'Mô tả ảnh: Trong căn bếp', uloha: 'Úloha 2', dur: '2 phút', desc: 'Quan sát ảnh và mô tả đồ vật, hành động.', done: true,  level: 'almost' },
  { n: 3, title: 'Hỏi & đáp: Đặt lịch hẹn', uloha: 'Úloha 3', dur: '3 phút', desc: 'Đối thoại đặt lịch tại phòng khám.', done: true,  level: 'needs' },
  { n: 4, title: 'Tình huống: Khiếu nại tiền nhà', uloha: 'Úloha 4', dur: '3 phút', desc: 'Trình bày vấn đề và đề xuất giải pháp với chủ nhà.', done: false, level: null },
  { n: 5, title: 'Mô tả: Ngôi nhà của tôi', uloha: 'Úloha 2', dur: '2 phút', desc: 'Kể về nơi bạn đang ở, các phòng và tiện nghi.', done: false, level: null },
  { n: 6, title: 'Hội thoại: Hàng xóm mới', uloha: 'Úloha 3', dur: '3 phút', desc: 'Làm quen, hỏi thăm, đề nghị giúp đỡ.', done: false, level: null },
];

const TRANSCRIPT_RAW = "Dobrý den, jmenuju se Lan a bydlím v Praze už pět let. Pracuju jako účetní v malé firmě v Karlíně. Můj manžel je kuchař. Máme jednu dceru, je jí osm let a chodí do druhý třídy. O víkendu rádi chodíme do parku nebo na výlet. Taky se učím česky každý večer.";

const TRANSCRIPT_FIXED = [
  { t: 'Dobrý den, ', ok: true },
  { t: 'jmenuju se Lan ', ok: true },
  { t: 'a bydlím v Praze ', ok: true },
  { t: 'už pět let', ok: true, note: 'Tốt — đúng cách dùng „už" với khoảng thời gian.' },
  { t: '. ', ok: true },
  { t: 'Pracuju jako účetní ', ok: true },
  { t: 'v malé firmě', ok: true },
  { t: ' v Karlíně. ', ok: true },
  { t: 'Můj manžel je kuchař. ', ok: true },
  { t: 'Máme jednu dceru, ', ok: true },
  { t: 'je jí osm let ', ok: true },
  { t: 'a chodí do ', ok: true },
  { t: 'druhý', fix: 'druhé', note: 'Lỗi cách: số thứ tự „druhá" → genitiv „druhé".' },
  { t: ' třídy. ', ok: true },
  { t: 'O víkendu rádi chodíme ', ok: true },
  { t: 'do parku nebo na výlet. ', ok: true },
  { t: 'Taky ', ok: true },
  { t: 'se učím česky', ok: true },
  { t: ' každý večer.', ok: true },
];

const STRENGTHS = [
  'Phát âm rõ, tốc độ tự nhiên, ít ngắt giữa câu.',
  'Sử dụng đúng „už" với khoảng thời gian (5 năm).',
  'Câu mở đầu chuẩn cấu trúc thi: tên, nơi sống, công việc.',
];

const IMPROVEMENTS = [
  { tag: 'Ngữ pháp', text: 'Số thứ tự ở cách 2 (genitiv): „do druhé třídy", không phải „druhý".' },
  { tag: 'Từ vựng', text: 'Có thể thay „malá firma" bằng „malý podnik" để đa dạng hơn.' },
  { tag: 'Cấu trúc', text: 'Thêm 1 câu kết để bài nói có mở-thân-kết rõ ràng.' },
];

const TIPS = [
  'Luyện cách 2 (genitiv) với số thứ tự: prvního, druhého, třetího…',
  'Khi giới thiệu bản thân, kể thêm 1 sở thích cụ thể (s konkrétním příkladem).',
];

const HISTORY = [
  { id: 1, title: 'Giới thiệu bản thân', when: 'Hôm nay · 14:22', level: 'ready',  uloha: 'Úloha 1' },
  { id: 2, title: 'Mô tả: Trong căn bếp', when: 'Hôm qua · 21:08', level: 'almost', uloha: 'Úloha 2' },
  { id: 3, title: 'Đặt lịch hẹn',         when: '2 ngày trước',    level: 'needs',  uloha: 'Úloha 3' },
  { id: 4, title: 'Mock Test 01',         when: '3 ngày trước',    level: 'almost', uloha: 'Mock', score: '28/40' },
  { id: 5, title: 'Giới thiệu gia đình',  when: '4 ngày trước',    level: 'ready',  uloha: 'Úloha 1' },
  { id: 6, title: 'Khiếu nại dịch vụ',    when: '6 ngày trước',    level: 'not',    uloha: 'Úloha 4' },
];

const MOCK_TESTS = [
  { id: 1, title: 'Mock Test 01 — Bản thân & nhà ở', dur: 12, max: 40, pass: 24, parts: 4 },
  { id: 2, title: 'Mock Test 02 — Công việc & lịch hẹn', dur: 12, max: 40, pass: 24, parts: 4, tag: 'Mới' },
  { id: 3, title: 'Mock Test 03 — Sức khỏe & dịch vụ', dur: 12, max: 40, pass: 24, parts: 4 },
];

const MOCK_PARTS = [
  { n: 1, uloha: 'Úloha 1', name: 'Giới thiệu bản thân',  dur: '1–2′', max: 8, status: 'done',   score: 7 },
  { n: 2, uloha: 'Úloha 2', name: 'Mô tả ảnh',            dur: '2′',   max: 8, status: 'done',   score: 6 },
  { n: 3, uloha: 'Úloha 3', name: 'Hỏi & đáp',            dur: '3′',   max: 12, status: 'doing', score: null },
  { n: 4, uloha: 'Úloha 4', name: 'Tình huống & giải pháp', dur: '3′', max: 12, status: 'todo',  score: null },
];

window.MOCK = {
  COURSES, MODULES, SKILLS, EXERCISES,
  TRANSCRIPT_RAW, TRANSCRIPT_FIXED,
  STRENGTHS, IMPROVEMENTS, TIPS, HISTORY,
  MOCK_TESTS, MOCK_PARTS,
};
