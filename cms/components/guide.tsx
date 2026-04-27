export function AdminGuide() {
  return (
    <div style={{ maxWidth: 760, margin: '0 auto' }}>

      {/* Header */}
      <div style={{ marginBottom: 40 }}>
        <div style={{ fontSize: 11, fontWeight: 700, letterSpacing: 1, color: 'var(--brand)', textTransform: 'uppercase', marginBottom: 8 }}>
          HƯỚNG DẪN QUẢN TRỊ
        </div>
        <h1 style={{ margin: '0 0 12px', fontSize: 32, fontWeight: 700, fontFamily: 'Fraunces, serif', color: 'var(--ink)' }}>
          Nhập liệu CMS
        </h1>
        <p style={{ margin: 0, fontSize: 15, color: 'var(--ink-3)', lineHeight: 1.6 }}>
          Luồng chuẩn để tạo nội dung học. Làm đúng thứ tự — mỗi bước phụ thuộc bước trước.
        </p>
      </div>

      {/* Flow diagram */}
      <div style={{ background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r3)', padding: '20px 24px', marginBottom: 40 }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 16 }}>Thứ tự bắt buộc</div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 8, flexWrap: 'wrap' }}>
          {[
            { num: '1', label: 'Course', href: '/courses', color: '#7c3aed' },
            { num: '2', label: 'Module', href: '/modules', color: '#0891b2' },
            { num: '3', label: 'Skill', href: '/skills', color: '#059669' },
            { num: '4', label: 'Exercise', href: '/', color: 'var(--brand)' },
          ].map((step, i, arr) => (
            <div key={step.num} style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <a href={step.href} style={{ display: 'flex', alignItems: 'center', gap: 8, textDecoration: 'none',
                background: step.color, color: '#fff', borderRadius: 'var(--r2)', padding: '8px 14px', fontSize: 14, fontWeight: 600 }}>
                <span style={{ opacity: 0.7, fontSize: 12 }}>{step.num}.</span>
                {step.label}
              </a>
              {i < arr.length - 1 && <span style={{ color: 'var(--ink-4)', fontSize: 20 }}>→</span>}
            </div>
          ))}
        </div>
        <div style={{ marginTop: 16, padding: '10px 14px', background: 'rgba(255, 106, 20, 0.06)', borderRadius: 'var(--r2)', borderLeft: '3px solid var(--brand)' }}>
          <span style={{ fontSize: 13, color: 'var(--ink-2)' }}>
            <b>Mock Test</b> — luồng riêng: tạo exercises với <Code>pool = exam</Code>, sau đó vào{' '}
            <a href="/mock-tests" style={{ color: 'var(--brand)', fontWeight: 600 }}>Mock Test</a> để gán.
          </span>
        </div>
      </div>

      {/* Step 1 - Course */}
      <Section num="1" title="Tạo Course" href="/courses" color="#7c3aed">
        <p>Course là khóa học tổng. Một khóa gồm nhiều Module.</p>
        <FieldTable rows={[
          ['Tiêu đề', 'Tên khóa học', 'Ôn thi A2 — trvalý pobyt', true],
          ['Slug', 'URL-friendly ID (tự sinh nếu để trống)', 'on-thi-a2', false],
          ['Thứ tự', 'Thứ tự hiển thị', '1', false],
          ['Trạng thái', 'Phải là published để Flutter thấy', 'published', true],
        ]} />
      </Section>

      {/* Step 2 - Module */}
      <Section num="2" title="Tạo Module" href="/modules" color="#0891b2">
        <p>Module là một tuần học hoặc chủ đề. Mỗi Module thuộc một Course.</p>
        <Callout type="info">Trang Modules: chọn Course ở filter trước khi tạo.</Callout>
        <FieldTable rows={[
          ['Tiêu đề', 'Tên module', 'Tuần 1 · Giới thiệu bản thân', true],
          ['Course', 'Chọn course vừa tạo', '—', true],
          ['Thứ tự', 'Số thứ tự trong course', '1', true],
          ['Trạng thái', 'published để học viên thấy', 'published', true],
        ]} />
      </Section>

      {/* Step 3 - Skill */}
      <Section num="3" title="Tạo Skill" href="/skills" color="#059669">
        <p>Mỗi Module có ít nhất 1 Skill loại <Code>noi</Code>. Skill khác (<Code>nghe</Code>, <Code>doc</Code>…) có thể tạo nhưng chưa có bài tập.</p>
        <Callout type="info">Trang Skills: chọn Module ở filter trước khi tạo.</Callout>
        <FieldTable rows={[
          ['Loại kỹ năng', 'Phải là noi để có bài tập ngay', 'noi', true],
          ['Tên kỹ năng', 'Tên hiển thị', 'Nói — Tuần 1', true],
          ['Trạng thái', 'published', 'published', true],
        ]} />
      </Section>

      {/* Step 4 - Exercise */}
      <Section num="4" title="Tạo Exercise" href="/" color="var(--brand)">
        <p>Exercise là bài tập cụ thể. Form ở trang chính (Bài tập) gồm 3 tab.</p>

        <SubSection title="Tab Đề bài — chọn loại bài">
          <div style={{ display: 'grid', gap: 10 }}>
            {[
              ['Úloha 1', 'Trả lời 3–4 câu hỏi ngắn theo chủ đề', 'Điền Title + 3–4 câu hỏi (mỗi câu 1 dòng)'],
              ['Úloha 2', 'Hội thoại — hỏi để lấy thông tin', 'Scenario title + prompt + Info slots: slot_key | label | sample question'],
              ['Úloha 3', 'Kể chuyện theo tranh', 'Story title + Checkpoints (mỗi điểm 1 dòng) + upload ảnh'],
              ['Úloha 4', 'Chọn 1/3 phương án và giải thích', 'Scenario prompt + Options: option_key | label | description'],
            ].map(([uloha, desc, format]) => (
              <div key={uloha} style={{ border: '1px solid var(--border)', borderRadius: 'var(--r2)', overflow: 'hidden' }}>
                <div style={{ display: 'flex', gap: 12, alignItems: 'flex-start', padding: '12px 14px', background: 'var(--surface)' }}>
                  <span style={{ background: 'var(--brand)', color: '#fff', fontSize: 11, fontWeight: 700,
                    borderRadius: 'var(--r1)', padding: '2px 8px', flexShrink: 0, marginTop: 1 }}>{uloha}</span>
                  <div>
                    <div style={{ fontSize: 14, fontWeight: 600, color: 'var(--ink)', marginBottom: 4 }}>{desc}</div>
                    <div style={{ fontSize: 12, color: 'var(--ink-3)', fontFamily: 'monospace' }}>{format}</div>
                  </div>
                </div>
              </div>
            ))}
          </div>
        </SubSection>

        <SubSection title="Tab Bài mẫu (tùy chọn)">
          <p style={{ margin: 0, fontSize: 14, color: 'var(--ink-2)' }}>
            Câu trả lời mẫu bằng tiếng Czech. Hiện trong phần Review sau khi học viên nộp bài.
            Nếu để trống, AI tự sinh câu mẫu.
          </p>
        </SubSection>

        <SubSection title="Tab Siêu dữ liệu — BẮT BUỘC">
          <FieldTable rows={[
            ['Pool', 'Bài luyện hay bài thi?', 'Bài luyện khóa học (course)', true],
            ['Module', 'Chọn module đã tạo ở bước 2', '—', true],
            ['Skill', 'Chọn skill noi vừa tạo', '—', true],
            ['Trạng thái', 'PHẢI là published để Flutter thấy', 'published', true],
          ]} />
          <Callout type="warning">
            Exercise <Code>status = draft</Code> sẽ <b>không hiển thị</b> trên Flutter app. Luôn đổi sang <Code>published</Code>.
          </Callout>
        </SubSection>
      </Section>

      {/* Mock Test */}
      <Section num="5" title="Tạo Mock Test" href="/mock-tests" color="#6b7280">
        <p>Mock Test dùng exercises riêng (pool = exam). Không dùng chung với exercises khóa học.</p>

        <SubSection title="Bước 1 — Tạo 4 exercises thi">
          <p style={{ margin: '0 0 10px', fontSize: 14, color: 'var(--ink-2)' }}>
            Vào trang Bài tập, tạo 4 exercises, tab Siêu dữ liệu chọn:
          </p>
          <div style={{ padding: '10px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontFamily: 'monospace', fontSize: 13, color: 'var(--ink-2)' }}>
            Pool: Bài thi mock exam (exam)<br />
            Không cần chọn Module / Skill<br />
            Status: published
          </div>
        </SubSection>

        <SubSection title="Bước 2 — Tạo Mock Test và gán exercises">
          <div style={{ display: 'grid', gap: 6 }}>
            {[
              ['Section 1', 'Úloha 1', '8 điểm'],
              ['Section 2', 'Úloha 2', '12 điểm'],
              ['Section 3', 'Úloha 3', '10 điểm'],
              ['Section 4', 'Úloha 4', '7 điểm'],
            ].map(([sec, task, pts]) => (
              <div key={sec} style={{ display: 'flex', alignItems: 'center', gap: 12,
                padding: '8px 14px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r2)', fontSize: 14 }}>
                <span style={{ fontWeight: 600, color: 'var(--ink)', minWidth: 80 }}>{sec}</span>
                <span style={{ color: 'var(--ink-2)' }}>{task}</span>
                <span style={{ marginLeft: 'auto', fontWeight: 700, color: 'var(--brand)' }}>{pts}</span>
              </div>
            ))}
          </div>
          <div style={{ marginTop: 12, fontSize: 13, color: 'var(--ink-3)' }}>
            Tổng: 37 điểm + 3 điểm phát âm = <b>40 điểm</b>. Đạt: <b>≥ 24 điểm</b>.
          </div>
        </SubSection>
      </Section>

      {/* Verify */}
      <div style={{ marginTop: 40, padding: '20px 24px', background: 'var(--surface)', border: '1px solid var(--border)', borderRadius: 'var(--r3)' }}>
        <div style={{ fontSize: 12, fontWeight: 700, letterSpacing: 0.8, color: 'var(--ink-3)', textTransform: 'uppercase', marginBottom: 12 }}>Kiểm tra kết quả</div>
        <ol style={{ margin: 0, padding: '0 0 0 20px', display: 'grid', gap: 8 }}>
          {[
            'Mở Flutter app → Home → tap Course → Module → Skill "Nói"',
            'Danh sách bài tập hiện → tap để vào màn hình ghi âm',
            'Ghi âm → Phân tích → Kết quả với feedback AI',
            'Nếu không thấy bài tập: kiểm tra exercise status = published và pool = course',
          ].map((step, i) => (
            <li key={i} style={{ fontSize: 14, color: 'var(--ink-2)', lineHeight: 1.5 }}>{step}</li>
          ))}
        </ol>
      </div>

      {/* Reset */}
      <details style={{ marginTop: 24 }}>
        <summary style={{ cursor: 'pointer', fontSize: 13, fontWeight: 600, color: 'var(--ink-3)', userSelect: 'none', padding: '8px 0' }}>
          Xóa toàn bộ data (reset)
        </summary>
        <div style={{ marginTop: 12, padding: '16px', background: '#1e1e2e', borderRadius: 'var(--r2)', fontFamily: 'monospace', fontSize: 12, color: '#cdd6f4', lineHeight: 1.7, overflowX: 'auto' }}>
          {'-- docker compose exec postgres psql -U postgres -d czech_go_system'}<br />
          {'TRUNCATE TABLE attempt_review_artifacts, attempt_feedback, attempt_audio,'}<br />
          {'  attempt_transcripts, attempts, mock_exam_sections, mock_exam_sessions,'}<br />
          {'  mock_test_sections, mock_tests, exercises,'}<br />
          {'  skills, modules, courses CASCADE;'}
        </div>
      </details>

      <div style={{ height: 48 }} />
    </div>
  );
}

function Section({ num, title, href, color, children }: {
  num: string; title: string; href: string; color: string; children: React.ReactNode;
}) {
  return (
    <div style={{ marginBottom: 40 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12, marginBottom: 16 }}>
        <div style={{ width: 32, height: 32, borderRadius: '50%', background: color,
          display: 'flex', alignItems: 'center', justifyContent: 'center',
          color: '#fff', fontSize: 14, fontWeight: 700, flexShrink: 0 }}>{num}</div>
        <h2 style={{ margin: 0, fontSize: 20, fontWeight: 700, color: 'var(--ink)' }}>{title}</h2>
        <a href={href} style={{ marginLeft: 'auto', fontSize: 13, color, fontWeight: 600,
          textDecoration: 'none', padding: '4px 12px', border: `1.5px solid ${color}`,
          borderRadius: 'var(--r2)' }}>
          Mở trang →
        </a>
      </div>
      <div style={{ paddingLeft: 44, display: 'grid', gap: 16 }}>
        {children}
      </div>
      <div style={{ height: 1, background: 'var(--border)', marginTop: 32 }} />
    </div>
  );
}

function SubSection({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <div style={{ display: 'grid', gap: 10 }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: 'var(--ink-2)', letterSpacing: 0.3 }}>{title}</div>
      {children}
    </div>
  );
}

function FieldTable({ rows }: { rows: [string, string, string, boolean][] }) {
  return (
    <div style={{ border: '1px solid var(--border)', borderRadius: 'var(--r2)', overflow: 'hidden', fontSize: 13 }}>
      <div style={{ display: 'grid', gridTemplateColumns: '140px 1fr 1fr 80px',
        background: 'var(--surface-muted)', padding: '8px 14px',
        fontWeight: 700, color: 'var(--ink-3)', fontSize: 11, letterSpacing: 0.5, textTransform: 'uppercase' }}>
        <span>Field</span><span>Mô tả</span><span>Ví dụ</span><span>Bắt buộc</span>
      </div>
      {rows.map(([field, desc, example, required], i) => (
        <div key={i} style={{ display: 'grid', gridTemplateColumns: '140px 1fr 1fr 80px',
          padding: '10px 14px', borderTop: '1px solid var(--border)',
          background: i % 2 === 0 ? 'transparent' : 'var(--surface)', alignItems: 'center' }}>
          <span style={{ fontWeight: 600, color: 'var(--ink)' }}>{field}</span>
          <span style={{ color: 'var(--ink-3)' }}>{desc}</span>
          <span style={{ fontFamily: 'monospace', fontSize: 12, color: 'var(--ink-2)' }}>{example}</span>
          <span>{required
            ? <span style={{ background: '#fef2f2', color: '#dc2626', borderRadius: 4, padding: '2px 8px', fontSize: 11, fontWeight: 700 }}>bắt buộc</span>
            : <span style={{ color: 'var(--ink-4)', fontSize: 12 }}>tuỳ chọn</span>
          }</span>
        </div>
      ))}
    </div>
  );
}

function Callout({ type, children }: { type: 'info' | 'warning'; children: React.ReactNode }) {
  const isWarning = type === 'warning';
  return (
    <div style={{
      padding: '10px 14px',
      borderRadius: 'var(--r2)',
      borderLeft: `3px solid ${isWarning ? '#f59e0b' : '#3b82f6'}`,
      background: isWarning ? 'rgba(245, 158, 11, 0.06)' : 'rgba(59, 130, 246, 0.06)',
      fontSize: 13,
      color: 'var(--ink-2)',
      lineHeight: 1.5,
    }}>
      {children}
    </div>
  );
}

function Code({ children }: { children: React.ReactNode }) {
  return (
    <code style={{ background: 'var(--surface)', border: '1px solid var(--border)',
      borderRadius: 4, padding: '1px 6px', fontFamily: 'monospace', fontSize: 12 }}>
      {children}
    </code>
  );
}
