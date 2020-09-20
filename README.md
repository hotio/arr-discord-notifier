# arr-discord-notifier

Send pretty *arr notifications to discord (bundled with hotio docker images). Only Radarr/Sonarr V3 are supported/tested.

## Configuration

You should add the following `Connect` settings to Sonarr/Radarr. To your docker container you add the environment variable `DISCORD_WEBHOOK` with your webhook url provided by Discord. After that hit the `Test` button and you should see a notification appear in your discord channel. If you also configure the environment variable `TMDB_API_KEY`, if found it will use an episode still as backdrop image.

<img src="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/config.png" alt="Config Screenshot">
