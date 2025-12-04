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
```json
{
    "content": "Hello, world!",
    "created": "2025-12-02T12:43:02.290Z",
    "signature": {
        "algorithm": "ed25519",
        "data": "gW3iRzFZ4C1znP0xC0m8tO7Qy0qfC9yCwkE7g0x0YgYV6Xq0rJb1CKt8H9uQO1rYqCq0H9i8+1Bf6wtZ+Q1yAg==",
    }
}
```

- `content` Must be the text of the message in the Markdown format
- `created` Is the time the message was created in the ISO 8601 format
- `signature.algorithm` Must be "ed25519"
- `signature.data` Must be the ed25519 signature of the message before the `signature` object is appended.

*That's it, so... why is it "Kinda Simple"?* Well it requires the message signature, which I will admit takes a bit of work to get right. The signature requirement can easily be solved with good tooling though. For example you could have a program that accepts a markdown text file as an argument and spits out the fully formatted message ready to be delivered to a friend or an audience on the internet.

*Isn't this a social protocol? How am I supposed to send memes and videos to my friends?* Yep, you can just include the links in the `content` markdown. Then it's up to the client to determine how they're rendered. They can be kept as links to the media on the internet, or they could appear inline with the message.

One other optional addition to the protocol is the references object:
```json
{
    "content": "[Aaron Hillel Swartz](https://en.wikipedia.org/wiki/Aaron_Swartz), also known as AaronSw, was an American computer programmer, entrepreneur, writer, political organizer, and Internet hacktivist.",
    "created": "2025-12-03T10:26:50.537Z",
    "references": {
        "https://en.wikipedia.org/wiki/Aaron_Swartz": "IXTqCQBJUG9xUCcd9BYE9y666AQ94orAg6itmSB84/jwFdUxOlMx1NhhR9QHzQiv5IGtpW9vX2q3sbOMu6TFdA==",
    },
    "signature": {
        "algorithm": "ed25519",
        "data": "gW3iRzFZ4C1znP0xC0m8tO7Qy0qfC9yCwkE7g0x0YgYV6Xq0rJb1CKt8H9uQO1rYqCq0H9i8+1Bf6wtZ+Q1yAg==",
    }
}
```

This is a way for clients to verify the contents of a link has not changed since the time the message was originally created. It's a way to ensure that images referenced in a message aren't edited later in time to skew the original meaning. This could be useful for government accounts or other accounts that have a legal responsibility. It is up to the client to determine how this is represented, it could display a warning that the content has changed or omit it entirely.

*What about resharing other peoples content?* You just include a link to the post you want to share in the message `content` it is up to the client to determine how this is represented.

*And Likes and Follows? I need to get my fix.* Well we've basically covered the full KSSM format. For likes and following we should probably talk about a Kinda Simple Social Protocol (KSSP).

## A Kinda Simple Social Protocol

This protocol defines how messages can be shared between servers and clients to their recipients. KSSP is built on top of HTTPS, it is a standardised collection of CRUD endpoints to keep track of users, their messages, followers and likes.

# Draft below this point

#### /$username/messages
- `GET` - List the messages authored by the user

#### /$username/messages/$id
- `GET` - Gets the specific message authored by the user

#### /$username/messages/$id/replies
- `GET` - Gets the replies for the specified message
- `POST` - Reply to the user's post

#### /$username/messages/$id/likes
- `POST` - Like the user's post TODO the payload

#### /$username/follow
- `POST` - Follow the user TODO the payload

#### /$username/key
- `GET` - Gets the public key of the user

#### /challenge
- `GET` - Gets a unique challenge that needs to be solved in order to POST content to the server. The challenge should only be valid for a short period of time e.g. 60 seconds.

```json
{
    "challenge": "aGFzbGRuYWxza25kYXNka2pua2puYXNka25h",
    "expiry": "2025-12-04T09:40:18.115Z"
}
```


the same ed25519 keys can generate a X25519 key pair which can be used to encrypt data. We can take advantage of this for DM's. Encrypt and base64 encode the content field and then send the message to the recipiant. now you have E2E encryption

no solution for LLM's slurping your data, if you want to put your thoughts on the public interenet then expect other companies to feed them into their LLMs