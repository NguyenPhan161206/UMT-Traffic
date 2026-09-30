import { useUser } from './hooks/useUser';
import { Login } from './features/auth/Login';
import { StudentRegistration } from './features/student/StudentRegistration';
import { StudentQuiz } from './features/student/StudentQuiz';
import { AdminDashboard } from './features/admin/AdminDashboard';

function App() {
  const { user, loading, logout } = useUser();

  if (loading) {
    return (
      <div className="d-flex justify-content-center align-items-center vh-100">
        <div className="spinner-border" role="status">
          <span className="visually-hidden">Loading...</span>
        </div>
      </div>
    );
  }

  if (!user) {
    return <Login />;
  }

  return (
    <>
      <nav className="navbar navbar-expand-lg navbar-dark bg-dark mb-4">
        <div className="container-fluid">
          <span className="navbar-brand">🚗 Cuộc thi An toàn Giao thông</span>
          <div className="ms-auto">
            <span className="text-light me-3">{user.email}</span>
            <button className="btn btn-outline-light btn-sm" onClick={logout}>
              Đăng xuất
            </button>
          </div>
        </div>
      </nav>

      <main className="container">
        {user.role === 'admin' ? (
          <AdminDashboard />
        ) : user.is_registered ? (
          <StudentQuiz />
        ) : (
          <StudentRegistration />
        )}
      </main>
    </>
  );
}

export default App;