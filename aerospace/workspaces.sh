#!/bin/bash
# Workspace profiles: which workspace number each app "role" lives on.
# Sourced by route.sh, apply-profile.sh, zoom-route.sh and
# first-window-to-workspace.sh. EDIT THE TABLES BELOW to change placements.
#
# Profile is picked by monitor count: 1 monitor -> laptop, 2+ -> desk.
#
#   ws | desk (3 displays)   | laptop only
#   ---+---------------------+-------------
#    1 | Slack               | Slack
#    2 | Vivaldi             | Vivaldi
#    3 | Alacritty           | Dashboard
#    4 | Zoom meeting        | Alacritty
#    5 | Dashboard           | Outlook
#    6 | Outlook             | Zoom meeting
#    7 | Spotify             | -
#    8 | -                   | Spotify
#    9 | parking             | parking

AEROSPACE=${AEROSPACE:-/opt/homebrew/bin/aerospace}

ws_profile() {
    local n
    n=$("$AEROSPACE" list-monitors --count 2>/dev/null)
    if [ "${n:-1}" -le 1 ]; then echo laptop; else echo desk; fi
}

# ws_for <role> [profile] -> workspace number (empty for unknown role)
ws_for() {
    local role="$1" profile="${2:-$(ws_profile)}"
    case "$profile:$role" in
        desk:slack)       echo 1 ;;
        desk:vivaldi)     echo 2 ;;
        desk:alacritty)   echo 3 ;;
        desk:meeting)     echo 4 ;;
        desk:dashboard)   echo 5 ;;
        desk:outlook)     echo 6 ;;
        desk:spotify)     echo 7 ;;
        desk:park)        echo 9 ;;

        laptop:slack)     echo 1 ;;
        laptop:vivaldi)   echo 2 ;;
        laptop:dashboard) echo 3 ;;
        laptop:alacritty) echo 4 ;;
        laptop:outlook)   echo 5 ;;
        laptop:meeting)   echo 6 ;;
        laptop:spotify)   echo 8 ;;
        laptop:park)      echo 9 ;;
    esac
}

# role -> app bundle id (used to find already-open windows)
app_for() {
    case "$1" in
        slack)     echo com.tinyspeck.slackmacgap ;;
        vivaldi)   echo com.vivaldi.Vivaldi ;;
        dashboard) echo com.vivaldi.Vivaldi.app.mcijphhnflbofdapglafogoladjmgfge ;;
        alacritty) echo org.alacritty ;;
        outlook)   echo com.microsoft.Outlook ;;
        spotify)   echo com.spotify.client ;;
    esac
}
