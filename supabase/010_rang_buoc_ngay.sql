-- 010: Ràng buộc ngày và chốt.
-- Ngày giao nhận, ngày hoàn thành phép thử, ngày nghiệm thu, ngày đã bảo trì: không được sau hôm nay (giờ Việt Nam).
-- Chốt lắp đặt: cần ngày nghiệm thu và ngày đó không sau hôm nay.
-- Deadline sửa chữa không trước ngày ghi phiếu.
-- Máy đã có lần bảo trì đã làm: không xoá được (tránh mất lịch sử do xoá dây chuyền).

create or replace function public.svc_vn_today() returns date language sql stable as $$ select (now() at time zone 'Asia/Ho_Chi_Minh')::date $$;

create or replace function public.svc_check_dates() returns trigger
language plpgsql set search_path = public as $$
declare d date; k text;
begin
  if tg_table_name = 'svc_installations' then
    if new.handover_date > svc_vn_today() then raise exception 'Ngày ký biên bản giao nhận không được sau hôm nay'; end if;
    if new.acceptance_date > svc_vn_today() then raise exception 'Ngày ký biên bản nghiệm thu không được sau hôm nay'; end if;
    for k in select jsonb_object_keys(coalesce(new.test_dates, '{}'::jsonb)) loop
      d := nullif(new.test_dates->>k, '')::date;
      if d > svc_vn_today() then raise exception 'Ngày hoàn thành % không được sau hôm nay', k; end if;
    end loop;
  elsif tg_table_name = 'svc_maintenance' then
    if new.done_date > svc_vn_today() then raise exception 'Ngày đã làm không được sau hôm nay'; end if;
  end if;
  return new;
end $$;
drop trigger if exists svc_installations_check_dates on public.svc_installations;
create trigger svc_installations_check_dates before insert or update on public.svc_installations for each row execute function public.svc_check_dates();
drop trigger if exists svc_maintenance_check_dates on public.svc_maintenance;
create trigger svc_maintenance_check_dates before insert or update on public.svc_maintenance for each row execute function public.svc_check_dates();

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
    if tg_table_name = 'svc_installations' and (new.acceptance_date is null or new.acceptance_date > public.svc_vn_today()) then
      raise exception 'Chưa đủ điều kiện chốt: cần ngày nghiệm thu và ngày này không được sau hôm nay';
    end if;
    new.locked_at := now();
    new.locked_by := auth.uid();
    if tg_table_name = 'svc_visits' then new.result := 'hoan_thanh'; end if;
  end if;
  return new;
end; $$;

alter table public.svc_visits drop constraint if exists svc_visits_deadline_after_visit;
alter table public.svc_visits add constraint svc_visits_deadline_after_visit check (deadline is null or visit_date is null or deadline >= visit_date);

create or replace function public.svc_equipment_keep_history() returns trigger
language plpgsql set search_path = public as $$
begin
  if exists (select 1 from public.svc_maintenance where equipment_id = old.id and done_date is not null) then
    raise exception 'Máy đã có lần bảo trì đã làm, không xoá được để giữ lịch sử.';
  end if;
  return old;
end $$;
drop trigger if exists svc_equipment_keep_history on public.svc_equipment;
create trigger svc_equipment_keep_history before delete on public.svc_equipment for each row execute function public.svc_equipment_keep_history();
