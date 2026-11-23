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
