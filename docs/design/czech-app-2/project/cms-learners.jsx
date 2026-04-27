// CMS Learners — list + detail

const LEARNERS = [
  { id: 1, name: 'Nguyễn Thị Mai', city: 'Praha', joined: '14/09', plan: 'Pro', pct: 78, label: 'ALMOST', tone: 'almost', streak: 12, lastSeen: '12 phút', exam: '15/12' },
  { id: 2, name: 'Trần Văn Long', city: 'Brno', joined: '02/10', plan: 'Pro', pct: 91, label: 'READY', tone: 'ready', streak: 28, lastSeen: '38 phút', exam: '04/12' },
  { id: 3, name: 'Phạm Anh', city: 'Plzeň', joined: '21/09', plan: 'Free', pct: 42, label: 'NEEDS', tone: 'needs', streak: 3, lastSeen: '1 giờ', exam: 'chưa đặt' },
  { id: 4, name: 'Lê Hà', city: 'Praha', joined: '01/08', plan: 'Pro', pct: 86, label: 'READY', tone: 'ready', streak: 45, lastSeen: '2 giờ', exam: '20/11' },
  { id: 5, name: 'Vũ Bình', city: 'Ostrava', joined: '17/10', plan: 'Free', pct: 31, label: 'NOT', tone: 'not', streak: 1, lastSeen: '3 giờ', exam: 'chưa đặt' },
  { id: 6, name: 'Đặng Thu Hương', city: 'Praha', joined: '06/09', plan: 'Pro', pct: 73, label: 'ALMOST', tone: 'almost', streak: 18, lastSeen: '4 giờ', exam: '08/01' },
  { id: 7, name: 'Hoàng Minh', city: 'Liberec', joined: '11/10', plan: 'Pro', pct: 65, label: 'NEEDS', tone: 'needs', streak: 8, lastSeen: '6 giờ', exam: '12/01' },
  { id: 8, name: 'Bùi Quỳnh', city: 'Praha', joined: '28/08', plan: 'Pro', pct: 88, label: 'READY', tone: 'ready', streak: 33, lastSeen: '1 ngày', exam: '02/12' },
];

const COLORS = ['#FF6A14', '#0F3D3A', '#3060B8', '#1F8A4D', '#C28012', '#C03A28', '#5C3A78', '#0E4A28'];

function LearnersPage({ go }) {
  const [filter, setFilter] = React.useState('Tất cả');
  return (
    <div>
      <PageHeader
        title="Học viên"
        subtitle="2.140 học viên · 1.842 active 7 ngày qua"
        actions={<>
          <Btn variant="ghost" icon="upload">Export CSV</Btn>
          <Btn variant="primary" icon="plus">Mời học viên</Btn>
        </>}
      />
      <div style={{ padding: '0 24px 12px', display: 'flex', gap: 8, alignItems: 'center' }}>
        {['Tất cả', 'Sắp thi (30d)', 'READY', 'ALMOST', 'NEEDS', 'NOT', 'Mất hoạt động'].map(f => (
          <button key={f} onClick={() => setFilter(f)} style={{ padding: '6px 12px', fontSize: 12.5, fontWeight: 600, color: filter === f ? '#fff' : C.ink2, background: filter === f ? C.ink : C.surface, border: '1px solid ' + (filter === f ? C.ink : C.border), borderRadius: 999, cursor: 'pointer' }}>{f}</button>
        ))}
        <div style={{ flex: 1 }} />
        <span style={{ fontSize: 12, color: C.ink3 }}>Hiện 8 / 2.140</span>
      </div>
      <div style={{ padding: '0 24px 28px' }}>
        <Card padded={false}>
          <div style={{ display: 'grid', gridTemplateColumns: '1.6fr 0.9fr 0.7fr 1.3fr 0.8fr 0.9fr 0.9fr 30px', gap: 14, padding: '12px 18px', borderBottom: '1px solid ' + C.divider, fontSize: 11, fontWeight: 700, color: C.ink3, letterSpacing: 0.5, textTransform: 'uppercase' }}>
            <div>Học viên</div>
            <div>Thành phố</div>
            <div>Plan</div>
            <div>Mức sẵn sàng</div>
            <div>Streak</div>
            <div>Ngày thi</div>
            <div>Hoạt động</div>
            <div></div>
          </div>
          {LEARNERS.map((l, i) => (
            <div key={l.id} className="row-hover" onClick={() => go('learner-detail', { id: l.id })} style={{ display: 'grid', gridTemplateColumns: '1.6fr 0.9fr 0.7fr 1.3fr 0.8fr 0.9fr 0.9fr 30px', gap: 14, padding: '12px 18px', alignItems: 'center', cursor: 'pointer', borderTop: '1px solid ' + C.divider, transition: 'background .12s' }}>
              <div style={{ display: 'flex', alignItems: 'center', gap: 10, minWidth: 0 }}>
                <div style={{ width: 32, height: 32, borderRadius: 999, background: COLORS[i % COLORS.length], color: '#fff', fontSize: 11.5, fontWeight: 700, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>{l.name.split(' ').slice(-2).map(s => s[0]).join('')}</div>
                <div style={{ minWidth: 0 }}>
                  <div style={{ fontSize: 13, fontWeight: 600, whiteSpace: 'nowrap', overflow: 'hidden', textOverflow: 'ellipsis' }}>{l.name}</div>
                  <div style={{ fontSize: 11, color: C.ink3 }}>tham gia {l.joined}</div>
                </div>
              </div>
              <div style={{ fontSize: 12.5, color: C.ink2 }}>{l.city}</div>
              <Tag tone={l.plan === 'Pro' ? 'brand' : 'neutral'} size="sm">{l.plan}</Tag>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                <div style={{ width: 60, height: 4, background: C.bg, borderRadius: 999 }}>
                  <div style={{ width: l.pct + '%', height: '100%', background: l.pct >= 85 ? C.ready : l.pct >= 70 ? C.almost : l.pct >= 50 ? C.needs : C.not, borderRadius: 999 }} />
                </div>
                <Tag tone={l.tone} size="sm">{l.label}</Tag>
              </div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 4, fontSize: 12.5, fontFamily: C.mono, fontWeight: 700, color: l.streak >= 14 ? C.brand : C.ink2 }}>
                <CIcon name="flame" size={13} color={l.streak >= 14 ? C.brand : C.ink4} /> {l.streak}
              </div>
              <div style={{ fontSize: 12, color: l.exam.includes('chưa') ? C.ink4 : C.ink }}>{l.exam}</div>
              <div style={{ fontSize: 11.5, color: C.ink3 }}>{l.lastSeen} trước</div>
              <CIcon name="chev-r" size={14} color={C.ink3} />
            </div>
          ))}
        </Card>
      </div>
    </div>
  );
}

function LearnerDetail({ go, learnerId }) {
  return (
    <div>
      <div style={{ padding: '24px 24px 18px', display: 'flex', alignItems: 'flex-start', gap: 20 }}>
        <div style={{ width: 80, height: 80, borderRadius: 999, background: '#0F3D3A', color: '#fff', fontFamily: C.display, fontSize: 28, fontWeight: 600, display: 'flex', alignItems: 'center', justifyContent: 'center', flexShrink: 0 }}>NM</div>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 4 }}>
            <Tag tone="brand" size="sm">Pro</Tag>
            <Tag tone="almost" size="sm">ALMOST · 78%</Tag>
            <span style={{ fontSize: 11.5, color: C.ink3 }}>· streak 12 ngày · last active 12 phút trước</span>
          </div>
          <div style={{ fontFamily: C.display, fontSize: 28, fontWeight: 600, letterSpacing: -0.5, fontVariationSettings: '"opsz" 144, "SOFT" 50' }}>Nguyễn Thị Mai</div>
          <div style={{ fontSize: 13, color: C.ink2, marginTop: 4 }}>Praha · tham gia 14/09 · ngày thi đã đặt: 15/12</div>
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Btn variant="ghost" icon="bell">Gửi nudge</Btn>
          <Btn variant="inverse" icon="globe">Mở app như Mai</Btn>
        </div>
      </div>

      <div style={{ padding: '0 24px 28px', display: 'grid', gridTemplateColumns: '1fr 1fr 1fr 1fr', gap: 12, marginBottom: 0 }}>
        <Stat label="Bài đã hoàn thành" value="142" delta="+18 tuần này" tone="ready" />
        <Stat label="Phút luyện nói" value="4h 38m" delta="+52m" tone="ready" />
        <Stat label="Điểm trung bình" value="78" delta="+4" tone="ready" />
        <Stat label="Câu nộp lại" value="9" delta="−3" tone="ready" />
      </div>

      <div style={{ padding: '20px 24px 28px', display: 'grid', gridTemplateColumns: '1fr 380px', gap: 20 }}>
        <Card padded={false}>
          <div style={{ padding: '14px 18px', borderBottom: '1px solid ' + C.divider, display: 'flex', alignItems: 'center', justifyContent: 'space-between' }}>
            <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600 }}>Submission gần đây</div>
            <Btn size="sm" variant="text" iconR="chev-r">Xem tất cả 142</Btn>
          </div>
          {[
            { d: 'Hôm nay 09:14', t: 'Úloha 4 · Khiếu nại tiền nhà', s: 'NEEDS', tone: 'needs', score: 64, conf: 'AI conf 64%' },
            { d: 'Hôm qua 21:02', t: 'Úloha 2 · Đặt lịch khám', s: 'READY', tone: 'ready', score: 88, conf: 'AI conf 92%' },
            { d: 'Hôm qua 20:48', t: 'Úloha 1 · Tự giới thiệu', s: 'READY', tone: 'ready', score: 91, conf: 'AI conf 95%' },
            { d: '2 ngày', t: 'Úloha 3 · Mua vé tàu', s: 'ALMOST', tone: 'almost', score: 76, conf: 'AI conf 81%' },
            { d: '2 ngày', t: 'Úloha 4 · Khiếu nại tiền nhà', s: 'NEEDS', tone: 'needs', score: 58, conf: 'AI conf 70%' },
          ].map((s, i) => (
            <div key={i} className="row-hover" style={{ display: 'grid', gridTemplateColumns: '110px 1fr 110px 50px 110px 26px', gap: 12, alignItems: 'center', padding: '12px 18px', borderTop: '1px solid ' + C.divider, cursor: 'pointer' }}>
              <div style={{ fontSize: 11.5, color: C.ink3 }}>{s.d}</div>
              <div style={{ fontSize: 13, fontWeight: 500 }}>{s.t}</div>
              <Tag tone={s.tone} size="sm">{s.s}</Tag>
              <div style={{ fontFamily: C.mono, fontSize: 13, fontWeight: 700, color: C.ink }}>{s.score}</div>
              <div style={{ fontSize: 11, color: C.ink3 }}>{s.conf}</div>
              <CIcon name="chev-r" size={14} color={C.ink3} />
            </div>
          ))}
        </Card>

        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 14 }}>Điểm theo trục</div>
            {[
              { l: 'Phát âm', v: 72 },
              { l: 'Trôi chảy', v: 81 },
              { l: 'Ngữ pháp', v: 74 },
              { l: 'Nội dung', v: 86 },
            ].map((s, i) => (
              <div key={i} style={{ marginBottom: 12 }}>
                <div style={{ display: 'flex', justifyContent: 'space-between', fontSize: 12, marginBottom: 5 }}>
                  <span style={{ color: C.ink2, fontWeight: 500 }}>{s.l}</span>
                  <span style={{ fontFamily: C.mono, fontWeight: 700 }}>{s.v}</span>
                </div>
                <div style={{ height: 6, background: C.bg, borderRadius: 999 }}>
                  <div style={{ width: s.v + '%', height: '100%', background: C.brand, borderRadius: 999 }} />
                </div>
              </div>
            ))}
          </Card>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Lỗi hay gặp</div>
            {[
              'Cách 4 (akusativ): "vidím <s>můj kamarád</s> → mého kamaráda"',
              'Trọng âm sai trên "telefon" (đầu, không phải cuối)',
              'Thiếu "se" trong động từ phản thân: "ptám" → "ptám se"',
            ].map((e, i) => (
              <div key={i} style={{ display: 'flex', gap: 8, padding: '8px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <CIcon name="dot" size={10} color={C.brand} style={{ marginTop: 4, flexShrink: 0 }} />
                <div style={{ fontSize: 12.5, color: C.ink2, lineHeight: 1.5 }} dangerouslySetInnerHTML={{ __html: e.replace(/<s>/g, '<span style="text-decoration:line-through;color:'+C.notInk+'">').replace(/<\/s>/g, '</span>') }} />
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

window.LearnersPage = LearnersPage;
window.LearnerDetail = LearnerDetail;
