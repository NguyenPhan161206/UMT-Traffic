import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';

export function StudentRegistration() {
  const [displayName, setDisplayName] = useState('');
  const [schoolId, setSchoolId] = useState('');
  const [grade, setGrade] = useState('10');
  const [schools, setSchools] = useState<Array<{ id: string; name: string; city?: string }>>([]);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState('');
  const [success, setSuccess] = useState(false);

  useEffect(() => {
    const loadSchools = async () => {
      try {
        const { data, error: err } = await supabase
          .from('schools')
          .select('*')
          .order('name');

        if (err) throw err;
        setSchools(data || []);
      } catch (e: unknown) {
        if (e instanceof Error) setError(e.message);
      }
    };
    loadSchools();
  }, []);

  async function handleRegister() {
    if (!displayName.trim() || !schoolId) {
      setError('Vui lòng điền đủ thông tin');
      return;
    }

    setLoading(true);
    setError('');

    try {
      const user = await supabase.auth.getUser();
      if (!user.data.user) throw new Error('Not authenticated');

      const { error: err } = await supabase
        .from('profiles')
        .update({
          display_name: displayName,
          school_id: schoolId,
          grade,
          is_registered: true,
        })
        .eq('id', user.data.user.id);

      if (err) throw err;
      setSuccess(true);
      setTimeout(() => {
        window.location.href = '/quiz';
      }, 1000);
    } catch (e: unknown) {
      if (e instanceof Error) {
        setError(e.message);
      }
    } finally {
      setLoading(false);
    }
  }

  return (
    <div className="container mt-5">
      <div className="row justify-content-center">
        <div className="col-md-6">
          <div className="card">
            <div className="card-body">
              <h2 className="card-title">📝 Ghi danh cuộc thi</h2>

              {error && <div className="alert alert-danger">{error}</div>}
              {success && <div className="alert alert-success">Đăng ký thành công! Chuyển hướng...</div>}

              <div className="mb-3">
                <label className="form-label">Họ và tên</label>
                <input
                  type="text"
                  className="form-control"
                  value={displayName}
                  onChange={(e) => setDisplayName(e.target.value)}
                  placeholder="Nguyễn Văn A"
                />
              </div>

              <div className="mb-3">
                <label className="form-label">Trường THPT</label>
                <select
                  className="form-select"
                  value={schoolId}
                  onChange={(e) => setSchoolId(e.target.value)}
                >
                  <option value="">-- Chọn trường --</option>
                  {schools.map((school) => (
                    <option key={school.id} value={school.id}>
                      {school.name}
                    </option>
                  ))}
                </select>
              </div>

              <div className="mb-3">
                <label className="form-label">Khối lớp</label>
                <select
                  className="form-select"
                  value={grade}
                  onChange={(e) => setGrade(e.target.value)}
                >
                  <option value="10">Khối 10</option>
                  <option value="11">Khối 11</option>
                  <option value="12">Khối 12</option>
                </select>
              </div>

              <button
                className="btn btn-primary w-100"
                onClick={handleRegister}
                disabled={loading}
              >
                {loading ? 'Đang xử lý...' : 'Đăng ký & Vào thi'}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
