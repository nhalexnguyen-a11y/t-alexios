-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- CEO (và Super Admin) bấm "Hoàn thành & chốt" để khoá phiếu sửa chữa / hồ sơ lắp đặt.
-- Bản ghi đã chốt: không ai sửa, không ai xoá (chặn bằng trigger, kể cả Super Admin).
-- Sự cố tiếp theo: tạo phiếu mới với parent_id = phiếu cũ; phiếu cũ có con thì không xoá được (on delete restrict).

alter table public.svc_visits
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by uuid references public.profiles(id) on delete set null,
  add column if not exists locked_by_name text,
  add column if not exists parent_id uuid references public.svc_visits(id) on delete restrict;
create index if not exists svc_visits_parent_idx on public.svc_visits(parent_id);
create index if not exists svc_visits_locked_by_idx on public.svc_visits(locked_by);

alter table public.svc_installations
  add column if not exists locked_at timestamptz,
  add column if not exists locked_by uuid references public.profiles(id) on delete set null,
  add column if not exists locked_by_name text;
create index if not exists svc_installations_locked_by_idx on public.svc_installations(locked_by);

create or replace function public.svc_can_lock() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.svc_members where user_id = auth.uid() and role in ('ceo','super_admin'));
$$;
revoke execute on function public.svc_can_lock() from public, anon;
grant execute on function public.svc_can_lock() to authenticated;

create or replace function public.svc_guard_lock() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.locked_at is not null then raise exception 'Bản ghi đã chốt, không xoá được'; end if;
    return old;
  end if;
  if old.locked_at is not null then raise exception 'Bản ghi đã chốt, không sửa được'; end if;
  if new.locked_at is not null then
    if not public.svc_can_lock() then raise exception 'Chỉ CEO được chốt hoàn thành'; end if;
    new.locked_at := now();
    new.locked_by := auth.uid();
    if tg_table_name = 'svc_visits' then new.result := 'hoan_thanh'; end if;
  end if;
  return new;
end; $$;
revoke execute on function public.svc_guard_lock() from public, anon, authenticated;
create trigger svc_visits_guard_lock before update or delete on public.svc_visits for each row execute function public.svc_guard_lock();
create trigger svc_installations_guard_lock before update or delete on public.svc_installations for each row execute function public.svc_guard_lock();

create or replace function public.svc_no_prelock() returns trigger
language plpgsql set search_path = public as $$
begin
  new.locked_at := null; new.locked_by := null; new.locked_by_name := null;
  return new;
end; $$;
revoke execute on function public.svc_no_prelock() from public, anon, authenticated;
create trigger svc_visits_no_prelock before insert on public.svc_visits for each row execute function public.svc_no_prelock();
create trigger svc_installations_no_prelock before insert on public.svc_installations for each row execute function public.svc_no_prelock();
