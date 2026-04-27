// CMS Courses — list + hierarchy editor

const COURSES = [
  { id: 'a2', code: 'A2', title: 'Ôn thi A2 — trvalý pobyt', subtitle: 'Lộ trình 6 tuần · Speaking + Listening', modules: 12, exercises: 84, learners: 1840, status: 'Đang chạy', tone: 'ready', emoji: '🇨🇿', color: '#FF6A14' },
  { id: 'mock', code: 'MOCK', title: 'Bộ Mock Test A2 chính thức', subtitle: '8 đề thi đầy đủ 4 úloha', modules: 8, exercises: 32, learners: 920, status: 'Đang chạy', tone: 'ready', emoji: '🏆', color: '#0F3D3A' },
  { id: 'survival', code: 'SUR', title: 'Tiếng Séc sinh tồn', subtitle: 'Cho người mới sang · 3 tuần', modules: 6, exercises: 28, learners: 412, status: 'Bản nháp', tone: 'needs', emoji: '🧭', color: '#C28012' },
];

function CoursesPage({ go }) {
  return (
    <div>
      <PageHeader
        title="Khóa học"
        subtitle="Quản lý cấu trúc Course → Module → Skill → Exercise. Kéo-thả để sắp lại."
        actions={<>
          <Btn variant="ghost" icon="filter">Lọc</Btn>
          <Btn variant="primary" icon="plus">Khóa học mới</Btn>
        </>}
      />
      <div style={{ padding: '0 24px 28px', display: 'grid', gridTemplateColumns: 'repeat(3, 1fr)', gap: 16 }}>
        {COURSES.map(c => (
          <Card key={c.id} padded={false} onClick={() => go('course-detail', { id: c.id })} style={{ overflow: 'hidden', transition: 'transform .15s, box-shadow .15s' }}>
            <div style={{ height: 120, background: c.color, position: 'relative', display: 'flex', alignItems: 'center', justifyContent: 'center', overflow: 'hidden' }}>
              <div style={{ position: 'absolute', inset: 0, opacity: 0.18, backgroundImage: 'radial-gradient(circle at 20% 30%, #fff 2px, transparent 2px), radial-gradient(circle at 70% 70%, #fff 2px, transparent 2px)', backgroundSize: '40px 40px' }} />
              <div style={{ fontSize: 56, filter: 'drop-shadow(0 2px 4px rgba(0,0,0,0.15))' }}>{c.emoji}</div>
              <div style={{ position: 'absolute', top: 12, left: 12, padding: '3px 8px', background: 'rgba(0,0,0,0.25)', backdropFilter: 'blur(6px)', borderRadius: 6, color: '#fff', fontSize: 10.5, fontWeight: 700, letterSpacing: 0.5, fontFamily: C.mono }}>{c.code}</div>
              <div style={{ position: 'absolute', top: 12, right: 12 }}><Tag tone={c.tone} size="sm">{c.status}</Tag></div>
            </div>
            <div style={{ padding: 18 }}>
              <div style={{ fontFamily: C.display, fontSize: 18, fontWeight: 600, letterSpacing: -0.3, lineHeight: 1.15 }}>{c.title}</div>
              <div style={{ fontSize: 12.5, color: C.ink3, marginTop: 4 }}>{c.subtitle}</div>
              <div style={{ display: 'flex', gap: 18, marginTop: 14, paddingTop: 14, borderTop: '1px solid ' + C.divider }}>
                <Mini label="Module" value={c.modules} />
                <Mini label="Bài tập" value={c.exercises} />
                <Mini label="Học viên" value={c.learners.toLocaleString('vi')} />
              </div>
            </div>
          </Card>
        ))}
      </div>
    </div>
  );
}

function Mini({ label, value }) {
  return (
    <div>
      <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, color: C.ink }}>{value}</div>
      <div style={{ fontSize: 10.5, color: C.ink3, fontWeight: 600, letterSpacing: 0.4, textTransform: 'uppercase', marginTop: 1, whiteSpace: 'nowrap' }}>{label}</div>
    </div>
  );
}

function CourseDetail({ go, courseId }) {
  const [openModule, setOpenModule] = React.useState(2);
  const modules = [
    { id: 1, title: 'Tuần 1 · Chào hỏi & tự giới thiệu', skills: 4, exercises: 14, status: 'Đã publish', tone: 'ready' },
    { id: 2, title: 'Tuần 2 · Đời sống hàng ngày', skills: 4, exercises: 12, status: 'Đã publish', tone: 'ready' },
    { id: 3, title: 'Tuần 3 · Mua sắm & dịch vụ', skills: 4, exercises: 16, status: 'Đang viết', tone: 'almost' },
    { id: 4, title: 'Tuần 4 · Y tế & cơ quan công', skills: 5, exercises: 18, status: 'Đang viết', tone: 'almost' },
    { id: 5, title: 'Tuần 5 · Nhà ở & hợp đồng', skills: 4, exercises: 14, status: 'Bản nháp', tone: 'needs' },
    { id: 6, title: 'Tuần 6 · Tổng ôn + 2 mock', skills: 3, exercises: 10, status: 'Bản nháp', tone: 'needs' },
  ];
  const skills = [
    { id: 's1', title: 'Đặt lịch khám bệnh', level: 'A2', exercises: 4, donut: 75 },
    { id: 's2', title: 'Mua vé tàu', level: 'A2', exercises: 4, donut: 100 },
    { id: 's3', title: 'Hỏi đường', level: 'A1', exercises: 3, donut: 60 },
    { id: 's4', title: 'Trả lại hàng ở cửa hàng', level: 'A2', exercises: 5, donut: 0 },
  ];
  return (
    <div>
      <div style={{ padding: '24px 24px 18px', display: 'flex', gap: 20, alignItems: 'flex-start' }}>
        <div style={{ width: 88, height: 88, borderRadius: 18, background: C.brand, display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 48, flexShrink: 0, boxShadow: C.shadowMd }}>🇨🇿</div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Tag tone="brand" size="sm">A2</Tag>
            <Tag tone="ready" size="sm">Đang chạy</Tag>
            <span style={{ fontSize: 11.5, color: C.ink3 }}>· cập nhật 2 ngày trước</span>
          </div>
          <div style={{ fontFamily: C.display, fontSize: 30, fontWeight: 600, letterSpacing: -0.5, lineHeight: 1.05, fontVariationSettings: '"opsz" 144, "SOFT" 50' }}>Ôn thi A2 — trvalý pobyt</div>
          <div style={{ fontSize: 13.5, color: C.ink2, marginTop: 6, maxWidth: 640 }}>Lộ trình 6 tuần luyện 4 úloha của kỳ thi A2 cấp trú dài hạn ở CH Séc. Tập trung vào Speaking với feedback AI realtime.</div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Btn variant="ghost" icon="eye">Xem trên app</Btn>
          <Btn variant="primary" icon="plus">Module mới</Btn>
        </div>
      </div>

      {/* Tabs */}
      <div style={{ padding: '0 24px', borderBottom: '1px solid ' + C.border, display: 'flex', gap: 22 }}>
        {['Cấu trúc', 'Học viên (1.840)', 'Analytics', 'Cài đặt'].map((t, i) => (
          <button key={t} style={{ padding: '12px 0', background: 'none', border: 'none', borderBottom: i === 0 ? '2px solid ' + C.brand : '2px solid transparent', color: i === 0 ? C.ink : C.ink3, fontWeight: i === 0 ? 600 : 500, fontSize: 13.5, cursor: 'pointer', marginBottom: -1, whiteSpace: 'nowrap' }}>{t}</button>
        ))}
      </div>

      <div style={{ padding: '20px 24px 28px', display: 'grid', gridTemplateColumns: '1fr 380px', gap: 20 }}>
        {/* Modules */}
        <div>
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
            <div style={{ fontFamily: C.display, fontSize: 18, fontWeight: 600, letterSpacing: -0.3 }}>6 module · 88 bài tập</div>
            <div style={{ display: 'flex', gap: 4, padding: 3, background: C.surface, borderRadius: 8, border: '1px solid ' + C.border }}>
              <button style={{ padding: '5px 9px', fontSize: 11.5, fontWeight: 600, color: C.ink, background: C.bg, border: 'none', borderRadius: 6, cursor: 'pointer' }}><CIcon name="list" size={13} /></button>
              <button style={{ padding: '5px 9px', fontSize: 11.5, fontWeight: 600, color: C.ink3, background: 'transparent', border: 'none', borderRadius: 6, cursor: 'pointer' }}><CIcon name="grid" size={13} /></button>
            </div>
          </div>
          <Card padded={false}>
            {modules.map((m, i) => (
              <div key={m.id} style={{ borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <div className="row-hover" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '14px 16px', cursor: 'pointer', transition: 'background .12s' }} onClick={() => setOpenModule(openModule === m.id ? null : m.id)}>
                  <CIcon name="drag" size={14} color={C.ink4} />
                  <div style={{ width: 26, height: 26, borderRadius: 7, background: C.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: C.mono, fontSize: 11.5, fontWeight: 700, color: C.ink2 }}>{m.id}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13.5, fontWeight: 600 }}>{m.title}</div>
                    <div style={{ fontSize: 11.5, color: C.ink3, marginTop: 1 }}>{m.skills} kỹ năng · {m.exercises} bài tập</div>
                  </div>
                  <Tag tone={m.tone} size="sm">{m.status}</Tag>
                  <CIcon name="chev-d" size={14} color={C.ink3} style={{ transform: openModule === m.id ? 'rotate(180deg)' : 'none', transition: 'transform .15s' }} />
                </div>
                {openModule === m.id && (
                  <div style={{ background: C.bg, borderTop: '1px solid ' + C.divider, padding: '8px 16px 12px 56px', animation: 'fadeIn .2s' }}>
                    {skills.map((s, j) => (
                      <div key={s.id} className="row-hover" style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '10px 12px', borderRadius: 8, cursor: 'pointer' }}>
                        <Donut value={s.donut} />
                        <div style={{ flex: 1 }}>
                          <div style={{ fontSize: 13, fontWeight: 600 }}>{s.title}</div>
                          <div style={{ fontSize: 11.5, color: C.ink3, marginTop: 1 }}>{s.exercises} bài · level {s.level}</div>
                        </div>
                        <Btn size="sm" variant="ghost" onClick={() => go('editor', { id: s.id })}>Chỉnh sửa</Btn>
                      </div>
                    ))}
                    <button style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '8px 12px', background: 'none', border: '1px dashed ' + C.borderStrong, borderRadius: 8, color: C.ink2, fontSize: 12.5, fontWeight: 500, cursor: 'pointer', width: '100%', justifyContent: 'center', marginTop: 4 }}>
                      <CIcon name="plus" size={13} /> Thêm kỹ năng
                    </button>
                  </div>
                )}
              </div>
            ))}
          </Card>
        </div>

        {/* Side info */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Tiến độ phát hành</div>
            <Bar label="Đã publish" v={68} c={C.ready} />
            <Bar label="Đang viết" v={22} c={C.brand} />
            <Bar label="Bản nháp" v={10} c={C.ink4} />
          </Card>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Người đóng góp</div>
            {[
              { n: 'Lan Phạm', r: 'Lead editor', i: 'LP', c: '#FF6A14' },
              { n: 'Petr Novák', r: 'Czech native', i: 'PN', c: '#0F3D3A' },
              { n: 'Hà Trang', r: 'Reviewer', i: 'HT', c: '#3060B8' },
            ].map((p, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <div style={{ width: 30, height: 30, borderRadius: 999, background: p.c, color: '#fff', fontSize: 11, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>{p.i}</div>
                <div style={{ flex: 1 }}>
                  <div style={{ fontSize: 12.5, fontWeight: 600 }}>{p.n}</div>
                  <div style={{ fontSize: 11, color: C.ink3 }}>{p.r}</div>
                </div>
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

function Donut({ value, size = 26 }) {
  const r = (size - 4) / 2;
  const C2 = 2 * Math.PI * r;
  const off = C2 - (value / 100) * C2;
  return (
    <svg width={size} height={size} style={{ flexShrink: 0 }}>
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={C.bg} strokeWidth="3" />
      <circle cx={size/2} cy={size/2} r={r} fill="none" stroke={value === 100 ? C.ready : value === 0 ? C.ink4 : C.brand} strokeWidth="3" strokeDasharray={C2} strokeDashoffset={off} strokeLinecap="round" transform={`rotate(-90 ${size/2} ${size/2})`} />
    </svg>
  );
}

function Bar({ label, v, c }) {
  return (
    <div style={{ marginBottom: 10 }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 4 }}>
        <span style={{ color: C.ink2 }}>{label}</span>
        <span style={{ fontFamily: C.mono, fontWeight: 700 }}>{v}%</span>
      </div>
      <div style={{ height: 6, background: C.bg, borderRadius: 999 }}>
        <div style={{ width: v + '%', height: '100%', background: c, borderRadius: 999 }} />
      </div>
    </div>
  );
}

window.CoursesPage = CoursesPage;
window.CourseDetail = CourseDetail;
