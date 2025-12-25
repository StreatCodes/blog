---
title: Social Etiquette
description: Your social interactions should not be owned by a corporation
date: 3rd of December 2025
---

I don't think it needs to be stated that private companies owning large social networks is a bad idea. Companies *or individuals* should not have the power to influence huge groups of people. Especially if those companies belong to foreign nations. I think most people recognise this and want an alternative. People wanted to move off of X after Elon's Nazi salute (and even long before that) but there aren't really any great alternatives. 

Bluesky has a nice UI and it's a familiar experience, but at the end of the day it's still 99% developed and run by a single company. Mastodon is better in this regard, there are many different servers you can join but development and adoption has stagnated. A social protocol needs to be accessible in order to create a flourishing social network. The Activity Pub protocol that underpins Mastodon and the rest of the fediverse network is extremely cumbersome. It takes weeks to get even a rudimentary server implemented. The Mastodon implementation of Activity Pub is based on such a loose schema that it's almost impossible to create a meaningful integration. Creating your own server, client or tool would be a monumental task.

A social protocol needs to be accessible in order to gain adoption. So I came up with something that even a novice programmer could interact with and contribute to within hours.

![XKCD Standards [source](https://xkcd.com/927/)](/assets/social-etiquette/standards.png)

## A Kinda Simple Social Message format

This is the Kinda Simple Social Message (KSSM) format:
```
Signature: ed25519 gW3iRzFZ4C1znP0xC0m8tO7Qy0qfC9yCwkE7g0x0YgYV6Xq0rJb1CKt8H9uQO1rYqCq0H9i8+1Bf6wtZ+Q1yAg==
Created: 2025-12-02T12:43:02.290Z

Hello, world!
```

The protocol is a series line delimited (`\n`) headers and a body containing the message. The header fields are case insensitive. The headers in the above example are defined as followed:

- `Signature` - This header must come first, the first value is the algorithm and must be `ed25519` followed by the signature of the remaining content of the message.
- `Created` - Is the time the message was created in the ISO 8601 format

The Signature header must come first so it's easy to validate the message. The order of the remaining headers does not matter. The headers and body should be seperated with one empty new line. The only valid header fields are `Signature`, `Created` and `Reference`. A message containing an invalid header should be rejected.

*That's it, so... why is it "Kinda Simple"?* Well it requires the message signature, which I will admit takes a bit of work to get right. The signature requirement can easily be solved with good tooling though. For example you could have a program that accepts a markdown text file as an argument and spits out the fully formatted message ready to be delivered to a friend or an audience on the internet.

*Isn't this a social protocol? How am I supposed to send memes and videos to my friends?* Yep, you can just include the links in the markdown body. Then it's up to the client to determine how they're rendered. They can be kept as links to the media on the internet, or they could appear inline with the message.

One other optional addition to the protocol is the Reference header:
```
Signature: ed25519 gW3iRzFZ4C1znP0xC0m8tO7Qy0qfC9yCwkE7g0x0YgYV6Xq0rJb1CKt8H9uQO1rYqCq0H9i8+1Bf6wtZ+Q1yAg==
Created: 2025-12-03T10:26:50.537Z
Reference: https://en.wikipedia.org/wiki/Aaron_Swartz IXTqCQBJUG9xUCcd9BYE9y666AQ94orAg6itmSB84/jwFdUxOlMx1NhhR9QHzQiv5IGtpW9vX2q3sbOMu6TFdA==

[Aaron Hillel Swartz](https://en.wikipedia.org/wiki/Aaron_Swartz), also known as AaronSw, was an American computer programmer, entrepreneur, writer, political organizer, and Internet hacktivist.
```

This is a way for clients to verify the contents of a link has not changed since the time the message was originally created. It's a way to ensure that images referenced in a message aren't edited later in time to skew the original meaning. This could be useful for government accounts or other accounts that have a legal responsibility. It is up to the client to determine how this is represented, it could display a warning that the content has changed or omit it entirely. There can be multiple `Reference` headers if there are multiple references to external information that have their contents signed. e.g.

```
Reference: https://example.com/image1.png gW3iRzFZ4C1znP0xC0m8tO7Qy0qfC9yCwkE7g0x0YgYV6Xq0rJb1CKt8H9uQO1rYqCq0H9i8+1Bf6wtZ+Q1yAg==
Reference: https://example.com/image2.png IXTqCQBJUG9xUCcd9BYE9y666AQ94orAg6itmSB84/jwFdUxOlMx1NhhR9QHzQiv5IGtpW9vX2q3sbOMu6TFdA==
```

*What about resharing other peoples content?* You just include a link to the post you want to share in the message body, it is up to the client to determine how this is represented.

*And Likes and Follows? I need to get my fix.* Well we've basically covered the full KSSM format. For likes and following we should probably talk about a Kinda Simple Social Protocol (KSSP).

## A Kinda Simple Social Protocol

This protocol defines how messages can be shared between servers and clients to their recipients. KSSP is built on top of HTTPS, it is a standardised collection of CRUD endpoints to keep track of users, their messages, followers and likes. It is not a JSON API, most endpoints simply return test. If an endpoint is a list of messages then it will use the MIME Multipart format to seperate them.

#### User endpoints

- `/api/{username}/messages` - `POST`, `GET` - Create a new message or list the messages authored by the user. The multipart format should be used to list multiple messasges.
- `/api/{username}/messages/{id}` - `PATCH`, `GET`, `DELETE` - Get, create or delete the message
- `/api/{username}/key` - `GET` - Get the user's public key

#### Server endpoints

The server must prevent users from using the username "server" to prevent them from colliding with the following endpoints.

- `/api/server/challenge` - `GET` - Get a unique challenge that needs to be solved in order to POST, PATCH or DELETE content on the server. The challenge should only be valid for a short period of time e.g. 60 seconds. The response must include the `Challenge-Expires-At` header to indicate when the challenge expires. This is a random string of text that client needs to sign with their public key in order to interact with any of the other endpoints. The client needs to send the challenge and signature in the `Authorization` header when attempting to make requests to any of the user endpoints.
- `/api/server/capabilities` - `GET` - Get a comma seperated list of server capabilities. This is a reserved endpoint to allow clients and servers to determine what a server is capable of. In future `replies`, `follows`, `likes` may be supported, but right now this should just return 200 OK with an empty body.

## Future endevours

Obviously adding support for replying, following and liking is high priority. But the above is the most minimal version of the protocol. It's the minimun required for the most fundemental social sharing like blogging or a new website.

Another interesting topic to explore is direct messaging. The same ed25519 keys can generate a X25519 key pair which can be used to encrypt data. We could encrypt and base64 encode messages and submit them directly to another user instead of displaying them publicly. In cases where the user's private key is not stored on the server you would have E2E encryption

*What about my privacy or LLM's being trained on my data?* Unfortunetly if you want to put your thoughts on the public interenet then expect private companies to feed them into their LLMs. Whether they're scrapping HTML or hitting APIs to consume it, they will do it. 