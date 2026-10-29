-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- Xoá dữ liệu thử theo cách ghi cũ; bảo trì chuyển sang kỹ thuật tự lên lịch, gắn theo máy.
delete from public.svc_visits;
delete from public.svc_equipment where id not in (select equipment_id from public.svc_installations where equipment_id is not null);

drop table if exists public.svc_maintenance;
create table public.svc_maintenance (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.svc_equipment(id) on delete cascade,
  due_date date not null,
  done_date date,
  done_by uuid references public.profiles(id) on delete set null,
  done_by_name text,
  plan_notes text,
  notes text,
  created_by uuid not null default auth.uid() references public.profiles(id) on delete set null,
  created_by_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (equipment_id, due_date)
);
create index svc_maintenance_due_idx on public.svc_maintenance(due_date) where done_date is null;
create index svc_maintenance_done_by_idx on public.svc_maintenance(done_by);
create index svc_maintenance_created_by_idx on public.svc_maintenance(created_by);
create trigger svc_maintenance_touch before update on public.svc_maintenance for each row execute function public.svc_touch();

alter table public.svc_maintenance enable row level security;
create policy svc_maint_select on public.svc_maintenance for select to authenticated using ((select public.svc_is_member()));
create policy svc_maint_insert on public.svc_maintenance for insert to authenticated with check ((select public.svc_is_member()) and created_by = (select auth.uid()));
create policy svc_maint_update on public.svc_maintenance for update to authenticated using ((select public.svc_is_member())) with check ((select public.svc_is_member()));
create policy svc_maint_delete on public.svc_maintenance for delete to authenticated using (created_by = (select auth.uid()) or (select public.svc_is_lead()));
grant select, insert, update, delete on public.svc_maintenance to authenticated;
revoke all on public.svc_maintenance from anon;
