create table public.profiles (
  id uuid references auth.users(id) on delete cascade,
  name text,
  latitude double precision,
  longitude double precision,
  locality text,
  created_at timestamp with time zone default now(),
  primary key (id)
);

create table public.books (
  id uuid default gen_random_uuid() primary key,
  title text not null,
  author text,
  isbn text,
  owner_id uuid references public.profiles(id) on delete cascade,
  status text default 'available',
  created_at timestamp with time zone default now()
);

create table public.borrow_requests (
  id uuid default gen_random_uuid() primary key,
  book_id uuid references public.books(id) on delete cascade,
  borrower_id uuid references public.profiles(id),
  owner_id uuid references public.profiles(id),
  status text default 'pending',
  due_date date,
  created_at timestamp with time zone default now()
);

create table public.chats (
  id uuid default gen_random_uuid() primary key,
  sender_id uuid references public.profiles(id),
  receiver_id uuid references public.profiles(id),
  message text,
  created_at timestamp with time zone default now()
);

create table public.reviews (
  id uuid default gen_random_uuid() primary key,
  book_id uuid references public.books(id) on delete cascade,
  reviewer_id uuid references public.profiles(id),
  rating int check (rating between 1 and 5),
  review_text text,
  sentiment text
);

create table public.analytics (
  id uuid default gen_random_uuid() primary key,
  event_type text,
  user_id uuid references public.profiles(id),
  created_at timestamp with time zone default now()
);
