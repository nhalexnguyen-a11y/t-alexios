-- 008: Lịch sử bàn giao phiếu sửa chữa.
-- Mỗi lần đổi người phụ trách (assignee_id) trên svc_visits, DB tự ghi một dòng vào svc_handovers.
-- Chỉ Manager, CEO, Super Admin bàn giao được (svc_guard_assign đã chặn User đổi assignee_id).
-- Lịch sử chỉ đọc: không có policy insert/update/delete cho người dùng; chỉ trigger ghi.

create table if not exists public.svc_handovers (
  id uuid primary key default gen_random_uuid(),
  visit_id uuid not null references public.svc_visits(id) on delete cascade,
  from_id uuid, from_name text,
  to_id uuid, to_name text,
  old_deadline date, new_deadline date,
  remaining text, next_action text,
  note text,
  by_id uuid default auth.uid(), by_name text,
  created_at timestamptz not null default now()
);
create index if not exists svc_handovers_visit_idx on public.svc_handovers(visit_id, created_at);

alter table public.svc_handovers enable row level security;
drop policy if exists svc_handovers_select on public.svc_handovers;
create policy svc_handovers_select on public.svc_handovers for select to authenticated using (public.svc_is_member());
revoke all on public.svc_handovers from anon, authenticated;
grant select on public.svc_handovers to authenticated;

create or replace function public.svc_log_handover() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_note text := nullif(current_setting('svc.handover_note', true), '');
begin
  if new.assignee_id is distinct from old.assignee_id then
    insert into public.svc_handovers(visit_id, from_id, from_name, to_id, to_name, old_deadline, new_deadline, remaining, next_action, note, by_id, by_name)
    values (new.id,
      old.assignee_id, coalesce((select coalesce(full_name, username) from public.profiles where id = old.assignee_id), old.assignee_name),
      new.assignee_id, coalesce((select coalesce(full_name, username) from public.profiles where id = new.assignee_id), new.assignee_name),
      old.deadline, new.deadline, new.remaining, new.next_action, v_note,
      auth.uid(), (select coalesce(full_name, username) from public.profiles where id = auth.uid()));
  end if;
  return new;
end $$;
revoke execute on function public.svc_log_handover() from public, anon, authenticated;
drop trigger if exists svc_visits_log_handover on public.svc_visits;
create trigger svc_visits_log_handover after update on public.svc_visits for each row execute function public.svc_log_handover();

-- Bàn giao kèm lý do: đổi người phụ trách và ghi lý do vào lịch sử trong cùng một giao dịch.
create or replace function public.svc_handover(p_visit uuid, p_to uuid, p_deadline date, p_remaining text, p_next text, p_note text)
returns void language plpgsql security invoker set search_path = public as $$
declare v public.svc_visits;
begin
  if not public.svc_is_lead() then raise exception 'Chỉ Manager, CEO, Super Admin được bàn giao' using errcode = '42501'; end if;
  select * into v from public.svc_visits where id = p_visit;
  if not found then raise exception 'Không tìm thấy phiếu'; end if;
  if v.locked_at is not null then raise exception 'Phiếu đã chốt, không bàn giao được'; end if;
  if p_to is null or p_to = v.assignee_id then raise exception 'Chọn người nhận bàn giao khác người đang phụ trách'; end if;
  perform set_config('svc.handover_note', coalesce(p_note, ''), true);
  update public.svc_visits set
    assignee_id = p_to,
    assignee_name = (select coalesce(full_name, username) from public.profiles where id = p_to),
    participant_ids = (select coalesce(array_agg(distinct x), '{}') from unnest(coalesce(v.participant_ids, '{}') || v.assignee_id) x where x is not null and x <> p_to),
    deadline = p_deadline, remaining = p_remaining, next_action = p_next
  where id = p_visit;
  perform set_config('svc.handover_note', '', true);
end $$;
revoke execute on function public.svc_handover(uuid, uuid, date, text, text, text) from public, anon;
grant execute on function public.svc_handover(uuid, uuid, date, text, text, text) to authenticated;
