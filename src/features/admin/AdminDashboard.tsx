import { useState, useEffect, useCallback } from 'react';
import { supabase } from '../../lib/supabase';

export function AdminDashboard() {
  const [tab, setTab] = useState<'questions' | 'submissions' | 'users' | 'permissions'>('questions');
  const [questions, setQuestions] = useState<Array<{ id: string; question: string; correct_answer: string }>>([]);
  const [submissions, setSubmissions] = useState<Array<{ id: string; user_id: string; score: number; submitted_at: string }>>([]);
  const [users, setUsers] = useState<Array<{ id: string; display_name: string; school?: { name: string }; grade?: string; is_registered: boolean }>>([]);
  const [loading, setLoading] = useState(false);

  const loadData = useCallback(async () => {
    setLoading(true);
    try {
      if (tab === 'questions') {
        const { data } = await supabase
          .from('quiz_questions')
          .select('*')
          .order('created_at');
        setQuestions(data || []);
      } else if (tab === 'submissions') {
        const { data } = await supabase
          .from('quiz_submissions')
          .select('*, user_id, submitted_at, score')
          .order('submitted_at', { ascending: false });
        setSubmissions(data || []);
      } else if (tab === 'users') {
        const { data: profiles } = await supabase
          .from('profiles')
          .select('*, school:schools(name)')
          .order('created_at', { ascending: false });
        setUsers(profiles || []);
      }
    } catch (e: unknown) {
      if (e instanceof Error) console.error('Error:', e.message);
    } finally {
      setLoading(false);
    }
  }, [tab]);

  useEffect(() => {
    // eslint-disable-next-line react/set-state-in-effect
    loadData();
  }, [loadData]);


  return (
    <div className="container-fluid mt-5">
      <h1>🔧 Admin Dashboard</h1>

      <ul className="nav nav-tabs mt-4">
        <li className="nav-item">
          <button
            className={`nav-link ${tab === 'questions' ? 'active' : ''}`}
            onClick={() => setTab('questions')}
          >
            📝 Quản lý câu hỏi
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${tab === 'submissions' ? 'active' : ''}`}
            onClick={() => setTab('submissions')}
          >
            ✓ Kết quả thi
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${tab === 'users' ? 'active' : ''}`}
            onClick={() => setTab('users')}
          >
            👥 Quản lý học sinh
          </button>
        </li>
        <li className="nav-item">
          <button
            className={`nav-link ${tab === 'permissions' ? 'active' : ''}`}
            onClick={() => setTab('permissions')}
          >
            🔐 Quyền truy cập
          </button>
        </li>
      </ul>

      <div className="mt-4">
        {loading && <div className="alert alert-info">Loading...</div>}

        {tab === 'questions' && (
          <QuestionManager questions={questions} onUpdate={loadData} />
        )}

        {tab === 'submissions' && (
          <SubmissionViewer submissions={submissions} />
        )}

        {tab === 'users' && (
          <UserManager users={users} />
        )}

        {tab === 'permissions' && (
          <PermissionsManager />
        )}
      </div>
    </div>
  );
}

interface QuestionManagerProps {
  questions: Array<{ id: string; question: string; correct_answer: string }>;
  onUpdate: () => void;
}

function QuestionManager({ questions, onUpdate }: QuestionManagerProps) {
  const [showForm, setShowForm] = useState(false);
  const [formData, setFormData] = useState({
    question: '',
    option_a: '',
    option_b: '',
    option_c: '',
    option_d: '',
    correct_answer: 'A',
    explanation: '',
  });

  async function handleAdd() {
    try {
      const user = await supabase.auth.getUser();
      await supabase.from('quiz_questions').insert({
        ...formData,
        created_by: user.data.user?.id,
      });
      setFormData({
        question: '',
        option_a: '',
        option_b: '',
        option_c: '',
        option_d: '',
        correct_answer: 'A',
        explanation: '',
      });
      setShowForm(false);
      onUpdate();
    } catch (e: unknown) {
      if (e instanceof Error) alert('Error: ' + e.message);
    }
  }

  return (
    <div>
      <button className="btn btn-primary mb-3" onClick={() => setShowForm(!showForm)}>
        {showForm ? '✕ Hủy' : '+ Thêm câu hỏi'}
      </button>

      {showForm && (
        <div className="card mb-4">
          <div className="card-body">
            <div className="mb-3">
              <label className="form-label">Câu hỏi</label>
              <textarea
                className="form-control"
                value={formData.question}
                onChange={(e) =>
                  setFormData({ ...formData, question: e.target.value })
                }
                rows={3}
              />
            </div>

            {['A', 'B', 'C', 'D'].map((opt) => (
              <div key={opt} className="mb-3">
                <label className="form-label">Đáp án {opt}</label>
                <input
                  type="text"
                  className="form-control"
                  value={formData[`option_${opt.toLowerCase()}` as keyof typeof formData]}
                  onChange={(e) =>
                    setFormData({
                      ...formData,
                      [`option_${opt.toLowerCase()}`]: e.target.value,
                    })
                  }
                />
              </div>
            ))}

            <div className="mb-3">
              <label className="form-label">Đáp án đúng</label>
              <select
                className="form-select"
                value={formData.correct_answer}
                onChange={(e) =>
                  setFormData({ ...formData, correct_answer: e.target.value })
                }
              >
                {['A', 'B', 'C', 'D'].map((opt) => (
                  <option key={opt} value={opt}>
                    {opt}
                  </option>
                ))}
              </select>
            </div>

            <div className="mb-3">
              <label className="form-label">Giải thích</label>
              <textarea
                className="form-control"
                value={formData.explanation}
                onChange={(e) =>
                  setFormData({ ...formData, explanation: e.target.value })
                }
                rows={2}
              />
            </div>

            <button className="btn btn-success" onClick={handleAdd}>
              ✓ Lưu câu hỏi
            </button>
          </div>
        </div>
      )}

      <div className="table-responsive">
        <table className="table table-striped">
          <thead>
            <tr>
              <th>#</th>
              <th>Câu hỏi</th>
              <th>Đáp án</th>
              <th>Action</th>
            </tr>
          </thead>
          <tbody>
            {questions.map((q, idx: number) => (
              <tr key={q.id}>
                <td>{idx + 1}</td>
                <td>{q.question.substring(0, 50)}...</td>
                <td>{q.correct_answer}</td>
                <td>
                  <button className="btn btn-sm btn-warning">Edit</button>
                  <button className="btn btn-sm btn-danger ms-2">Delete</button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}

interface SubmissionViewerProps {
  submissions: Array<{ id: string; user_id: string; score: number; submitted_at: string }>;
}

function SubmissionViewer({ submissions }: SubmissionViewerProps) {
  return (
    <div className="table-responsive">
      <table className="table table-striped">
        <thead>
          <tr>
            <th>Student ID</th>
            <th>Score</th>
            <th>Submitted</th>
            <th>Action</th>
          </tr>
        </thead>
        <tbody>
          {submissions.map((sub) => (
            <tr key={sub.id}>
              <td>{sub.user_id.substring(0, 8)}</td>
              <td>
                <strong>{sub.score}</strong>
              </td>
              <td>{new Date(sub.submitted_at).toLocaleDateString()}</td>
              <td>
                <button className="btn btn-sm btn-info">View</button>
              </td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

interface UserManagerProps {
  users: Array<{ id: string; display_name: string; school?: { name: string }; grade?: string; is_registered: boolean }>;
}

function UserManager({ users }: UserManagerProps) {
  return (
    <div className="table-responsive">
      <table className="table table-striped">
        <thead>
          <tr>
            <th>Name</th>
            <th>School</th>
            <th>Grade</th>
            <th>Registered</th>
          </tr>
        </thead>
        <tbody>
          {users.map((user) => (
            <tr key={user.id}>
              <td>{user.display_name}</td>
              <td>{user.school?.name || '-'}</td>
              <td>{user.grade || '-'}</td>
              <td>{user.is_registered ? '✓' : '✕'}</td>
            </tr>
          ))}
        </tbody>
      </table>
    </div>
  );
}

function PermissionsManager() {
  return (
    <div className="alert alert-info">
      <h5>🔐 Quản lý quyền (ĐỘNG)</h5>
      <p>Chọn role → chọn resource → chọn action → Lưu</p>
      <p className="text-muted">Admin có thể thêm/xóa permissions mà không cần deploy lại code.</p>
      {/* TODO: Implement permission UI form */}
    </div>
  );
}
