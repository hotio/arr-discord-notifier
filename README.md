# arr-discord-notifier

Send pretty *arr notifications to discord (bundled with hotio docker images). Only Radarr/Sonarr V3 are supported/tested.

## Configuration

Add a `Custom Script` to the `Connect` settings in Sonarr/Radarr as seen below.  

Then add the environment variable `DISCORD_WEBHOOK` with your webhook url provided by Discord to the container. After that hit the `Test` button and you should see a notification appear in your discord channel.  

If you also configure the environment variable `TMDB_API_KEY`, when possible it will use an episode still as a backdrop image. If you want to hide some fields, you can use `DROP_FIELDS="backdrop overview release airdate"` as a variable, all field names in lowercase, `backdrop` and `poster` are valid values.

<img src="https://raw.githubusercontent.com/hotio/arr-discord-notifier/master/img/config.png" alt="Config Screenshot" width=600>
