# Court Ledger — NBA Stats & Mercado

App de uma página (HTML/JS) ligada a um Supabase, no mesmo estilo dos teus
outros projetos (guarda-redes FC Porto). Três secções: Estatísticas,
Transferências, Comparação de Equipas.

## 1. Criar o Supabase

1. Cria um projeto novo em supabase.com (ou usa um existente).
2. Vai a **SQL Editor** e corre, por esta ordem:
   - `schema.sql` — cria as tabelas, views e políticas de segurança (RLS).
   - `seed_players.sql` — insere os 150 jogadores e stats 2025-26 que já
     tínhamos preparado (Basketball-Reference).
3. Em **Project Settings → API**, copia o `Project URL` e a chave `anon public`.

## 2. Abrir a app

Já não precisas de fazer nada aqui — o `index.html` já vem ligado ao projeto
`nba-court-ledger` (URL + chave anon já embutidos no ficheiro). Basta abrir.
Se um dia quiseres apontar para outro projeto Supabase, usa o botão "Trocar
projeto Supabase" no canto superior direito da app.

## 3. Deploy (Netlify)

Mesmo processo que usaste nos outros projetos: arrasta a pasta (ou só o
`index.html`) para o Netlify Drop, ou liga a um repositório Git. Não há
build step — é um ficheiro estático puro.

## 4. Uso

- **Estatísticas** — lista os jogadores, pesquisável e ordenável por
  qualquer coluna. A equipa mostrada já reflete transferências registadas.
- **Transferências** — formulário para registar trades/signings/draft. Usa
  o autocomplete para apanhar o nome exato de um jogador existente (senão
  fica só como registo novo, útil para draftados).
- **Comparação de Equipas** — escolhe duas equipas e vê médias lado a lado
  + uma probabilidade estimada (modelo Elo/logístico simples, documentado
  na própria página — não é uma métrica preditiva validada, é um ponto de
  partida).

## Notas técnicas

- `team_ratings` é uma **view SQL**: recalcula-se sozinha sempre que
  inseres uma transferência ou stats novas — não há nada para "atualizar"
  manualmente na base de dados.
- Para adicionares uma nova época (26-27) no futuro, basta inserir novas
  linhas em `player_stats` com `season = '2026-27'`; a view
  `player_latest_stats` passa automaticamente a usar a época mais recente.
- RLS está aberta (leitura e escrita públicas) para simplicidade de uso
  interno — se um dia expuseres isto publicamente, vale a pena trocar por
  autenticação (Supabase Auth) nas políticas de `insert`/`update`/`delete`.
