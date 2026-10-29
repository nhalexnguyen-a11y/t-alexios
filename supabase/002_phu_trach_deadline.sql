-- ĐÃ CHẠY trên project xfgqtgzgptavhqjjklkh (29/10/2026).
-- Người phụ trách, kỹ thuật tham gia, deadline; tách ghi nhận thành nguyên nhân / hướng khắc phục.
-- Cột cũ problem, time_in, time_out, co_workers giữ lại để không mất dữ liệu, giao diện không dùng nữa
-- (problem cũ vẫn hiện là "Ghi nhận (bản cũ)" nếu có). next_action = "Vấn đề còn lại và hướng giải quyết tiếp theo".

alter table public.svc_visits
  add column if not exists cause text,
  add column if not exists solution text,
  add column if not exists deadline date,
  add column if not exists assignee_id uuid references public.profiles(id) on delete set null,
  add column if not exists assignee_name text,
  add column if not exists participant_ids uuid[] not null default '{}';

update public.svc_visits set assignee_id = technician_id, assignee_name = technician_name where assignee_id is null;

create index if not exists svc_visits_assignee_idx on public.svc_visits(assignee_id);
create index if not exists svc_visits_deadline_idx on public.svc_visits(deadline) where deadline is not null;
create index if not exists svc_visits_participants_idx on public.svc_visits using gin(participant_ids);

-- Danh sách nhân sự để chọn phụ trách / tham gia (role user không đọc được profiles của người khác)
create or replace function public.svc_staff()
returns table(id uuid, full_name text, username text, role text)
language sql stable security definer set search_path = public as $$
  select p.id, p.full_name, p.username, p.role::text from public.profiles p
  where public.svc_is_member() and (p.role <> 'super_admin'::user_role or p.id = auth.uid())
  order by coalesce(p.full_name, p.username);
$$;
revoke execute on function public.svc_staff() from public, anon;
grant execute on function public.svc_staff() to authenticated;

-- Sửa nhật ký: người tạo, người phụ trách, người tham gia hoặc nhóm quản lý. Xoá: người tạo hoặc quản lý (không đổi).
drop policy if exists svc_visits_update on public.svc_visits;
create policy svc_visits_update on public.svc_visits for update to authenticated
  using (technician_id = (select auth.uid()) or assignee_id = (select auth.uid()) or (select auth.uid()) = any(participant_ids) or (select public.svc_is_lead()))
  with check ((select public.svc_is_member()));
