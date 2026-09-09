-- ============================================================
-- NBA Stats + Transferências + Comparação de Equipas
-- Schema Supabase (Postgres)
-- ============================================================

-- 30 equipas da NBA
create table if not exists teams (
  code text primary key,
  name text not null
);

insert into teams (code, name) values
  ('ATL','Atlanta Hawks'),('BOS','Boston Celtics'),('BRK','Brooklyn Nets'),('CHI','Chicago Bulls'),
  ('CHO','Charlotte Hornets'),('CLE','Cleveland Cavaliers'),('DAL','Dallas Mavericks'),('DEN','Denver Nuggets'),
  ('DET','Detroit Pistons'),('GSW','Golden State Warriors'),('HOU','Houston Rockets'),('IND','Indiana Pacers'),
  ('LAC','LA Clippers'),('LAL','Los Angeles Lakers'),('MEM','Memphis Grizzlies'),('MIA','Miami Heat'),
  ('MIL','Milwaukee Bucks'),('MIN','Minnesota Timberwolves'),('NOP','New Orleans Pelicans'),('NYK','New York Knicks'),
  ('OKC','Oklahoma City Thunder'),('ORL','Orlando Magic'),('PHI','Philadelphia 76ers'),('PHO','Phoenix Suns'),
  ('POR','Portland Trail Blazers'),('SAC','Sacramento Kings'),('SAS','San Antonio Spurs'),('TOR','Toronto Raptors'),
  ('UTA','Utah Jazz'),('WAS','Washington Wizards')
on conflict (code) do nothing;

-- Jogadores (identidade estável ao longo de épocas/equipas)
create table if not exists players (
  id bigserial primary key,
  name text not null unique,
  position text,
  age int,
  created_at timestamptz default now()
);

-- Estatísticas por jogador/época (histórico — permite guardar várias épocas)
create table if not exists player_stats (
  id bigserial primary key,
  player_id bigint not null references players(id) on delete cascade,
  season text not null,               -- ex: '2025-26'
  team_code text references teams(code),
  games int, games_started int, minutes numeric,
  fg numeric, fga numeric, fg_pct numeric,
  p3 numeric, p3a numeric, p3_pct numeric,
  p2 numeric, p2a numeric, p2_pct numeric,
  efg_pct numeric,
  ft numeric, fta numeric, ft_pct numeric,
  orb numeric, drb numeric, trb numeric,
  ast numeric, stl numeric, blk numeric, tov numeric, pf numeric,
  pts numeric,
  awards text,
  updated_at timestamptz default now(),
  unique (player_id, season)
);

-- Transferências / mercado (trades, signings, draft, waivers...)
create table if not exists transactions (
  id bigserial primary key,
  player_id bigint references players(id) on delete set null,
  player_name_snapshot text,          -- guarda o nome mesmo que o jogador não exista ainda em `players` (ex: draftado novo)
  from_team text references teams(code),
  to_team text references teams(code),
  move_type text check (move_type in ('Trade','Signing','Draft','Waived','Free Agent','Extension')),
  move_date date,
  contract text,
  source text,                        -- link/nome da fonte (NBA.com, Basketball-Reference, ESPN...)
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_transactions_player on transactions(player_id);
create index if not exists idx_transactions_date on transactions(move_date desc);
create index if not exists idx_player_stats_player on player_stats(player_id);

-- ============================================================
-- Views: equipa atual e ratings agregados (recalculam sozinhas)
-- ============================================================

-- Equipa mais recente de cada jogador: última transação, senão a equipa da
-- época mais recente registada em player_stats.
create or replace view player_current_team as
select
  p.id as player_id,
  p.name,
  p.position,
  coalesce(
    (select t.to_team from transactions t
      where t.player_id = p.id and t.to_team is not null
      order by t.move_date desc nulls last, t.created_at desc limit 1),
    (select ps.team_code from player_stats ps
      where ps.player_id = p.id
      order by ps.season desc limit 1)
  ) as team_code
from players p;

-- Stats mais recentes de cada jogador (última época disponível)
create or replace view player_latest_stats as
select distinct on (ps.player_id) ps.*
from player_stats ps
order by ps.player_id, ps.season desc;

-- Rating agregado por equipa (usa a equipa ATUAL, já refletindo transferências)
create or replace view team_ratings as
select
  ct.team_code,
  count(*) as n_players,
  round(avg(ls.pts), 2) as avg_pts,
  round(avg(ls.trb), 2) as avg_reb,
  round(avg(ls.ast), 2) as avg_ast,
  round(avg(ls.fg_pct), 4) as avg_fg_pct,
  round(avg(ls.p3_pct), 4) as avg_3p_pct,
  round(avg(ls.efg_pct), 4) as avg_efg_pct,
  -- Rating composto ilustrativo (mesmos pesos usados no Excel):
  -- PTS + 0.7*REB + 0.7*AST + 50*eFG%  — ajustável, não é métrica oficial
  round(avg(ls.pts) + 0.7*avg(ls.trb) + 0.7*avg(ls.ast) + 50*avg(ls.efg_pct), 2) as rating
from player_current_team ct
join player_latest_stats ls on ls.player_id = ct.player_id
where ct.team_code is not null
group by ct.team_code;

-- ============================================================
-- RLS — leitura pública, escrita liberada para a app (uso interno/equipa).
-- Ajustar depois para autenticação real se for exposto publicamente.
-- ============================================================
alter table teams enable row level security;
alter table players enable row level security;
alter table player_stats enable row level security;
alter table transactions enable row level security;

create policy "public read teams" on teams for select using (true);
create policy "public read players" on players for select using (true);
create policy "public read player_stats" on player_stats for select using (true);
create policy "public read transactions" on transactions for select using (true);

create policy "public write players" on players for insert with check (true);
create policy "public write player_stats" on player_stats for insert with check (true);
create policy "public write transactions" on transactions for insert with check (true);
create policy "public update transactions" on transactions for update using (true);
create policy "public delete transactions" on transactions for delete using (true);
