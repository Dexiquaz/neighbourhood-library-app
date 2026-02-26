# Database Schema Documentation

Complete SQL schema for Neighbourhood Library Management system exported directly from Supabase.

## Core Tables

### Profiles Table
```sql
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  name text NOT NULL,
  latitude double precision NOT NULL,
  longitude double precision NOT NULL,
  locality text,
  created_at timestamp with time zone DEFAULT now(),
  age integer,
  gender text,
  phone_number text,
  bio text,
  profile_picture_url text,
  address text,
  favorite_genres text[],
  CONSTRAINT profiles_pkey PRIMARY KEY (id),
  CONSTRAINT profiles_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id)
);
```

### Books Table
```sql
CREATE TABLE public.books (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  title text NOT NULL,
  author text,
  isbn text,
  owner_id uuid NOT NULL,
  status text DEFAULT 'available'::text CHECK (status = ANY (ARRAY['available'::text, 'borrowed'::text])),
  created_at timestamp with time zone DEFAULT now(),
  genre text,
  condition character varying DEFAULT 'good'::character varying,
  language text DEFAULT 'English'::text,
  edition integer,
  pages integer,
  rating numeric DEFAULT 0,
  rating_count integer DEFAULT 0,
  borrow_count integer DEFAULT 0,
  average_borrow_duration_days integer,
  last_borrowed_at timestamp without time zone,
  trending_score numeric DEFAULT 0,
  CONSTRAINT books_pkey PRIMARY KEY (id),
  CONSTRAINT books_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
```

### Borrow Requests Table
```sql
CREATE TABLE public.borrow_requests (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  book_id uuid NOT NULL,
  borrower_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  status text DEFAULT 'pending'::text CHECK (status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text, 'returned'::text, 'completed'::text])),
  due_date date,
  created_at timestamp with time zone DEFAULT now(),
  borrower_rating integer,
  owner_rating integer,
  review text,
  actual_borrow_duration_days integer,
  CONSTRAINT borrow_requests_pkey PRIMARY KEY (id),
  CONSTRAINT borrow_requests_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id),
  CONSTRAINT borrow_requests_borrower_id_fkey FOREIGN KEY (borrower_id) REFERENCES public.profiles(id),
  CONSTRAINT borrow_requests_owner_id_fkey FOREIGN KEY (owner_id) REFERENCES public.profiles(id)
);
```

### Messages Table (for chat in borrow requests)
```sql
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  request_id uuid,
  sender_id uuid,
  content text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  is_seen boolean DEFAULT false,
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_request_id_fkey FOREIGN KEY (request_id) REFERENCES public.borrow_requests(id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES auth.users(id)
);
```

## Analytics Tables

### Analytics Logs Table
```sql
CREATE TABLE public.analytics_logs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  book_id uuid,
  event_type text,
  created_at timestamp without time zone DEFAULT now(),
  CONSTRAINT analytics_logs_pkey PRIMARY KEY (id),
  CONSTRAINT analytics_logs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT analytics_logs_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id)
);
```

### User Preferences Table (for ML/Recommendations)
```sql
CREATE TABLE public.user_preferences (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL UNIQUE,
  genre_scores jsonb DEFAULT '{}'::jsonb,
  preferred_condition text,
  preferred_language text DEFAULT 'English'::text,
  updated_at timestamp without time zone DEFAULT now(),
  CONSTRAINT user_preferences_pkey PRIMARY KEY (id),
  CONSTRAINT user_preferences_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
```

### Reviews Table
```sql
CREATE TABLE public.reviews (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  book_id uuid NOT NULL,
  reviewer_id uuid NOT NULL,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  review_text text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reviews_pkey PRIMARY KEY (id),
  CONSTRAINT reviews_book_id_fkey FOREIGN KEY (book_id) REFERENCES public.books(id),
  CONSTRAINT reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id)
);
```

## Row Level Security (RLS) Policies

### Enable RLS on All Tables

```sql
-- Run this first to enable RLS on all tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE books ENABLE ROW LEVEL SECURITY;
ALTER TABLE borrow_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE analytics_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE reviews ENABLE ROW LEVEL SECURITY;
```

### Security Model Summary

- **Profiles**: Public (everyone can view), but users can only update their own
- **Books**: Public (everyone can view), users can insert and update only their own books
- **Borrow Requests**: Private (only participants can view), borrowers can create, owners can approve/reject
- **Messages**: Private (only participants in the request can view), only senders can insert
- **Analytics & Preferences**: Personal (users can only access their own data)

### Table: Profiles Policies

```sql
-- Users can view all profiles (public profiles)
CREATE POLICY "Users can view profiles" ON profiles
  FOR SELECT USING (true);

-- Users can insert their own profile
CREATE POLICY "Users can insert their own profile" ON profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "User can update own location" ON profiles
  FOR UPDATE USING (auth.uid() = id);
```

### Table: Books Policies

```sql
-- Everyone can view all books
CREATE POLICY "Users can view books" ON books
  FOR SELECT USING (true);

-- Users can insert their own books
CREATE POLICY "Users can insert their own books" ON books
  FOR INSERT WITH CHECK (auth.uid() = owner_id);

-- Owners can update their own books
CREATE POLICY "Owners can update their books" ON books
  FOR UPDATE USING (auth.uid() = owner_id);

-- Owners can update book status
CREATE POLICY "Owner can update book status" ON books
  FOR UPDATE USING (auth.uid() = owner_id);
```

### Table: Borrow Requests Policies

```sql
-- Users can view their own borrow requests (as borrower or owner)
CREATE POLICY "Users can view their borrow requests" ON borrow_requests
  FOR SELECT USING (
    (auth.uid() = borrower_id) OR (auth.uid() = owner_id)
  );

-- Borrowers can create new borrow requests
CREATE POLICY "Borrower can create borrow request" ON borrow_requests
  FOR INSERT WITH CHECK (auth.uid() = borrower_id);

-- Owners can update borrow requests (approve/reject)
CREATE POLICY "Owner can update borrow request" ON borrow_requests
  FOR UPDATE USING (auth.uid() = owner_id);

-- Borrowers can mark books as returned
CREATE POLICY "Borrower can mark return" ON borrow_requests
  FOR UPDATE USING (auth.uid() = borrower_id)
  WITH CHECK (status = 'returned'::text);
```

### Table: Messages Policies

```sql
-- Users can view messages from their borrow requests
CREATE POLICY "Users can view messages of their requests" ON messages
  FOR SELECT USING (
    request_id IN (
      SELECT borrow_requests.id
      FROM borrow_requests
      WHERE (
        (borrow_requests.borrower_id = auth.uid()) 
        OR (borrow_requests.owner_id = auth.uid())
      )
    )
  );

-- Users can insert their own messages
CREATE POLICY "Users can insert their own messages" ON messages
  FOR INSERT WITH CHECK (sender_id = auth.uid());
```

### Table: Analytics Logs Policies

```sql
-- Users can only view their own analytics logs
CREATE POLICY "Users can view own analytics" ON analytics_logs
  FOR SELECT USING (auth.uid() = user_id);

-- Only the app can insert analytics logs (via service account)
CREATE POLICY "App can log analytics" ON analytics_logs
  FOR INSERT WITH CHECK (true);
```

### Table: User Preferences Policies

```sql
-- Users can only view their own preferences
CREATE POLICY "Users can view own preferences" ON user_preferences
  FOR SELECT USING (auth.uid() = user_id);

-- Users can only update their own preferences
CREATE POLICY "Users can update own preferences" ON user_preferences
  FOR UPDATE USING (auth.uid() = user_id);

-- Users can insert their own preferences
CREATE POLICY "Users can insert own preferences" ON user_preferences
  FOR INSERT WITH CHECK (auth.uid() = user_id);
```

### Table: Reviews Policies

```sql
-- Everyone can view reviews
CREATE POLICY "Everyone can view reviews" ON reviews
  FOR SELECT USING (true);

-- Users can insert their own reviews
CREATE POLICY "Users can insert reviews" ON reviews
  FOR INSERT WITH CHECK (auth.uid() = reviewer_id);

-- Users can update their own reviews
CREATE POLICY "Users can update own reviews" ON reviews
  FOR UPDATE USING (auth.uid() = reviewer_id);
```

## Notes

- All tables use UUID for primary keys
- Foreign keys enforce referential integrity
- Status values for borrow_requests: 'pending', 'approved', 'rejected', 'returned', 'completed'
- Status values for books: 'available', 'borrowed'
- Condition values: 'new', 'like-new', 'good', 'fair', 'poor'
- Timestamps use timezone-aware format
- JSONB for flexible genre preferences storage
- Array type for favorite_genres (suitable for search/filtering)

## Deployment Guide

### Already Implemented in Supabase
✅ All table schemas
✅ All RLS policies for: profiles, books, borrow_requests, messages, analytics_logs, user_preferences, reviews

### Setup Instructions

All SQL commands needed are documented in this file:

1. **Create Tables**: Copy all `CREATE TABLE` commands from Core Tables and Analytics Tables sections
2. **Enable RLS**: Copy the `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` commands
3. **Add Policies**: Copy all `CREATE POLICY` commands for each table

Execute in Supabase SQL Editor in order: Tables → Enable RLS → Policies
