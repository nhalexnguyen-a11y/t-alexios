-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (20/11/2026).
-- Vai trò T-Alexios: super_admin, ceo, manager, user (cto_coo -> manager, technician -> user).
-- Manager / CEO / Super Admin tạo lệnh (lắp đặt, sửa chữa, bảo trì), khách hàng, máy và giao người phụ trách chính + người tham gia.
-- User không tạo mới, không xoá; chỉ cập nhật lệnh mình phụ trách chính hoặc tham gia, không đổi người được giao.
-- Chốt hoàn thành: CEO, Super Admin (không đổi).

-- 1. Vai trò
alter table public.svc_members drop constraint if exists svc_members_role_check;
update public.svc_members set role = 'manager' where role = 'cto_coo';
update public.svc_members set role = 'user' where role = 'technician';
alter table public.svc_members add constraint svc_members_role_check check (role in ('super_admin','ceo','manager','user'));

create or replace function public.svc_is_lead() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.svc_members where user_id = auth.uid() and role in ('super_admin','ceo','manager'));
$$;

-- 2. Cột giao việc
alter table public.svc_installations add column if not exists participant_ids uuid[] not null default '{}';
create index if not exists svc_installations_participants_idx on public.svc_installations using gin(participant_ids);

alter table public.svc_maintenance
  add column if not exists assignee_id uuid references public.profiles(id) on delete set null,
  add column if not exists assignee_name text,
  add column if not exists participant_ids uuid[] not null default '{}';
update public.svc_maintenance set assignee_id = created_by, assignee_name = created_by_name where assignee_id is null;
create index if not exists svc_maintenance_assignee_idx on public.svc_maintenance(assignee_id);
create index if not exists svc_maintenance_participants_idx on public.svc_maintenance using gin(participant_ids);

-- 3. Policy: chỉ lead tạo / xoá; user cập nhật khi được giao
drop policy if exists svc_customers_insert on public.svc_customers;
drop policy if exists svc_customers_update on public.svc_customers;
create policy svc_customers_insert on public.svc_customers for insert to authenticated with check ((select public.svc_is_lead()));
create policy svc_customers_update on public.svc_customers for update to authenticated using ((select public.svc_is_lead())) with check ((select public.svc_is_lead()));

drop policy if exists svc_equipment_insert on public.svc_equipment;
drop policy if exists svc_equipment_update on public.svc_equipment;
create policy svc_equipment_insert on public.svc_equipment for insert to authenticated with check ((select public.svc_is_lead()));
create policy svc_equipment_update on public.svc_equipment for update to authenticated using ((select public.svc_is_lead())) with check ((select public.svc_is_lead()));

drop policy if exists svc_inst_insert on public.svc_installations;
drop policy if exists svc_inst_update on public.svc_installations;
drop policy if exists svc_inst_delete on public.svc_installations;
create policy svc_inst_insert on public.svc_installations for insert to authenticated with check ((select public.svc_is_lead()));
create policy svc_inst_update on public.svc_installations for update to authenticated
  using ((select public.svc_is_lead()) or owner_id = (select auth.uid()) or (select auth.uid()) = any(participant_ids))
  with check ((select public.svc_is_member()));
create policy svc_inst_delete on public.svc_installations for delete to authenticated using ((select public.svc_is_lead()));

drop policy if exists svc_visits_insert on public.svc_visits;
drop policy if exists svc_visits_update on public.svc_visits;
drop policy if exists svc_visits_delete on public.svc_visits;
create policy svc_visits_insert on public.svc_visits for insert to authenticated with check ((select public.svc_is_lead()) and technician_id = (select auth.uid()));
create policy svc_visits_update on public.svc_visits for update to authenticated
  using ((select public.svc_is_lead()) or assignee_id = (select auth.uid()) or (select auth.uid()) = any(participant_ids))
  with check ((select public.svc_is_member()));
create policy svc_visits_delete on public.svc_visits for delete to authenticated using ((select public.svc_is_lead()));

drop policy if exists svc_maint_insert on public.svc_maintenance;
drop policy if exists svc_maint_update on public.svc_maintenance;
drop policy if exists svc_maint_delete on public.svc_maintenance;
create policy svc_maint_insert on public.svc_maintenance for insert to authenticated with check ((select public.svc_is_lead()) and created_by = (select auth.uid()));
create policy svc_maint_update on public.svc_maintenance for update to authenticated
  using ((select public.svc_is_lead()) or assignee_id = (select auth.uid()) or (select auth.uid()) = any(participant_ids))
  with check ((select public.svc_is_member()));
create policy svc_maint_delete on public.svc_maintenance for delete to authenticated using ((select public.svc_is_lead()));

-- 4. User không đổi người được giao / đối tượng của lệnh
create or replace function public.svc_guard_assign() returns trigger
language plpgsql set search_path = public as $$
begin
  if public.svc_is_lead() then return new; end if;
  if tg_table_name = 'svc_visits' then
    if new.assignee_id is distinct from old.assignee_id or new.participant_ids is distinct from old.participant_ids
       or new.equipment_id is distinct from old.equipment_id or new.parent_id is distinct from old.parent_id then
      raise exception 'Chỉ Manager được đổi người phụ trách, người tham gia hoặc máy của lệnh';
    end if;
  elsif tg_table_name = 'svc_installations' then
    if new.owner_id is distinct from old.owner_id or new.participant_ids is distinct from old.participant_ids
       or new.customer_id is distinct from old.customer_id then
      raise exception 'Chỉ Manager được đổi người phụ trách, người tham gia hoặc khách hàng của lệnh';
    end if;
  elsif tg_table_name = 'svc_maintenance' then
    if new.assignee_id is distinct from old.assignee_id or new.participant_ids is distinct from old.participant_ids
       or new.equipment_id is distinct from old.equipment_id or new.due_date is distinct from old.due_date then
      raise exception 'Chỉ Manager được đổi người phụ trách, máy hoặc ngày bảo trì';
    end if;
  end if;
  return new;
end; $$;
revoke execute on function public.svc_guard_assign() from public, anon, authenticated;
drop trigger if exists svc_visits_guard_assign on public.svc_visits;
drop trigger if exists svc_installations_guard_assign on public.svc_installations;
drop trigger if exists svc_maintenance_guard_assign on public.svc_maintenance;
create trigger svc_visits_guard_assign before update on public.svc_visits for each row execute function public.svc_guard_assign();
create trigger svc_installations_guard_assign before update on public.svc_installations for each row execute function public.svc_guard_assign();
create trigger svc_maintenance_guard_assign before update on public.svc_maintenance for each row execute function public.svc_guard_assign();

-- 5. User cập nhật Đợt 2/3 lắp đặt vẫn phải đồng bộ được hạn bảo hành vào máy
alter function public.svc_installation_sync() security definer;
