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

API_KEY=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "${CONFIG_DIR}/app/config.xml")
TIMESTAMP=$(date -u --iso-8601=seconds)

if [[ ${1} == "Radarr" ]]; then
    radarr_eventtype="Download"
    radarr_movie_tmdbid="612706"
    radarr_isupgrade="False"
fi

if [[ ${1} == "Sonarr" ]]; then
    sonarr_eventtype="Download"
    sonarr_series_tvdbid="268592"
    sonarr_isupgrade="True"
    sonarr_episodefile_seasonnumber="1"
    sonarr_episodefile_episodenumbers="1,2"
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
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
fi

if [[ ${radarr_eventtype} == "Download" ]]; then
    COLOR="16761392"; [[ ${radarr_isupgrade} == "True" ]] && COLOR="7105644"

    json="$(curl -fsSL --request GET "localhost:7878/api/v3/movie?tmdbId=${radarr_movie_tmdbid}&apikey=${API_KEY}")"

    movie_title=$(echo "${json}" | jq -r '.[].title')
    movie_release_year=$(echo "${json}" | jq -r '.[].year')

    movie_poster=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
    [[ -z ${movie_poster} ]] && movie_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/poster.png"

    movie_backdrop=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/original/w500/)
    [[ -z ${movie_backdrop} ]] && movie_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/radarr/backdrop.png"

    movie_overview=$(echo "${json}" | jq -r '.[].overview')
    if [[ ${movie_overview} != "null" ]] && [[ -n ${movie_overview} ]]; then
        [[ ${#movie_overview} -gt 300 ]] && dots="..."
        movie_overview_field='{"name": "Overview", "value": "'${movie_overview:0:300}${dots}'"},'
    fi

    movie_genres=$(echo "${json}" | jq -r '.[].genres | join(", ")')
    if [[ ${movie_genres} != "null" ]] && [[ -n ${movie_genres} ]]; then
        movie_genres_field='{"name": "Genres", "value": "'${movie_genres}'"},'
    fi

    movie_rating=$(echo "${json}" | jq -r '.[].ratings.value')
    if [[ ${movie_rating} != "0" ]] && [[ -n ${movie_rating} ]]; then
        movie_rating_field='{"name": "Rating", "value": "'${movie_rating}'"},'
    fi

    movie_scene_name=$(echo "${json}" | jq -r '.[].movieFile.sceneName')
    if [[ ${movie_scene_name} != "null" ]] && [[ -n ${movie_scene_name} ]]; then
        movie_scene_name_field=',{"name": "Release", "value": "```'${movie_scene_name}'```"}'
    fi

    movie_quality=$(echo "${json}" | jq -r '.[].movieFile.quality.quality.name')
    movie_video=$(echo "${json}" | jq -r '.[].movieFile.mediaInfo.videoCodec')
    movie_audio="$(echo "${json}" | jq -r '.[].movieFile.mediaInfo.audioCodec') $(echo "${json}" | jq -r '.[].movieFile.mediaInfo.audioChannels')"

    movie_subtitles=$(echo "${json}" | jq -r '.[].movieFile.mediaInfo.subtitles')
    if [[ ${movie_subtitles} != "null" ]] && [[ -n ${movie_subtitles} ]]; then
        movie_subtitles_field=',{"name": "Subtitles", "value": "'${movie_subtitles}'"}'
    fi

    movie_languages=$(echo "${json}" | jq -r '.[].movieFile.mediaInfo.audioLanguages')
    if [[ ${movie_languages} != "null" ]] && [[ -n ${movie_languages} ]]; then
        movie_languages_field=',{"name": "Languages", "value": "'${movie_languages}'"}'
    fi

    movie_size=$(PrettyPrintSize "$(echo "${json}" | jq -r '.[].movieFile.size')")

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

if [[ ${sonarr_eventtype} == "Test" ]]; then
    COLOR="2200501"

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                    "title": "Test succeeded!",
                    "color": "'${COLOR}'",
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"
fi

if [[ ${sonarr_eventtype} == "Download" ]]; then
    COLOR="2200501"; [[ ${sonarr_isupgrade} == "True" ]] && COLOR="7105644"

    json="$(curl -fsSL --request GET "localhost:8989/api/v3/series/lookup?term=tvdb:${sonarr_series_tvdbid}&apikey=${API_KEY}")"
    tv_title=$(echo "${json}" | jq -r '.[].title')
    tv_release_year=$(echo "${json}" | jq -r '.[].year')
    tv_id=$(echo "${json}" | jq -r '.[].id')

    tv_poster=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
    [[ -z ${tv_poster} ]] && tv_poster="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/poster.png"

    tv_backdrop=$(echo "${json}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/.jpg/_t.jpg/)
    [[ -z ${tv_backdrop} ]] && tv_backdrop="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/backdrop.png"

    tv_genres=$(echo "${json}" | jq -r '.[].genres | join(", ")')
    if [[ ${tv_genres} != "null" ]] && [[ -n ${tv_genres} ]]; then
        tv_genres_field='{"name": "Genres", "value": "'${tv_genres}'"},'
    fi

    tv_rating=$(echo "${json}" | jq -r '.[].ratings.value')
    if [[ ${tv_rating} != "0" ]] && [[ -n ${tv_rating} ]]; then
        tv_rating_field='{"name": "Rating", "value": "'${tv_rating}'"},'
    fi

    DEFAULTIFS="${IFS}"
    IFS=','
    read -r -a episodes <<< "${sonarr_episodefile_episodenumbers}"
    IFS="${DEFAULTIFS}"

    for i in "${!episodes[@]}"; do
        episode=$(curl -fsSL --request GET "localhost:8989/api/v3/episode?seriesId=${tv_id}&apikey=${API_KEY}" | jq -r ".[] | select(.seasonNumber==${sonarr_episodefile_seasonnumber}) | select(.episodeNumber==${episodes[i]})")

        episode_title=$(echo "${episode}" | jq -r '.title')
        if [[ ${episode_title} != "null" ]] && [[ -n ${episode_title} ]]; then
            episode_title_field='{"name": "Title", "value": "'${episode_title}'"},'
        fi

        episode_overview=$(echo "${episode}" | jq -r '.overview')
        if [[ ${episode_overview} != "null" ]] && [[ -n ${episode_overview} ]]; then
            [[ ${#episode_overview} -gt 300 ]] && dots="..."
            episode_overview_field='{"name": "Overview", "value": "'${episode_overview:0:300}${dots}'"},'
        fi

        episode_airdate=$(echo "${episode}" | jq -r '.airDate')
        episode_file_id=$(echo "${episode}" | jq -r '.episodeFileId')
        episode_file=$(curl -fsSL --request GET "localhost:8989/api/v3/episodefile?seriesId=${tv_id}&apikey=${API_KEY}")

        episode_scene_name=$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .sceneName")
        if [[ ${episode_scene_name} != "null" ]] && [[ -n ${episode_scene_name} ]]; then
            episode_scene_name_field=',{"name": "Release", "value": "```'${episode_scene_name}'```"}'
        fi

        episode_quality=$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .quality.quality.name")
        episode_video=$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .mediaInfo.videoCodec")
        episode_audio="$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .mediaInfo.audioCodec") $(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .mediaInfo.audioChannels")"

        episode_subtitles=$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .mediaInfo.subtitles")
        if [[ ${episode_subtitles} != "null" ]] && [[ -n ${episode_subtitles} ]]; then
            episode_subtitles_field=',{"name": "Subtitles", "value": "'${episode_subtitles}'"}'
        fi

        episode_languages=$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .mediaInfo.audioLanguages")
        if [[ ${episode_languages} != "null" ]] && [[ -n ${episode_languages} ]]; then
            episode_languages_field=',{"name": "Languages", "value": "'${episode_languages}'"}'
        fi

        episode_size=$(PrettyPrintSize "$(echo "${episode_file}" | jq -r ".[] | select(.id==${episode_file_id}) | .size")")

        json='
        {
            "embeds":
                [
                    {
                        "author": {"name": "'$HOSTNAME'", "icon_url": "https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                        "title": "'${tv_title//([[:digit:]][[:digit:]][[:digit:]][[:digit:]])/}' ('${tv_release_year}')",
                        "url": "http://www.thetvdb.com/?tab=series&id='${sonarr_series_tvdbid}'",
                        "thumbnail": {"url": "'${tv_poster}'"},
                        "image": {"url": "'${tv_backdrop}'"},
                        "color": "'${COLOR}'",
                        "timestamp": "'${TIMESTAMP}'",
                        "fields":
                            [
                                {"name": "Episode", "value": "S'$(printf "%02d" "${sonarr_episodefile_seasonnumber}")'E'$(printf "%02d" "${episodes[i]}")'", "inline": true},
                                {"name": "Air Date", "value": "'${episode_airdate}'", "inline": true},
                                '${episode_title_field}'
                                '${episode_overview_field}'
                                '${tv_rating_field}'
                                '${tv_genres_field}'
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
    done
fi
