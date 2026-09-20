create extension if not exists pgcrypto;

create table if not exists public.articles (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references auth.users(id) on delete cascade,
  title text not null,
  slug text not null unique,
  category text not null default 'Technology',
  excerpt text not null default '',
  content text not null,
  cover_image_url text,
  status text not null default 'published' check (status in ('draft', 'published')),
  published_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.articles enable row level security;
drop policy if exists "Published articles are public" on public.articles;
drop policy if exists "Authors create their own articles" on public.articles;
drop policy if exists "Authors update their own articles" on public.articles;
drop policy if exists "Authors delete their own articles" on public.articles;
create policy "Published articles are public" on public.articles for select to anon, authenticated using (status = 'published' or (select auth.uid()) = author_id);
create policy "Authors create their own articles" on public.articles for insert to authenticated with check ((select auth.uid()) = author_id);
create policy "Authors update their own articles" on public.articles for update to authenticated using ((select auth.uid()) = author_id) with check ((select auth.uid()) = author_id);
create policy "Authors delete their own articles" on public.articles for delete to authenticated using ((select auth.uid()) = author_id);

create table if not exists public.article_reactions (
  id uuid primary key default gen_random_uuid(),
  article_id uuid not null references public.articles(id) on delete cascade,
  reaction text not null check (reaction in ('useful', 'learned', 'loved', 'think')),
  visitor_id text not null,
  created_at timestamptz not null default now(),
  unique(article_id, visitor_id)
);
alter table public.article_reactions enable row level security;
drop policy if exists "Anyone can read reactions" on public.article_reactions;
drop policy if exists "Anyone can add one reaction" on public.article_reactions;
create policy "Anyone can read reactions" on public.article_reactions for select to anon, authenticated using (true);
create policy "Anyone can add one reaction" on public.article_reactions for insert to anon, authenticated with check (char_length(visitor_id) between 8 and 128);

create table if not exists public.newsletter_subscribers (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  created_at timestamptz not null default now()
);
alter table public.newsletter_subscribers enable row level security;
drop policy if exists "Anyone can subscribe to newsletter" on public.newsletter_subscribers;
create policy "Anyone can subscribe to newsletter" on public.newsletter_subscribers for insert to anon, authenticated with check (char_length(email) <= 320 and position('@' in email) > 1);

insert into storage.buckets (id, name, public) values ('article-images', 'article-images', true) on conflict (id) do nothing;
drop policy if exists "Authenticated users upload article images" on storage.objects;
drop policy if exists "Public can read article images" on storage.objects;
create policy "Authenticated users upload article images" on storage.objects for insert to authenticated with check (bucket_id = 'article-images' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Public can read article images" on storage.objects for select to public using (bucket_id = 'article-images');

create index if not exists articles_status_published_idx on public.articles(status, published_at desc);
create index if not exists articles_author_idx on public.articles(author_id, created_at desc);
grant select on public.articles to anon, authenticated;
grant insert, update, delete on public.articles to authenticated;
grant select, insert on public.article_reactions to anon, authenticated;
grant insert on public.newsletter_subscribers to anon, authenticated;

create index if not exists reactions_article_idx on public.article_reactions(article_id);

-- Run this file in Supabase SQL Editor. It preserves existing rows and users.
