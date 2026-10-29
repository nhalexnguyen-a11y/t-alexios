-- App nhật ký dịch vụ kỹ thuật (T-Alexios). ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- Bảng riêng svc_*; không đụng bảng của Alex workspace hay quote_*.
-- Quyền: mọi tài khoản có profile xem chung và thêm được; nhật ký chỉ người tạo hoặc
-- super_admin/admin/manager/cto_coo sửa/xoá; xoá khách hàng/máy chỉ nhóm quản lý.

create or replace function public.svc_is_member() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid());
$$;

create or replace function public.svc_is_lead() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles where id = auth.uid()
    and role in ('super_admin','admin','manager','cto_coo'));
$$;

create table public.svc_customers (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  address text,
  contact_name text,
  phone text,
  notes text,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.svc_equipment (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.svc_customers(id) on delete restrict,
  name text not null,
  brand text,
  model text,
  serial text,
  location text,
  install_date date,
  warranty_end date,
  notes text,
  created_by uuid default auth.uid() references public.profiles(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index svc_equipment_serial_uq on public.svc_equipment (lower(brand), lower(serial)) where serial is not null and serial <> '';
create index svc_equipment_customer_idx on public.svc_equipment(customer_id);
create index svc_equipment_created_by_idx on public.svc_equipment(created_by);
create index svc_customers_created_by_idx on public.svc_customers(created_by);

create table public.svc_visits (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.svc_equipment(id) on delete restrict,
  visit_date date not null default current_date,
  time_in time,
  time_out time,
  work_type text not null check (work_type in ('lap_dat','bao_tri','sua_chua','hieu_chuan','dao_tao','kiem_tra','khac')),
  technician_id uuid default auth.uid() references public.profiles(id) on delete set null,
  technician_name text,
  co_workers text,
  customer_contact text,
  problem text,
  action text,
  result text not null default 'hoan_thanh' check (result in ('hoan_thanh','chua_xong','cho_linh_kien','theo_doi')),
  parts jsonb not null default '[]'::jsonb,
  under_warranty boolean,
  next_action text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index svc_visits_equipment_idx on public.svc_visits(equipment_id, visit_date desc);
create index svc_visits_tech_idx on public.svc_visits(technician_id);
create index svc_visits_date_idx on public.svc_visits(visit_date desc);

create or replace function public.svc_touch() returns trigger
language plpgsql set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;
create trigger svc_customers_touch before update on public.svc_customers for each row execute function public.svc_touch();
create trigger svc_equipment_touch before update on public.svc_equipment for each row execute function public.svc_touch();
create trigger svc_visits_touch before update on public.svc_visits for each row execute function public.svc_touch();

alter table public.svc_customers enable row level security;
alter table public.svc_equipment enable row level security;
alter table public.svc_visits enable row level security;

create policy svc_customers_select on public.svc_customers for select to authenticated using ((select public.svc_is_member()));
create policy svc_customers_insert on public.svc_customers for insert to authenticated with check ((select public.svc_is_member()));
create policy svc_customers_update on public.svc_customers for update to authenticated using ((select public.svc_is_member())) with check ((select public.svc_is_member()));
create policy svc_customers_delete on public.svc_customers for delete to authenticated using ((select public.svc_is_lead()));

create policy svc_equipment_select on public.svc_equipment for select to authenticated using ((select public.svc_is_member()));
create policy svc_equipment_insert on public.svc_equipment for insert to authenticated with check ((select public.svc_is_member()));
create policy svc_equipment_update on public.svc_equipment for update to authenticated using ((select public.svc_is_member())) with check ((select public.svc_is_member()));
create policy svc_equipment_delete on public.svc_equipment for delete to authenticated using ((select public.svc_is_lead()));

create policy svc_visits_select on public.svc_visits for select to authenticated using ((select public.svc_is_member()));
create policy svc_visits_insert on public.svc_visits for insert to authenticated with check ((select public.svc_is_member()) and technician_id = (select auth.uid()));
create policy svc_visits_update on public.svc_visits for update to authenticated using (technician_id = (select auth.uid()) or (select public.svc_is_lead())) with check (technician_id = (select auth.uid()) or (select public.svc_is_lead()));
create policy svc_visits_delete on public.svc_visits for delete to authenticated using (technician_id = (select auth.uid()) or (select public.svc_is_lead()));

revoke execute on function public.svc_is_member() from public, anon;
revoke execute on function public.svc_is_lead() from public, anon;
grant execute on function public.svc_is_member() to authenticated;
grant execute on function public.svc_is_lead() to authenticated;

grant select, insert, update, delete on public.svc_customers, public.svc_equipment, public.svc_visits to authenticated;
revoke all on public.svc_customers, public.svc_equipment, public.svc_visits from anon;
