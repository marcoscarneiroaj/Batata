# Batata

Projeto modular em Lua para Roblox.

## Rodar localmente no Wave

```lua
loadstring(readfile("batata\\gui.lua"), "@batata\\gui.lua")()
```

## Rodar pelo GitHub Raw

1. Suba todos os arquivos desta pasta para a raiz de um repositorio no GitHub.
2. Edite `web_loader.lua`.
3. Troque `BASE_URL` pela URL raw da raiz do repositorio.

Exemplo:

```lua
local BASE_URL = "https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPOSITORIO/main/"
```

4. Use o link raw do `web_loader.lua`:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPOSITORIO/main/web_loader.lua", true))()
```

## Observacao

- O `web_loader.lua` baixa `shared.lua`, `gui.lua` e os outros modulos pela internet.
- O `shared.lua` agora suporta tanto leitura local quanto carregamento remoto por `BASE_URL`.
