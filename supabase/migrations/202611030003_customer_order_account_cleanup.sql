alter table public.customer_orders
  drop constraint if exists customer_orders_user_id_fkey;

alter table public.customer_orders
  add constraint customer_orders_user_id_fkey
  foreign key (user_id) references auth.users(id) on delete cascade;
