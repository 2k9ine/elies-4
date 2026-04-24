-- ============================================
-- ELI'S LEARNING — SUPABASE SQL SCHEMA
-- ============================================
-- Run this in Supabase SQL Editor
-- ============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ============================================
-- AUTH & USERS
-- ============================================

-- Create auth.users trigger to auto-create profile
CREATE TABLE public.profiles (
  id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
  email TEXT NOT NULL,
  full_name TEXT,
  role TEXT DEFAULT 'admin' CHECK (role IN ('admin', 'teacher')),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, email, full_name)
  VALUES (
    NEW.id,
    NEW.email,
    COALESCE(NEW.raw_user_meta_data->>'full_name', NEW.email)
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- ============================================
-- STUDENTS
-- ============================================

CREATE TABLE public.students (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT,
  phone TEXT,
  parent_name TEXT,
  parent_phone TEXT,
  instrument TEXT DEFAULT 'Piano',
  grade_level INTEGER DEFAULT 1 CHECK (grade_level >= 1 AND grade_level <= 8),
  teacher_id UUID REFERENCES public.profiles(id),
  start_date DATE DEFAULT CURRENT_DATE,
  status TEXT DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'archived')),
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- BOOKS
-- ============================================

CREATE TABLE public.books (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  title TEXT NOT NULL,
  grade_level INTEGER NOT NULL CHECK (grade_level >= 1 AND grade_level <= 8),
  isbn TEXT,
  publisher TEXT,
  total_stock INTEGER DEFAULT 0 CHECK (total_stock >= 0),
  low_stock_threshold INTEGER DEFAULT 2 CHECK (low_stock_threshold >= 0),
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(title, grade_level)
);

-- ============================================
-- BOOK ISSUANCES
-- ============================================

CREATE TABLE public.book_issuances (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  book_id UUID NOT NULL REFERENCES public.books(id) ON DELETE RESTRICT,
  issued_date DATE DEFAULT CURRENT_DATE,
  returned_date DATE,
  condition_issued TEXT DEFAULT 'good',
  condition_returned TEXT,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- OBSERVATIONS
-- ============================================

CREATE TABLE public.observations (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES public.profiles(id),
  observation_date DATE DEFAULT CURRENT_DATE,
  category TEXT DEFAULT 'general' CHECK (category IN ('general', 'progress', 'behavior', 'technique', 'performance', 'other')),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  flags TEXT[] DEFAULT '{}',
  follow_up_required BOOLEAN DEFAULT FALSE,
  follow_up_notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- REPORTS
-- ============================================

CREATE TABLE public.reports (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES public.profiles(id),
  report_type TEXT DEFAULT 'progress' CHECK (report_type IN ('progress', 'assessment', 'evaluation')),
  tone TEXT NOT NULL CHECK (tone IN ('good', 'average', 'needs_improvement')),
  title TEXT,
  content TEXT NOT NULL,
  generated_ai BOOLEAN DEFAULT TRUE,
  assessment_date DATE DEFAULT CURRENT_DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ATTENDANCE (existing, for reference)
-- ============================================

CREATE TABLE public.attendance (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  teacher_id UUID REFERENCES public.profiles(id),
  attendance_date DATE NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
  make_up_lesson BOOLEAN DEFAULT FALSE,
  notes TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  UNIQUE(student_id, attendance_date)
);

-- ============================================
-- MUSIC PIECES (existing, for reference)
-- ============================================

CREATE TABLE public.music_pieces (
  id UUID DEFAULT uuid_generate_v4() PRIMARY KEY,
  student_id UUID NOT NULL REFERENCES public.students(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  composer TEXT,
  grade_level INTEGER,
  status TEXT DEFAULT 'learning' CHECK (status IN ('learning', 'practicing', 'mastered', 'performed', 'archived')),
  notes TEXT,
  started_date DATE DEFAULT CURRENT_DATE,
  completed_date DATE,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================
-- ROW LEVEL SECURITY (RLS)
-- ============================================

-- Enable RLS on all tables
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.book_issuances ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.observations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.music_pieces ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update own profile
CREATE POLICY "Users can view own profile"
  ON public.profiles FOR SELECT
  USING (auth.uid() = id);

CREATE POLICY "Users can update own profile"
  ON public.profiles FOR UPDATE
  USING (auth.uid() = id);

-- Students: authenticated users can do everything
CREATE POLICY "Authenticated users can read students"
  ON public.students FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert students"
  ON public.students FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update students"
  ON public.students FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete students"
  ON public.students FOR DELETE
  USING (auth.role() = 'authenticated');

-- Books: authenticated users full access
CREATE POLICY "Authenticated users can read books"
  ON public.books FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert books"
  ON public.books FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update books"
  ON public.books FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete books"
  ON public.books FOR DELETE
  USING (auth.role() = 'authenticated');

-- Book issuances: authenticated users full access
CREATE POLICY "Authenticated users can read issuances"
  ON public.book_issuances FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert issuances"
  ON public.book_issuances FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update issuances"
  ON public.book_issuances FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete issuances"
  ON public.book_issuances FOR DELETE
  USING (auth.role() = 'authenticated');

-- Observations: authenticated users full access
CREATE POLICY "Authenticated users can read observations"
  ON public.observations FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert observations"
  ON public.observations FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update observations"
  ON public.observations FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete observations"
  ON public.observations FOR DELETE
  USING (auth.role() = 'authenticated');

-- Reports: authenticated users full access
CREATE POLICY "Authenticated users can read reports"
  ON public.reports FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert reports"
  ON public.reports FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update reports"
  ON public.reports FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete reports"
  ON public.reports FOR DELETE
  USING (auth.role() = 'authenticated');

-- Attendance: authenticated users full access
CREATE POLICY "Authenticated users can read attendance"
  ON public.attendance FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert attendance"
  ON public.attendance FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update attendance"
  ON public.attendance FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete attendance"
  ON public.attendance FOR DELETE
  USING (auth.role() = 'authenticated');

-- Music pieces: authenticated users full access
CREATE POLICY "Authenticated users can read pieces"
  ON public.music_pieces FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can insert pieces"
  ON public.music_pieces FOR INSERT
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can update pieces"
  ON public.music_pieces FOR UPDATE
  USING (auth.role() = 'authenticated');

CREATE POLICY "Authenticated users can delete pieces"
  ON public.music_pieces FOR DELETE
  USING (auth.role() = 'authenticated');

-- ============================================
-- FUNCTIONS & TRIGGERS
-- ============================================

-- Auto-update updated_at timestamp
CREATE OR REPLACE FUNCTION public.update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_students_updated_at
  BEFORE UPDATE ON public.students
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_books_updated_at
  BEFORE UPDATE ON public.books
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_observations_updated_at
  BEFORE UPDATE ON public.observations
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_reports_updated_at
  BEFORE UPDATE ON public.reports
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

CREATE TRIGGER update_music_pieces_updated_at
  BEFORE UPDATE ON public.music_pieces
  FOR EACH ROW EXECUTE FUNCTION public.update_updated_at();

-- Auto-decrement stock on book issuance
CREATE OR REPLACE FUNCTION public.decrement_stock_on_issuance()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.books
  SET total_stock = total_stock - 1
  WHERE id = NEW.book_id AND total_stock > 0;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_book_issuance_insert
  AFTER INSERT ON public.book_issuances
  FOR EACH ROW EXECUTE FUNCTION public.decrement_stock_on_issuance();

-- Auto-increment stock on book return
CREATE OR REPLACE FUNCTION public.increment_stock_on_return()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.returned_date IS NOT NULL AND OLD.returned_date IS NULL THEN
    UPDATE public.books
    SET total_stock = total_stock + 1
    WHERE id = NEW.book_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_book_issuance_update
  AFTER UPDATE ON public.book_issuances
  FOR EACH ROW EXECUTE FUNCTION public.increment_stock_on_return();

-- ============================================
-- SAMPLE DATA (optional - comment out for production)
-- ============================================

-- INSERT INTO public.books (title, grade_level, total_stock) VALUES
--   ('Piano Grade 1 - Selected Examination Pieces', 1, 10),
--   ('Piano Grade 2 - Selected Examination Pieces', 2, 8),
--   ('Piano Grade 3 - Selected Examination Pieces', 3, 6),
--   ('Piano Grade 4 - Selected Examination Pieces', 4, 5),
--   ('Piano Grade 5 - Selected Examination Pieces', 5, 4),
--   ('Piano Grade 6 - Selected Examination Pieces', 6, 3),
--   ('Piano Grade 7 - Selected Examination Pieces', 7, 2),
--   ('Piano Grade 8 - Selected Examination Pieces', 8, 2);
