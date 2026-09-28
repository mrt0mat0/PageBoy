#!/bin/sh
# Fail if the addon reads or writes a global that isn't on the list below.
# Catches a local used before it's defined, which Lua silently treats as a nil global.
# Run from the repo root: sh tests/globals.sh
cd "$(dirname "$0")/.." || exit 1

ALLOWED="_G C_AddOns C_Spell GameTooltip C_UnitAuras CreateFrame GetActionBarPage GetBindingAction GetBindingKey GetCurrentBindingSet
GetAddOnMetadata GetBonusBarOffset InCombatLockdown InterfaceOptions_AddCategory InterfaceOptionsFrame_OpenToCategory IsInInstance PageBoyCharDB RegisterStateDriver
SLASH_PAGEBOY1 SaveBindings SecureCmdOptionParse SetBinding Settings SlashCmdList StaticPopupDialogs StaticPopup_Show UIParent UnitHealth NO YES issecretvalue
ipairs math pairs pcall print select table tonumber tostring type"

status=0
for f in $(grep -v '^#' PageBoy.toc | grep '\.lua$'); do
    [ -f "$f" ] || continue
    for g in $(luac -l -p "$f" | grep -oE '_ENV "[A-Za-z_0-9]+"' | sed 's/_ENV "//; s/"//' | sort -u); do
        case " $(echo $ALLOWED) " in
            *" $g "*) ;;
            *) echo "FAIL $f uses unknown global: $g"; status=1 ;;
        esac
    done
done
[ $status -eq 0 ] && echo "globals ok"
exit $status
