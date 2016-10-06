Improvements for update-tool-cron.sh:

- better handling of git errors, like merge conflicts
- support branches
- remove dependency on y2m (we can directly call git pull)
- add a mode where a single yast module/text domain can be updated
