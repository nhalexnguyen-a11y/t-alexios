-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- Phân quyền riêng của T-Alexios, tách khỏi profiles.role của Alexios. Đăng nhập vẫn dùng chung.
-- Vai trò: super_admin (quản lý thành viên), ceo, cto_coo (quản lý), technician (kỹ thuật).
-- Chỉ người có trong svc_members mới đọc/ghi được các bảng svc_* (qua svc_is_member / svc_is_lead).

create table if not exists public.svc_members (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  role text not null check (role in ('super_admin','ceo','cto_coo','technician')),
  added_by uuid references public.profiles(id) on delete set null default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index if not exists svc_members_added_by_idx on public.svc_members(added_by);
create trigger svc_members_touch before update on public.svc_members for each row execute function public.svc_touch();

-- Khởi tạo: Super Admin của Alexios là Super Admin đầu tiên của T-Alexios
insert into public.svc_members(user_id, role, added_by)
select id, 'super_admin', id from public.profiles where role = 'super_admin'
on conflict (user_id) do nothing;

create or replace function public.svc_my_role() returns text
language sql stable security definer set search_path = public as $$
  select role from public.svc_members where user_id = auth.uid();
$$;
create or replace function public.svc_is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.svc_members where user_id = auth.uid());
$$;
create or replace function public.svc_is_lead() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.svc_members where user_id = auth.uid() and role in ('super_admin','ceo','cto_coo'));
$$;
create or replace function public.svc_is_owner() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.svc_members where user_id = auth.uid() and role = 'super_admin');
$$;

-- Không cho xoá / hạ cấp Super Admin cuối cùng
create or replace function public.svc_keep_owner() returns trigger
language plpgsql set search_path = public as $$
begin
  if (tg_op = 'DELETE' and old.role = 'super_admin') or (tg_op = 'UPDATE' and old.role = 'super_admin' and new.role <> 'super_admin') then
    if not exists (select 1 from public.svc_members where role = 'super_admin' and user_id <> old.user_id) then
      raise exception 'Phải còn ít nhất một Super Admin';
    end if;
  end if;
  return coalesce(new, old);
end; $$;
create trigger svc_members_keep_owner before update or delete on public.svc_members for each row execute function public.svc_keep_owner();

alter table public.svc_members enable row level security;
create policy svc_members_select on public.svc_members for select to authenticated using ((select public.svc_is_member()));
create policy svc_members_insert on public.svc_members for insert to authenticated with check ((select public.svc_is_owner()));
create policy svc_members_update on public.svc_members for update to authenticated using ((select public.svc_is_owner())) with check ((select public.svc_is_owner()));
create policy svc_members_delete on public.svc_members for delete to authenticated using ((select public.svc_is_owner()));
grant select, insert, update, delete on public.svc_members to authenticated;
revoke all on public.svc_members from anon;

drop function if exists public.svc_staff();
create function public.svc_staff()
returns table(id uuid, full_name text, username text, role text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.username, m.role
  from public.svc_members m join public.profiles p on p.id = m.user_id
  where public.svc_is_member()
  order by coalesce(p.full_name, p.username);
$$;

create or replace function public.svc_candidates()
returns table(id uuid, full_name text, username text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.username from public.profiles p
  where public.svc_is_owner() and not exists (select 1 from public.svc_members m where m.user_id = p.id)
  order by coalesce(p.full_name, p.username);
$$;

revoke execute on function public.svc_my_role(), public.svc_is_owner(), public.svc_staff(), public.svc_candidates() from public, anon;
grant execute on function public.svc_my_role(), public.svc_is_owner(), public.svc_staff(), public.svc_candidates() to authenticated;
revoke execute on function public.svc_keep_owner() from public, anon, authenticated;
