---
title: Meta Gaming
description: Reverse engineering a game network protocol
date: 17th of February 2025
---

Most evenings when I was in years 6 and 7 I'd come home from school and log into an MMORPG. This game (which I will not name) is super grindy, you basically progress by killing monsters repeatably. It's also super pay to win, for instance you can upgrade each item you equip 10 times, each time it's significantly less likely the upgrade will succeed. These upgrade items drop from monsters, however if the upgrade fails there's a chance your equipment will break. To prevent the equipment from breaking you have to use an additional item which can only be purchased with real money or from other players in game who have paid for this item and are selling it for in game currency. Regardless of this terrible monitization strategy I still enjoyed the game growing up. I stopped playing back in early high school and the games player base gradually died down. Fast forward 10 years and a whole rework of the game has been released. They've compiled the game to web assembly and added some glue code so it renders in the browser and all the input events and networking works. They also fixed a bunch of bugs and it has completely revived the game, you can run through the towns and hundreds of people are running around and selling items.

I started playing again for a bit of fun when they re-released the game and was enjoying the nostalgia hit. However it slowly wore off as I realised the amount of grinding that's required to level up and gross advantage people pouring money into the game had. Then I started wondering how they'd managed to get the game running in the browser. They'd done a really good job, textures get streamed as needed to the client, they just briefly appear white and fade in. There aren't any huge lag spikes when entering areas with large crowds, which used to be an issue in the original game. They also aggressively cache assets in the CDN and in your browser so you don't have to redownload parts of the game often, honestly you can register and play in like 30 seconds.

This got me curious so set out to see how it all works under the hood, I'm sure a professional developer of 10 years can pull out a few nifty tricks for a small advantage. Well a big advantage, I wanted to build a bot that was extremely hard to detect, just by intercepting network traffic and sending commands to the server. I started referring to building a bot as 'Meta gaming' because I was no longer playing the game, yet finding more enjoyment in the new task at hand. Turns out there were a number of counter measures to prevent this kind of behaviour.

Firstly, the moment you open the developer tools you get locked into an infinite loop of `debugger` statements:

![Debugger stuck in an infinite loop](/assets/meta-gaming/debugger-trap.png)

After pressing the continue button the browser immediately pauses again with the same result. This prevents you from looking at how the game works while it's running. Disabling breakpoint is a quick hack to get around this. The call stack on the right allows you to navigate to the code responsible for this annoying behaviour, more on this in a moment. Chrome and Firefox have a cool feature where you can intercept network requests coming from the server and serve your own equivalent file from your computer. This allows me to modify the javascript files locally so I can start changing how things work:

![Override files so they can be modified](/assets/meta-gaming/override-files.png)

Chrome sets up all the directories for you when you mark a file as 'Overridden'. In the screenshot is the `play` file which is basically an `index.html`, this contains all the bootstrapping code required to run the game. This file is saved on my hard drive and I can now modify it at will. The commented code on the right is some obfuscated code that modifies the browsers built in `console` object, which impacts logging to the console to debug things. At this point I had also disable the code that spams us with `debugger` statements, the next issue is code that maxes out the CPU when developer tools are open.

![CPU maxed out caused by regex denial of service](/assets/meta-gaming/cpu-maxed.png)

I can't actually remember how I found the cause of this, I may have just recognised the regex attack when browsing the code. Chrome handles this a lot better and the tab doesn't completely become unusable. Deleting that obfuscated function call with the obvious `(((.+)+)+)+` string solves this problem. Now all the immediate issues are out of the way and we can start poking around.

My goal of the bot is pretty basic:

- Automatically use healing items when my health goes below a certain threshold
- Automatically attack the closest mob until it's dead
- Don't stray too far from a certain location
- Maybe add some natural movement so it's not so obvious it's a bot running

I took a look at the network tab and found the websocket used for realtime communications from the server.

![Chrome websocket traffic for the game](/assets/meta-gaming/network-traffic.png)

This is what the raw network traffic looks like, one thing that's immediately obvious is there is a message identifier at the start of the packet. `1F` is used to delineate sent packets, `B8` is used for received (from the clients perspective). Following this is the message type a 32 bit little endian integer `216` in this case. I've linked up some useful id's as followed:

- received `24` - health/mana regenerate
- received `98` - damage dealt
- received `54` - mob moving to new location
- sent `12` - use item
- sent `39` - target mob

`54` is useful as I can see where all the monsters are moving around me and their ID's. `98` can be used to track damage my character receive and the monsters I'm attacking. `39` can be used to target monsters to attack and `12` to automatically use health items when necessary. It's worth noting that there is no key a user can press to target monsters automatically, also it would likely be easily detectable if I generated fake keyboard events to control the character. From what I could tell; programatically generated keyboard events can easily be differentiated from hardware events for security reasons within the browser. Regardless you get much more control and precision from network commands. To start decoding these messages I logged a bunch of them and started looking for patterns within them, it became clear pretty quick that the messages were encoded somehow, encryption maybe? Well... kinda... the messages are [XOR](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_XOR)'d, this is a pretty poor attempt at hiding the underlying data and if real encryption was used I would have had a lot more trouble. I basically stared at columns of hex for hours until I noticed reoccurring patterns:

![Noticeable patterns in hex data](/assets/meta-gaming/hex-pattern.png)

The highlighted columns are 32 bytes apart and I suspected that each of those numbers were actually supposed to be `0`. Additionally much of the data was the same line after line which indicates that there isn't any decent encryption with a proper Nonce at play. I then started to figure out which column corresponded to certain actions. I used an item in my inventory which had a stack of 40, then again at 39 and 38 and tracked which parts of the messages were changing. Once I identified the offset of the item count it meant I had the encoded hex value that gets sent to the server and the real value visible in my characters inventory. I then wrote a script that to find the key used to encode the real value before it gets sent to the server:

```javascript
const result = 40;
const hex = "1506d370";
const value = Number(`0x${reverseHex(hex)}`); //convert to big-endian

for (let i = 0; i < 4294967295; i++) {
  if ((value ^ i) === result) {
    const hexed = i.toString(16);
    console.log("xor key", i, hexed);
    break;
  }
}
```

There is probably some mathematical way to do this in one operation but I'm not Terrance Toa so who knows. At this point it's worth mentioning the architecture of this game. The server is the ultimate truth, I can't just send a message to the server saying 'pickup 1,000,000 gold from here` because the server knows that there is no gold there; so it's not going to allow my request. Secondly, the javascript portion of this application is very minimal, messages flow two and from the wasm binary through javascript only out of necessity. Game client ([wasm binary](https://developer.mozilla.org/en-US/docs/WebAssembly)) -> javascript code -> Websocket Server. The game is written in C++ and uses [embind](https://emscripten.org/docs/porting/connecting_cpp_and_javascript/embind.html) to export C++ functions to javascript and allow javascript functions to be called within C++ code. This is the magic layer that allowed them to re-release this game in the browser, they basically wrote functions for receiving keyboard input, WebGL rendering code and websocket network code to make it all work. Pretty neat solution and an impressive result.

Once I was able to get fragments of the XOR key with the function above I then search through the entire memory of the web assembly module for the fragments:

```javascript
window.findHexValue = (hexValue, flipEndian = false) => {
  const wasmMem = exports.ic.buffer; //Web assembly memory
  const dataView = new DataView(wasmMem);
  const values = hexToNumbers(hexValue, flipEndian);

  let matches = 0;
  for (let i = 0; i < wasmMem.byteLength - values.length; i++) {
    if (dataView.getUint8(i) !== values[matches]) {
      matches = 0;
      continue;
    }

    matches += 1;

    if (matches === values.length) {
      console.debug("Found match at", i - (matches - 1));
    }
  }

  console.log(wasmMem); //Allows me to open the memory inspector in chrome
};
```

This function prints the memory offsets for the given hex value. Here it is in action:

![Searching web assembly memory for values](/assets/meta-gaming/memory-search.png)

In this case the function found multiple occurrences of the value, however the first one contains the entire key. I'm only searching for 4 bytes of the key, so the rest of the 32 byte key is on either end. I can press the little memory icon at the end of the line that says `Arraybuffer` to open the memory inspector. Then I just enter the offset in the input at the top and it takes us to a view of the memory at that address. I have redacted the full key, not that it matters I've shown you how to extract it. The chrome debugging tools are actually amazing, being able to check the memory of a live running web assembly module with that fantastic interface is insane. Now we have the key we can intercept all the websocket messages going to and from the server and decode them. I whack the following code in before any other game related javascript runs in the browsers:

```javascript
const OriginalWebSocket = window.WebSocket;

window.WebSocket = function (...args) {
  console.debug("Intercepted WebSocket creation:", args);

  const ws = new OriginalWebSocket(...args);
  const originalSend = ws.send;

  ws.send = function (data) {
    window.socketSendHandler(data); //Send function that I wrote
    return originalSend.call(this, data);
  };

  ws.addEventListener("message", (event) => {
    if (typeof window.socketMessageHandler !== "undefined") {
      window.socketMessageHandler(event); //Receive function that I wrote
    }
  });

  return ws;
};
```

This basically wraps the built in Websocket object the browser provides, the same shenanigans they were using on the `console` object from the beginning of this post. This is what the handler looks like that intercepts received messages so we can execute actions when things happen:

```javascript
window.socketMessageHandler = (event) => {
  /** @type ArrayBuffer */
  const data = event.data;
  const view = new DataView(data);
  const messageId = view.getInt32(1, true);

  const decoded = decode(data, true);

  // mob moves
  if (messageId === 54) {
    handleMobPosUpdate(decoded);
  }
};
```

At this point we almost have everything we need for our bot, we can listen to events from the server, decode them and use the same technique to encode messages we send. There are a few hurdles left in our way however, lets take a closer look at the decoded messages:

```
redacted ffe30946acd6bb4274bc8745 5a01 0237 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted 9fe40946abd6bb4244cb8745 5a01 1237 0000 70ef2e4300000000 01 595d7562ce936511
redacted 9fe40946abd6bb4244cb8745 5a01 1337 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 63e40946abd6bb42b6c58745 5a01 1937 0000 6c78b14300000000 01 cf98dcc5ada2c70d
redacted 3be40946acd6bb4202c28745 5a01 2337 0000 6c78b14300000000 01 f06190834070c698
redacted 3be40946acd6bb4202c28745 5a01 2437 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted b3e40946abd6bb421ecd8745 5a01 3037 0000 70ef2e4300000000 01 50aadfcbcdcbaaa4
redacted b3e40946abd6bb421ecd8745 5a01 3437 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 63e40946abd6bb42b6c58745 5a01 3c37 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted 95e40946abd6bb4257ca8745 5a01 6137 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted 67e50946abd6bb42c8dd8745 5a01 7637 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 0de50946abd6bb4273d58745 5a01 7f37 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted d5e50946abd6bb42f7e78745 5a01 9337 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 21e50946abd6bb424dd78745 5a01 a537 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted c1e50946abd6bb421de68745 5a01 b537 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 99e50946abd6bb4269e28745 5a01 d537 0000 6c78b14300000000 17 71a03c189b6b9d10
redacted 17e50946abd6bb4260d68745 5a01 e237 0000 70ef2e4300000000 17 71a03c189b6b9d10
redacted 35e50946abd6bb4227d98745 5a01 f737 0000 70ef2e4300000000 17 71a03c189b6b9d10
```

- `redacted` - I think this is my character ID or something
- `ffe30946 acd6bb42 74bc8745` - Three 32bit floats the x, y and z co-ordinates of my character
- `5a01` - I believe this is the current area my character is in
- `0237` - This is the current game tick, you can see it increment above, I believe this is to add randomness (more on this later)
- `0000` - Unknown, seems to always be 0
- `70ef2e4300000000` - The mob id, a 64bit integer
- `17` - The action, Attack selected target in this case
- `71a03c189b6b9d10` - Need to figure out what this is

And this is what they look like when the messages are translated to their real meanings:

```
targetted mobId: 98005541 x: 8598.3896484375 y: 195.37403869628906 z: 4436.40625 area: 346 tick: 453 b4468a9fa514f43d
moved mobId: 1126201184 x: 8598.3896484375 y: 195.37403869628906 z: 4436.40625 area: 346 tick: 499 124c9f63e1d4bfc5
jump mobId: 1122362256 x: 8598.888671875 y: 195.164794921875 z: 4436.82177734375 area: 346 tick: 505 e1246dedf070d6f4
moved mobId: 1125543464 x: 8598.19140625 y: 193.5052032470703 z: 4439.82470703125 area: 346 tick: 595 124c9f63e1d4bfc5
moved mobId: 1100000000 x: 8599.4755859375 y: 193.8284454345703 z: 4439.62841796875 area: 346 tick: 614 124c9f63e1d4bfc5
jump mobId: 1099850240 x: 8599.724609375 y: 194.2017059326172 z: 4438.85595703125 area: 346 tick: 621 c55a7a1af10127ed
stopped mobId: 1099435520 x: 8596.896484375 y: 195.153076171875 z: 4436.97900390625 area: 346 tick: 699 767ddcbccf07e0a9
```

So far we've only looked at the decoded portion of the message, however all messages include a header that looks like this: `1f 27000000 ce0c0399`

- `1f` - Sent message as mentioned earlier
- `27000000` - Message type (targeting)
- `ce0c0399` - CRC value

This part is problematic, we need to be able to send a real [CRC](https://en.wikipedia.org/wiki/Cyclic_redundancy_check) to the server, if this is incorrect the server will almost certainly reject my messages (I never tested this as I didn't want my account to potentially get flagged). This is intentionally made random based on the contents of the message so it can be verified when receiving the message. I tested a bunch of CRC algorithms to see if it was a common off the shelf implementation but couldn't find a match (though there were some hints it was derived from [crc32c](https://github.com/google/crc32c)).

Finding out how the CRC was generated required some serious devilry. It originates from the game client's web assembly module, adding a break point in our message sending handler allows us to see which web assembly functions get called prior to sending the messages.

![Javascript and web assembly call stack on break point](/assets/meta-gaming/call-stack.png)

We traverse up the call stack until we find something that looks interesting:

![The characters decoded position visible in local variables](/assets/meta-gaming/call-stack-decoded-messages.png)

The raw positional data for our character is visible in the local variables of that function, so one of the subsequent functions likely does the network message encoding. Going back down one function I found bunch of pointers on the local stack, looking up the memory for each of them I discovered the encoded message available in memory. So somewhere in this function the actually encoding was happening, this actually took hours to figure out, trawling through all the variables and memory addresses, setting break points and stepping through the web assembly binary to see what changes.

![The encoded network packet in web assembly memory](/assets/meta-gaming/encoded-message-in-memory.png)

The highlighted breakpoint in the image above is the function that writes to that memory address. Prior to `$func2809` running the memory at `30103656` has the unencoded message and after it has the encoded message including the CRC value. Lets take a closer look at `$func2809` so we can figure out how the encoding and checksum work:

![Web assembly code that XOR's the packet and writes the checksum](/assets/meta-gaming/wasm-encoding-loop.png)

This code is basically a for loop that iterates over each byte of the packet. The red box looks up the XOR key and XOR's the current byte. `317488` is the memory address of the outbound XOR key.

The blue box generates the checksum. It's interesting that both the encoding and checksum get generated in the same `for` loop, this makes me think that my suspicion of a custom CRC implementation may be true. `$var1` is the checksum value which always starts at `-1` and each iteration updates this value. The constant `317520` is the starting address of the (CRC look up table)[https://en.wikipedia.org/wiki/Computation_of_cyclic_redundancy_checks#Multi-bit_computation_using_lookup_tables].

Finally, the yellow box writes the checksum (`$var1`) to the correct position in the packet, the 5th byte.

Initially I thought I could maybe call this function from outside the web assembly module to generate a correct packet. I even discovered I can easily write memory to the web assembly module's address space using their own binding tool 'embind':

```
const buf = Module._malloc(20);
const data = new Uint8Array([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20])
Module.HEAPU8.set(data, buf);
Module._free(buf);
```

Pretty neat, however there are two problems, the encoding function isn't exported by the module (I could modify the binary and export it myself). Additionally, the pointer that gets passed into the function is quite complicated and it would be really hard to fake all the data inside. There is a bunch of other stuff `$func2809` does above the small part I screen shot. I quickly abandoned this idea and decided to just reimplement the checksum part of the function myself in javascript, so I wrote a small script to dump the lookup table:

```
const view = new DataView(Module.asm.ic.buffer, 317520);
const table = [];
for(let i = 0; i < 256; i++) {
    const val = view.getUint32(i * 4, true);
    table.push(val);
}
```

I simply ran this from the Chrome console and it outputs the following: `(256) [0, 4067132163, 3778769143, 324072436, 3348797215, 904991772, 648144872 ....]`, googling some of these numbers leads you to google's crc32c implementation which led me to believe it was based off of that. Now that I have all the constants I extended my own XOR decoder function to generate the CRC:

```javascript
let checksum = -1;
for (let i = 1; i < view.byteLength; i++) {
  // XOR decode portion omitted

  //calculate checksum
  let offset = checksum ^ value;
  offset = offset & 255;
  offset = offset << 2;

  const tableValue = table[offset / 4]; //our table is already u32 aligned
  const nextValue = checksum >>> 8;

  checksum = tableValue ^ nextValue;
}
const hexChecksum = (checksum >>> 0).toString(16).padStart(8, "0");
```

Amazingly this pretty much worked first go, I now have the checksum generating for every outbound packet and I can easily verify it by testing it against the real messages!

### To be continued...

The next step is to figure out the last section of the targeting packets and then I can start sending messages to the server
