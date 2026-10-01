import { useState, useEffect } from 'react';
import { supabase } from '../../lib/supabase';

export function StudentQuiz() {
  const [questions, setQuestions] = useState<Array<{ id: string; question: string; option_a: string; option_b: string; option_c: string; option_d: string; correct_answer: string }>>([]);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  const [currentQuestion, setCurrentQuestion] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [submitted, setSubmitted] = useState(false);
  const [score, setScore] = useState<number | null>(null);

  useEffect(() => {
    const loadQuestions = async () => {
    try {
      const { data, error: err } = await supabase
        .from('quiz_questions')
        .select('*')
        .order('created_at');

      if (err) throw err;
      setQuestions(data || []);

      // Initialize answers
      const init: Record<string, string> = {};
      data?.forEach((q) => {
        init[q.id] = '';
      });
      setAnswers(init);
    } catch (e: unknown) {
      if (e instanceof Error) setError(e.message);
    } finally {
      setLoading(false);
    }
    };
    loadQuestions();
  }, []);

  function handleAnswerChange(questionId: string, answer: string) {
    setAnswers((prev) => ({
      ...prev,
      [questionId]: answer,
    }));
  }

  async function handleSubmit() {
    if (!window.confirm('Xác nhận nộp bài? Bạn không thể thay đổi sau đó.')) {
      return;
    }

    setLoading(true);
    try {
      const user = await supabase.auth.getUser();
      if (!user.data.user) throw new Error('Not authenticated');

      // Calculate score
      let calculatedScore = 0;
      questions.forEach((q) => {
        if (answers[q.id] === q.correct_answer) {
          calculatedScore += 1;
        }
      });

      // Submit
      const { error: err } = await supabase
        .from('quiz_submissions')
        .insert({
          user_id: user.data.user.id,
          answers,
          score: calculatedScore,
        });

      if (err) throw err;
      setScore(calculatedScore);
      setSubmitted(true);
    } catch (e: unknown) {
      if (e instanceof Error) setError(e.message);
    } finally {
      setLoading(false);
    }
  }

  if (loading) return <div className="alert alert-info">Loading...</div>;
  if (error) return <div className="alert alert-danger">{error}</div>;

  if (submitted) {
    return (
      <div className="container mt-5">
        <div className="alert alert-success text-center">
          <h2>✅ Nộp bài thành công!</h2>
          <h3 className="mt-3">Điểm của bạn: {score}/{questions.length}</h3>
          <p className="mt-3">Cảm ơn bạn đã tham gia cuộc thi!</p>
        </div>
      </div>
    );
  }

  if (questions.length === 0) {
    return <div className="alert alert-warning">Chưa có câu hỏi nào.</div>;
  }

  const q = questions[currentQuestion];

  return (
    <div className="container mt-5">
      <div className="row">
        <div className="col-md-8">
          <div className="card">
            <div className="card-header">
              <div className="d-flex justify-content-between align-items-center">
                <span>Câu {currentQuestion + 1}/{questions.length}</span>
                <div className="progress" style={{ width: '200px', height: '25px' }}>
                  <div
                    className="progress-bar"
                    style={{
                      width: `${((currentQuestion + 1) / questions.length) * 100}%`,
                    }}
                  />
                </div>
              </div>
            </div>

            <div className="card-body">
              <h5 className="card-title">{q.question}</h5>

              <div className="mt-4">
                {['A', 'B', 'C', 'D'].map((option) => (
                  <div key={option} className="form-check mb-3">
                    <input
                      className="form-check-input"
                      type="radio"
                      name={`question-${q.id}`}
                      id={`${q.id}-${option}`}
                      value={option}
                      checked={answers[q.id] === option}
                      onChange={(e) => handleAnswerChange(q.id, e.target.value)}
                    />
                    <label className="form-check-label" htmlFor={`${q.id}-${option}`}>
                      {option}. {(q as Record<string, string>)[`option_${option.toLowerCase()}`]}
                    </label>
                  </div>
                ))}
              </div>
            </div>

            <div className="card-footer">
              <div className="d-flex justify-content-between">
                <button
                  className="btn btn-secondary"
                  onClick={() => setCurrentQuestion(Math.max(0, currentQuestion - 1))}
                  disabled={currentQuestion === 0}
                >
                  ← Câu trước
                </button>

                <div>
                  {currentQuestion === questions.length - 1 ? (
                    <button
                      className="btn btn-success"
                      onClick={handleSubmit}
                      disabled={loading}
                    >
                      ✓ Nộp bài
                    </button>
                  ) : (
                    <button
                      className="btn btn-primary"
                      onClick={() => setCurrentQuestion(currentQuestion + 1)}
                    >
                      Câu tiếp →
                    </button>
                  )}
                </div>
              </div>
            </div>
          </div>
        </div>

        <div className="col-md-4">
          <div className="card">
            <div className="card-header">
              <strong>Navigator</strong>
            </div>
            <div className="card-body" style={{ maxHeight: '600px', overflowY: 'auto' }}>
              <div className="d-flex flex-wrap gap-2">
                {questions.map((question, idx) => (
                  <button
                    key={question.id}
                    className={`btn btn-sm ${
                      answers[question.id]
                        ? 'btn-success'
                        : currentQuestion === idx
                          ? 'btn-primary'
                          : 'btn-outline-secondary'
                    }`}
                    onClick={() => setCurrentQuestion(idx)}
                  >
                    {idx + 1}
                  </button>
                ))}
              </div>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}
