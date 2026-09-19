create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  slug text not null unique,
  excerpt text,
  content text not null,
  category text not null,
  cover_image_url text,
  status text not null default 'published' check (status in ('draft', 'pending', 'published', 'rejected')),
  rejection_reason text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz
);

alter table public.articles enable row level security;

create policy "Published articles are public" on public.articles for select to anon, authenticated using (status = 'published' or (select auth.uid()) = author_id);
create policy "Authors create their own articles" on public.articles for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "Authors update their own articles" on public.articles for update to authenticated using ((select auth.uid()) = author_id) with check ((select auth.uid()) = author_id);
create policy "Authors delete their own articles" on public.articles for delete to authenticated using ((select auth.uid()) = author_id);

create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);

alter table public.newsletter_subscribers enable row level security;

create policy "Anyone can subscribe to newsletter"
  on public.newsletter_subscribers for insert
  to anon, authenticated
  with check (char_length(email) <= 320 and position('@' in email) > 1);
