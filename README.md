# Portfolio App - The Interactive CV 🚀

Recruitment can be dry. PDFs are static. I wanted to make the process of "updating my CV" a bit more entertaining—both for me and for anyone hiring. 

**This isn't a polished product launch.** It's a creative playground built to show what's possible with a little bit of time between the holidays and a desire to learn cool new tech.

## Why did I build this? 🤷‍♂️

1.  **To escape the classic CV**: Static CVs are boring. I wanted a format that feels alive and responds to all the questions a recruiter might have. 
2.  **To make recruitment fun**: Tech interviews are serious enough. The application process shouldn't be boring.
3.  **To learn the fun stuff**: I wanted to dive into **Metal Shaders** (making things gloopy) and **On-Device AI** (making things smart) without burning cloud credits.
4.  **To experiment**: A challenge to myself to see how interactive and creative a mobile CV app might become compared to a static website or document. 
5.  **To broaden my horizons**: I admittedly used AI for some features (like parts of the Metal code). But that is the point: to use AI to broaden one's horizons and learn new things.

## Tech Stack 🛠️

*   **SwiftUI**: The declarative backbone of the app.
*   **Metal Shaders 🤘**: See that lava lamp effect? That's raw Metal ([LavaShaders.metal](Portfolio-App/LavaShaders.metal)) handling the fluid rendering.
*   **Apple Foundation Models 🧠**: Experimental integration of local, on-device LLMs.

## The Chat Assistant 🤖

I added a digital proxy of myself to the app. It's built in [ChatService.swift](Portfolio-App/ChatService.swift).

*   **100% On-Device**: It uses Apple's Foundation Models. No data leaves your phone.
*   **Zero API Keys**: You don't need an OpenAI key or a cloud subscription.

## Requirements 📋

*   **Xcode**: Recent enough to build for iOS 17+ (ensure Metal tools are installed via Xcode).
*   **Target**: iOS 17.0+.

## How to run it 🏃

1.  **Clone it**: `git clone <repo-url>`
2.  **Open it**: Double-click `Portfolio-App.xcodeproj`.
3.  **Run it**: Select your simulator or device and hit **Run** (▶️).
4.  **Enjoy the blobs**: Look at the liquid glass lava menu. It's satisfying.

## License ⚖️

This project is licensed under **Creative Commons Attribution-NonCommercial 4.0 International (CC BY-NC 4.0)**. 

*   **Attribution**: If you use this, please credit **Pascal Fischer** (link to this repo or [p-f.consulting](https://www.p-f.consulting)).
*   **Non-Commercial**: Don't sell it. It's for fun! But if you do find a way, ask for permission ;-)

## Contact 📬

*   **Email**: fischer@p-f.consulting
*   **Web**: [p-f.consulting](https://www.p-f.consulting)
