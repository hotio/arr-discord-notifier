#!/bin/bash

global_exit_code=0

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

[[ -z ${API_KEY} ]]     && API_KEY=$(grep -oPm1 "(?<=<ApiKey>)[^<]+" "${CONFIG_DIR}/config.xml")
[[ -z ${API_KEY} ]]     && >&2 echo "No API_KEY could be found!" && exit 1
[[ -z ${API_HOST} ]]    && API_HOST=localhost
[[ -z ${AUTHOR_NAME} ]] && AUTHOR_NAME=${HOSTNAME}
[[ -z ${TIMESTAMP} ]]   && TIMESTAMP=$(date -u +'%FT%T.%3NZ')

if [[ ${1} == "Radarr" ]]; then
    radarr_eventtype="Test"
fi

if [[ ${1} == "Sonarr" ]]; then
    sonarr_eventtype="Test"
fi

if [[ ${radarr_eventtype^^} == "TEST" ]]; then
    COLOR="16761392"

    radarr_movie_tmdbid="$(curl -fsSL --request GET "${API_HOST}:7878/api/v3/movie?apikey=${API_KEY}" | jq -r '.[] | select(.hasFile==true) | .tmdbId' | shuf -n 1)"

    if [[ -n ${radarr_movie_tmdbid} ]]; then
        radarr_eventtype="Download"
        radarr_isupgrade="False"
    else
        radarr_movie_tmdbid="no movies found"
    fi

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                    "title": "Test succeeded!",
                    "description": "We were able to send to your webhook without any problems. Below you should see a sample notification for the movie `tmdb:'${radarr_movie_tmdbid}'`.",
                    "color": '${COLOR}',
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"

fi

if [[ ${sonarr_eventtype^^} == "TEST" ]]; then
    COLOR="2200501"

    sonarr_series_tvdbid="$(curl -fsSL --request GET "${API_HOST}:8989/api/v3/series?apikey=${API_KEY}" | jq -r '.[] | select(.statistics.episodeFileCount>2) | select(.statistics.percentOfEpisodes==100) | .tvdbId' | shuf -n 1)"

    if [[ -n ${sonarr_series_tvdbid} ]]; then
        sonarr_eventtype="Download"
        sonarr_isupgrade="False"
        sonarr_episodefile_seasonnumber="1"
        sonarr_episodefile_episodenumbers="1,2"
    else
        sonarr_series_tvdbid="no tv shows found"
    fi

    json='
    {
        "embeds":
            [
                {
                    "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                    "title": "Test succeeded!",
                    "description": "We were able to send to your webhook without any problems. Below you should see 2 sample notifications for the tv show `tvdb:'${sonarr_series_tvdbid}'`.",
                    "color": '${COLOR}',
                    "timestamp": "'${TIMESTAMP}'"
                }
            ]
    }
    '
    curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${DISCORD_WEBHOOK}"

fi

if [[ ${radarr_eventtype^^} == "DOWNLOAD" ]]; then
    webhooks=$(env | grep "^DISCORD_WEBHOOK")

    while IFS= read -r DISCORD_WEBHOOK; do
        webhook_url=$(sed "s#DISCORD_WEBHOOK.*=##" <<< "${DISCORD_WEBHOOK}")
        webhook_suffix=$(grep -o "DISCORD_WEBHOOK.*=" <<< "${DISCORD_WEBHOOK}" | sed s/=// | sed s/DISCORD_WEBHOOK//)
        drop_fields=$(env | grep "DROP_FIELDS${webhook_suffix}=" | sed "s/DROP_FIELDS${webhook_suffix}=//")

        COLOR="16761392"; [[ ${radarr_isupgrade} == "True" ]] && COLOR="7105644"

        movie="$(curl -fsSL --request GET "${API_HOST}:7878/api/v3/movie?tmdbId=${radarr_movie_tmdbid}&apikey=${API_KEY}")"
        movie_id=$(echo "${movie}" | jq -r '.[].id')

        # Poster
        movie_poster_field=""
        if [[ ${drop_fields} != *poster* ]]; then
            movie_poster=$(echo "${movie}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
            [[ -z ${movie_poster} ]] && movie_poster="https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/radarr/poster.png"
            grep "http" <<< ${movie_poster} && movie_poster_field='"thumbnail": {"url": "'${movie_poster}'"},'
        fi

        # Backdrop
        movie_backdrop_field=""
        if [[ ${drop_fields} != *backdrop* ]]; then
            movie_backdrop=$(echo "${movie}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/original/w500/)
            [[ -z ${movie_backdrop} ]] && movie_backdrop="https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/radarr/backdrop.png"
            grep "http" <<< ${movie_backdrop} && movie_backdrop_field='"image": {"url": "'${movie_backdrop}'"},'
        fi

        # Movie Name (Year)
        movie_title=$(echo "${movie}" | jq -r '.[].title')
        movie_release_year=$(echo "${movie}" | jq -r '.[].year')

        # URL
        if [[ -z ${EXTERNAL_URL} ]]; then
            movie_url="https://www.themoviedb.org/movie/${radarr_movie_tmdbid}"
        else
            movie_url="${EXTERNAL_URL}/movie/${radarr_movie_tmdbid}"
        fi

        # Overview
        movie_overview_field=""
        if [[ ${drop_fields} != *overview* ]]; then
            movie_overview=$(echo "${movie}" | jq '.[].overview')
            if [[ ${movie_overview} != "null" ]] && [[ -n ${movie_overview} ]]; then
                [[ ${#movie_overview} -gt 1026 ]] && movie_overview=${movie_overview:0:1022}'..."'
                movie_overview_field='{"name": "Overview", "value": '${movie_overview}'},'
            fi
        fi

        # Rating
        movie_rating_field=""
        if [[ ${drop_fields} != *rating* ]]; then
            movie_rating=$(echo "${movie}" | jq -r '.[].ratings.value')
            if [[ ${movie_rating} != "0" ]] && [[ -n ${movie_rating} ]]; then
                movie_rating_field='{"name": "Rating", "value": "'${movie_rating}'"},'
            fi
        fi

        # Genres
        movie_genres_field=""
        if [[ ${drop_fields} != *genres* ]]; then
            movie_genres=$(echo "${movie}" | jq -r '.[].genres | join(", ")')
            if [[ ${movie_genres} != "null" ]] && [[ -n ${movie_genres} ]]; then
                movie_genres_field='{"name": "Genres", "value": "'${movie_genres}'"},'
            fi
        fi

        # Cast
        movie_cast_field=""
        if [[ ${drop_fields} != *cast* ]]; then
            movie_cast=$(curl -fsSL --request GET "${API_HOST}:7878/api/v3/credit?movieId=${movie_id}&apikey=${API_KEY}" | jq -r '.[] | select(.type=="cast") | .personName' | head -n 8 | awk -vORS=', ' '{ print $0 }' | sed 's/, $/\n/')
            if [[ -n ${movie_cast} ]]; then
                movie_cast_field='{"name": "Cast", "value": "'${movie_cast}'"},'
            fi
        fi

        # Quality
        movie_quality_field=""
        if [[ ${drop_fields} != *quality* ]]; then
            movie_quality=$(echo "${movie}" | jq -r '.[].movieFile.quality.quality.name')
            if [[ ${movie_quality} != "null" ]] && [[ -n ${movie_quality} ]]; then
                movie_quality_field='{"name": "Quality", "value": "'${movie_quality}'", "inline": true},'
            fi
        fi

        # Codecs
        movie_codecs_field=""
        if [[ ${drop_fields} != *codecs* ]]; then
            movie_video=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.videoCodec')
            movie_audio="$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioCodec') $(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioChannels')"
            if [[ ${movie_video} != "null" ]] && [[ -n ${movie_video} ]]; then
                movie_codecs_field='{"name": "Codecs", "value": "'${movie_video}' / '${movie_audio}'", "inline": true},'
            fi
        fi

        # Size
        movie_size_field=""
        if [[ ${drop_fields} != *size* ]]; then
            movie_size=$(PrettyPrintSize "$(echo "${movie}" | jq -r '.[].movieFile.size')")
            movie_size_field='{"name": "Size", "value": "'${movie_size}'", "inline": true},'
        fi

        # Audio Languages
        movie_languages_field=""
        if [[ ${drop_fields} != *languages* ]] && [[ ${drop_fields} != *audio* ]]; then
            movie_languages=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.audioLanguages')
            if [[ ${movie_languages} != "null" ]] && [[ -n ${movie_languages} ]]; then
                movie_languages_field='{"name": "Audio", "value": "'${movie_languages}'", "inline": true},'
            fi
        fi

        # Subtitles
        movie_subtitles_field=""
        if [[ ${drop_fields} != *subtitles* ]]; then
            movie_subtitles=$(echo "${movie}" | jq -r '.[].movieFile.mediaInfo.subtitles')
            if [[ ${movie_subtitles} != "null" ]] && [[ -n ${movie_subtitles} ]]; then
                movie_subtitles_field='{"name": "Subtitles", "value": "'${movie_subtitles}'", "inline": true},'
            fi
        fi

        # Links
        movie_links_field=""
        if [[ ${drop_fields} != *links* ]]; then
            movie_links="[TMDb](https://www.themoviedb.org/movie/${radarr_movie_tmdbid}) / [Trakt](https://trakt.tv/search/tmdb/${radarr_movie_tmdbid}?id_type=movie)"
            movie_link_imdb=$(echo "${movie}" | jq -r '.[].imdbId')
            if [[ ${movie_link_imdb} != "null" ]] && [[ -n ${movie_link_imdb} ]]; then
                movie_links="${movie_links} / [IMDb](https://www.imdb.com/title/${movie_link_imdb}) / [Movie Chat](https://moviechat.org/${movie_link_imdb})"
            fi
            movie_link_youtube=$(echo "${movie}" | jq -r '.[].youTubeTrailerId')
            if [[ ${movie_link_youtube} != "null" ]] && [[ -n ${movie_link_youtube} ]]; then
                movie_links="${movie_links} / [YouTube](https://www.youtube.com/watch?v=${movie_link_youtube})"
            fi
            movie_link_website=$(echo "${movie}" | jq -r '.[].website')
            if [[ ${movie_link_website} != "null" ]] && [[ -n ${movie_link_website} ]]; then
                movie_links="${movie_links} / [Website](${movie_link_website})"
            fi
            movie_links_field='{"name": "Links", "value": "'${movie_links}'"},'
        fi

        # Release
        movie_scene_name_field=""
        if [[ ${drop_fields} != *release* ]]; then
            movie_scene_name=$(echo "${movie}" | jq -r '.[].movieFile.sceneName')
            if [[ ${movie_scene_name} != "null" ]] && [[ -n ${movie_scene_name} ]]; then
                movie_scene_name_field='{"name": "Release", "value": "```'${movie_scene_name}'```"},'
            fi
        fi

        movie_fields="${movie_overview_field}${movie_rating_field}${movie_genres_field}${movie_cast_field}${movie_quality_field}${movie_codecs_field}${movie_size_field}${movie_languages_field}${movie_subtitles_field}${movie_links_field}${movie_scene_name_field}"
        movie_fields=$(sed 's/,$//' <<< "${movie_fields}")
        [[ -n ${movie_fields} ]] && movie_fields=',"fields":['${movie_fields}']'

        json='
        {
            "embeds":
                [
                    {
                        "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                        "title": "'${movie_title}' ('${movie_release_year}')",
                        "url": "'${movie_url}'",
                        '${movie_poster_field}'
                        '${movie_backdrop_field}'
                        "color": '${COLOR}',
                        "timestamp": "'${TIMESTAMP}'"
                        '${movie_fields}'
                    }
                ]
        }
        '
        curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${webhook_url}"
        exit_code=$?

        if [[ ${exit_code} -gt 0 ]]; then
            >&2 echo "Something went wrong trying to send a notification for movie tmdb:${radarr_movie_tmdbid}."
            >&2 echo "${json}"
            COLOR="15746887"

            json='
            {
                "embeds":
                    [
                        {
                            "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/radarr/logo.png"},
                            "title": "Failure!",
                            "description": "Something went wrong trying to send a notification for movie `tmdb:'${radarr_movie_tmdbid}'`.",
                            "color": '${COLOR}',
                            "timestamp": "'${TIMESTAMP}'"
                        }
                    ]
            }
            '
            curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${webhook_url}"
            global_exit_code=$((global_exit_code + exit_code))
        fi

    done < <(printf '%s\n' "$webhooks")
fi

if [[ ${sonarr_eventtype^^} == "DOWNLOAD" ]]; then
    webhooks=$(env | grep "^DISCORD_WEBHOOK")

    while IFS= read -r DISCORD_WEBHOOK; do
        webhook_url=$(sed "s#DISCORD_WEBHOOK.*=##" <<< "${DISCORD_WEBHOOK}")
        webhook_suffix=$(grep -o "DISCORD_WEBHOOK.*=" <<< "${DISCORD_WEBHOOK}" | sed s/=// | sed s/DISCORD_WEBHOOK//)
        drop_fields=$(env | grep "DROP_FIELDS${webhook_suffix}=" | sed "s/DROP_FIELDS${webhook_suffix}=//")

        COLOR="2200501"; [[ ${sonarr_isupgrade} == "True" ]] && COLOR="7105644"

        tvshow="$(curl -fsSL --request GET "${API_HOST}:8989/api/v3/series?tvdbId=${sonarr_series_tvdbid}&apikey=${API_KEY}")"
        tvshow_id=$(echo "${tvshow}" | jq -r '.[].id')

        # Poster
        tvshow_poster_field=""
        if [[ ${drop_fields} != *poster* ]]; then
            tvshow_poster=$(echo "${tvshow}" | jq -r '.[].images[] | select(.coverType=="poster") | .remoteUrl')
            [[ -z ${tvshow_poster} ]] && tvshow_poster="https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/sonarr/poster.png"
            grep "http" <<< ${tvshow_poster} && tvshow_poster_field='"thumbnail": {"url": "'${tvshow_poster}'"},'
        fi

        # Backdrop
        tvshow_backdrop_field=""
        if [[ ${drop_fields} != *backdrop* ]]; then
            tvshow_backdrop=$(echo "${tvshow}" | jq -r '.[].images[] | select(.coverType=="fanart") | .remoteUrl' | sed s/.jpg/_t.jpg/)
            [[ -z ${tvshow_backdrop} ]] && tvshow_backdrop="https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/sonarr/backdrop.png"
            grep "http" <<< ${tvshow_backdrop} && tvshow_backdrop_field='"image": {"url": "'${tvshow_backdrop}'"},'
        fi

        # TV Show Name (Year)
        tvshow_title=$(echo "${tvshow}" | jq -r '.[].title')
        tvshow_release_year=$(echo "${tvshow}" | jq -r '.[].year')

        # URL
        if [[ -z ${EXTERNAL_URL} ]]; then
            tvshow_url="http://www.thetvdb.com/?tab=series&id=${sonarr_series_tvdbid}"
        else
            tvshow_title_slug=$(echo "${tvshow}" | jq -r '.[].titleSlug')
            tvshow_url="${EXTERNAL_URL}/series/${tvshow_title_slug}"
        fi

        # Rating
        tvshow_rating_field=""
        if [[ ${drop_fields} != *rating* ]]; then
            tvshow_rating=$(echo "${tvshow}" | jq -r '.[].ratings.value')
            if [[ ${tvshow_rating} != "0" ]] && [[ -n ${tvshow_rating} ]]; then
                tvshow_rating_field='{"name": "Rating", "value": "'${tvshow_rating}'"},'
            fi
        fi

        # Genres
        tvshow_genres_field=""
        if [[ ${drop_fields} != *genres* ]]; then
            tvshow_genres=$(echo "${tvshow}" | jq -r '.[].genres | join(", ")')
            if [[ ${tvshow_genres} != "null" ]] && [[ -n ${tvshow_genres} ]]; then
                tvshow_genres_field='{"name": "Genres", "value": "'${tvshow_genres}'"},'
            fi
        fi

        # Cast
        tvshow_cast_field=""
        if [[ ${drop_fields} != *cast* ]]; then
            if [[ -n ${TMDB_API_KEY} ]]; then
                tvshow_tmdbid="$(curl -fsSL "https://api.themoviedb.org/3/find/${sonarr_series_tvdbid}?api_key=${TMDB_API_KEY}&external_source=tvdb_id" | jq -r '.tv_results[0].id')"
                if [[ ${tvshow_tmdbid} != null ]]; then
                    tvshow_cast="$(curl -fsSL "https://api.themoviedb.org/3/tv/${tvshow_tmdbid}/credits?api_key=${TMDB_API_KEY}" | jq -r '.cast[].name' | head -n 8 | awk -vORS=', ' '{ print $0 }' | sed 's/, $/\n/')"
                    if [[ -n ${tvshow_cast} ]]; then
                        tvshow_cast_field='{"name": "Cast", "value": "'${tvshow_cast}'"},'
                    fi
                fi
            fi
        fi

        # Links
        tvshow_links_field=""
        if [[ ${drop_fields} != *links* ]]; then
            tvshow_links="[TVDb](http://www.thetvdb.com/?tab=series&id=${sonarr_series_tvdbid}) / [Trakt](http://trakt.tv/search/tvdb/${sonarr_series_tvdbid}?id_type=show)"
            tvshow_link_imdb=$(echo "${tvshow}" | jq -r '.[].imdbId')
            if [[ ${tvshow_link_imdb} != "null" ]] && [[ -n ${tvshow_link_imdb} ]]; then
                tvshow_links="${tvshow_links} / [IMDb](https://www.imdb.com/title/${tvshow_link_imdb})"
            fi
            tvshow_link_tvmaze=$(echo "${tvshow}" | jq -r '.[].tvMazeId')
            if [[ ${tvshow_link_tvmaze} != "null" ]] && [[ -n ${tvshow_link_tvmaze} ]]; then
                tvshow_links="${tvshow_links} / [TV Maze](http://www.tvmaze.com/shows/${tvshow_link_tvmaze}/_)"
            fi
            tvshow_links_field='{"name": "Links", "value": "'${tvshow_links}'"},'
        fi

        DEFAULTIFS="${IFS}"
        IFS=','
        read -r -a episodes <<< "${sonarr_episodefile_episodenumbers}"
        IFS="${DEFAULTIFS}"

        for i in "${!episodes[@]}"; do
            episode=$(curl -fsSL --request GET "${API_HOST}:8989/api/v3/episode?seriesId=${tvshow_id}&apikey=${API_KEY}" | jq -r ".[] | select(.seasonNumber==${sonarr_episodefile_seasonnumber}) | select(.episodeNumber==${episodes[i]})")
            episode_file=$(curl -fsSL --request GET "${API_HOST}:8989/api/v3/episodefile?seriesId=${tvshow_id}&apikey=${API_KEY}" | jq -r ".[] | select(.id==$(echo "${episode}" | jq -r '.episodeFileId'))")

            # Air Date
            episode_airdate_field=""
            if [[ ${drop_fields} != *airdate* ]]; then
                episode_airdate=$(echo "${episode}" | jq -r '.airDate')
                episode_airdate_field='{"name": "Air Date", "value": "'${episode_airdate}'"},'
            fi

            # Title
            episode_title_field=""
            if [[ ${drop_fields} != *title* ]]; then
                episode_title=$(echo "${episode}" | jq '.title')
                if [[ ${episode_title} != "null" ]] && [[ -n ${episode_title} ]]; then
                    episode_title_field='{"name": "Title", "value": '${episode_title}'},'
                fi
            fi

            # Overview
            episode_overview_field=""
            if [[ ${drop_fields} != *overview* ]]; then
                episode_overview=$(echo "${episode}" | jq '.overview')
                if [[ ${episode_overview} != "null" ]] && [[ -n ${episode_overview} ]]; then
                    [[ ${#episode_overview} -gt 1026 ]] && episode_overview=${episode_overview:0:1022}'..."'
                    episode_overview_field='{"name": "Overview", "value": '${episode_overview}'},'
                fi
            fi

            # Quality
            episode_quality_field=""
            if [[ ${drop_fields} != *quality* ]]; then
                episode_quality=$(echo "${episode_file}" | jq -r '.quality.quality.name')
                if [[ ${episode_quality} != "null" ]] && [[ -n ${episode_quality} ]]; then
                    episode_quality_field='{"name": "Quality", "value": "'${episode_quality}'", "inline": true},'
                fi
            fi

            # Codecs
            episode_codecs_field=""
            if [[ ${drop_fields} != *codecs* ]]; then
                episode_video=$(echo "${episode_file}" | jq -r '.mediaInfo.videoCodec')
                episode_audio="$(echo "${episode_file}" | jq -r '.mediaInfo.audioCodec') $(echo "${episode_file}" | jq -r '.mediaInfo.audioChannels')"
                if [[ ${episode_video} != "null" ]] && [[ -n ${episode_video} ]]; then
                    episode_codecs_field='{"name": "Codecs", "value": "'${episode_video}' / '${episode_audio}'", "inline": true},'
                fi
            fi

            # Size
            episode_size_field=""
            if [[ ${drop_fields} != *size* ]]; then
                episode_size=$(PrettyPrintSize "$(echo "${episode_file}" | jq -r '.size')")
                episode_size_field='{"name": "Size", "value": "'${episode_size}'", "inline": true},'
            fi

            # Audio Languages
            episode_languages_field=""
            if [[ ${drop_fields} != *languages* ]] && [[ ${drop_fields} != *audio* ]]; then
                episode_languages=$(echo "${episode_file}" | jq -r '.mediaInfo.audioLanguages')
                if [[ ${episode_languages} != "null" ]] && [[ -n ${episode_languages} ]]; then
                    episode_languages_field='{"name": "Audio", "value": "'${episode_languages}'", "inline": true},'
                fi
            fi

            # Subtitles
            episode_subtitles_field=""
            if [[ ${drop_fields} != *subtitles* ]]; then
                episode_subtitles=$(echo "${episode_file}" | jq -r '.mediaInfo.subtitles')
                if [[ ${episode_subtitles} != "null" ]] && [[ -n ${episode_subtitles} ]]; then
                    episode_subtitles_field='{"name": "Subtitles", "value": "'${episode_subtitles}'", "inline": true},'
                fi
            fi

            # Release
            episode_scene_name_field=""
            if [[ ${drop_fields} != *release* ]]; then
                episode_scene_name=$(echo "${episode_file}" | jq -r '.sceneName')
                if [[ ${episode_scene_name} != "null" ]] && [[ -n ${episode_scene_name} ]]; then
                    episode_scene_name_field='{"name": "Release", "value": "```'${episode_scene_name}'```"},'
                fi
            fi

            # Episode Still if found
            if [[ ${drop_fields} != *backdrop* ]]; then
                if [[ -n ${TMDB_API_KEY} ]]; then
                    tvshow_tmdbid="$(curl -fsSL "https://api.themoviedb.org/3/find/${sonarr_series_tvdbid}?api_key=${TMDB_API_KEY}&external_source=tvdb_id" | jq -r '.tv_results[0].id')"
                    if [[ ${tvshow_tmdbid} != null ]]; then
                        episode_still="$(curl -fsSL "https://api.themoviedb.org/3/tv/${tvshow_tmdbid}/season/${sonarr_episodefile_seasonnumber}/episode/${episodes[i]}?api_key=${TMDB_API_KEY}" | jq -r .still_path)"
                        if [[ ${episode_still} != null ]]; then
                            tvshow_backdrop="https://image.tmdb.org/t/p/w500${episode_still}"
                            tvshow_backdrop_field='"image": {"url": "'${tvshow_backdrop}'"},'
                        fi
                    fi
                fi
            fi

            tvshow_fields="${episode_airdate_field}${episode_title_field}${episode_overview_field}${tvshow_rating_field}${tvshow_genres_field}${tvshow_cast_field}${episode_quality_field}${episode_codecs_field}${episode_size_field}${episode_languages_field}${episode_subtitles_field}${tvshow_links_field}${episode_scene_name_field}"
            tvshow_fields=$(sed 's/,$//' <<< "${tvshow_fields}")
            [[ -n ${tvshow_fields} ]] && tvshow_fields=',"fields":['${tvshow_fields}']'

            json='
            {
                "embeds":
                    [
                        {
                            "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                            "title": "'${tvshow_title//([[:digit:]][[:digit:]][[:digit:]][[:digit:]])/}' ('${tvshow_release_year}') - S'$(printf "%02d" "${sonarr_episodefile_seasonnumber}")'E'$(printf "%02d" "${episodes[i]}")'",
                            "url": "'${tvshow_url}'",
                            '${tvshow_poster_field}'
                            '${tvshow_backdrop_field}'
                            "color": '${COLOR}',
                            "timestamp": "'${TIMESTAMP}'"
                            '${tvshow_fields}'
                        }
                    ]
            }
            '
            curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${webhook_url}"
            exit_code=$?

            if [[ ${exit_code} -gt 0 ]]; then
                >&2 echo "Something went wrong trying to send a notification for tv show tvdb:${sonarr_series_tvdbid}, s${sonarr_episodefile_seasonnumber}e${episodes[i]}."
                >&2 echo "${json}"
                COLOR="15746887"

                json='
                {
                    "embeds":
                        [
                            {
                                "author": {"name": "'${AUTHOR_NAME}'", "icon_url": "https://raw.githubusercontent.com/docker-hotio/arr-discord-notifier/master/img/sonarr/logo.png"},
                                "title": "Failure!",
                                "description": "Something went wrong trying to send a notification for tv show `tvdb:'${sonarr_series_tvdbid}', s'${sonarr_episodefile_seasonnumber}'e'${episodes[i]}'`.",
                                "color": '${COLOR}',
                                "timestamp": "'${TIMESTAMP}'"
                            }
                        ]
                }
                '
                curl -fsSL -X POST -H "Content-Type: application/json" -d "${json}" "${webhook_url}"
                global_exit_code=$((global_exit_code + exit_code))
            fi

            sleep 5
        done

    done < <(printf '%s\n' "$webhooks")
fi

exit ${global_exit_code}
