-- Seed schools
insert into public.schools (name, city) values
  ('THPT Nguyễn Huệ', 'Hà Nội'),
  ('THPT Trần Phú', 'Hà Nội'),
  ('THPT Lê Quý Đôn', 'Hồ Chí Minh'),
  ('THPT Phan Bội Châu', 'Huế'),
  ('THPT Trường Chinh', 'Đà Nẵng')
on conflict (name) do nothing;

-- Seed quiz questions
insert into public.quiz_questions (
  question,
  option_a,
  option_b,
  option_c,
  option_d,
  correct_answer,
  explanation
) values
  (
    'Biển báo giao thông nào chỉ dành cho xe máy?',
    'Biển tròn với ký tự M',
    'Biển vuông màu xanh',
    'Biển hình mũi tên',
    'Biển hình tam giác',
    'A',
    'Biển báo hình tròn với ký tự M được dùng để cấm và hạn chế các xe máy.'
  ),
  (
    'Tốc độ tối đa cho phép trong đô thị là bao nhiêu?',
    '30 km/h',
    '40 km/h',
    '50 km/h',
    '60 km/h',
    'C',
    'Theo quy tắc giao thông, tốc độ tối đa trong đô thị là 50 km/h.'
  ),
  (
    'Khi gặp tín hiệu đèn đỏ, người tham gia giao thông nên làm gì?',
    'Tăng tốc qua nhanh',
    'Dừng lại ở vạch chờ',
    'Vượt sang làn khác',
    'Rẽ trái bỏ qua',
    'B',
    'Khi gặp đèn đỏ, phải dừng lại trước vạch chờ và chỉ được tiếp tục khi đèn xanh sáng.'
  ),
  (
    'Khoảng cách an toàn tối thiểu giữa hai xe ô tô khi lưu thông là bao nhiêu?',
    '1 mét',
    '2 mét',
    '3 mét',
    '5 mét',
    'C',
    'Khoảng cách an toàn giữa hai xe phải đủ để tránh va chạm khi xe phía trước phanh đột ngột, thường tối thiểu 3 mét.'
  ),
  (
    'Đội mũ bảo hiểm khi điều khiển xe máy là bắt buộc?',
    'Chỉ trong thành phố',
    'Chỉ trên đường cao tốc',
    'Ở tất cả mọi nơi',
    'Tuỳ theo sở thích',
    'C',
    'Quy định giao thông yêu cầu bắt buộc đội mũ bảo hiểm khi điều khiển mọi loại xe máy ở tất cả mọi nơi.'
  )
on conflict do nothing;
