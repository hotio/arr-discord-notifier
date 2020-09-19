#!/bin/bash

set -e

API_KEY=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "${CONFIG_DIR}/app/config.xml")

if [[ ${radarr_eventtype} == "Test" ]] || [[ ${1} == "Radarr" ]]; then
    radarr_eventtype="Download"
    radarr_moviefile_path="$0"
    radarr_movie_title="Work It"
    radarr_movie_tmdbid="612706"
    radarr_moviefile_quality="WEBDL-1080p"
    radarr_isupgrade="False"
    radarr_moviefile_releasegroup="GROUP"
fi

if [[ ${sonarr_eventtype} == "Test" ]] || [[ ${1} == "Sonarr" ]]; then
    sonarr_eventtype="Download"
    sonarr_episodefile_path="$0"
    sonarr_series_title="Lovecraft Country"
    sonarr_series_tvdbid="357864"
    sonarr_episodefile_quality="WEBDL-1080p"
    sonarr_isupgrade="True"
    sonarr_episodefile_releasegroup="GROUP"
    sonarr_episodefile_seasonnumber="1"
    sonarr_episodefile_episodenumbers="1,2"
    sonarr_episodefile_episodeairdates="2020-08-16,2020-08-23"
fi

if [[ ${radarr_eventtype} == "Download" ]]; then
    COLOR="16761392"
    TIMESTAMP=$(date -u --iso-8601=seconds)

    if [[ ${radarr_isupgrade} == "True" ]]; then
        upgrade_text="Upgrade"
        COLOR="7105644"
    else
        upgrade_text="New"
    fi

    json="$(curl -fsSL --request GET "localhost:7878/api/movie/lookup/tmdb?tmdbId=${radarr_movie_tmdbid}&apikey=${API_KEY}")"
    movie_poster=$(echo "${json}" | jq -r '.images[] | select(.coverType=="poster") | .url')
    [[ -z ${movie_poster} ]] && movie_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/poster.png"
    movie_backdrop=$(echo "${json}" | jq -r '.images[] | select(.coverType=="fanart") | .url' | sed s/original/w500/)
    [[ -z ${movie_backdrop} ]] && movie_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/backdrop.png"
    movie_release_year=$(echo "${json}" | jq -r '.year')
    movie_size=$(du -h "${radarr_moviefile_path}" | awk '{print $1}')
    if [[ -z ${radarr_moviefile_releasegroup} ]]; then
        movie_group="---"
    else
        movie_group="${radarr_moviefile_releasegroup}"
    fi

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                    "title": "'${radarr_movie_title}' ('${movie_release_year}')",
                    "url": "https://www.themoviedb.org/movie/'${radarr_movie_tmdbid}'",
                    "thumbnail": {"url": "'${movie_poster}'"},
                    "image": {"url": "'${movie_backdrop}'"},
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'",
                    "footer": {"text": "'${upgrade_text}'"},
                    "fields":
                        [
                            {"name": "Quality", "value": "'${radarr_moviefile_quality}'", "inline": true},
                            {"name": "Group", "value": "'${movie_group}'", "inline": true},
                            {"name": "Size", "value": "'${movie_size}'", "inline": true}
                        ]
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
fi

if [[ ${sonarr_eventtype} == "Download" ]]; then
    COLOR="2200501"
    TIMESTAMP=$(date -u --iso-8601=seconds)

    if [[ ${sonarr_isupgrade} == "True" ]]; then
        upgrade_text="Upgrade"
        COLOR="7105644"
    else
        upgrade_text="New"
    fi

    json="$(curl -fsSL --request GET "localhost:8989/api/series/lookup?term=tvdb:${sonarr_series_tvdbid}&apikey=${API_KEY}")"
    tv_poster=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="poster") | .url')
    [[ -z ${tv_poster} ]] && tv_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/poster.png"
    tv_backdrop=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="fanart") | .url' | sed s/.jpg/_t.jpg/)
    [[ -z ${tv_backdrop} ]] && tv_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/backdrop.png"
    tv_release_year=$(echo "${json}" | jq -r '.[].year')
    tv_size=$(du -h "${sonarr_episodefile_path}" | awk '{print $1}')
    if [[ -z ${sonarr_episodefile_releasegroup} ]]; then
        tv_group="---"
    else
        tv_group="${sonarr_episodefile_releasegroup}"
    fi

    DEFAULTIFS="${IFS}"
    IFS=','
    read -r -a episodes <<< "${sonarr_episodefile_episodenumbers}"
    read -r -a airdates <<< "${sonarr_episodefile_episodeairdates}"
    IFS="${DEFAULTIFS}"

    for i in "${!episodes[@]}"; do
        json='
        {
            "embeds":
                [
                    {
                        "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                        "title": "'${sonarr_series_title//([[:digit:]][[:digit:]][[:digit:]][[:digit:]])/}' ('${tv_release_year}')",
                        "url": "http://www.thetvdb.com/?tab=series&id='${sonarr_series_tvdbid}'",
                        "thumbnail": {"url": "'${tv_poster}'"},
                        "image": {"url": "'${tv_backdrop}'"},
                        "color": "'${COLOR}'",
                        "timestamp": "'${TIMESTAMP}'",
                        "footer": {"text": "'${upgrade_text}'"},
                        "fields":
                            [
                                {"name": "Episode", "value": "S'$(printf "%02d" "${sonarr_episodefile_seasonnumber}")'E'$(printf "%02d" "${episodes[i]}")'"},
                                {"name": "Air date", "value": "'${airdates[i]}'"},
                                {"name": "Quality", "value": "'${sonarr_episodefile_quality}'", "inline": true},
                                {"name": "Group", "value": "'${tv_group}'", "inline": true},
                                {"name": "Size", "value": "'${tv_size}'", "inline": true}
                            ]
                    }
                ]
        }
        '
        curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
    done
fi
