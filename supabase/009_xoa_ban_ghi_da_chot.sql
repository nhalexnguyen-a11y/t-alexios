-- 009: Xoá bản ghi đã chốt.
-- Chưa chốt: Manager, CEO, Super Admin xoá được (policy delete = svc_is_lead()).
-- Đã chốt: chỉ CEO và Super Admin xoá được. Sửa bản ghi đã chốt vẫn bị chặn với mọi người.
create or replace function public.svc_guard_lock() returns trigger
language plpgsql set search_path = public as $$
begin
  if tg_op = 'DELETE' then
    if old.locked_at is not null and not public.svc_can_lock() then
      raise exception 'Bản ghi đã chốt, chỉ CEO hoặc Super Admin được xoá';
    end if;
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

-- User không được đổi máy (equipment_id) của hồ sơ lắp đặt: trigger đồng bộ sẽ ghi đè thông tin máy khác.
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
       or new.customer_id is distinct from old.customer_id or new.equipment_id is distinct from old.equipment_id then
      raise exception 'Chỉ Manager được đổi người phụ trách, người tham gia, khách hàng hoặc máy của lệnh';
    end if;
  elsif tg_table_name = 'svc_maintenance' then
    if new.assignee_id is distinct from old.assignee_id or new.participant_ids is distinct from old.participant_ids
       or new.equipment_id is distinct from old.equipment_id or new.due_date is distinct from old.due_date then
      raise exception 'Chỉ Manager được đổi người phụ trách, máy hoặc ngày bảo trì';
    end if;
  end if;
  return new;
end; $$;
