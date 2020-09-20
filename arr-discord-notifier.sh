#!/bin/bash

set -e

PrettyPrintSize() {
    if [[ $1 -lt 1024 ]]; then
        printf "%0.2f B" "$(echo "${1}" | awk '{print $1}')"
    elif [[ $1 -lt 1048576 ]]; then
        printf "%0.2f KB" "$(echo "${1}" | awk '{print $1/1024}')"
    elif [[ $1 -lt 1073741824 ]]; then
        printf "%0.2f MB" "$(echo "${1}" | awk '{print $1/1024/1024}')"
    else
        printf "%0.2f GB" "$(echo "${1}" | awk '{print $1/1024/1024/1024}')"
    fi
}

[[ -z ${DISCORD_WEBHOOK} ]] && >&2 echo "No Discord webhook is configured!" && exit 1
[[ -z ${API_KEY} ]] && API_KEY=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "${CONFIG_DIR}/app/config.xml")
[[ -z ${API_KEY} ]] && >&2 echo "No API_KEY could be configured!" && exit 1
[[ -z ${HOST} ]] && HOST=localhost
TIMESTAMP=$(date -u --iso-8601=seconds)

if [[ ${1} == "Radarr" ]]; then
    radarr_eventtype="Test"
fi

if [[ ${1} == "Sonarr" ]]; then
    sonarr_eventtype="Test"
fi

if [[ ${radarr_eventtype} == "Test" ]]; then
    COLOR="16761392"

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                    "title": "Test succeeded!",
                    "description": "If you can read this we were able to send to your webhook without any problems. Below you can also find a test notification for one of your movies.",
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"

    radarr_eventtype="Download"
    radarr_movie_tmdbid="$(curl -fsSL --request GET "${HOST}:7878/api/v3/movie?apikey=${API_KEY}" | jq -r '.[0].tmdbId')"
    radarr_isupgrade="False"
fi

if [[ ${sonarr_eventtype} == "Test" ]]; then
    COLOR="2200501"

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                    "title": "Test succeeded!",
                    "description": "If you can read this we were able to send to your webhook without any problems. Below you can also find a test notification for one of your tv shows.",
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"

    sonarr_eventtype="Download"
    sonarr_series_tvdbid="$(curl -fsSL --request GET "${HOST}:8989/api/v3/series?apikey=${API_KEY}" | jq -r '.[0].tvdbId')"
    sonarr_isupgrade="True"
    sonarr_episodefile_seasonnumber="1"
    sonarr_episodefile_episodenumbers="1,2"
fi

if [[ ${radarr_eventtype} == "Download" ]]; then
    COLOR="16761392"; [[ ${radarr_isupgrade} == "True" ]] && COLOR="7105644"

    movie="$(curl -fsSL --request GET "${HOST}:7878/api/v3/movie?tmdbId=${radarr_movie_tmdbid}&apikey=${API_KEY}")"

    movie_title=$(echo "${movie}" | jq -r '.[].title')
    movie_release_year=$(echo "${movie}" | jq -r '.[].year')
    movie_quality=$(echo "${movie}" | jq -r '.[].movieFile.quality.quality.name')
    movie_video=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.videoCodec')
    movie_audio="$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioCodec') $(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioChannels')"
    movie_size=$(PrettyPrintSize "$(echo "${movie}" | jq -r '.[].movieFile.size')")

    movie_poster=$(echo "${movie}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
    [[ -z ${movie_poster} ]] && movie_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/poster.png"

    movie_backdrop=$(echo "${movie}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/original/w500/)
    [[ -z ${movie_backdrop} ]] && movie_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/backdrop.png"

    movie_overview=$(echo "${movie}" | jq -r '.[].overview')
    if [[ ${movie_overview} != "null" ]] && [[ -n ${movie_overview} ]]; then
        [[ ${#movie_overview} -gt 300 ]] && dots="..."
        movie_overview_field='{"name": "Overview", "value": "'${movie_overview:0:300}${dots}'"},'
    fi

    movie_genres=$(echo "${movie}" | jq -r '.[].genres | join(", ")')
    if [[ ${movie_genres} != "null" ]] && [[ -n ${movie_genres} ]]; then
        movie_genres_field='{"name": "Genres", "value": "'${movie_genres}'"},'
    fi

    movie_rating=$(echo "${movie}" | jq -r '.[].ratings.value')
    if [[ ${movie_rating} != "0" ]] && [[ -n ${movie_rating} ]]; then
        movie_rating_field='{"name": "Rating", "value": "'${movie_rating}'"},'
    fi

    movie_languages=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioLanguages')
    if [[ ${movie_languages} != "null" ]] && [[ -n ${movie_languages} ]]; then
        movie_languages_field=',{"name": "Languages", "value": "'${movie_languages}'"}'
    fi

    movie_subtitles=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.subtitles')
    if [[ ${movie_subtitles} != "null" ]] && [[ -n ${movie_subtitles} ]]; then
        movie_subtitles_field=',{"name": "Subtitles", "value": "'${movie_subtitles}'"}'
    fi

    movie_scene_name=$(echo "${movie}" | jq -r '.[].movieFile.sceneName')
    if [[ ${movie_scene_name} != "null" ]] && [[ -n ${movie_scene_name} ]]; then
        movie_scene_name_field=',{"name": "Release", "value": "```'${movie_scene_name}'```"}'
    fi

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                    "title": "'${movie_title}' ('${movie_release_year}')",
                    "url": "https://www.themoviedb.org/movie/'${radarr_movie_tmdbid}'",
                    "thumbnail": {"url": "'${movie_poster}'"},
                    "image": {"url": "'${movie_backdrop}'"},
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'",
                    "fields":
                        [
                            '${movie_overview_field}'
                            '${movie_rating_field}'
                            '${movie_genres_field}'
                            {"name": "Quality", "value": "'${movie_quality}'", "inline": true},
                            {"name": "Codecs", "value": "'${movie_video}' / '${movie_audio}'", "inline": true},
                            {"name": "Size", "value": "'${movie_size}'", "inline": true}
                            '${movie_languages_field}'
                            '${movie_subtitles_field}'
                            '${movie_scene_name_field}'
                        ]
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
fi

if [[ ${sonarr_eventtype} == "Download" ]]; then
    COLOR="2200501"; [[ ${sonarr_isupgrade} == "True" ]] && COLOR="7105644"

    tvshow="$(curl -fsSL --request GET "${HOST}:8989/api/v3/series?tvdbId=${sonarr_series_tvdbid}&apikey=${API_KEY}")"
    tvshow_id=$(echo "${tvshow}" | jq -r '.[].id')
    tvshow_title=$(echo "${tvshow}" | jq -r '.[].title')
    tvshow_release_year=$(echo "${tvshow}" | jq -r '.[].year')

    tvshow_poster=$(echo "${tvshow}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
    [[ -z ${tvshow_poster} ]] && tvshow_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/poster.png"

    tvshow_backdrop=$(echo "${tvshow}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/.jpg/_t.jpg/)
    [[ -z ${tvshow_backdrop} ]] && tvshow_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/backdrop.png"

    tvshow_genres=$(echo "${tvshow}" | jq -r '.[].genres | join(", ")')
    if [[ ${tvshow_genres} != "null" ]] && [[ -n ${tvshow_genres} ]]; then
        tvshow_genres_field='{"name": "Genres", "value": "'${tvshow_genres}'"},'
    fi

    tvshow_rating=$(echo "${tvshow}" | jq -r '.[].ratings.value')
    if [[ ${tvshow_rating} != "0" ]] && [[ -n ${tvshow_rating} ]]; then
        tvshow_rating_field='{"name": "Rating", "value": "'${tvshow_rating}'"},'
    fi

    DEFAULTIFS="${IFS}"
    IFS=','
    read -r -a episodes <<< "${sonarr_episodefile_episodenumbers}"
    IFS="${DEFAULTIFS}"

    for i in "${!episodes[@]}"; do
        episode=$(curl -fsSL --request GET "${HOST}:8989/api/v3/episode?seriesId=${tvshow_id}&apikey=${API_KEY}" | jq -r ".[] | select(.seasonNumber==${sonarr_episodefile_seasonnumber}) | select(.episodeNumber==${episodes[i]})")
        episode_file=$(curl -fsSL --request GET "${HOST}:8989/api/v3/episodefile?seriesId=${tvshow_id}&apikey=${API_KEY}" | jq -r ".[] | select(.id==$(echo "${episode}" | jq -r '.episodeFileId'))")

        episode_airdate=$(echo "${episode}" | jq -r '.airDate')
        episode_quality=$(echo "${episode_file}" | jq -r '.quality.quality.name')
        episode_video=$(echo "${episode_file}" | jq -r '.mediaInfo.videoCodec')
        episode_audio="$(echo "${episode_file}" | jq -r '.mediaInfo.audioCodec') $(echo "${episode_file}" | jq -r '.mediaInfo.audioChannels')"
        episode_size=$(PrettyPrintSize "$(echo "${episode_file}" | jq -r '.size')")

        episode_title=$(echo "${episode}" | jq -r '.title')
        if [[ ${episode_title} != "null" ]] && [[ -n ${episode_title} ]]; then
            episode_title_field='{"name": "Title", "value": "'${episode_title}'"},'
        fi

        episode_overview=$(echo "${episode}" | jq -r '.overview')
        if [[ ${episode_overview} != "null" ]] && [[ -n ${episode_overview} ]]; then
            [[ ${#episode_overview} -gt 300 ]] && dots="..."
            episode_overview_field='{"name": "Overview", "value": "'${episode_overview:0:300}${dots}'"},'
        fi

        episode_languages=$(echo "${episode_file}" | jq -r '.mediaInfo.audioLanguages')
        if [[ ${episode_languages} != "null" ]] && [[ -n ${episode_languages} ]]; then
            episode_languages_field=',{"name": "Languages", "value": "'${episode_languages}'"}'
        fi

        episode_subtitles=$(echo "${episode_file}" | jq -r '.mediaInfo.subtitles')
        if [[ ${episode_subtitles} != "null" ]] && [[ -n ${episode_subtitles} ]]; then
            episode_subtitles_field=',{"name": "Subtitles", "value": "'${episode_subtitles}'"}'
        fi

        episode_scene_name=$(echo "${episode_file}" | jq -r '.sceneName')
        if [[ ${episode_scene_name} != "null" ]] && [[ -n ${episode_scene_name} ]]; then
            episode_scene_name_field=',{"name": "Release", "value": "```'${episode_scene_name}'```"}'
        fi

        json='
        {
            "embeds":
                [
                    {
                        "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                        "title": "'${tvshow_title//([[:digit:]][[:digit:]][[:digit:]][[:digit:]])/}' ('${tvshow_release_year}')",
                        "url": "http://www.thetvdb.com/?tab=series&id='${sonarr_series_tvdbid}'",
                        "thumbnail": {"url": "'${tvshow_poster}'"},
                        "image": {"url": "'${tvshow_backdrop}'"},
                        "color": "'${COLOR}'",
                        "timestamp": "'${TIMESTAMP}'",
                        "fields":
                            [
                                {"name": "Episode", "value": "S'$(printf "%02d" "${sonarr_episodefile_seasonnumber}")'E'$(printf "%02d" "${episodes[i]}")'", "inline": true},
                                {"name": "Air Date", "value": "'${episode_airdate}'", "inline": true},
                                '${episode_title_field}'
                                '${episode_overview_field}'
                                '${tvshow_rating_field}'
                                '${tvshow_genres_field}'
                                {"name": "Quality", "value": "'${episode_quality}'", "inline": true},
                                {"name": "Codecs", "value": "'${episode_video}' / '${episode_audio}'", "inline": true},
                                {"name": "Size", "value": "'${episode_size}'", "inline": true}
                                '${episode_languages_field}'
                                '${episode_subtitles_field}'
                                '${episode_scene_name_field}'
                            ]
                    }
                ]
        }
        '
        curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
        sleep 5
    done
fi
