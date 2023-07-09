_addon.name = 'Metronome'
_addon.author = 'Shasta'
_addon.version = '1.0.0'
_addon.commands = {'met','metronome'}

-------------------------------------------------------------------------------
-- Includes/imports
-------------------------------------------------------------------------------
require('tables')
require('lists')
require('sets')
require('strings')

res = require('resources')
packets = require('packets')
config = require('config')
texts = require('texts')
-- inspect = require('inspect')

chat_purple = string.char(0x1F, 200)
chat_grey = string.char(0x1F, 160)
chat_red = string.char(0x1F, 167)
chat_white = string.char(0x1F, 001)
chat_green = string.char(0x1F, 214)
chat_yellow = string.char(0x1F, 036)
chat_d_blue = string.char(0x1F, 207)
chat_pink = string.char(0x1E, 5)
chat_l_blue = string.char(0x1E, 6)

inline_white = '\\cs(255,255,255)'
inline_red = '\\cs(255,0,0)'
inline_green = '\\cs(0,255,0)'
inline_blue = '\\cs(0,0,255)'
inline_gray = '\\cs(170,170,170)'

default_settings = {
  display_on_all_jobs = false,
  loop_interval = 1000,
  display={
    text={
      size=10,
      font='Consolas',
      alpha=255,
      red=255,
      green=255,
      blue=255,
    },
    pos={
      x=0,
      y=0
    },
    bg={
      visible=true,
      alpha=200,
      red=0,
      green=0,
      blue=0,
    },
  }
}
step_actions = {
  [201] = {name='Quickstep',    action_id=201, status_id=386},
  [202] = {name='Box Step',     action_id=202, status_id=391},
  [203] = {name='Stutter Step', action_id=203, status_id=396},
  [312] = {name='Feather Step', action_id=312, status_id=448},
}
step_debuffs = {
  [386] = {name='Quickstep',    action_id=201, status_id=386},
  [391] = {name='Box Step',     action_id=202, status_id=391},
  [396] = {name='Stutter Step', action_id=203, status_id=396},
  [448] = {name='Feather Step', action_id=312, status_id=448},
}
STEP_TIME_EXTENSION = 30

function init(force_init)
  player = {} -- Player status
  tracker = {} -- Tracks enemies' step debuffs, keyed by enemy actor ID
  -- Tracked value model:
  -- {
  --   ['Quickstep'] =    {name='Quick Step',   action_id=201, status_id=386, exp=6483818, level=1},
  --   ['Box Step'] =     {name='Box Step',     action_id=201, status_id=391, exp=1345345, level=3},
  --   ['Stutter Step'] = {name='Stutter Step', action_id=201, status_id=396, exp=4573573, level=1},
  --   ['Feather Step'] = {name='Feather Step', action_id=201, status_id=448, exp=7894567, level=5},
  -- }
  update_player_info()
  loop_time = now() -- Timestamp of previous loop reset
  settings = config.load(default_settings)
  ui = texts.new('${value}', settings.display)
  ui.value = 'Loading Metronome...'

  if not force_init and not display_on_all_jobs and player.main_job ~= 'DNC' and player.sub_job ~= 'DNC' then
    -- If not dnc or /dnc soft unload
    ui:hide()
    initialized = false
  else
    -- Set UI visibility based on saved setting
    ui:visible(settings.show_ui)
    initialized = true
  end
end

-- Update player info
function update_player_info()
  local player_info = windower.ffxi.get_player()
  if player_info then
    player.id = player_info.id
    player.name = player_info.name
    player.main_job = player_info.main_job
    player.main_job_level = player_info.main_job_level
    player.sub_job = player_info.sub_job
    player.sub_job_level = player_info.sub_job_level
    player.merits = player_info.merits
    player.job_points = player_info.job_points
  end
end

function toggle_ui()
  local is_vis = ui:visible()
  -- If we're changing it to be visible, we need to update the UI text first
  if not is_vis then
    update_ui_text(true)
  end
  
  -- Toggle visibility
  ui:visible(not is_vis)
end

function show_ui()
  local is_vis = ui:visible()
  -- If we're changing it to be visible, we need to update the UI text first
  if not is_vis then
    update_ui_text(true)
    ui:show()
  end
end

function hide_ui()
  ui:hide()
end

function update_ui_text(force_update)
  -- No point in setting UI text if it's not visible
  if not force_update and not ui:visible() then return end

  -- Get current target
  local target = windower.ffxi.get_mob_by_target('t')
  tracked_steps = target and tracker[target.id]
  if not tracked_steps then
    -- Target does not have step debuffs, clear UI
    ui:text('')
    return
  end

  -- Create text line-by-line
  local lines = T{}
  local header = '  Lv  Step         Time'
  lines:append(header)
  for _, step in pairs(tracked_steps) do
    -- If expired, remove from tracker
    if step.exp < now() then
      tracker[target.id][step.name] = nil
    else
      local str = '['
      -- Calculate spacer
      if step.level < 10 then
        str = str..' '
      end
      str = str..step.level..'] '..step.name
      -- Calculate spacer
      local len = 13 - step.name:length()
      str = str..string.rep(' ', len)
      str = str..format_time(step.exp - now())
      lines:append(str)
    end
  end

  -- If only one line (the header), remove tracked enemy because no active debuffs
  if lines:length() == 1 then
    tracker[target.id] = nil
    ui:text('')
    return
  end

  -- Compose new text by combining all lines into a single string separated by line breaks
  local str = lines:concat('\n ')
  ui:text(str)
end

-- Convert time in milliseconds to a string in the format mm:ss
function format_time(time_in_milli)
  local minutes = time_in_milli / 1000 / 60
  local seconds = math.fmod(time_in_milli / 1000, 60)

  return string.format('%02d', minutes)..':'..string.format('%02d', seconds)
end

-- Calculate expiration time for the debuff and track it
function process_step_action(act, step, level)
  local target_id = act.targets[1].id

  -- Duration affected by DNC main vs subjob
  -- Duration affected by DNC job point allocation
  
  -- If not action used by self and not Feather Step, assume player is subjob DNC
  local is_main
  local step_jp = 0
  if step.action_id == 312 then -- Feather Step can only be used by main DNC
    is_main = true
  elseif act.actor_id == player.id then
    -- Check own job to determine if main or subjob DNC
    is_main = player.main_job == 'DNC'
    if is_main then
      -- Check job points
      step_jp = player.job_points[player.main_job:lower()].step_duration
    end
  else
    is_main = false
  end

  -- Get current debuff expiration
  local current_exp = tracker[target_id] and tracker[target_id][step.name] and tracker[target_id][step.name].exp or nil
  local new_exp

  -- If current buff is already expired, treat it as if enemy doesn't have debuff
  if current_exp and current_exp < now() then
    current_exp = nil
  end

  -- If no current expiration or current tracked step is expired, this is intial application
  if not current_exp then
    -- Initial application is 1 min (plus possible step JP)
    new_exp = now() + (STEP_TIME_EXTENSION * 1000 *2) + (step_jp * 1000)
  else -- If debuff is already on enemy, calculate extended duration
    new_exp = current_exp + (is_main and STEP_TIME_EXTENSION * 1000) + (step_jp * 1000)

    -- Clip duration based on main/sub DNC and JP allocation
    -- Max duration is 2 mins without JP or 2:20 with full JP
    local max_exp = now() + 120000 + (step_jp * 1000)

    if current_exp > max_exp then
      new_exp = current_exp
    else
      new_exp = math.min(new_exp, max_exp)
    end
  end

  local new_step = step
  new_step.exp = new_exp
  new_step.level = level

  if not tracker[target_id] then
    tracker[target_id] = {}
  end

  tracker[target_id][step.name] = new_step
end

-- Time in milliseconds
function now()
  return os.clock() * 1000
end

windower.register_event('incoming chunk', function(id, data, modified, injected, blocked)
  if id == 0x00E then -- NPC Update
    -- Clear entry from tracker if enemy is dead
    local packet = packets.parse('incoming', data)
    local actor_id = packet['NPC']
    if tracker[actor_id] then
      if packet['HP %'] <= 0 and (packet['Status'] == 2 or packet['Status'] == 3) then
        tracker[actor_id] = nil
      end
    end
  elseif id == 0x05B then -- Spawn
    -- Clear entry from tracker when enemy spawns
    local packet = packets.parse('incoming', data)
    local actor_id = packet.ID
    if tracker[actor_id] then
      tracker[actor_id] = nil
    end
  elseif id == 0x029 then -- Action message
    -- Listen for debuff removal/expiration
    local packet = packets.parse('incoming', data)
    local actor_id = packet['Target']
    local msg_id = packet['Message']
    local debuff_id1 = packet['Param 1']
    local debuff_id2 = packet['Param 2']
    
    if tracker[actor_id]
        and S{64,204,206,350,531}:contains(msg_id)
        and (step_debuffs[debuff_id1] or step_debuffs[debuff_id2]) then
      local debuff1 = step_debuffs[debuff_id1] and step_debuffs[debuff_id1].name
      local debuff2 = step_debuffs[debuff_id2] and step_debuffs[debuff_id2].name
      if debuff1 then
        tracker[actor_id][debuff1] = nil
      end
      if debuff2 then
        tracker[actor_id][debuff2] = nil
      end
      -- If actor has no more step debuffs, remove from tracker
      if table.length(tracker[actor_id]) == 0 then
        tracker[actor_id] = nil
      end
    end
  end
end)

windower.register_event('load', function()
  if windower.ffxi.get_player() then
    init()
  end
end)

windower.register_event('unload', function()
  settings:save()
  hide_ui()
end)

windower.register_event('logout', function()
  settings:save()
  hide_ui()
end)

windower.register_event('login', function()
  windower.send_command('lua r metronome')
end)

windower.register_event('job change', function(main_job_id, main_job_level, sub_job_id, sub_job_level)
  init()
end)

windower.register_event('action', function(act)
  if act.category == 14 then -- Unblinkable JA
    local step = step_actions[act.param]
    if step then
      local level = act.targets[1].actions[1].param
      if level > 0 then
        process_step_action(act, step, level)
        update_ui_text(true)
      end
    end
  elseif act.category == 6 and (act.param == 18 or act.param == 96) then -- Benediction or Wild Card
    -- If target is a tracked enemy, reset its debuffs
    for _,target in pairs(act.targets) do
      if tracker[target.id] then
        tracker[target.id] = nil
      end
    end
  end
end)

windower.register_event('addon command', function(cmd, ...)
  local cmd = cmd and cmd:lower()
  local args = {...}
  -- Force all args to lowercase
  for k,v in ipairs(args) do
    args[k] = v:lower()
  end

  if cmd then
    if S{'reload', 'r'}:contains(cmd) then
      windower.send_command('lua r metronome')
      windower.add_to_chat(001, chat_d_blue..'Metronome: Reloading.')
    elseif S{'visible', 'vis'}:contains(cmd) then
      settings.show_ui = not settings.show_ui
      toggle_ui()
      settings:save()
      windower.add_to_chat(001, chat_d_blue..'Metronome: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
    elseif 'show' == cmd then
      settings.show_ui = true
      show_ui()
      settings:save()
      windower.add_to_chat(001, chat_d_blue..'Metronome: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
      if not initialized then
        init(true)
      end
    elseif 'hide' == cmd then
      settings.show_ui = false
      hide_ui()
      settings:save()
      windower.add_to_chat(001, chat_d_blue..'Metronome: UI visibility set to '..chat_white..tostring(settings.show_ui)..chat_d_blue..'.')
    elseif 'resetpos' == cmd then
      settings.display.pos.x = 0
      settings.display.pos.y = 0
      ui:pos(0, 0)
      settings:save()
      windower.add_to_chat(001, chat_d_blue..'Metronome: UI position reset to default.')
    elseif 'jobs' == cmd then
      settings.display_on_all_jobs = not settings.display_on_all_jobs
      settings:save()
      windower.add_to_chat(001, chat_d_blue..'Metronome: Display On All Jobs set to '..chat_white..tostring(settings.display_on_all_jobs)..chat_d_blue..'.')
      if settings.display_on_all_jobs and not initialized then
        init(true)
      end
    elseif 'test' == cmd then
    elseif 'help' == cmd then
      windower.add_to_chat(6, ' ')
      windower.add_to_chat(6, chat_d_blue.. 'Metronome Commands available:' )
      windower.add_to_chat(6, chat_l_blue..	'//met r' .. chat_white .. ': Reload HasteInfo addon')
      windower.add_to_chat(6, chat_l_blue..	'//met vis ' .. chat_white .. ': Toggle UI visibility')
      windower.add_to_chat(6, chat_l_blue..	'//met show ' .. chat_white .. ': Show UI')
      windower.add_to_chat(6, chat_l_blue..	'//met hide ' .. chat_white .. ': Hide UI')
      windower.add_to_chat(6, chat_l_blue..	'//met resetpos ' .. chat_white .. ': Reset position of UI to default')
      windower.add_to_chat(6, chat_l_blue..	'//met jobs ' .. chat_white .. ': Display show/hide based on job being DNC or not.')
      windower.add_to_chat(6, chat_l_blue..	'//met help ' .. chat_white .. ': Display this help menu again')
    else
      windower.send_command('met help')
    end
  else
    windower.send_command('met help')
  end
end)

-- Infinite loop to do things like update the UI
windower.register_event('prerender', function()
  if initialized then
    if now() > loop_time + settings.loop_interval then
      loop_time = now()
      update_ui_text()
    end
  end
end)
