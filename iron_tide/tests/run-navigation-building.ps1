param(
    [string]$Godot = "$env:LOCALAPPDATA\Programs\Godot\Godot_v4.7.2-stable_win64_console.exe",
    [string]$RunRoot = "",
    [ValidateSet("traffic_frame_cache_regression", "passing_traffic_regression", "six_traffic_regression", "unit_neighborhood_regression", "timed_congestion_regression", "logic15_bridge_regression", "mirage_selection_regression", "ai_engagement_regression", "house_defeat_notice_regression", "house_elimination_regression", "stuck_retry_fairness_regression", "slot3_stuck_retry_regression", "sold_production_regression", "siege_chopper_collision_regression", "tank_hero_regression", "expedition_regression", "expedition_income_regression", "expedition_layout_regression", "expedition_traits_regression", "expedition_growth_regression", "expedition_relics_regression", "friendly_outline_regression", "ra3_apocalypse_crush_regression", "friendly_infantry_traffic_regression", "bridge_parked_exit_regression", "superweapon_damage_regression", "carrier_attack_bonus_regression", "force_shield_target_regression", "bridge_sections_regression", "bridge_weapons_regression", "bridge_damage_regression", "native_bridge_traffic_regression", "unit_status_regression", "gm_hero_contracts_regression", "ai_wall_clearance_regression", "ai_power_recovery_regression", "unit_lost_owner_regression", "card_gallery_regression", "auto_w_regression", "progression_expansion_regression", "navigation_building_regression", "rules_mode_regression", "minimap_regression", "selection_regression", "input_ownership_regression", "hud_layout_regression", "hud_identity_regression", "audio_regression", "building_preview_regression", "production_status_regression", "batch_rally_regression", "building_exit_regression", "building_animation_regression", "unit_art_regression", "defense_art_regression", "defense_fire_regression", "hit_structure_regression", "harvester_regression", "miner_heading_regression", "cameo_regression", "unit_fire_regression", "recoil_regression", "unit_muzzle_regression", "economy_ai_regression", "logistics_regression", "carrier_sortie_regression", "naval_regression", "naval_navigation_regression", "asw_regression", "sonic_regression", "camera_input_regression", "wall_regression", "wall_fire_regression", "hero_air_gun_regression", "furnace_contract_regression", "growth_balance_regression", "brutal_three_regression", "production_reason_regression", "production_sidebar_regression", "display_resolution_regression", "display_settings_regression", "damage_startup_regression", "ra3_mirage_conditions_regression", "unit_composition_regression", "control_group_regression", "audio_lifecycle_regression", "command_transition_regression", "country_regression", "unlock_guidance_regression", "unlock_navigation_regression", "unlock_options_regression", "base_recovery_regression", "mcv_opening_regression", "skill_hotkey_regression", "economy_integrity_regression", "economy_detail_regression", "fog_rules_regression", "fog_long_match", "soviet_opening_regression", "soviet_reinforcements_regression", "soviet_defense_regression", "soviet_advanced_regression", "feedback_regression", "factory_tabs_regression", "dual_build_regression", "cursor_regression", "veterancy_regression", "economy_chain_regression", "music_regression", "music_ui_regression", "attack_range_regression", "deployed_attack_regression", "command_voice_regression", "ground_control_regression", "structure_queue_regression", "tactical_target_regression", "traffic_regression", "combat_load_regression", "yr_guardian_regression", "yr_voice_regression", "harvest_fx_regression", "deploy_pointer_regression", "construction_audio_regression", "building_advisor_regression", "unit_capability_audit", "refinery_traffic_regression", "yr_robot_regression", "ggi_skill_regression", "yr_damage_regression", "ore_passage_regression", "building_actions_regression", "savegame_regression", "auto_harvest_regression", "allied_abilities_regression", "repair_depot_regression", "unit_cancel_regression", "deploy_skill_dedup_regression", "structure_technology_regression", "technology_progression_regression", "refinery_gift_regression", "weapon_vision_regression", "boarding_cursor_regression", "ready_tab_regression", "production_hold_regression", "attack_cooldown_indicator_regression", "sidebar_camera_regression", "box_ui_release_regression", "vehicle_motion_regression", "commando_attack_regression", "refinery_skill_ui_regression", "flight_motion_regression", "yr_fortress_regression", "temporal_visual_regression", "weapon_trail_regression", "aircraft_ammo_regression", "c4_entry_regression", "production_catalog_regression", "model_render_regression", "elite_weapon_regression", "support_buildings_regression", "support_visual_regression", "double_click_view_regression", "build_range_regression", "vehicle_turn_regression", "movement_order_regression", "flight_speed_regression", "fortress_speed_regression", "mining_obstruction_regression", "airport_docking_regression", "spy_infiltration_regression", "construction_transition_regression", "yr_baseline_regression", "airfield_order_regression", "lobby_preferences_regression", "battle_clock_regression", "automatic_defense_regression", "guard_toggle_regression", "c4_approach_regression", "building_fire_regression", "spy_money_regression", "spy_lab_regression", "deployed_traffic_regression", "spy_disguise_regression", "transport_indicator_regression", "building_repair_visual_regression", "model_smoothing_regression", "production_clock_regression", "war_factory_timing_regression", "shp_detail_regression", "miner_selection_regression", "lightning_storm_regression", "force_fire_regression", "projectile_lifetime_regression", "production_origin_regression", "healing_indicator_regression", "skirmish_strength_regression", "skirmish_tactics_regression", "miner_unload_regression", "special_mechanics_regression", "oil_footprint_regression", "skirmish_operations_regression", "strategic_landing_regression", "superweapon_alert_regression", "shipyard_repair_regression", "american_paradrop_regression", "special_mechanics_visual", "ra3_lighting_regression", "gm_death_cleanup_regression", "yr_death_regression", "yr_vehicle_death_regression", "selection_outline_regression")]
    [string]$Suite = "navigation_building_regression",
    [switch]$Render,
    [switch]$FreshImport
)

$ErrorActionPreference = "Stop"
$taskSource = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot ".."))
if (-not (Test-Path -LiteralPath $Godot -PathType Leaf)) {
    throw "Godot executable not found: $Godot"
}
if ([string]::IsNullOrWhiteSpace($RunRoot)) {
    $RunRoot = Join-Path $env:TEMP ("iron-tide-check-" + [guid]::NewGuid().ToString("N"))
}
$taskRun = [IO.Path]::GetFullPath($RunRoot)
if ($taskRun.Equals($taskSource, [StringComparison]::OrdinalIgnoreCase) -or
    $taskRun.StartsWith($taskSource + "\", [StringComparison]::OrdinalIgnoreCase)) {
    throw "RunRoot must be outside the source project."
}
if (Test-Path -LiteralPath $taskRun) {
    throw "RunRoot already exists; choose a new directory to preserve previous evidence."
}

function Get-SourceFingerprint([string]$Root) {
    $result = [ordered]@{}
    $files = @(
        foreach ($name in @("scripts", "scenes", "data", "shaders", "tests", "assets")) {
            Get-ChildItem -LiteralPath (Join-Path $Root $name) -File -Recurse
        }
        Get-Item -LiteralPath (Join-Path $Root "project.godot")
    )
    foreach ($file in ($files | Sort-Object FullName)) {
        $relative = $file.FullName.Substring($Root.Length + 1).Replace("\", "/")
        $result[$relative] = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
    }
    return $result
}

$taskBefore = Get-SourceFingerprint $taskSource
$taskProject = Join-Path $taskRun "project"
$taskReports = Join-Path $taskRun "reports"
New-Item -ItemType Directory -Path $taskProject, $taskReports -Force | Out-Null
foreach ($name in @("scripts", "scenes", "data", "shaders", "assets", "tests", ".godot", "icon.svg", "icon.svg.import", "icon.ico", "project.godot")) {
    if ($FreshImport -and $name -eq ".godot") { continue }
    $source = Join-Path $taskSource $name
    if (Test-Path -LiteralPath $source) {
        if ((Get-Item -LiteralPath $source).PSIsContainer) {
            & robocopy $source (Join-Path $taskProject $name) /E /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "Failed copying $source" }
        } else {
            Copy-Item -LiteralPath $source -Destination $taskProject
        }
    }
}

# Change only the disposable project's storage location, before autoloads can run.
$taskUserDir = "CodexIronTideValidation/" + [guid]::NewGuid().ToString("N")
$taskConfigPath = Join-Path $taskProject "project.godot"
$taskConfig = [IO.File]::ReadAllText($taskConfigPath)
$taskConfig = [regex]::Replace($taskConfig, '(?m)^config/(use_custom_user_dir|custom_user_dir_name)=.*\r?\n', "")
$taskConfig = $taskConfig.Replace("[application]", "[application]`nconfig/use_custom_user_dir=true`nconfig/custom_user_dir_name=`"$taskUserDir`"")
# Set before the first native window exists, including the initial splash.
# Offscreen placement alone does not prevent Windows focus activation.
$taskConfig = [regex]::Replace($taskConfig, '(?m)^window/size/(no_focus|always_on_top)=.*\r?\n', "")
$taskConfig = $taskConfig.Replace("[display]", "[display]`nwindow/size/no_focus=true`nwindow/size/always_on_top=false")
# Display settings validation owns native resizing; begin windowed and offscreen.
if ($Suite -eq "display_settings_regression") {
    $taskConfig = $taskConfig.Replace("window/size/mode=3", "window/size/mode=0")
}
[IO.File]::WriteAllText($taskConfigPath, $taskConfig, [Text.UTF8Encoding]::new($false))
$taskArguments = @("--path", $taskProject, "--fixed-fps", "60",
    "--log-file", (Join-Path $taskReports "godot.log"), "res://tests/$Suite.tscn")
if (-not $Render) {
    $taskArguments = @("--headless") + $taskArguments
}
if ($Suite -eq "battle_clock_regression") {
    # Wall-clock assertions need actual elapsed time, not --fixed-fps simulation.
    $taskArguments = @("--path", $taskProject, "--max-fps", "60",
        "--log-file", (Join-Path $taskReports "godot.log"), "res://tests/$Suite.tscn")
    if (-not $Render) { $taskArguments = @("--headless") + $taskArguments }
}
if ($Suite -in @("audio_regression", "music_regression", "command_voice_regression", "yr_voice_regression", "construction_audio_regression")) {
    # The mixer runs on wall time; fixed-fps can finish before audio is mixed.
    $taskArguments = @("--headless", "--audio-driver", "WASAPI", "--path", $taskProject,
        "--log-file", (Join-Path $taskReports "godot.log"), "res://tests/$Suite.tscn")
}
if ($Render) { $taskArguments = @('--windowed', '--resolution', '1600x900', '--position', '-4000,-4000') + $taskArguments }
$taskOldReportDir = $env:IRON_TIDE_REPORT_DIR
$taskExit = 2
function Invoke-BackgroundGodot([string[]]$Arguments, [string]$LogName) {
    # All generated paths are files/directories without trailing separators.
    $quoted = @($Arguments | ForEach-Object { '"' + $_.Replace('"', '\"') + '"' })
    $process = Start-Process -FilePath $Godot -ArgumentList $quoted -WindowStyle Hidden -PassThru -Wait `
        -RedirectStandardOutput (Join-Path $taskReports "$LogName-console.log") `
        -RedirectStandardError (Join-Path $taskReports "$LogName-error.log")
    return $process.ExitCode
}
try {
    $env:IRON_TIDE_REPORT_DIR = $taskReports
    $taskImportLog = Join-Path $taskReports "import.log"
    $taskImportExit = Invoke-BackgroundGodot @('--headless', '--path', $taskProject, '--editor', '--quit', '--log-file', $taskImportLog) 'import'
    if ($taskImportExit -ne 0 -or (Get-Content -LiteralPath $taskImportLog -Raw) -match "(?m)^(SCRIPT ERROR|ERROR):") {
        throw "Isolated project import failed. Reports: $taskReports"
    }
    $taskExit = Invoke-BackgroundGodot $taskArguments 'runtime'
}
finally {
    $env:IRON_TIDE_REPORT_DIR = $taskOldReportDir
    $taskAfter = Get-SourceFingerprint $taskSource
    $taskStable = (ConvertTo-Json $taskBefore -Compress) -eq (ConvertTo-Json $taskAfter -Compress)
    $taskAudit = [ordered]@{
        source = $taskSource
        suite = $Suite
        fresh_import = [bool]$FreshImport
        isolated_project = $taskProject
        custom_user_dir = $taskUserDir
        source_unchanged = $taskStable
        engine_exit_code = $taskExit
        native_window_no_focus = $true
        native_window_always_on_top = $false
        console_hidden = $true
        source_before = $taskBefore
        source_after = $taskAfter
    }
    $taskAudit | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskReports "environment-audit.json") -Encoding UTF8
}
$taskLog = Get-Content -LiteralPath (Join-Path $taskReports "godot.log") -Raw
$taskResultPath = Join-Path $taskReports "result.json"
if (-not $taskStable -or $taskExit -ne 0 -or $taskLog -match "(?m)^(SCRIPT ERROR|ERROR):" -or
    -not (Test-Path -LiteralPath $taskResultPath)) {
    throw "Validation failed or environment changed. Reports: $taskReports"
}
$taskResult = Get-Content -LiteralPath $taskResultPath -Raw -Encoding UTF8 | ConvertFrom-Json
if ($taskResult.failed -ne 0) {
    throw "Regression assertions failed. Reports: $taskReports"
}
Write-Output "PASS: $($taskResult.checks.Count) assertions. Reports: $taskReports"
