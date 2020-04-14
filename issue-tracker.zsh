#!/usr/bin/env zsh

emulate -R zsh
setopt extendedglob typesetsilent warncreateglobal

: ${GIT_SLEEP_TIME:=300}
: ${GIT_PROJECTS:=zdharma/zsh-github-issues}

typeset -ga reply

typeset -g URL="https://api.github.com/repos/\$ORG/\$PRJ/issues?state=open"
typeset -g CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-github-issues"
typeset -g CACHE_SEEN_IDS="$CACHE_DIR/ids_seen.dat"
typeset -g CACHE_NEW_TITLES="$CACHE_DIR/new_titles.log"

command mkdir -p "$CACHE_DIR"
command touch "$CACHE_SEEN_IDS"

download() {
    local url ORG="$1" PRJ="$2"
    eval "url=$URL"
    reply=( "${(@f)"$(curl --netrc --silent -i $url)"}" )
}

while (( 1 )) {
    for ORG PRJ in "${(@s:/:)${(s;:;)GIT_PROJECTS[@]}[@]}"; do
        print "Processing $ORG/$PRJ"
        download "$ORG" "$PRJ"

        local -a ids titles
        ids=( "${(M)reply[@]:#    \"id\":[[:space:]]#*,}" )
        ids=( "${${(M)ids[@]//(#b)[[:space:]]#\"id\":[[:space:]]#(*),/${match[1]}}[@]}" )
        titles=( ${(M)reply[@]:#[[:space:]]#\"title\":[[:space:]]#*,} )
        titles=( "${${(M)titles[@]//(#b)[[:space:]]#\"title\":[[:space:]]#\"(*)\",/${match[1]}}[@]}" )

        local -A map
        integer idx=0
        : ${ids[@]//(#b)(*)/${map[${match[1]}]::=${titles[$((++idx))]}}}

        local -a seen_ids diff
        seen_ids=( "${(@f)"$(<${CACHE_SEEN_IDS})"}" )
        if [[ -z "${seen_ids[*]}" ]]; then
            # Initial run – assume that all issues have been seen
            print -rl "${ids[@]}" >! "${CACHE_SEEN_IDS}"
        else
            # Detect new issues
            diff=( ${ids[@]:#(${(~j:|:)seen_ids[@]})} )
        fi

        if [[ ${#diff} -gt 0 ]]; then
            print -rl "${diff[@]}" >>! "${CACHE_SEEN_IDS}"
            local issue_id
            for issue_id in "${(Oa)diff[@]}"; do
                print -r -- "New issue for $ORG/$PRJ: ${map[$issue_id]}"
                print -rl "$ORG/$PRJ: ${map[$issue_id]}" >> "${CACHE_NEW_TITLES}"
            done
        fi
    done

    LANG=C sleep $GIT_SLEEP_TIME
}
