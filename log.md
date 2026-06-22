Nasdaq Notes -- Research Log


Day One: 

The first day, like most new tasks, was mostly about figuring out what the assignment involved and getting a feel for the landscape. First of all, what is Canton? I was not familiar with it at all. Second, what is the development like on Canton? Do they use Solidity? Do they use Foundry. As it turns out, no to both. Once I discovered Daml, my next questions were all about how it worked, and what a contract looked like in it. I was mostly trying to wrap my head around how I could compare this to the EVM and Solidity. Below are my thoughts as I was actually learning and reading about Canton and Daml. These were taken as a stream of consciousness:

- The project seemed fairly straightforward until I realized that there was a completely new language involved. Little experience with functional programming languages. 

- There seems to be a complete ecosystem of tooling I have not yet seen. Presumably there is a different VM that the Canton Network runs on? 

- I need to figure out what Canton has going on, how it works, and anything about the ecosystem that might help me here. 
    - I've loaded up the [docs](https://docs.canton.network/appdev/get-started/choose-your-path) and gotten my bearings a bit. Going to ask Claude about the VM since I don't see anything obvious in the docs about how it works under the hood. The docs are fairly extensive though so I will probably take the first couple of hours to read about the chain and tooling.

- Discovered the [daml-finance](https://github.com/digital-asset/daml-finance) repo. Is this useable? Maybe as a baseline and for reference.

- I'm going to set up a small demo project so I can get a feel for the language, the syntax, and the tooling. HelloWorld.daml, basically. Is there syntax highlighting for vim? I hope so.

- Ok, I got a Hello World compiling. Need to figure out how to "run" this, or whatever the equivalent here would be. Deploy/read? How does `dpm` work?


Day Two: 

After spending about an hour or two on the first day mostly researching and getting a basic project set up, I wanted to dive into more and learn about Daml and how to write it. Functional programming is not something I am very familiar with, so the syntax was, uh, quite jarring, to say the least. Even after reading the docs, I was still very confused about what was going on, and I know that the best way to learn something is to simply just try it out. My goal for the second session of work was to answer the question, "How do Daml contracts fit together?" Below are my thoughts for day two: 

- I have about an hour in the morning to do some more research, going to see what exists out there already and how Daml programs are generally laid out and so some more research on the ecosystem. 

- Discovered CIP-56 Standard. This is the recommended path it seems? I might specifically ignore this for the purposes of this demo, just to figure out how a daml contract actually works. If I wanted to learn how an ERC20 worked I would not use the ERC20 standard, I would make my own to get a feel for the layout. I'll do the same here.

- Making a small throwaway project so I can learn the ins and outs of Daml. Small, 30-45 mins of work.  
    - Looking up patterns in Daml, it seems propose-accept is recommended for multi-party agreements, which this assignment would fall under since there are at least 2 parties at play here.
    - My mental model is still a bit fuzzy, so building out a small throwaway should solidify some of these newer concepts.
    - Looks like we need a contract for the stock itself, and maybe one to create it? Not sure how you actually mint on Canton...
    - Roles are assignable right in the language, which is cool. I like that. RBAC is such a pain on the EVM side. 
    - I need to allowlist someone to receive funds. What does that even mean? 
    - Ah, after some more research, it looks like this is probably not a whitelist, but some kind of Accept like in the Propose-Accept pattern. I wonder if I can just use that?
    - Maybe I can have the issuer create the stock, and then the end user would accept it? Can they accept ownership directly on the stock contract?
    - I don't think that is the right pattern... Claude found me a couple of new links to explore, I think I need a wrapper of some kind that creates an Account. The user has to Accept the proposal, which is a contract itself, which then creates the Account for them, which can be minted shares. I think that's right? That still doesn't make a lot of sense though. 
    - I have the contracts compiling, need the script to put it all together now. Not sure of the canonical way to do this in daml... do I just run a script? Can I even do that here?
    - Ah, I seem to have found the pyramid of testing strategies in the docs. This is probably what I should use for the demo. Unit tests, integration tests, and some kind of api interface for the actual prototype demonstration. Looks like you can run scripts and that is even how you test. Interesting.

Day Three

After making solid progress on the contracts on day two, I decided that for day three I wanted to see how to actually interact with them. How would I connect to the ledger like we would on the EVM, and how would I sent calls to functions, update state, etc? The documentation on the canton network site has a whole page about fullstack applications, and a REST API I could take advantage of to interact with them. This was pretty similar to older tooling that was around in EVMland when I got started back in the day, like Hardhat and Truffle, so this felt familiar enough to try and work with. The docs were very descriptive, and I just kinda used them to work my way through setting up and creating the demo. Querying was the thing that I had the most trouble with, reading state on Canton was quite difficult. The difference between getting a balance on Canton and EVM is night and day! I'm still not totally sure how the ledger system offset works entirely. I really wanted to figure out how to interact with the network like I would if I wanted to let end users interact with contracts that were deployed there, like we do on Ethereum or L2s. Below are my thoughts for day three:

- I have another hour or so this morning to get some work done, going to be reading the docs mostly to see how to put a service together and actually interact with the canton network and contracts deployed on there without just relying on using the script interface. 

- I managed to get the contracts running and some unit tests passing. The entire toolchain is new to me and I'm honestly not quite sure what is correct/standard, but following along the docs has been a reasonably pleasant experience. 
  
- It looks like there is a JSON API I can use to interact with deployed contracts, I'm not sure this is needed for this but I think it would be easier to demonstrate than running a `dpm script` command and might help me learn more about the network, so I will get that going. 
  
- looks like I'll need a wrapper around the create contract and ExerciseCommand endpoints. This comes from the docs after running the localnet: http://localhost:<port>/docs/openapi

- I am not using Typescript here or Java due to my inexperience with them, I should be able to use anything that has an http library though since we are just sending get/post requests. 
  
- I've now managed to get a working demo in Zig in a couple hours. That proved to be quite enlightening, I am glad I went down that path. The demo is quite small, I wonder if there needs to be more here? 
  
- I've added dividend distribution in the contrats in one form because I was curious how they would work, but I've opted not to include it in the demo or test suite and leave it as something that I explored but didn't test since it was not explicity asked for. I was mostly curious about how the strucutre would look, like if we push or pull the data on Canton since on EVM this would be pull based or you'd need an off-chain distribution system to send shares to accounts that hold x tokens at y point in time.

- Overall this was a good time, I enjoyed learning about Canton, though I'm not sure I entirely understand how to make production grade contracts quite yet, this was a nice introduction. I would be interested to see much more you can do with this model, as it's quite a deviation from Ethereum.



Citations: 

1) https://docs.canton.network/appdev/modules/m3-dev-environment and the rest of the docs
2) https://www.canton.network/blog/what-is-cip-56-a-guide-to-cantons-token-standard and https://github.com/canton-foundation/cips/blob/main/cip-0056/cip-0056.md
3) https://github.com/digital-asset/daml-finance
4) https://docs.daml.com/daml/patterns/propose-accept.html 
5)  
