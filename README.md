# Spotify-Premium-O-CARALHO

We all love Spotify, but sometimes people (like us) want to listen to our songs without having bought [Spotify Premium](https://www.spotify.com/premium/). Well, with this killer project, now you can!

**This is for testing purposes ONLY!** Spotify is a fantastic service and worth every penny. This script is **NOT** meant to circumvent buying premium! Please do consider switching to premium to support Spotify - especially if you're going to use it on mobile. If the script does not work for you, help us improve it!

### Dependencies

Utilities used in the script:
  - xprop
  - pacmd
  - xdotool
  - arecord
  - lame

[![openSUSE](https://news.opensuse.org/wp-content/uploads/2014/11/468x60.png)](http://www.opensuse.org/)

Install all utilities + VLC on **[openSUSE](http://www.opensuse.org/)** with:

    sudo zypper in binutils pulseaudio-utils xdotool alsa-utils lame

[![Ubuntu](http://spreadubuntu.neomenlo.org/files/banner-468x60.png)](http://www.ubuntu.com/)

Install all utilities + VLC on **[Ubuntu](http://www.ubuntu.com/)** with:

    sudo apt-get install x11-utils pulseaudio-utils xdotool alsa-utils lame

### Installation

**Automated Installation**

Grab the latest release:

    git clone https://github.com/kingarthurpt/spotify-premium-o-caralho.git

Run the provided installer:

    cd spotify-premium-o-caralho
    chmod u+x spotify-premium-o-caralho.sh

**Troubleshooting**

- This project has been tested to work with Spotify 1.0.38. If you run into any bugs while using it please report them on the bug tracker.

- If you've installed Spotify from any source other than the official repository please make sure that the `spotify` executable is in your `PATH`.

    You can create a symbolic link, if necessary (e.g. linking `my-spotify` to `spotify` if you are using the user installation of [spotify-make](https://github.com/leamas/spotify-make)).

### Usage

1. Open Spotify
2. Execute ```./spotify-premium-o-caralho.sh```

### License

This project was forked from [Spotify-AdKiller](https://github.com/SecUpwN/Spotify-AdKiller).
Thanks to everyone who contributed to that project.

If you are like us and think that it is very sad when projects die, please accept that all code here is fully licensed under GPL v3+. Have a look at the full [License](https://github.com/kingarthurpt/spotify-premium-o-caralho/blob/master/LICENSE). Contribute pull requests!

**This product is not endorsed, certified or otherwise approved in any way by Spotify. Spotify is the registered trade mark of the Spotify Group. Use your brainz prior to formatting your HDD.**
