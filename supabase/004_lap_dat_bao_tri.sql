-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- Tách mục: Lắp đặt (svc_installations, 3 đợt), Sửa chữa (svc_visits, work_type = sua_chua), Bảo trì (svc_maintenance).
-- Sửa chữa: problem = Vấn đề, solution = Khắc phục, remaining = Vấn đề còn lại, next_action = Hướng giải quyết tiếp theo, deadline.
-- Lịch bảo trì tính ở giao diện: từ acceptance_date, mỗi maint_interval_months, trong maint_duration_months.

alter table public.svc_visits add column if not exists remaining text;

create table public.svc_installations (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid references public.svc_equipment(id) on delete restrict,
  customer_id uuid not null references public.svc_customers(id) on delete restrict,
  machine_name text not null,
  brand text,
  model text,
  serial text,
  contract_no text,
  planned_date date,
  owner_id uuid not null default auth.uid() references public.profiles(id) on delete set null,
  owner_name text,
  maint_duration_months int check (maint_duration_months is null or maint_duration_months >= 0),
  maint_interval_months int check (maint_interval_months is null or maint_interval_months > 0),
  tests text[] not null default '{}' check (tests <@ array['IQ','OQ','PQ','FAT','SAT']),
  handover_date date,
  test_dates jsonb not null default '{}'::jsonb,
  acceptance_date date,
  warranty_months int check (warranty_months is null or warranty_months >= 0),
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create index svc_installations_customer_idx on public.svc_installations(customer_id);
create index svc_installations_equipment_idx on public.svc_installations(equipment_id);
create index svc_installations_owner_idx on public.svc_installations(owner_id);
create trigger svc_installations_touch before update on public.svc_installations for each row execute function public.svc_touch();

-- Tự tạo / đồng bộ bản ghi máy (Máy đã lắp) từ hồ sơ lắp đặt; hạn BH = ngày nghiệm thu + số tháng bảo hành
create or replace function public.svc_installation_sync() returns trigger
language plpgsql set search_path = public as $$
declare w date;
begin
  w := case when new.acceptance_date is not null and new.warranty_months is not null
            then (new.acceptance_date + make_interval(months => new.warranty_months))::date end;
  if new.equipment_id is null then
    insert into public.svc_equipment(customer_id, name, brand, model, serial, install_date, warranty_end)
    values (new.customer_id, new.machine_name, new.brand, new.model, nullif(new.serial,''), coalesce(new.acceptance_date, new.handover_date), w)
    returning id into new.equipment_id;
  else
    update public.svc_equipment set customer_id = new.customer_id, name = new.machine_name, brand = new.brand, model = new.model,
      serial = nullif(new.serial,''), install_date = coalesce(new.acceptance_date, new.handover_date, install_date), warranty_end = coalesce(w, warranty_end)
    where id = new.equipment_id;
  end if;
  return new;
end; $$;
create trigger svc_installations_sync before insert or update on public.svc_installations for each row execute function public.svc_installation_sync();
revoke execute on function public.svc_installation_sync() from public, anon, authenticated;

alter table public.svc_installations enable row level security;
create policy svc_inst_select on public.svc_installations for select to authenticated using ((select public.svc_is_member()));
create policy svc_inst_insert on public.svc_installations for insert to authenticated with check ((select public.svc_is_member()) and owner_id = (select auth.uid()));
create policy svc_inst_update on public.svc_installations for update to authenticated using (owner_id = (select auth.uid()) or (select public.svc_is_lead())) with check ((select public.svc_is_member()));
create policy svc_inst_delete on public.svc_installations for delete to authenticated using (owner_id = (select auth.uid()) or (select public.svc_is_lead()));
grant select, insert, update, delete on public.svc_installations to authenticated;
revoke all on public.svc_installations from anon;

create table public.svc_maintenance (
  id uuid primary key default gen_random_uuid(),
  installation_id uuid not null references public.svc_installations(id) on delete cascade,
  due_date date not null,
  done_date date not null default current_date,
  done_by uuid default auth.uid() references public.profiles(id) on delete set null,
  done_by_name text,
  notes text,
  created_at timestamptz not null default now(),
  unique (installation_id, due_date)
);
create index svc_maintenance_done_by_idx on public.svc_maintenance(done_by);
alter table public.svc_maintenance enable row level security;
create policy svc_maint_select on public.svc_maintenance for select to authenticated using ((select public.svc_is_member()));
create policy svc_maint_insert on public.svc_maintenance for insert to authenticated with check ((select public.svc_is_member()) and done_by = (select auth.uid()));
create policy svc_maint_update on public.svc_maintenance for update to authenticated using (done_by = (select auth.uid()) or (select public.svc_is_lead())) with check ((select public.svc_is_member()));
create policy svc_maint_delete on public.svc_maintenance for delete to authenticated using (done_by = (select auth.uid()) or (select public.svc_is_lead()));
grant select, insert, update, delete on public.svc_maintenance to authenticated;
revoke all on public.svc_maintenance from anon;
