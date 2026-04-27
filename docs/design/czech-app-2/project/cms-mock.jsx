// CMS Mock test list + builder

const MOCKS = [
  { id: '01', title: 'Mock 01 — Cuộc sống ở Praha', status: 'Đã publish', tone: 'ready', taken: 412, pass: 68, updated: '5 ngày' },
  { id: '02', title: 'Mock 02 — Công việc & lịch hẹn', status: 'Đã publish', tone: 'ready', taken: 318, pass: 71, updated: '6 ngày' },
  { id: '03', title: 'Mock 03 — Sức khoẻ & bảo hiểm', status: 'Đang viết', tone: 'almost', taken: 0, pass: null, updated: '1 ngày' },
  { id: '04', title: 'Mock 04 — Thuê nhà & hợp đồng', status: 'Bản nháp', tone: 'needs', taken: 0, pass: null, updated: '2 tuần' },
  { id: '05', title: 'Mock 05 — Trường học & con cái', status: 'Đã publish', tone: 'ready', taken: 198, pass: 64, updated: '3 tuần' },
];

function MockListPage({ go }) {
  return (
    <div>
      <PageHeader
        title="Mock test"
        subtitle="Bộ đề thi đầy đủ 4 úloha. Học viên làm như thi thật."
        actions={<Btn variant="primary" icon="plus" onClick={() => go('mock', { id: 'new' })}>Mock mới</Btn>}
      />
      <div style={{ padding: '0 24px 28px' }}>
        <Card padded={false}>
          <div style={{ display: 'grid', gridTemplateColumns: '40px 1fr 130px 140px 110px 130px 30px', gap: 14, padding: '12px 18px', borderBottom: '1px solid ' + C.divider, fontSize: 11, fontWeight: 700, color: C.ink3, letterSpacing: 0.5, textTransform: 'uppercase' }}>
            <div></div>
            <div>Mock test</div>
            <div>Trạng thái</div>
            <div>Lượt làm</div>
            <div>Pass rate</div>
            <div>Cập nhật</div>
            <div></div>
          </div>
          {MOCKS.map(m => (
            <div key={m.id} className="row-hover" onClick={() => go('mock', { id: m.id })} style={{ display: 'grid', gridTemplateColumns: '40px 1fr 130px 140px 110px 130px 30px', gap: 14, padding: '14px 18px', alignItems: 'center', cursor: 'pointer', borderTop: '1px solid ' + C.divider, transition: 'background .12s' }}>
              <div style={{ width: 30, height: 30, borderRadius: 8, background: C.bg, display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: C.mono, fontSize: 11, fontWeight: 700, color: C.ink2 }}>{m.id}</div>
              <div style={{ fontSize: 13.5, fontWeight: 600 }}>{m.title}</div>
              <Tag tone={m.tone} size="sm">{m.status}</Tag>
              <div style={{ fontFamily: C.mono, fontSize: 12.5, color: C.ink }}>{m.taken.toLocaleString('vi')}</div>
              <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                {m.pass !== null ? (
                  <>
                    <div style={{ width: 50, height: 4, background: C.bg, borderRadius: 999 }}>
                      <div style={{ width: m.pass + '%', height: '100%', background: m.pass >= 70 ? C.ready : m.pass >= 60 ? C.brand : C.not, borderRadius: 999 }} />
                    </div>
                    <span style={{ fontFamily: C.mono, fontSize: 12, fontWeight: 700 }}>{m.pass}%</span>
                  </>
                ) : <span style={{ fontSize: 12, color: C.ink4 }}>—</span>}
              </div>
              <div style={{ fontSize: 12, color: C.ink3 }}>{m.updated} trước</div>
              <CIcon name="chev-r" size={14} color={C.ink3} />
            </div>
          ))}
        </Card>
      </div>
    </div>
  );
}

function MockBuilder({ go, mockId }) {
  const [parts, setParts] = React.useState([
    { id: 1, code: 'Úloha 1', title: 'Tự giới thiệu & chào hỏi', sec: 60, status: 'ready', exercise: 'Tự giới thiệu chuẩn A2' },
    { id: 2, code: 'Úloha 2', title: 'Mua vé tàu Brno → Praha', sec: 75, status: 'ready', exercise: 'Mua vé tàu — bài 04' },
    { id: 3, code: 'Úloha 3', title: 'Đặt lịch khám bác sĩ gia đình', sec: 90, status: 'almost', exercise: 'Đặt lịch khám — bài 02' },
    { id: 4, code: 'Úloha 4', title: 'Khiếu nại tiền nhà tháng 11', sec: 90, status: 'almost', exercise: '— chưa chọn —' },
  ]);
  const totalSec = parts.reduce((a, p) => a + p.sec, 0);

  return (
    <div>
      <div style={{ padding: '20px 24px 16px', display: 'flex', alignItems: 'flex-start', gap: 16, borderBottom: '1px solid ' + C.border }}>
        <div style={{ flex: 1 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, marginBottom: 6 }}>
            <Tag tone="brand" size="sm">Mock 03</Tag>
            <Tag tone="almost" size="sm">Đang viết</Tag>
            <span style={{ fontSize: 11.5, color: C.ink3 }}>· cần 2 sample audio</span>
          </div>
          <input defaultValue="Sức khoẻ & bảo hiểm" style={{ width: '100%', maxWidth: 640, fontFamily: C.display, fontSize: 28, fontWeight: 600, letterSpacing: -0.5, background: 'transparent', border: 'none', outline: 'none', padding: 0 }} />
        </div>
        <div style={{ display: 'flex', gap: 8 }}>
          <Btn variant="ghost" icon="eye">Mô phỏng thi</Btn>
          <Btn variant="inverse" icon="save">Lưu nháp</Btn>
          <Btn variant="primary">Publish</Btn>
        </div>
      </div>

      <div style={{ padding: '20px 24px 28px', display: 'grid', gridTemplateColumns: '1fr 360px', gap: 20 }}>
        <div>
          {/* Timeline */}
          <Card padded={false} style={{ marginBottom: 16 }}>
            <div style={{ padding: '14px 18px', display: 'flex', alignItems: 'center', justifyContent: 'space-between', borderBottom: '1px solid ' + C.divider }}>
              <div>
                <div style={{ fontFamily: C.display, fontSize: 17, fontWeight: 600 }}>Timeline kỳ thi</div>
                <div style={{ fontSize: 12, color: C.ink3, marginTop: 2 }}>Tổng {Math.floor(totalSec / 60)} phút {totalSec % 60}s · 4 phần</div>
              </div>
              <CIcon name="clock" size={18} color={C.ink3} />
            </div>
            <div style={{ padding: 18 }}>
              <div style={{ display: 'flex', height: 32, borderRadius: 8, overflow: 'hidden', marginBottom: 18 }}>
                {parts.map((p, i) => (
                  <div key={p.id} style={{ flex: p.sec, background: ['#FF6A14', '#0F3D3A', '#3060B8', '#C28012'][i], color: '#fff', display: 'flex', alignItems: 'center', justifyContent: 'center', fontSize: 11, fontWeight: 700, position: 'relative' }}>
                    {p.code} · {p.sec}s
                  </div>
                ))}
              </div>
              {/* Parts list */}
              {parts.map((p, i) => (
                <div key={p.id} style={{ display: 'flex', alignItems: 'center', gap: 12, padding: '12px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                  <CIcon name="drag" size={14} color={C.ink4} />
                  <div style={{ width: 30, height: 30, borderRadius: 8, background: ['#FFE5D2', '#D9E5E3', '#DEE9F7', '#F8EAC9'][i], color: ['#5A2406', '#0F3D3A', '#103A78', '#5C3A06'][i], display: 'flex', alignItems: 'center', justifyContent: 'center', fontFamily: C.mono, fontSize: 11, fontWeight: 700 }}>{p.id}</div>
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 13, fontWeight: 600 }}>{p.code} · {p.title}</div>
                    <div style={{ fontSize: 11.5, color: C.ink3, marginTop: 2 }}>Bài tham chiếu: {p.exercise}</div>
                  </div>
                  <div style={{ display: 'flex', alignItems: 'center', gap: 4, padding: '4px 8px', background: C.bg, borderRadius: 6, fontFamily: C.mono, fontSize: 11.5, fontWeight: 700, color: C.ink2 }}>
                    <CIcon name="clock" size={11} color={C.ink3} /> {p.sec}s
                  </div>
                  <Tag tone={p.status} size="sm">{p.status === 'ready' ? 'OK' : 'Cần audio'}</Tag>
                  <button style={{ padding: 6, background: 'none', border: 'none', cursor: 'pointer', color: C.ink3 }}><CIcon name="chev-r" size={14} /></button>
                </div>
              ))}
              <button style={{ display: 'flex', alignItems: 'center', justifyContent: 'center', gap: 8, padding: '10px', background: 'none', border: '1px dashed ' + C.borderStrong, borderRadius: 8, color: C.ink2, fontSize: 12.5, fontWeight: 600, cursor: 'pointer', width: '100%', marginTop: 8 }}>
                <CIcon name="plus" size={13} /> Thêm úloha
              </button>
            </div>
          </Card>

          {/* Settings */}
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 14 }}>Cài đặt mock</div>
            <div style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: 14 }}>
              <Field label="Điểm đỗ (tổng)"><input defaultValue="60%" style={inputStyle} /></Field>
              <Field label="Thời gian chờ giữa úloha (s)"><input type="number" defaultValue="10" style={inputStyle} /></Field>
              <Field label="Cho xem đáp án mẫu sau khi nộp">
                <select style={inputStyle}><option>Có — sau khi xong cả 4 úloha</option><option>Không</option></select>
              </Field>
              <Field label="Số lần làm tối đa">
                <select style={inputStyle}><option>3 lần / 7 ngày</option></select>
              </Field>
            </div>
          </Card>
        </div>

        {/* Right rail */}
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16 }}>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 12 }}>Sẵn sàng publish?</div>
            {[
              { l: '4 úloha có đề bài', ok: true },
              { l: '4 sample audio đã ghi', ok: false, n: '2/4' },
              { l: 'Rúbric cho từng phần', ok: true },
              { l: 'Đã chạy QA với reviewer', ok: false },
              { l: 'Native speaker đã duyệt', ok: false },
            ].map((c, i) => (
              <div key={i} style={{ display: 'flex', alignItems: 'center', gap: 8, padding: '7px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider }}>
                <div style={{ width: 18, height: 18, borderRadius: 999, background: c.ok ? C.readyBg : C.bg, color: c.ok ? C.ready : C.ink4, display: 'flex', alignItems: 'center', justifyContent: 'center' }}>
                  {c.ok ? <CIcon name="check" size={11} color={C.ready} /> : <CIcon name="x" size={10} color={C.ink4} />}
                </div>
                <div style={{ flex: 1, fontSize: 12.5, color: c.ok ? C.ink : C.ink2 }}>{c.l}</div>
                {c.n && <span style={{ fontFamily: C.mono, fontSize: 11.5, color: C.ink3, fontWeight: 700 }}>{c.n}</span>}
              </div>
            ))}
            <div style={{ marginTop: 12, padding: 10, background: C.needsBg, borderRadius: 8, fontSize: 12, color: C.needsInk, lineHeight: 1.5 }}>
              <strong>3 mục còn thiếu</strong> — không thể publish cho tới khi xong.
            </div>
          </Card>
          <Card>
            <div style={{ fontFamily: C.display, fontSize: 16, fontWeight: 600, marginBottom: 8 }}>Lịch sử thay đổi</div>
            {[
              { who: 'Lan', what: 'sửa úloha 4 bullets', t: '12 phút' },
              { who: 'Petr', what: 'ghi audio úloha 1, 2', t: 'hôm qua' },
              { who: 'Trang', what: 'tạo bản nháp', t: '6 ngày' },
            ].map((h, i) => (
              <div key={i} style={{ display: 'flex', gap: 8, padding: '7px 0', borderTop: i === 0 ? 'none' : '1px solid ' + C.divider, fontSize: 12 }}>
                <span style={{ color: C.ink, fontWeight: 600 }}>{h.who}</span>
                <span style={{ color: C.ink2, flex: 1 }}>{h.what}</span>
                <span style={{ color: C.ink3 }}>{h.t}</span>
              </div>
            ))}
          </Card>
        </div>
      </div>
    </div>
  );
}

window.MockListPage = MockListPage;
window.MockBuilder = MockBuilder;
