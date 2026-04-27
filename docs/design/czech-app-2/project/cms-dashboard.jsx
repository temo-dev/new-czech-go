// CMS Dashboard

function Dashboard({ go }) {
  return (
    <div>
      <PageHeader
        eyebrow="Thứ 5 · 13 tháng 11"
        title="Chào Trang, hôm nay có 12 việc cần xem"
        subtitle="3 bài cần review, 8 submission đang chờ chấm tay, và 1 mock test sắp publish."
        actions={<>
          <Btn variant="ghost" icon="upload">Nhập từ Sheet</Btn>
          <Btn variant="primary" icon="plus" onClick={() => go('editor', { id: 'new' })}>Bài tập mới</Btn>
        </>}
      />

      <div style={{ padding: '0 24px 24px', display: 'grid', gridTemplateColumns: 'repeat(4, 1fr)', gap: 12 }}>
        <Stat label="Học viên active (7d)" value="1.842" delta="+9.2%" tone="ready" />
        <Stat label="Bài hoàn thành / ngày" value="14.230" delta="+3.1%" tone="ready" />
        <Stat label="Pass rate Mock A2" value="68%" delta="−2.4%" tone="not" />
        <Stat label="AI agreement với reviewer" value="91.3%" delta="+1.2%" tone="ready" />
      </div>

      <div style={{ padding: '0 24px 28px', display: 'grid', gridTemplateColumns: '1fr 360px', gap: 16 }}>
        {/* LEFT */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Card padded={false}>
            <div style={{ padding: '16px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid ' + C.divider }}>
              <div>
                <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, letterSpacing: -0.3 }}>Hoạt động học viên · 14 ngày</div>
                <div style={{ fontSize: 12, color: C.ink3, marginTop: 2 }}>Số bài Speaking nộp mỗi ngày</div>
              </div>
              <div style={{ display: 'flex', gap: 4, padding: 3, background: C.bg, borderRadius: 8 }}>
                {['Speaking', 'Listening', 'Cả hai'].map((s, i) => (
                  <button key={s} style={{ padding: '5px 10px', fontSize: 11.5, fontWeight: 600, color: i === 0 ? C.ink : C.ink3, background: i === 0 ? C.surface : 'transparent', border: 'none', borderRadius: 6, cursor: 'pointer', boxShadow: i === 0 ? C.shadowSm : 'none' }}>{s}</button>
                ))}
              </div>
            </div>
            <div style={{ padding: '20px 18px 14px', height: 220 }}>
              <ActivityChart />
            </div>
          </Card>

          <Card padded={false}>
            <div style={{ padding: '16px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid ' + C.divider }}>
              <div>
                <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, letterSpacing: -0.3 }}>Bài cần xử lý</div>
                <div style={{ fontSize: 12, color: C.ink3, marginTop: 2 }}>Submission AI chấm thấp confidence</div>
              </div>
              <Btn variant="text" size="sm" iconR="chev-r">Xem tất cả 23</Btn>
            </div>
            <div>
              {SUBMISSIONS.map((s, i) => (
                <div key={s.id} className="row-hover" style={{ display: 'grid', gridTemplateColumns: '24px 1fr 90px 110px 90px 26px', alignItems: 'center', gap: 14, padding: '12px 18px', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider, cursor: 'pointer', transition: 'background .12s' }}>
                  <div style={{ width: 24, height: 24, borderRadius: 999, background: s.avatarBg, color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 10.5, fontWeight: 700 }}>{s.initials}</div>
                  <div style={{ minWidth: 0 }}>
                    <div style={{ fontSize: 13, fontWeight: 600, color: C.ink, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{s.title}</div>
                    <div style={{ fontSize: 11.5, color: C.ink3, marginTop: 1 }}>{s.learner} · {s.time}</div>
                  </div>
                  <Tag tone={s.aiTone} size="sm">AI {s.aiScore}</Tag>
                  <div style={{ fontSize: 11.5, color: C.ink2 }}>conf. {s.conf}%</div>
                  <Tag tone={s.statusTone} size="sm">{s.status}</Tag>
                  <CIcon name="chev-r" size={14} color={C.ink3} />
                </div>
              ))}
            </div>
          </Card>
        </div>

        {/* RIGHT */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Card>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 12 }}>
              <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600 }}>Pipeline nội dung</div>
              <Tag tone="brand" size="sm">12 mục</Tag>
            </div>
            {[
              { l: 'Bản nháp', n: 4, c: C.ink4 },
              { l: 'Đang viết', n: 3, c: C.brand },
              { l: 'Chờ duyệt', n: 3, c: '#3060B8' },
              { l: 'Đã publish tuần này', n: 2, c: C.ready },
            ].map((s, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <div style={{ width: 8, height: 8, borderRadius: 999, background: s.c }} />
                <div style={{ flex: 1, fontSize: 13, color: C.ink }}>{s.l}</div>
                <div style={{ fontFamily: C.mono, fontSize: 12, color: C.ink2, fontWeight: 600 }}>{s.n}</div>
              </div>
            ))}
          </Card>

          <Card>
            <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 14 }}>
              <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600 }}>Câu hỏi khó nhất</div>
              <CIcon name="flame" size={16} color={C.brand} />
            </div>
            {[
              { q: 'Úloha 4 · Khiếu nại tiền nhà', pass: 41, n: 312 },
              { q: 'Úloha 3 · Đặt lịch khám', pass: 58, n: 280 },
              { q: 'Úloha 2 · Mua vé tàu Brno', pass: 63, n: 247 },
            ].map((s, i) => (
              <div key={i} style={{ padding: '10px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: 6 }}>
                  <div style={{ fontSize: 12.5, color: C.ink, fontWeight: 500, flex: 1 }}>{s.q}</div>
                  <div style={{ fontFamily: C.mono, fontSize: 11.5, fontWeight: 700, color: s.pass < 50 ? C.notInk : C.ink2 }}>{s.pass}%</div>
                </div>
                <div style={{ height: 4, background: C.bg, borderRadius: 999, overflow: 'hidden' }}>
                  <div style={{ width: s.pass + '%', height: '100%', background: s.pass < 50 ? C.not : s.pass < 70 ? C.needs : C.ready, borderRadius: 999 }} />
                </div>
              </div>
            ))}
          </Card>

          <Card style={{ background: C.ink, color: '#fff', border: 'none' }}>
            <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600, letterSpacing: -0.3, marginBottom: 4 }}>Mock test 03 sắp publish</div>
            <div style={{ fontSize: 12.5, color: 'rgba(255,255,255,0.7)', marginBottom: 14, lineHeight: 1.5 }}>Còn 2 úloha thiếu sample audio. Lan đang ghi.</div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 14 }}>
              <div style={{ flex: 1, height: 5, background: 'rgba(255,255,255,0.15)', borderRadius: 999, overflow: 'hidden' }}>
                <div style={{ width: '50%', height: '100%', background: C.brand }} />
              </div>
              <span style={{ fontFamily: C.mono, fontSize: 11, fontWeight: 700 }}>2/4</span>
            </div>
            <Btn variant="primary" size="sm" onClick={() => go('mock', { id: '03' })}>Mở mock test 03</Btn>
          </Card>
        </div>
      </div>
    </div>
  );
}

function Stat({ label, value, delta, tone }) {
  const up = !delta.startsWith('−');
  return (
    <Card>
      <div style={{ fontSize: 11.5, fontWeight: 600, color: C.ink3, letterSpacing: 0.4, textTransform: 'uppercase' }}>{label}</div>
      <div style={{ display: 'flex', alignItems: 'baseline', gap: 10, marginTop: 8 }}>
        <div style={{ fontFamily: C.display, fontSize: 28, fontWeight: 600, letterSpacing: -0.5, color: C.ink, fontVariationSettings: '"opsz" 144' }}>{value}</div>
        <div style={{ display: 'inline-flex', alignItems: 'center', gap: 2, fontSize: 11.5, fontWeight: 700, color: up ? C.readyInk : C.notInk }}>
          <CIcon name={up ? 'arrow-up' : 'arrow-down'} size={11} />
          {delta}
        </div>
      </div>
    </Card>
  );
}

function ActivityChart() {
  const data = [62, 71, 58, 84, 92, 78, 65, 88, 110, 96, 84, 119, 132, 124];
  const max = 140;
  const labels = ['T 31', '', '', 'T 3', '', '', '', 'T 7', '', '', '', 'T 11', '', 'Hôm qua'];
  return (
    <div style={{ height: '100%', display: 'flex', alignItems: 'flex-end', gap: 6, position: 'relative', paddingBottom: 22 }}>
      {data.map((v, i) => {
        const isLast = i === data.length - 1;
        return (
          <div key={i} style={{ flex: 1, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 6, height: '100%', justifyContent: 'flex-end' }}>
            <div style={{ width: '100%', height: (v / max * 100) + '%', background: isLast ? C.brand : C.brandSoft, borderRadius: '6px 6px 2px 2px', position: 'relative' }}>
              {isLast && <div style={{ position: 'absolute', top: -22, left: '50%', transform: 'translateX(-50%)', background: C.ink, color: '#fff', fontSize: 10.5, fontWeight: 700, padding: '2px 6px', borderRadius: 4, fontFamily: C.mono, whiteSpace: 'nowrap' }}>{v}</div>}
            </div>
            <div style={{ fontSize: 10.5, color: C.ink3, fontWeight: 500, position: 'absolute', bottom: 0 }}>{labels[i]}</div>
          </div>
        );
      })}
    </div>
  );
}

const SUBMISSIONS = [
  { id: 1, initials: 'NM', avatarBg: '#0F3D3A', title: 'Úloha 4 · Khiếu nại tiền nhà — "Bydlím v Karlíně..."', learner: 'Nguyễn Thị Mai', time: '12 phút trước', aiScore: 'NEEDS', aiTone: 'needs', conf: 64, status: 'Chờ review', statusTone: 'almost' },
  { id: 2, initials: 'TL', avatarBg: '#C28012', title: 'Úloha 2 · Mua vé tàu — "Dobrý den, jeden lístek..."', learner: 'Trần Văn Long', time: '38 phút trước', aiScore: 'ALMOST', aiTone: 'almost', conf: 71, status: 'Chờ review', statusTone: 'almost' },
  { id: 3, initials: 'PA', avatarBg: '#3060B8', title: 'Úloha 1 · Tự giới thiệu — "Jmenuji se Phương..."', learner: 'Phạm Anh', time: '1 giờ trước', aiScore: 'NOT', aiTone: 'not', conf: 58, status: 'Cần chấm tay', statusTone: 'not' },
  { id: 4, initials: 'LH', avatarBg: '#1F8A4D', title: 'Úloha 3 · Đặt lịch khám — "Chtěl bych se objednat..."', learner: 'Lê Hà', time: '2 giờ trước', aiScore: 'READY', aiTone: 'ready', conf: 92, status: 'Đã chấm', statusTone: 'ready' },
  { id: 5, initials: 'VB', avatarBg: '#FF6A14', title: 'Úloha 4 · Khiếu nại tiền nhà — "Mám problém s..."', learner: 'Vũ Bình', time: '3 giờ trước', aiScore: 'NEEDS', aiTone: 'needs', conf: 67, status: 'Chờ review', statusTone: 'almost' },
];

window.Dashboard = Dashboard;
