--[[
reaper_ai_track_namer_sws_sync.lua

Este script roda o script Python `sync_sws_colors.py` para sincronizar 
as cores e ícones do seu projeto com as regras do SWS Auto Color.

Ele irá abrir uma janela de terminal que indicará se você precisa fechar 
o Reaper para que as configurações sejam salvas com sucesso.
]]

local _, script_path = reaper.get_action_context()
local script_dir = script_path:match("^(.*[/\\])")
if not script_dir then script_dir = "" end

local os_name = reaper.GetOS()
local is_windows = os_name:find("Win") ~= nil

local python_exe
if is_windows then
  python_exe = script_dir .. "venv\\Scripts\\python.exe"
  -- Verifica se o executável do venv existe
  local f = io.open(python_exe, "rb")
  if f then
    f:close()
  else
    python_exe = "python"
  end
else
  python_exe = script_dir .. "venv/bin/python"
  local f = io.open(python_exe, "rb")
  if f then
    f:close()
  else
    python_exe = "python3"
  end
end

local sync_script = script_dir .. "sync_sws_colors.py"

local launch_cmd
if is_windows then
  -- Abre uma janela de terminal visível (/k mantém aberta caso haja erro no Python, mas como o python já tem pause, start comum basta)
  launch_cmd = string.format('start "" "%s" "%s"', python_exe, sync_script)
else
  -- No Mac/Linux
  launch_cmd = string.format('"%s" "%s" &', python_exe, sync_script)
end

os.execute(launch_cmd)
