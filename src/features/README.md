# Feature-Sliced Architecture

Thư mục này chứa các tính năng (features) cốt lõi của ứng dụng. Mỗi tính năng hoạt động như một module độc lập.

## Quy Tắc Bắt Buộc (Clean Code)

1. **Isolation (Cô lập):** 
   - Một tính năng KHÔNG ĐƯỢC import trực tiếp các file nằm sâu bên trong tính năng khác.
   - Tránh việc: `import { QuizTimer } from '../quiz/components/QuizTimer'` từ bên trong thư mục `auth/`.

2. **Public API (`index.ts`):**
   - Chỉ xuất (export) những thành phần (components, types, hooks) mà ứng dụng bên ngoài thực sự cần.
   - Nếu tính năng `A` cần dùng thành phần của tính năng `B`, thì `B` phải export thành phần đó ra `index.ts`.

3. **Data Access (Gọi Supabase):**
   - Tuyệt đối không gọi `supabase.from(...)` bên trong các UI Component.
   - Các logic tương tác DB phải nằm trong thư mục `api/` hoặc `hooks/` của tính năng đó.

## Cấu Trúc Mỗi Feature

```text
features/feature-name/
├── api/             # API request / Supabase queries
├── components/      # UI components (chỉ dùng cho feature này)
├── hooks/           # Custom hooks chứa business logic
├── types/           # Type definitions (TS)
└── index.ts         # Public API (Entry point)
```
