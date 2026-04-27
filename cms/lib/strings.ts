// CMS UI strings — Vietnamese. Import from here instead of hardcoding in components.

export const S = {
  // ── Nav ────────────────────────────────────────────────────────────────────
  nav: {
    exercises:  'Bài tập',
    courses:    'Khóa học',
    mockTests:  'Mock Test',
    learners:   'Học viên',
    modules:    'Module',
    skills:     'Kỹ năng',
  },

  // ── Common actions ─────────────────────────────────────────────────────────
  action: {
    create:      'Tạo',
    edit:        'Chỉnh sửa',
    save:        'Lưu',
    saveChanges: 'Lưu thay đổi',
    saving:      'Đang lưu…',
    delete:      'Xóa',
    cancel:      'Hủy',
    update:      'Cập nhật',
  },

  // ── Status labels ──────────────────────────────────────────────────────────
  status: {
    draft:      'Bản nháp',
    published:  'Đã xuất bản',
    archived:   'Đã lưu trữ',
  },

  // ── Dropdown placeholders ──────────────────────────────────────────────────
  pick: {
    module:   '— Chọn module —',
    skill:    '— Chọn kỹ năng —',
    course:   '— Chọn khóa học —',
    exercise: '— Chọn bài tập —',
    moduleForSkills: '— Chọn module để xem kỹ năng —',
    allCourses: 'Tất cả khóa học',
  },

  // ── Exercise dashboard ─────────────────────────────────────────────────────
  exercise: {
    tabPrompt:    'Đề bài',
    tabSample:    'Bài mẫu',
    tabMetadata:  'Siêu dữ liệu',
    createTitle:  'Tạo bài tập',
    editTitle:    'Chỉnh sửa bài tập',
    createCta:    'Tạo bài tập',
    updateCta:    'Cập nhật bài tập',
    poolCourse:   'Bài luyện khóa học (course)',
    poolExam:     'Bài thi mock exam (exam)',
  },

  // ── Mock test dashboard ────────────────────────────────────────────────────
  mockTest: {
    createTitle: 'Đề thi mới',
    editTitle:   'Chỉnh sửa đề thi',
    newCta:      '+ Thêm đề thi mới',
    createCta:   'Tạo',
    updateCta:   'Lưu thay đổi',
    maxPointsLabel: 'Điểm tối đa',
    emptyState: 'Chưa có đề thi nào.',
  },

  // ── Module dashboard ───────────────────────────────────────────────────────
  module: {
    createTitle: 'Module mới',
    editTitle:   'Chỉnh sửa module',
    newCta:      '+ Thêm module mới',
    filterLabel: 'Lọc theo khóa học:',
    filterCta:   'Lọc',
  },

  // ── Skill dashboard ────────────────────────────────────────────────────────
  skill: {
    createTitle:    'Kỹ năng mới',
    editTitle:      'Chỉnh sửa kỹ năng',
    newCta:         '+ Thêm kỹ năng mới',
    filterLabel:    'Lọc theo module:',
    emptyModule:    'Chọn module ở trên để quản lý kỹ năng.',
    emptySkills:    'Chưa có kỹ năng nào cho module này.',
    kindLabel:      'Loại kỹ năng *',
    titleLabel:     'Tên kỹ năng',
  },

  // ── Learners dashboard ─────────────────────────────────────────────────────
  learners: {
    viewAttempts: 'Lượt nộp',
    viewLearners: 'Học viên',
    colTime:      'Thời gian',
    colExercise:  'Bài tập',
    colStatus:    'Trạng thái',
    colCount:     'Lần',
    colPlatform:  'Nền tảng',
    colLearner:   'Học viên',
    colAttempts:  'Lượt',
    colCompleted: 'Hoàn thành',
    colReadiness: 'Phân bố readiness',
    colRecent:    'Gần nhất',
  },

  // ── Dashboard stats ────────────────────────────────────────────────────────
  stats: {
    activeUsers:  'Học viên active (7d)',
    attemptsDay:  'Bài hoàn thành/ngày',
    passRate:     'Pass rate Mock A2',
    aiAgreement:  'AI / reviewer đồng ý',
  },
} as const;
