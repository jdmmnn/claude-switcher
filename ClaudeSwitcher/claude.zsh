# Claude Switcher: choose the Claude Code profile by the current folder.
# Folders are assigned in the app; the map is read on every call, so changes apply at once.
# Map format, one line per folder: <folder> TAB <config dir> TAB <profile name>
claude() {
  local map=${CLAUDE_SWITCHER_MAP:-$HOME/.config/claude-switcher/folders.tsv}
  local here=${PWD:A} root config name best='' chosen='' profile=''
  here=${(L)here%/}/   # macOS paths are usually case-insensitive
  # An explicitly set CLAUDE_CONFIG_DIR always wins.
  if [[ -z ${CLAUDE_CONFIG_DIR-} && -r $map ]]; then
    while IFS=$'\t' read -r root config name; do
      if [[ -n $root && $here == "${(L)root%/}/"* ]] && (( ${#root} > ${#best} )); then
        best=$root chosen=$config profile=$name
      fi
    done < $map
  fi
  if [[ -n $chosen ]]; then
    [[ -t 2 ]] && print -u2 -r -- "Claude Code: Profil $profile"
    CLAUDE_CONFIG_DIR=$chosen command claude "$@"
  else
    command claude "$@"
  fi
}
